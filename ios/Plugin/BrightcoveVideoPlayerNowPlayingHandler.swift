import UIKit
import BrightcovePlayerSDK

class BrightcoveVideoPlayerNowPlayingHandler: NowPlayingHandler {
    private weak var playbackController: BCOVPlaybackController?
    private var session: BCOVPlaybackSession?
    private var observerContext = 0
    
    init(withPlaybackController playbackController: BCOVPlaybackController, session: BCOVPlaybackSession) {
        self.playbackController = playbackController
        
        super.init(player: session.player)
        super.updatePreferedIntervals(skipForwardIntervalSeconds: 15, skipBackwardIntervalSeconds: 15)
        
        playbackController.add(self)
    }
    
    deinit {
        if let session = session as? NSObject {
            session.removeObserver(self, forKeyPath: "player.rate")
        }
    }
}

extension BrightcoveVideoPlayerNowPlayingHandler: BCOVPlaybackSessionConsumer {
    func didAdvance(to session: BCOVPlaybackSession!) {
        if let prevSession = self.session as? NSObject {
            prevSession.removeObserver(self, forKeyPath: "player.rate")
        }
        
        self.session = session
        self.player = session.player
        
        if let newSession = session as? NSObject {
            newSession.addObserver(self, forKeyPath: "player.rate", options: NSKeyValueObservingOptions([.new, .initial]), context: &observerContext)
        }
        
        var _nowPlayingInfo = [String:AnyHashable]()
        guard let videoName = localizedNameForLocale(session.video, nil), let durationNum = session.video.properties[kBCOVVideoPropertyKeyDuration] as? NSNumber else {
            return
        }
        
        let duration = Double(durationNum.doubleValue / 1000)
        
        _nowPlayingInfo[MPMediaItemPropertyTitle] = videoName
        _nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = session.video.properties[kBCOVVideoPropertyKeyDescription] as? String ?? ""
        _nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = NSNumber(floatLiteral: duration)
        
        let infoCenter = MPNowPlayingInfoCenter.default()
        infoCenter.nowPlayingInfo = _nowPlayingInfo
        
        super.nowPlayingInfo = _nowPlayingInfo
        
        if let posterURLString = session.video.properties[kBCOVVideoPropertyKeyPoster] as? String, let posterURL = URL(string: posterURLString) {
            DispatchQueue.global(qos: .background).async {
                do {
                    let imageData = try Data(contentsOf: posterURL)
                    if let image = UIImage(data: imageData) {
                        self.nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { (size: CGSize) -> UIImage in
                            return image
                        }
                        let infoCenter = MPNowPlayingInfoCenter.default()
                        infoCenter.nowPlayingInfo = self.nowPlayingInfo
                    }
                } catch {}

            }
        }
    }
    
    func playbackSession(_ session: BCOVPlaybackSession!, didProgressTo progress: TimeInterval) {
        if progress.isInfinite {
            return
        }
        let infoCenter = MPNowPlayingInfoCenter.default()
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = NSNumber(integerLiteral: Int(progress))
        infoCenter.nowPlayingInfo = nowPlayingInfo
    }
}
