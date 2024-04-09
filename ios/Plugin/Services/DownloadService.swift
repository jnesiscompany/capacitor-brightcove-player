import UIKit
import BrightcovePlayerSDK
import Network

struct VideoDownload {
    let video: BCOVVideo
    let paramaters: [String:Any]
}

@available(iOS 12.0, *)
class DownloadService: NSObject {
    private var videoPreloadQueue: [VideoDownload] = []
    private var videoDownloadQueue: [VideoDownload] = []
    private var downloadInProgress = false
    
    private var videoToDownload: BCOVVideo?
    weak var delegate: ReloadDelegate?
    static var shared = DownloadService()
    private var setup: BrightcoveSetup?

    override init() {
        super.init()
        BCOVOfflineVideoManager.initializeOfflineVideoManager(
            with: self,
            options: [
                kBCOVOfflineVideoManagerAllowsCellularDownloadKey: true,
                kBCOVOfflineVideoManagerAllowsCellularPlaybackKey: true,
                kBCOVOfflineVideoManagerAllowsCellularAnalyticsKey: true
            ])
    }
    
    func setSetup(setup: BrightcoveSetup) -> Void { self.setup = setup }
    
    func deleteAllDownloadedMedias() throws -> Void {
        guard let brightcoveOfflineManager = BCOVOfflineVideoManager.shared() else {
            throw CustomError(PluginError.TECHNICAL_ERROR, "DownloadService.deleteAllDownloadedMedias : Cannot get BCOVOfflineVideoManager")
        }

        for offlineVideoStatus in brightcoveOfflineManager.offlineVideoStatus() {
            guard let token = offlineVideoStatus.offlineVideoToken else {
                continue
            }
            
            brightcoveOfflineManager.deleteOfflineVideo(token)
            
            self.downloadEvent(state: [
                "mediaId": self.getMediaIdFromToken(token: token),
                "status": DownloadState.DELETED.rawValue
            ])
        }
    }
    
    func deleteDownloadedMedia(fileId: String?) throws -> Void {
        guard let id = fileId else {
            throw PluginError.MISSING_FILEID
        }
        let tokenToDelete = try self.getTokenFromMediaId(fileId: id)
        if(tokenToDelete == "") {
            throw CustomError(PluginError.DOWNLOADED_FILE_NOT_FOUND, "DownloadService.deleteDownloadedMedia: Media id not found in the download list (fileId: \(id)")
        }
        
        BCOVOfflineVideoManager.shared()?.deleteOfflineVideo(tokenToDelete)
        self.downloadEvent(state: [
            "mediaId": id,
            "status": DownloadState.DELETED.rawValue
        ])
    }
    
    func getDownloadedMediasState() throws -> [[String: Any]] {
        var videosStatus: [[String: Any]] = []
        guard let brightcoveOfflineManager = BCOVOfflineVideoManager.shared() else {
            throw CustomError(PluginError.TECHNICAL_ERROR, "DownloadService.getDownloadedMediasState : Cannot get BCOVOfflineVideoManager")
        }
        
        for offlineVideoStatus in brightcoveOfflineManager.offlineVideoStatus() {
            guard let token = offlineVideoStatus.offlineVideoToken else {
                throw CustomError(PluginError.TECHNICAL_ERROR, "DownloadService.getDownloadedMediasState : Cannot get offlineVideoToken")
            }
            guard let video = brightcoveOfflineManager.videoObject(fromOfflineVideoToken: token) else {
                throw CustomError(PluginError.TECHNICAL_ERROR, "DownloadService.getDownloadedMediasState : Cannot get video from videoObject")
            }
            let size = try getDownloadedSize(media: video)
            
            var videoStatus = [
                "mediaId": video.properties[kBCOVVideoPropertyKeyId]!,
                "status": try self.getDownloadState(state: offlineVideoStatus.downloadState).rawValue
            ]
            
            if(size != -1) {
                videoStatus["estimatedSize"] = size
            }
            
            videosStatus.append(videoStatus)
        }
        
        return videosStatus
    }
    
    private func getMediaIdFromToken(token: String) -> String {
        guard let mediaId = BCOVOfflineVideoManager.shared()?.videoObject(fromOfflineVideoToken: token) else {
            return ""
        }
        
        guard let token = mediaId.properties[kBCOVVideoPropertyKeyId] else {
            return ""
        }
        
        return token as! String
    }
    
