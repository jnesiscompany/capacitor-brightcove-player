import UIKit
import AVKit
import BrightcovePlayerSDK

@available(iOS 12.0, *)
public class BrightcoveVideoPlayerViewController: UIViewController {
    
    let setup: BrightcoveSetup
    var playbackController: BCOVPlaybackController?
    var videoId: String
    var token: String? = nil
    var subtitle: String
    var nowPlayingHandler: BrightcoveVideoPlayerNowPlayingHandler?
    
    var currentProgress: TimeInterval?
    var currentSession: BCOVPlaybackSession?
    var duration: Int = 0
    var playerView: BCOVPUIPlayerView?
    let closeButton = UIButton(type: .custom);
    var closeVideoCalled = false
    var readyToUpdateSubtitle = false
    var currentProgressMillis: Int = 0
    var startPosition: Int = 0

    static var shared = DownloadService()

    required init?(coder: NSCoder) {
        fatalError(PluginError.NOT_IMPLEMENTED.rawValue)
    }

    init(setup: BrightcoveSetup, startPosition: Int, videoId: String, subtitle: String) {
        self.currentProgress = 0
        self.setup = setup
        self.videoId = videoId
        self.startPosition = startPosition
        self.subtitle = subtitle
        self.token = nil

        super.init(nibName: nil, bundle: nil)

        self.playbackController = (setup.sharedSDKManager.createPlaybackController())!

        if(super.modalPresentationStyle != .fullScreen) {
            super.modalPresentationStyle = .fullScreen
        }

        playbackController?.delegate = self
        playbackController?.isAutoAdvance = true
        playbackController?.isAutoPlay = true
        playbackController?.allowsBackgroundAudioPlayback = true
        playbackController?.allowsExternalPlayback = true
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        let gesture = UISwipeGestureRecognizer(target: self, action: #selector(closeVideo))
        gesture.direction = .down
        view.isUserInteractionEnabled = true
        view.addGestureRecognizer(gesture)

        let options = BCOVPUIPlayerViewOptions()
        options.showPictureInPictureButton = true

        // Set up our player view. Create with a standard VOD layout.
        guard let playerView = BCOVPUIPlayerView(playbackController: self.playbackController, options: options, controlsView: BCOVPUIBasicControlView.withVODLayout()) else {
            return
        }

        self.playerView = playerView

        // Install in the container view and match its size.
        view.addSubview(playerView)
        playerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: view.topAnchor),
            playerView.rightAnchor.constraint(equalTo: view.rightAnchor),
            playerView.leftAnchor.constraint(equalTo: view.leftAnchor),
            playerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        playerView.delegate = self
        playerView.playbackController = playbackController

        self.closeButton.addTarget(self, action: #selector(closeVideo), for: .touchUpInside)
        self.closeButton.setTitle("X", for: .normal)
        self.closeButton.accessibilityLabel = "close"
        self.closeButton.setTitleColor(UIColor.white, for: .normal)
        self.closeButton.translatesAutoresizingMaskIntoConstraints = false
        playerView.controlsFadingView.addSubview(self.closeButton)

        self.playerView = playerView
        self.playerView?.performScreenTransition(with: BCOVPUIScreenMode.full)

        self.closeButton.rightAnchor.constraint(equalTo: (self.playerView?.safeAreaLayoutGuide.rightAnchor)!).isActive = true

        print("Brightcove plugin: BrightCoveVideoPlayerViewController::viewDidLoad");
        
    }

    public func pauseVideo() throws {
        if let playbackController = self.playbackController {
            playbackController.pause()
        }
    }

    public func resumeVideo() throws {
        if let playbackController = self.playbackController {
            playbackController.play()
        }
    }

    @objc
    public func closeVideo() {
        self.closeVideoCalled = true
        self.readyToUpdateSubtitle = false
        self.playbackController?.pause()
        self.currentSession?.player.replaceCurrentItem(with: nil)

        let callback = {() -> Void in
            NotificationCenter.default.post(
                name: Notification.Name("closeVideo"), object: nil,
                userInfo: [
                    "completed": self.currentProgressMillis >= self.duration,
                    "currentMillis": self.currentProgressMillis,
                    "totalMillis": self.duration,
                    "subtitle": self.subtitle
                ]
            )
        }
        self.dismiss(animated: false, completion: callback);
    }
    
    func loadVideo(local: Bool, completion: @escaping ((any Error)?) -> Void) {
        
        if(self.videoId.isEmpty) {
            return completion(CustomError(PluginError.MISSING_FILEID))
        }
        
        // Try to play downloaded video
        if(local) {
            self.token = self.getToken()
            
            if(self.token == nil && !NetworkService.isConnected) {
                return completion(CustomError(PluginError.FILE_NOT_EXIST_AND_NO_INTERNET, "token: \(String(describing: self.token)), mediaId: \(String(describing: self.videoId))"))
            }
            
            if let video = BCOVOfflineVideoManager.shared()?.videoObject(fromOfflineVideoToken: self.token) {
                self.setVideoProperties(video: video)
                self.playbackController?.setVideos([video] as NSArray)
                return completion(nil)
            }
        }
        
        // Stream online media
        self.setup.playbackService.findVideo(withVideoID: self.videoId, parameters: nil) { (video: BCOVVideo?, jsonResponse: [AnyHashable: Any]?, error: Error?) -> Void in
            if(error != nil) {
                return completion(error)
            }
            
            if(video != nil) {
                self.setVideoProperties(video: video!)
                self.playbackController?.setVideos([video!] as NSArray)
                completion(nil)
            } else {
                return completion(CustomError(PluginError.TECHNICAL_ERROR, "the video \(self.videoId) cannot be retrieved from the catalog"))
            }
        }
    }
    
    private func getToken() -> String? {
        for offlineVideoStatus in BCOVOfflineVideoManager.shared()!.offlineVideoStatus() {
            let token = offlineVideoStatus.offlineVideoToken!;
            
            if let downloadedVideoId = BCOVOfflineVideoManager.shared()?.videoObject(fromOfflineVideoToken: token)?.properties[kBCOVVideoPropertyKeyId] {
                if (downloadedVideoId as! String == self.videoId) {
                    return token
                }
            }
        }
        
        return nil
    }

    private func setVideoProperties(video: BCOVVideo) {
        if let videoLength = video.properties["duration"] {
            self.duration = videoLength as! Int
        }
    }

    public func forward(millis: Float64) {
        self.seekRelative(millis: millis)
    }

    public func backward(millis: Float64) {
        self.seekRelative(millis: -millis)
    }

    public func seekRelative(millis: Float64) {
        guard let position = self.currentProgress else {
            return
        }

        var newTime = position + millis/1000
        if newTime < 0 {
            newTime = 0
        }
        
        if(Int(newTime) < self.duration) {
            let resultingTime: CMTime = CMTimeMake(value: Int64(newTime * 1000 as Float64), timescale: 1000)
            self.playbackController?.seek(to: resultingTime, completionHandler: nil)

            self.currentProgressMillis = Int(newTime * 1000)
            videoPositionChangeEvent()
        }
    }

    public func setupNowPlayingHandler() {
        if(self.nowPlayingHandler != nil) {
            return
        }
        
        guard let playback = self.playbackController else {
            return
        }
        
        guard let session = self.currentSession else {
            return
        }

        self.nowPlayingHandler = BrightcoveVideoPlayerNowPlayingHandler(withPlaybackController: playback, session: session)
        self.nowPlayingHandler?.playAction = {() -> Void in
            self.playbackController?.play()
        }
        self.nowPlayingHandler?.pauseAction = {() -> Void in
            self.playbackController?.pause()
        }
        self.nowPlayingHandler?.skipForwardAction = {() -> Void in
            self.forward(millis: Float64(self.nowPlayingHandler!.skipForwardIntervalSeconds * 1000))
        }
        self.nowPlayingHandler?.skipBackwardAction = {() -> Void in
            self.backward(millis: Float64(self.nowPlayingHandler!.skipBackwardIntervalSeconds * 1000))
        }
        self.nowPlayingHandler?.changePlaybackPositionAction = {(event) -> Void in
            let time = CMTime(seconds: event.positionTime, preferredTimescale: 1000000)
            self.playbackController?.seek(to: time, completionHandler: nil)
        }
    }

    public func destroy() {
        self.playbackController = nil
        self.nowPlayingHandler = nil
        self.videoId = ""

        if self.currentSession != nil && self.playbackController != nil {
            self.currentSession?.player.replaceCurrentItem(with: nil)
            self.playbackController?.remove(self.nowPlayingHandler)
            self.playbackController?.pause()
        }
    }
}

@available(iOS 12.0, *)
extension BrightcoveVideoPlayerViewController: BCOVPlaybackControllerDelegate {

