import BrightcovePlayerSDK
import AVFoundation
import MediaPlayer

@available(iOS 12.0, *)
public class BrightcoveAudioPlayer:NSObject {
    let setup: BrightcoveSetup
    var fileId: String = ""
    var token: String = ""
    var defaultPosterUrl: String = ""
    var player: AVPlayer?
    var remainingTime: Int64? = nil

    var video: BCOVVideo?
    var looping: Bool = false
    @objc var playerState: AudioPlayerState = AudioPlayerState()
    
    var stateObserver: NSKeyValueObservation?
    var playerItemObserver: NSKeyValueObservation?
    var playerItemStatusObserver: NSKeyValueObservation?
    var timeObserverToken: Any?
    var remainingLoopTimeObserverToken: Any?
    var endReachedObserver: NSObjectProtocol?
    
    var nowPlayingInfo = [String : Any]()
    var skipForwardIntervalSeconds: Int = 15;
    var skipBackwardIntervalSeconds: Int = 15;
    
    var nowPlayingHandler: NowPlayingHandler?
    
    var sendAudioPositionChange: Bool = true
    
    private var loaded = false

    init(setup: BrightcoveSetup) {
        self.setup = setup
    }
    
    func load(fileId: String, token: String, local: Bool, defaultPosterUrl: String, completion: @escaping (Error?) -> Void) {
        self.destroy()
        self.fileId = fileId
        self.token = token
        self.defaultPosterUrl = defaultPosterUrl

        if(self.fileId.isEmpty) {
            return completion(CustomError(PluginError.MISSING_FILEID, "BrightcoveAudioPlayer.checkFileId: FileId is missing in audio player (null fileId)"))
        }
        
        print("Brightcove plugin: Searching for audio \(self.fileId)")
        self.loadAudio(local: local) {
            error in
            if let error = error {
                return completion(error)
            } else {
                return completion(nil)
            }
        }
    }
    
    func loadAudio(local: Bool, completion: @escaping (Error?) -> Void) {
        let loadFunction = local ? loadLocalAudio : loadOnlineAudio
        let message = local ? "Brightcove plugin: Run audio locally" : "Brightcove plugin: Run audio online"
        print(message)
        
        loadFunction {
            error in
            if let error = error {
                return completion(error)
            } else {
                return completion(nil)
            }
        }
    }
    
    func enableAudioLooping(time: Double?) throws {
        if let loopingTime = time {
            try self.toggleLooping(enabled: true)
            self.remainingTime = Int64(loopingTime)
        }
    }
    
    private func loadLocalAudio(completion: @escaping (Error?) -> Void) {
        guard let brightcoveOfflineManager = BCOVOfflineVideoManager.shared() else {
            return completion(CustomError(PluginError.TECHNICAL_ERROR, "BrightcoveAudioPlayer.locaLocalAudio : Cannot get BCOVOfflineVideoManager"))
        }
        
        var source: BCOVSource? = nil
        
        for offlineVideoStatus in brightcoveOfflineManager.offlineVideoStatus() {
            guard let token = offlineVideoStatus.offlineVideoToken else {
                return completion(CustomError(PluginError.TECHNICAL_ERROR, "BrightcoveAudioPlayer.locaLocalAudio : Cannot get token from offlineVideoStatus"))
            }
            
            let downloadedVideoObject = brightcoveOfflineManager.videoObject(fromOfflineVideoToken: token)

            if let downloadedVideoId = downloadedVideoObject?.properties[kBCOVVideoPropertyKeyId] {
                if (downloadedVideoId as? String == self.fileId) {
                    // Check that the status of the download is completed. If not, we load the remote media
                    if let downloadStatus = brightcoveOfflineManager.offlineVideoStatus(forToken: token) {
                        if downloadStatus.downloadState == .stateCompleted {
                            print("Brightcove plugin: Run local audio with token \(token)")
                            self.token = token
                            self.video = brightcoveOfflineManager.videoObject(fromOfflineVideoToken: token)
                            source = BCOVBasicSessionProviderOptions().sourceSelectionPolicy(video)
                        } else {
                            print("Brightcove plugin: Local media is not available yet status: \(String(describing: downloadStatus.downloadState))")
                        }
                    }
                }
            }
        }

        
        if(self.token.isEmpty) {
            print("Brightcove plugin: No local media, stream online media")
            self.loadOnlineAudio() { error in
                if let error = error {
                    return completion(error)
                } else {
                    return completion(nil)
                }
            }
        } else {
            guard let url = source?.url else {
                return completion(CustomError(PluginError.MISSING_SOURCE_URL, "BrightcoveAudioPlayer.load: Cannot load audio. Source not found (fileId: \(self.fileId))"))
            }

            // Ensure that player is not destroyed before loading the media
            if(!self.fileId.isEmpty) {
                do {
                    try self.load(url: url)
                    return completion(nil)
                } catch {
                    return completion(error)
                }
            }
        }
    }
    