    func getTokenFromMediaId(fileId: String) throws -> String {
        guard let brightcoveOfflineManager = BCOVOfflineVideoManager.shared() else {
            throw CustomError(PluginError.TECHNICAL_ERROR, "DownloadService.getTokenFromMediaId : Cannot get BCOVOfflineVideoManager")
        }

        for offlineVideoStatus in brightcoveOfflineManager.offlineVideoStatus() {
            guard let token = offlineVideoStatus.offlineVideoToken else {
                return ""
            }

            let downloadedFileId = getMediaIdFromToken(token: token)
            if (downloadedFileId == fileId) {
                return token
            }
        }
        return ""
    }

    func isMediaAvailableLocally(fileId: String?) throws -> Bool {
        guard let id = fileId else {
            throw PluginError.MISSING_FILEID
        }
        let token = try self.getTokenFromMediaId(fileId: id)
        
        if(token == "") {
            return false
        } else {
            // This is OK because getTokenFromMediaId->getMediaIdFromToken guarantees that videoObject is OK
            return self.isVideoDownloaded((BCOVOfflineVideoManager.shared()?.videoObject(fromOfflineVideoToken: token))!)
        }
    }
    
    func download(fileId : String, completion: @escaping ((any Error)?) -> Void) {

        if(fileId.isEmpty) {
            return completion(CustomError(PluginError.MISSING_FILEID, "DownloadService.download: Missing fileId to start download"))
        }

   
        if(!NetworkService.isConnected) {
            return completion(CustomError(PluginError.NO_INTERNET_CONNECTION,"NetworkService.checkIfOnline: Need internet connection to do this action"))
        }
        

        self.setup!.playbackService.findVideo(withVideoID: fileId, parameters: nil) { (video: BCOVVideo?, jsonResponse: [AnyHashable: Any]?, error: Error?) -> Void in
            if(error != nil) {
                return completion(error)
            }
            
            if(video == nil) {
                return completion(CustomError(PluginError.TECHNICAL_ERROR, "DownloadService.download: There is no video to download"))
            } else {
                if(!video!.canBeDownloaded) {
                    completion(CustomError(PluginError.VIDEO_CANT_BE_DOWNLOADED, "DownloadService.download: Check if this media can be downloaded in the brightcove administration panel (mediaId: \(fileId))"))
                }
                
                if(!self.videoAlreadyProcessing(video!)) {
                    self.downloadEvent(state: ["mediaId":fileId,"status": DownloadState.REQUESTED.rawValue])
                    self.doDownload(forVideo: video!)
                }
            }
            return completion(nil)
        }
    }
    
    func doDownload(forVideo video: BCOVVideo) {
        if videoAlreadyProcessing(video) {
            return
        }
        
        let downloadParamaters = DownloadService.generateDownloadParameters()
        let videoDownload = VideoDownload(video: video, paramaters: downloadParamaters)
        videoPreloadQueue.append(videoDownload)
        
        runPreloadVideoQueue()
    }

    private func languagesArrayForAlternativeRenditions(attributesDictArray: [[AnyHashable:Any]]?) -> [String] {
        // We want to download all subtitle/audio tracks
        guard let attributesDictArray = attributesDictArray else {
            return []
        }

        // Collect all the available subtitle languages in a set to avoid duplicates
        var languageSet = Set<String>()
        for attributeDict in attributesDictArray {
            if let typeString = attributeDict["TYPE"] as? String, let langString = attributeDict["LANGUAGE"] as? String {
                if typeString == "SUBTITLES" {
                    languageSet.insert(langString)
                }
            }
        }
        
        let languagesArray = Array(languageSet)
        // For debugging: display the languages we found
        var languagesString = String()
        var first = true
        for languageString in languagesArray {
            // Add comma before each entry after the first
            if first {
                first = false
            } else {
                languagesString = languagesString + ", "
            }
            
            languagesString = languagesString + languageString
        }
        
        print("Brightcove plugin: Languages to download: \(languagesString)")
        
        return languagesArray
    }
    