    public func playbackController(_ controller: BCOVPlaybackController!, didCompletePlaylist playlist: NSFastEnumeration!) {
        let callback = {() -> Void in
            NotificationCenter.default.post(
                name: Notification.Name("closeVideo"),
                object: nil, userInfo: [
                    "completed": true,
                    "currentMillis": self.currentProgressMillis,
                    "totalMillis": self.duration,
                    "subtitle": self.subtitle
                ]
            )
        }

        self.dismiss(animated: false, completion: callback);
    }

    public func playbackController(_ controller: BCOVPlaybackController!, didAdvanceTo session: BCOVPlaybackSession!) {
        self.currentSession = session
        self.setupNowPlayingHandler()
    }

    public func playbackController(_ controller: BCOVPlaybackController!, playbackSession session: BCOVPlaybackSession!, didProgressTo progress: TimeInterval) {
        if(progress.isFinite) {
            self.currentProgressMillis = Int(progress * 1000)
            self.videoPositionChangeEvent()
        }

        self.currentProgress = progress
    }
    
    public func playbackController(_ controller: BCOVPlaybackController!, playbackSession session: BCOVPlaybackSession!, didChangeSelectedLegibleMediaOption legibleMediaOption: AVMediaSelectionOption!) {
        if(self.readyToUpdateSubtitle) {
            self.subtitle = legibleMediaOption?.extendedLanguageTag ?? ""
        }
    }

