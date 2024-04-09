import Network
import Foundation
import BrightcovePlayerSDK

@available(iOS 12.0, *)
class MediaService {
    let setup : BrightcoveSetup
    let downloadService: DownloadService
    
    init(setup: BrightcoveSetup, downloadService: DownloadService) {
        self.setup = setup
        self.downloadService = downloadService
    }
    
    public func getMetadata(fileId: String?) throws -> [String: Any] {
        guard let fileId = fileId else {
           throw CustomError(PluginError.MISSING_FILEID, "MediaService.getMetadata: Need fileId to get Metadata")
       }
        
        // If available locally, try to get metadata from storage, otherwise get data from online catalog.
        if(try self.downloadService.isMediaAvailableLocally(fileId: fileId)) {
            return try self.getOfflineMetadata(fileId: fileId)
        } else {
            return try self.getOnlineMetadata(fileId: fileId)
        }
    }
    
    private func getOfflineMetadata(fileId: String) throws -> [String: Any] {
        guard let media: BCOVVideo = BCOVOfflineVideoManager.shared()?.videoObject(fromOfflineVideoToken: try self.downloadService.getTokenFromMediaId(fileId: fileId)) else {
            throw CustomError(PluginError.FILE_NOT_EXIST_AND_NO_INTERNET, "MediaService.getOfflineMetadata: The plugin needs an internet connection or the media to be downloaded to access the metadata (fileId: \(fileId)")
        }
        
        return try self.getMetadata(media: media, downloaded: true)
    }
    
    private func getOnlineMetadata(fileId: String) throws -> [String: Any] {
        if(!NetworkService.isConnected) {
            throw PluginError.FILE_NOT_EXIST_AND_NO_INTERNET
        }

        var media: BCOVVideo? = nil
        var mediaError: Error? = nil
        let group = DispatchGroup()
        group.enter()

        setup.playbackService.findVideo(withVideoID: fileId, parameters: nil)  { (video: BCOVVideo?, jsonResponse: [AnyHashable: Any]?, error: Error?) -> Void in
            if(error != nil) {
                mediaError = error!
            } else if let mediaFound = video {
                media = mediaFound
            } else {
                mediaError =  CustomError(PluginError.FILE_NOT_EXIST, "MediaService.getOnlineMetadata: File not found in the online brightcove catalog (fileId: \(fileId)")
            }
            group.leave()
        }

        group.wait()

        if(mediaError != nil) {
            throw mediaError!
        }

        return try self.getMetadata(media: media!, downloaded: false)
    }
    
    private func getMetadata(media: BCOVVideo, downloaded: Bool) throws -> [String: Any] {
        return [
            "mediaId": media.properties[kBCOVVideoPropertyKeyId] ?? "",
            "title": media.properties[kBCOVVideoPropertyKeyName] ?? "",
            "totalMillis": media.properties[kBCOVVideoPropertyKeyDuration] ?? 0,
            "thumbnail":  downloaded ? media.properties["offline_thumbnail"] ?? "" : media.properties[kBCOVVideoPropertyKeyThumbnail] ?? "",
            "posterUrl": downloaded ? media.properties["offline_poster"] ?? "" : media.properties[kBCOVVideoPropertyKeyPoster] ?? "",
            "downloaded": downloaded,
            "fileSize": downloaded ? try self.downloadService.getDownloadedSize(media: media) : try self.downloadService.getDownloadSize(media: media),
            "subtitles": self.getTextTracksList(media: media)
        ]
    }
    
    private func getTextTracksList(media: BCOVVideo) -> [[String:String]] {
        var tracksList: [[String: String]] = []
        
        guard let textTracks = media.properties[kBCOVVideoPropertyKeyTextTracks] as? [[String: Any]] else {
            return []
        }
                
        for textTrack in textTracks {
            let srclang = textTrack["srclang"] ?? ""
            let src = textTrack["src"] ?? ""
            
            if(srclang is NSString) {
                tracksList.append([
                    "language": srclang as! String,
                    "src": src as! String
                ])
            }
        }

        return tracksList
    }
}