    func isVideoDownloaded(_ video: BCOVVideo) -> Bool {
        guard let offlineVideoTokens = BCOVOfflineVideoManager.shared()?.offlineVideoTokens else {
            return false
        }
        
        for offlineVideoToken in offlineVideoTokens {
            guard let testVideo = BCOVOfflineVideoManager.shared()?.videoObject(fromOfflineVideoToken: offlineVideoToken) else {
                continue
            }
            
            if testVideo.matches(offlineVideo: video) {
                _ = localizedNameForLocale(video, nil) ?? ""
                
                if let downloadStatus = BCOVOfflineVideoManager.shared()?.offlineVideoStatus(forToken: offlineVideoToken) {
                    return downloadStatus.downloadState == .stateCompleted
                }
            }
        }
        
        return false
    }
    
    public func getDownloadedSize(media: BCOVVideo) throws -> Int {
        guard let brightcoveOfflineManager = BCOVOfflineVideoManager.shared() else {
            throw CustomError(PluginError.TECHNICAL_ERROR, "DownloadService.getDownloadedSize : Cannot get BCOVOfflineVideoManager")
        }

        for offlineVideoStatus in brightcoveOfflineManager.offlineVideoStatus() {
            guard let token = offlineVideoStatus.offlineVideoToken else {
                throw CustomError(PluginError.TECHNICAL_ERROR, "DownloadService.getDownloadedSize : Cannot get offlineVideoToken")
            }

            guard let downloadedMedia = brightcoveOfflineManager.videoObject(fromOfflineVideoToken: token) else {
                throw CustomError(PluginError.TECHNICAL_ERROR, "DownloadService.getDownloadedSize : Cannot find offline media")
            }
            
            let downloadedMediaId = downloadedMedia.properties[kBCOVVideoPropertyKeyId]! as! String
            let mediaId = media.properties[kBCOVVideoPropertyKeyId]! as! String
            
            
            if (downloadedMediaId == mediaId) {
                let videoFilePath = downloadedMedia.properties[kBCOVOfflineVideoFilePathPropertyKey]

                // Get local file size
                if(videoFilePath != nil && self.isVideoDownloaded(media)) {
                    return FileHelper.directorySize(folderPath: videoFilePath! as! String)
                } else {
                    // Video not fully downloaded
                    return -1
                }
            }
        }
        // Video not found
        return -1
    }
    
    public func getDownloadSize(media: BCOVVideo) throws -> Int {
        var size: Double? = nil
        var sizeError: Error? = nil
        let group = DispatchGroup()
        group.enter()
        
        BCOVOfflineVideoManager.shared()?.estimateDownloadSize(media, options: [kBCOVOfflineVideoManagerRequestedBitrateKey: 0], completion: { (megabytes: Double, error: Error?) in
           if(error != nil) {
               sizeError = error!
           } else {
               size = megabytes
           }
           group.leave()
        })
        
        group.wait()
        
        if(sizeError != nil) {
            throw sizeError!
        }
        
        return Int(size! * 1000000)
    }
        
    private func videoAlreadyProcessing(_ video: BCOVVideo) -> Bool {
        // First check to see if the video is in a preload queue
        // videoPreloadQueue is an array of NSDictionary objects,
        // with a BCOVVideo under each "video" key.
        
        for videoDict in videoPreloadQueue {
            if videoDict.video.matches(offlineVideo: video) {
                return true
            }
        }
        
        // First check to see if the video is in a download queue
        // videoDownloadQueue is an array of BCOVVideo objects
        for videoDict in videoDownloadQueue {
            if videoDict.video.matches(offlineVideo: video) {
                return true
            }
        }
        
        // Next check to see if the video has already been downloaded
        // or is in the process of downloading
        guard let offlineVideoTokens = BCOVOfflineVideoManager.shared()?.offlineVideoTokens else {
            return false
        }
        
        for offlineVideoToken in offlineVideoTokens {
            guard let testVideo = BCOVOfflineVideoManager.shared()?.videoObject(fromOfflineVideoToken: offlineVideoToken) else {
                continue
            }
            
            if testVideo.matches(offlineVideo: video) {
                if let downloadStatus = BCOVOfflineVideoManager.shared()?.offlineVideoStatus(forToken: offlineVideoToken) {
                    if downloadStatus.downloadState == .stateError {
                        BCOVOfflineVideoManager.shared()?.deleteOfflineVideo(offlineVideoToken)
                        return false
                    }
                }
                return true
            }
        }
        return false
    }