    public func playbackController(_ controller: BCOVPlaybackController!,playbackSession session: BCOVPlaybackSession!,didReceive event: BCOVPlaybackSessionLifecycleEvent) {
        if (kBCOVPlaybackSessionLifecycleEventReady == event.eventType) {
            self.readyToUpdateSubtitle = true
            // set or disable subtitle
            if let legibleMediaSelectionGroup = session?.legibleMediaSelectionGroup?.options {
                let locale = NSLocale(localeIdentifier: self.subtitle) as Locale
                let mediaSelectionOptions = AVMediaSelectionGroup.mediaSelectionOptions(from: legibleMediaSelectionGroup, with: locale)
                let mediaSelectionOption = mediaSelectionOptions.first
                session?.selectedLegibleMediaOption = mediaSelectionOption
            }

            // set start to position
            if(self.startPosition != 0) {
                session.player.seek(
                    to: CMTimeMake(value: Int64(self.startPosition), timescale: 1000),
                    toleranceBefore: CMTime.zero,
                    toleranceAfter: CMTime.zero,
                    completionHandler: { (isFinished:Bool) -> Void in
                        if(!self.closeVideoCalled) {
                            session.player.play()
                        }
                    }
                )
            }
        }
    }

    private func videoPositionChangeEvent() {
        // This is a temporary fix to prevent Brightcove SDK from playing a video forever
        // Related Brightcove support ticket : https://supportportal.brightcove.com/s/case/5006f00001qUKV1AAO/ios-video-player-issue
        if(self.currentProgressMillis >= self.duration) {
            return self.closeVideo()
        }
        
        NotificationCenter.default.post(
            name: Notification.Name("videoPositionChange"),
            object: nil,
            userInfo: [
                "currentMillis":  self.currentProgressMillis,
                "totalMillis": self.duration
            ]
        )

    }
}

@available(iOS 12.0, *)
extension BrightcoveVideoPlayerViewController: BCOVPUIPlayerViewDelegate {

    public func playerView(_ playerView: BCOVPUIPlayerView!, willTransitionTo screenMode: BCOVPUIScreenMode) {
        // Quit player as soon as we leave fullscreen
        if (screenMode == .normal) {
            self.closeVideo()
        }
    }
}