    private func loadOnlineAudio(completion: @escaping (Error?) -> Void)  {
        if(!NetworkService.isConnected) {
            return completion(CustomError(PluginError.NO_INTERNET_CONNECTION,"NetworkService.checkIfOnline: Need internet connection to do this action"))
        }
        
        setup.playbackService.findVideo(withVideoID: self.fileId, parameters: nil) { (video: BCOVVideo?, jsonResponse: [AnyHashable: Any]?, error: Error?) -> Void in
            if(error != nil) {
                return completion(error)
            } else if (video == nil) {
                return completion(CustomError(PluginError.FILE_NOT_EXIST, "BrightcoveAudioPlayer.loadOnlineAudio: File not found in the online brightcove catalog (fileId: \(self.fileId)"))
            } else {
                self.video = video
                // We get the best source using the default policy
         
                let source = BCOVBasicSessionProviderOptions().sourceSelectionPolicy(video)
                   
                guard let url = source?.url else {
                    return completion(CustomError(PluginError.MISSING_SOURCE_URL, "BrightcoveAudioPlayer.load: Cannot load audio. Source not found (fileId: \(self.fileId))"))
                }
                
                do {
                    try self.load(url: url)
                    return completion(nil)
                } catch {
                    return completion(error)
                }
            }
        }
    }

    func load(url: URL) throws {
        print("Brightcove plugin: Loading audio file at url: \(url)")
        // Observe PlayerState.state
        self.initPlayerStateObserver()
        self.loaded = false
        self.playerState.state = AudioPlayerState.State.LOADING.rawValue
        let playerItem:AVPlayerItem = AVPlayerItem(url: url)
        self.player = AVPlayer(playerItem: playerItem)

        // Adding handler when the track has finished playing
        endReachedObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil, queue: nil) {_ in
            self.endReached()
        }

        // Observe AVPlayerItem status
        self.initPlayerItemObserver(playerItem: playerItem)

        // Observe AVPlayer position
        try self.addPeriodicTimeObserver()