    private func runPreloadVideoQueue() {
        guard let videoDownload = videoPreloadQueue.first else {
            downloadVideoFromQueue()
            return
        }
        
        let video = videoDownload.video
        
        if let indexOfVideo = videoPreloadQueue.firstIndex(where: { $0.video.matches(offlineVideo: video) }) {
            videoPreloadQueue.remove(at: indexOfVideo)
        }
        
        // Preloading only applies to FairPlay-protected videos.
        // If there's no FairPlay involved, the video is moved on
        // to the video download queue.
        if !video.usesFairPlay {
            if let videoName = localizedNameForLocale(video, nil) {
                print("Brightcove plugin: Video \"\(videoName)\" does not use FairPlay; preloading not necessary")
            }
            videoDownloadQueue.append(videoDownload)
            
            delegate?.reloadRow(forVideo: video)
            runPreloadVideoQueue()
        } else {
            BCOVOfflineVideoManager.shared()?.preloadFairPlayLicense(video, parameters: videoDownload.paramaters, completion: { [weak self] (offlineVideoToken: String?, error: Error?) in
                DispatchQueue.main.async {
                    if let error = error {
                        // Report any errors
                        self!.downloadEvent(state: [
                            "mediaId": self!.getMediaIdFromToken(token: offlineVideoToken!),
                            "status": DownloadState.FAILED.rawValue,
                            "reason": String(describing: error)
                        ])
                    } else {
                        if let offlineVideoToken = offlineVideoToken {
                            print("Brightcove plugin: Preloaded \(offlineVideoToken)")
                        }
                        self?.videoDownloadQueue.append(videoDownload)
                        self?.delegate?.reloadRow(forVideo: video)
                    }
                    
                    self?.runPreloadVideoQueue()
                }
            })
        }
    }
    
    private func getDownloadState(state: BCOVOfflineVideoDownloadState) throws -> DownloadState {
        print("Brightcove plugin: Download state : Raw value state \(state.rawValue)")
        
        switch state.rawValue {
        case 0:
            return DownloadState.REQUESTED
        case 1:
            return DownloadState.IN_PROGRESS
        case 2:
            return DownloadState.PAUSED
        case 3:
            return DownloadState.CANCELED
        case 4:
            return DownloadState.COMPLETED
        case 5:
            return DownloadState.FAILED
        default:
            throw PluginError.DOWNLOAD_STATUS_NOT_DETERMINED
        }
    }
    
    private func downloadVideoFromQueue() {
        guard let videoDownload = videoDownloadQueue.first else {
            return
        }
        
        let video = videoDownload.video
        
        if let indexOfVideo = videoDownloadQueue.firstIndex(where: { $0.video.matches(offlineVideo: video) }) {
            videoDownloadQueue.remove(at: indexOfVideo)
        }
        
        downloadInProgress = true
        
        // Display all available bitrates
        BCOVOfflineVideoManager.shared()?.variantBitrates(for: video, completion: { (bitrates: [NSNumber]?, error: Error?) in
            if let name = localizedNameForLocale(video, nil) {
                print("Brightcove plugin: Variant Bitrates for video: \(name)")
            }
            
            if let bitrates = bitrates {
                for bitrate in bitrates {
                    print("Brightcove plugin: \(bitrate.intValue)")
                }
            }
            
        })
    
        var avURLAsset: AVURLAsset?
        do {
            avURLAsset = try BCOVOfflineVideoManager.shared()?.urlAsset(for: video)
        } catch {}
        
        // If mediaSelections is `nil` the SDK will default to the AVURLAsset's `preferredMediaSelection`
        var mediaSelections = [AVMediaSelection]()
        
        if let avURLAsset = avURLAsset {
            mediaSelections = avURLAsset.allMediaSelections
            
            if let legibleMediaSelectionGroup = avURLAsset.mediaSelectionGroup(forMediaCharacteristic: .legible), let audibleMediaSelectionGroup = avURLAsset.mediaSelectionGroup(forMediaCharacteristic: .audible) {
                
                var counter = 0
                for selection in mediaSelections {
                    let legibleMediaSelectionOption = selection.selectedMediaOption(in: legibleMediaSelectionGroup)
                    let audibleMediaSelectionOption = selection.selectedMediaOption(in: audibleMediaSelectionGroup)
                    
                    let legibleName = legibleMediaSelectionOption?.displayName ?? "nil"
                    let audibleName = audibleMediaSelectionOption?.displayName ?? "nil"
                    
                    print("Brightcove plugin: AVMediaSelection option \(counter) | legible display name: \(legibleName)")
                    print("Brightcove plugin: AVMediaSelection option \(counter) | audible display name: \(audibleName)")
                    counter += 1
                }
                
            }
        }
        
        BCOVOfflineVideoManager.shared()?.requestVideoDownload(video, mediaSelections: mediaSelections, parameters: videoDownload.paramaters, completion: { [weak self] (offlineVideoToken: String?, error: Error?) in
            
            DispatchQueue.main.async {
                if let error = error, let self = self {
                    self.downloadInProgress = false
                    
                    // Report any errors
                    if let offlineVideoToken = offlineVideoToken, let offlineVideo = BCOVOfflineVideoManager.shared()?.videoObject(fromOfflineVideoToken: offlineVideoToken), let _ = localizedNameForLocale(offlineVideo, nil) {
                        self.downloadEvent(state : [
                            "mediaId":self.getMediaIdFromToken(token: offlineVideoToken),
                            "status": DownloadState.FAILED.rawValue,
                            "reason": String(describing: error)
                        ])
                    }
                }
            }
        })
    }
}

