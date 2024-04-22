import Foundation
import AVFoundation
import MediaPlayer

class NowPlayingHandler: NSObject {
    var nowPlayingInfo = [String : Any]()
    private var observerContext = 0
    
    var player: AVPlayer
    
    var center: MPRemoteCommandCenter
    
    var skipForwardIntervalSeconds: Int = 15
    var skipBackwardIntervalSeconds: Int = 15
    var showProgressAndTime: Bool = true {
        didSet {
            self.updateNowPlaying()
        }
    }
    
    private var timeObserverToken: Any?
    private var rateObserverToken: Any?
    
    var playAction: (() -> Void)?
    var pauseAction: (() -> Void)?
    var skipBackwardAction: (() -> Void)?
    var skipForwardAction: (() -> Void)?
    var changePlaybackPositionAction: ((MPChangePlaybackPositionCommandEvent) -> Void)?
    
    init(player: AVPlayer) {
        self.center = MPRemoteCommandCenter.shared()
        self.player = player
        super.init()
        self.setup()
    }

    private func setup() {
        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget(self, action: #selector(pauseCommand))
        
        center.playCommand.isEnabled = true
        center.playCommand.addTarget(self, action: #selector(playCommand))
        
        center.skipForwardCommand.isEnabled = true
        center.skipForwardCommand.addTarget(self, action: #selector(skipForwardCommand))
        
        center.skipBackwardCommand.isEnabled = true
        center.skipBackwardCommand.addTarget(self, action: #selector(skipBackwardCommand))
        
        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget(self, action: #selector(changePlaybackPositionCommand))
        
        // Notify every half second
        let time = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: time, queue: .main) { [weak self] time in
            let infoCenter = MPNowPlayingInfoCenter.default()
            self?.nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = time.seconds
            infoCenter.nowPlayingInfo = self?.nowPlayingInfo
        }
        
        player.addObserver(self, forKeyPath: #keyPath(AVPlayer.rate), options: [.old, .new], context: nil)
    }

    @objc func pauseCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        self.pauseAction?()
        return .success
    }
    
    @objc func playCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        self.playAction?()
        return .success
    }
    
    @objc func skipForwardCommand(_ event: MPSkipIntervalCommandEvent) -> MPRemoteCommandHandlerStatus {
        self.skipForwardAction?()
        return .success
    }
    
    @objc func skipBackwardCommand(_ event: MPSkipIntervalCommandEvent) -> MPRemoteCommandHandlerStatus {
        self.skipBackwardAction?()
        return .success
    }
    
    @objc func changePlaybackPositionCommand(_ event: MPChangePlaybackPositionCommandEvent) -> MPRemoteCommandHandlerStatus {
        self.changePlaybackPositionAction?(event)
        return .success
    }
    
    public func updatePreferedIntervals(skipForwardIntervalSeconds: Int, skipBackwardIntervalSeconds: Int) {
        self.skipForwardIntervalSeconds = skipForwardIntervalSeconds
        self.skipBackwardIntervalSeconds = skipBackwardIntervalSeconds
        self.center.skipForwardCommand.preferredIntervals = [skipForwardIntervalSeconds as NSNumber];
        self.center.skipBackwardCommand.preferredIntervals = [skipBackwardIntervalSeconds as NSNumber];
    }
    
    public func updateNowPlaying(name: String, description: String, thumbnail: String) {
        self.updateNowPlaying()
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = name
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = description // Using album title to show the description, it may not be the most appropriate field for that but otherwise it won't appear on the lock screen
        
        // Loading thumbnail if there is one
        do {
            if let url = URL(string: thumbnail) {
                let data = try Data(contentsOf: url)
                let image = UIImage(data: data)
                let artwork = MPMediaItemArtwork.init(boundsSize: image!.size, requestHandler: {_ in
                    return image!
                })
                nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
            } else {
                print("Brightcove plugin: No thumbnail found")
            }
        } catch{
            print("Brightcove plugin: Couldn't load thumbnail")
        }
        
        // Set the metadata
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    public func updateNowPlaying() {
        guard let playerItem = player.currentItem else {
            return
        }
        
        if(self.showProgressAndTime) {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = playerItem.currentTime().seconds
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = playerItem.asset.duration.seconds
            self.center.changePlaybackPositionCommand.isEnabled = true
        } else { // The time is not displayed and the progress bar is grayed out
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = nil
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = nil
            self.center.changePlaybackPositionCommand.isEnabled = false
        }
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
        
        // Set the metadata
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let _object = object as? NSObject, let rate = change?[NSKeyValueChangeKey.newKey] as? NSNumber {
            if _object == player && keyPath == "rate" {
                let infoCenter = MPNowPlayingInfoCenter.default()
                nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = rate
                infoCenter.nowPlayingInfo = nowPlayingInfo
            }
        }
    }

    private func removeObservers() {
        if let timeObserverToken = timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
        self.player.removeObserver(self, forKeyPath: "rate")
    }
    
    deinit {
        self.removeObservers()
        
        self.center.playCommand.isEnabled = false;
        self.center.pauseCommand.isEnabled = false;
        self.center.skipBackwardCommand.isEnabled = false;
        self.center.skipForwardCommand.isEnabled = false;
        self.center.changePlaybackPositionCommand.isEnabled = false;
        
        self.center.playCommand.removeTarget(self);
        self.center.pauseCommand.removeTarget(self);
        self.center.skipBackwardCommand.removeTarget(self);
        self.center.skipForwardCommand.removeTarget(self);
        self.center.changePlaybackPositionCommand.removeTarget(self);
    }
}