        print("Brightcove plugin: Playing audio file at url: \(url)")
        try self.setupNowPlayingHandler()
    }
    
    private func setupNowPlayingHandler() throws {
        guard let player = self.player else {
            throw CustomError(PluginError.TECHNICAL_ERROR,  "BrightcoveAudioPlayer.setupNowPlayingHandler: Player not available")
        }
        
        let audioName = video?.properties[kBCOVVideoPropertyKeyName] as? String ?? "Unknown media"
        let audioDescription = video?.properties[kBCOVVideoPropertyKeyDescription] as? String ?? ""
        let audioThumbnail = self.defaultPosterUrl.isEmpty ? video?.properties[kBCOVVideoPropertyKeyThumbnail] as? String ?? "" : self.defaultPosterUrl
        
        self.nowPlayingHandler = NowPlayingHandler(player: player)
        self.nowPlayingHandler?.updateNowPlaying(name: audioName, description: audioDescription, thumbnail: audioThumbnail)
        self.nowPlayingHandler?.updatePreferedIntervals(skipForwardIntervalSeconds: skipForwardIntervalSeconds, skipBackwardIntervalSeconds: skipBackwardIntervalSeconds)
        self.nowPlayingHandler?.playAction = {() -> Void in
            try? self.play()
        }
        self.nowPlayingHandler?.pauseAction = {() -> Void in
            try? self.pause()
        }
        self.nowPlayingHandler?.skipForwardAction = {() -> Void in
            try? self.forward(millis: Float64(self.skipForwardIntervalSeconds * 1000))
        }
        self.nowPlayingHandler?.skipBackwardAction = {() -> Void in
            try? self.backward(millis: Float64(self.skipBackwardIntervalSeconds * 1000))
        }
        self.nowPlayingHandler?.changePlaybackPositionAction = {(event) -> Void in
            let time = CMTime(seconds: event.positionTime, preferredTimescale: 1000000)
            guard let duration = self.player?.currentItem?.duration else {
                return
            }
            if(time >= duration) {
                self.endReached()
                return
            }
            player.seek(to: time)
        }
    }
    
    func setLockScreenIntervals(forwardMillis: Int?, backwardMillis: Int?) throws {
        if let lockScreenSkipForwardIntervalMs = forwardMillis, let lockScreenSkipBackwardIntervalMs = backwardMillis {
            self.skipForwardIntervalSeconds = lockScreenSkipForwardIntervalMs/1000
            self.skipBackwardIntervalSeconds = lockScreenSkipBackwardIntervalMs/1000
            
            if((try? self.checkFileId()) != nil && (try? self.checkPlayer()) != nil) {
                // If we are currently playing i.e. the player is set with a file id, we can directly update on the nowPlayingHandler, otherwise it will be done on the next instanciation
                self.nowPlayingHandler?.updatePreferedIntervals(skipForwardIntervalSeconds: skipForwardIntervalSeconds, skipBackwardIntervalSeconds: skipBackwardIntervalSeconds)
            }
        }
    }
    
    private func endReached() {
        // We reset the track to the start
        player?.seek(to: CMTime.zero)
        
        self.playerState.state = AudioPlayerState.State.ENDED.rawValue

        if(self.looping) {
            // We have to force update of the lock screen progress bar by doing pause+play or it will be stuck at the end
            self.player?.play()
        } else {
            self.player?.pause()
        }
    }
    
    private func initPlayerStateObserver() {
        self.stateObserver = observe(
            \.playerState.state,
            options: [.old, .new]
        ) { object, change in
            print("Brightcove plugin: state changed from: \(String(describing: change.oldValue ?? "")), updated to: \(String(describing: change.newValue ?? "")))")
            if let newValue = change.newValue {
                var state = [:]
                state["state"] = newValue
                
                if(newValue == AudioPlayerState.State.ERROR.rawValue) {
                    state["error"] = self.playerState.error
                }
                
                NotificationCenter.default.post(name: Notification.Name("audioStateChange"), object: nil, userInfo: state)
            }
        }
    }
    
    private func initPlayerItemObserver(playerItem :AVPlayerItem) {
        self.playerItemObserver = playerItem.observe(\.status, options:  [.new, .old], changeHandler: { (playerItem, change) in
            if playerItem.status == .readyToPlay {
                if self.player?.timeControlStatus == AVPlayer.TimeControlStatus.playing {
                    self.playerState.state = AudioPlayerState.State.RUNNING.rawValue
                } else if(!self.loaded) {
                    self.playerState.state = AudioPlayerState.State.LOADED.rawValue
                    self.loaded = true
                }
            }
            if playerItem.status == .failed {
                let error = String(describing:playerItem.error)
                self.playerState.error = error
                self.playerState.state = AudioPlayerState.State.ERROR.rawValue
            }
            if playerItem.status == .unknown {
                self.playerState.state = AudioPlayerState.State.NONE.rawValue
            }
        })
        
        self.playerItemStatusObserver = self.player?.observe(\.timeControlStatus, options: [.new, .old], changeHandler: { (playerItem, change) in
            if playerItem.timeControlStatus == AVPlayer.TimeControlStatus.playing {
                self.playerState.state = AudioPlayerState.State.RUNNING.rawValue
            }
            if playerItem.timeControlStatus == AVPlayer.TimeControlStatus.paused {
                self.playerState.state = AudioPlayerState.State.PAUSED.rawValue
            }
        })
    }
    
    private func addPeriodicTimeObserver() throws {
        guard let player = self.player else {
            throw CustomError(PluginError.TECHNICAL_ERROR,  "BrightcoveAudioPlayer.addPeriodicTimeObserver: Player not available")
        }
        
        let timeScale = CMTimeScale(NSEC_PER_SEC)
        var time = CMTime(seconds: 1, preferredTimescale: timeScale)
        // Weak self is used here to prevent memory leaks
        // See https://www.codingem.com/weak-self-in-swift/
        self.timeObserverToken = player.addPeriodicTimeObserver(forInterval: time, queue: .main) {
            [weak self] time in
            
            if(self?.sendAudioPositionChange == false) {
                self?.sendAudioPositionChange = true
                return
            }
            
            var totalMillis :Int64 = 0
            if let currentItem = self?.player?.currentItem {
                totalMillis = Int64(CMTimeGetSeconds(currentItem.asset.duration) * 1000)
                self?.playerState.totalMillis = totalMillis
            }
            let currentMillis = Int64(CMTimeGetSeconds(player.currentTime()) * 1000)
            let remainingTime = self?.remainingTime ?? 0
            self?.playerState.currentMillis = currentMillis
            self?.playerState.remainingTime = remainingTime

            if(self?.sendAudioPositionChange == true) {
                NotificationCenter.default.post(
                    name: Notification.Name("audioPositionChange"),
                    object: nil,
                    userInfo: ["currentMillis": currentMillis, "totalMillis": totalMillis, "remainingTime": remainingTime]
                )
            }
        }
        
        time = CMTime(seconds: 0.05, preferredTimescale: timeScale)
        self.remainingLoopTimeObserverToken = self.player?.addPeriodicTimeObserver(forInterval: time, queue: .main) {
            [weak self] time in
            do {
                if let remainingTime = self?.remainingTime {
                    let newRemainingTime = remainingTime - 50
                    
                    if self?.playerState.state == AudioPlayerState.State.RUNNING.rawValue {
                        self?.remainingTime = newRemainingTime
                    }
                    
                    if (newRemainingTime <= 0) {
                        self?.remainingTime = nil
                        try self?.stop()
                        try self?.toggleLooping(enabled: false)
                    }
                }
            }
            catch let error as NSError {
                print("Brightcove plugin: Error: \(error.localizedDescription)")
            }            
        }
    }

    private func removePeriodicTimeObserver() {
        if let timeObserverToken = timeObserverToken {
            self.player?.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }
    
    func stop() throws {
        try self.seekTo(position: 0)
        self.player?.pause()
        self.playerState.state = AudioPlayerState.State.STOPPED.rawValue
    }
    
    func pause() throws {
        try self.checkFileId()
        try self.checkPlayer()
        self.player?.pause()
    }
    
    func play() throws {
        try self.checkFileId()
        try self.checkPlayer()
        self.player?.play()
    }
    
    func forward(millis: Double?) throws {
        if let forwardMillis = millis {
            try self.seek(millis: Float64(forwardMillis))
        } else {
            try self.seek(millis: 15000)
        }
    }

    func backward(millis: Double?) throws {
        if let backwardMillis = millis {
            try self.seek(millis: Float64(-backwardMillis))
        } else {
            try self.seek(millis: -15000)
        }
    }
    
    func seek(millis: Float64) throws {
        try self.checkFileId()
        try self.checkPlayer()
        guard let duration = self.player?.currentItem?.duration else {
            return
        }
        guard let player = self.player else {
            throw CustomError(PluginError.TECHNICAL_ERROR, "BrightcoveAudioPlayer.seek : Player is nil")
        }
        
        let playerCurrentTime = CMTimeGetSeconds(player.currentTime())
        
        var newTime = playerCurrentTime + millis/1000
        if newTime < 0 {
            newTime = 0
        }

        if newTime < CMTimeGetSeconds(duration) {
            let resultingTime: CMTime = CMTimeMake(value: Int64(newTime * 1000 as Float64), timescale: 1000)
            player.seek(to: resultingTime)
        } else {
            self.endReached()
            return
        }
    }
    
    func seekTo(position: Float64?) throws {
        if let seekToPosition = position {
            self.sendAudioPositionChange = false
            try self.checkFileId()
            try self.checkPlayer()
            let position: CMTime = CMTimeMake(value: Int64(seekToPosition), timescale: 1000)
            self.player?.seek(to: position)
        }
    }
    
    private func checkFileId() throws {
        if(self.fileId.isEmpty) {
            throw CustomError(PluginError.MISSING_FILEID, "BrightcoveAudioPlayer.checkFileId: FileId is missing in audio player (null fileId)")
        }
    }
    
    private func checkPlayer() throws {
        guard self.player != nil else {
            throw CustomError(PluginError.MISSING_SOURCE_URL,  "BrightcoveAudioPlayer.checkPlayer: Source url is missing in audio player")
        }
    }
    
    func toggleLooping(enabled: Bool) throws {
        try self.checkFileId()
        self.looping = enabled
        self.nowPlayingHandler?.showProgressAndTime = !self.looping
        if (!enabled) {
           self.remainingTime = nil
       }
    }
    
    func isLooping() throws -> Bool {
        return self.looping
    }
    
    func getPlayerState() -> AudioPlayerState{
        if let player = self.player {
            let currentTime = player.currentTime()
            var totalMillis :Int64 = 0
            if let duration = player.currentItem?.asset.duration {
                totalMillis = Int64(CMTimeGetSeconds(duration) * 1000)
            }
            
           return AudioPlayerState(
                state: self.playerState.state,
                currentMillis: (self.playerState.state == AudioPlayerState.State.STOPPED.rawValue ? 0 : Int64(CMTimeGetSeconds(currentTime) * 1000)),
                totalMillis: totalMillis,
                error: self.playerState.error,
                remainingTime: self.remainingTime ?? 0
           )
        }
        return AudioPlayerState()
    }
    
    func destroy() {
        NotificationCenter.default.post(name: Notification.Name("audioStateChange"), object: nil, userInfo: ["state":  AudioPlayerState.State.NONE.rawValue])
        NotificationCenter.default.removeObserver(self.endReachedObserver as Any)
        self.playerItemObserver?.invalidate()
        self.stateObserver?.invalidate()
        self.removePeriodicTimeObserver()
        self.nowPlayingHandler = nil
        self.player = nil
        self.fileId = ""
    }

    deinit {
        self.destroy();
    }
}