// MARK: - Class Methods
@available(iOS 12.0, *)
extension DownloadService {
    class func generateDownloadParameters() -> [String:Any] {
        var downloadParameters : [String: Int] = [:]
        downloadParameters[kBCOVOfflineVideoManagerRequestedBitrateKey] = 0
        
        return downloadParameters
    }
}

// MARK: - BCOVOfflineVideoManagerDelegate
@available(iOS 12.0, *)
extension DownloadService: BCOVOfflineVideoManagerDelegate {
    
    func didCreateSharedBackgroundSesssionConfiguration(_ backgroundSessionConfiguration: URLSessionConfiguration!) {
        // Helps prevent downloads from appearing to sometimes stall
        backgroundSessionConfiguration.isDiscretionary = false
    }
        
    // Download in progress
    func offlineVideoToken(_ offlineVideoToken: String!, aggregateDownloadTask: AVAggregateAssetDownloadTask!, didProgressTo progressPercent: TimeInterval, for mediaSelection: AVMediaSelection!) {
        if let offlineVideoToken = offlineVideoToken {
            self.downloadEvent(state: [
                "mediaId": self.getMediaIdFromToken(token: offlineVideoToken),
                "status": DownloadState.IN_PROGRESS.rawValue,"progress": String(progressPercent)
            ])
        }
    }
    
    // Download complete
    func offlineVideoToken(_ offlineVideoToken: String?, didFinishDownloadWithError error: Error?) {
        if let error = error {
            self.downloadEvent(state : [
                "mediaId": self.getMediaIdFromToken(token: offlineVideoToken!),
                "status": DownloadState.FAILED.rawValue,
                "reason": String(describing:error)
            ])
        } else if let media: BCOVVideo = (BCOVOfflineVideoManager.shared()?.videoObject(fromOfflineVideoToken: offlineVideoToken)) {
            do {
                let downloadedSize = try self.getDownloadedSize(media: media)
                self.downloadEvent(state : [
                    "mediaId": self.getMediaIdFromToken(token: offlineVideoToken!),
                    "status": DownloadState.COMPLETED.rawValue,
                    "estimatedSize": downloadedSize
                ])
            } catch {
                self.downloadEvent(state : [
                    "mediaId": self.getMediaIdFromToken(token: offlineVideoToken!),
                    "status": DownloadState.FAILED.rawValue,
                    "reason": "DownloadService.offlineVideoToken: Can't get downloadedSize"
                ])
            }
        } else {
            self.downloadEvent(state : [
                "mediaId": self.getMediaIdFromToken(token: offlineVideoToken!),
                "status": DownloadState.FAILED.rawValue,
                "reason": "DownloadService.offlineVideoToken: Media not available"
            ])
        }
        
        downloadInProgress = false
    }

    // download event fired to the plugin
    private func downloadEvent(state: [String : Any]) {
        NotificationCenter.default.post(
            name: Notification.Name("downloadStateChange"),
            object: nil,
            userInfo: state
        )
    }
}

enum DownloadState: String {
    case REQUESTED = "REQUESTED"
    case IN_PROGRESS = "IN_PROGRESS"
    case PAUSED = "PAUSED"
    case CANCELED = "CANCELED"
    case COMPLETED = "COMPLETED"
    case DELETED = "DELETED"
    case FAILED = "FAILED"
}

