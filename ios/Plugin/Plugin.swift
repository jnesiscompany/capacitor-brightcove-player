import Foundation
import Capacitor
import AVFoundation
import BrightcovePlayerSDK

@available(iOS 12.0, *)
@objc(BrightcovePlayer)
public class BrightcovePlayer: CAPPlugin {
    var setup: BrightcoveSetup?
    var downloadService: DownloadService!
    var mediaService: MediaService!

    var brightcoveVideoPlayer: BrightcoveVideoPlayerViewController!
    var brightcoveAudioPlayer: BrightcoveAudioPlayer!
    let audioPlayer: AudioPlayer! = AudioPlayer()

    @objc override public func load() {
        print("Brightcove plugin: Load capacitor brightcove plugin")
        BCOVOfflineVideoManager.initializeOfflineVideoManager(with: DownloadService.shared, options: nil)
        NetworkService.initNetwork()
        self.downloadService = DownloadService()

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: .allowAirPlay)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch let error as NSError {
            print("Brightcove plugin: Error setting the AVAudioSession:", error.localizedDescription)
        }

        self.initEvents()
     }

    @objc func updateBrightcoveAccount(_ call: CAPPluginCall) {
        print("Brightcove plugin: updateBrightcoveAccount")
        do {
            guard let accountId = call.getString("accountId") else {
                throw CustomError(PluginError.MISSING_ACCOUNTID, "updateBrightcoveAccount: Missing account ID")
            }

            guard let policyKey = call.getString("policyKey") else {
                throw CustomError(PluginError.MISSING_POLICYKEY, "updateBrightcoveAccount: Missing policy key")
            }


            self.setup = BrightcoveSetup(accountId: accountId, policyKey: policyKey)
            self.brightcoveAudioPlayer = BrightcoveAudioPlayer(setup: self.setup!)
            self.downloadService.setSetup(setup: self.setup!)
            self.mediaService = MediaService(setup: self.setup!, downloadService: self.downloadService)

            call.resolve()
        } catch {
            self.rejectError(error, call)
        }
    }

    @objc func pauseVideo(_ call: CAPPluginCall) {
        print("Brightcove plugin: pauseVideo")
        do {

            guard let videoPlayer = self.brightcoveVideoPlayer else {
                return call.resolve()
            }

            try videoPlayer.pauseVideo()
            call.resolve()
        } catch {
            self.rejectError(error, call)
        }
    }

    @objc func closeVideo(_ call: CAPPluginCall) {
        print("Brightcove plugin: closeVideo")

        guard let videoPlayer = self.brightcoveVideoPlayer else {
            return call.resolve()
        }

        DispatchQueue.main.async {
            videoPlayer.closeVideo()
            call.resolve()
        }
    }

    @objc func getMetadata(_ call: CAPPluginCall) {
        print("Brightcove plugin: getMetadata")
        do {
            call.resolve(["metadata": try self.mediaService.getMetadata(fileId: call.getString("fileId"))])
        } catch {
            self.rejectError(error, call)
        }
    }

    @objc func playVideo(_ call: CAPPluginCall) {
        let fileId: String = call.getString("fileId","")
        do {
            // Resume video
            if(fileId.isEmpty) {
                if(self.brightcoveVideoPlayer != nil) {
                    try self.brightcoveVideoPlayer.resumeVideo()
                }
                return call.resolve()
            }
        } catch {
            self.brightcoveVideoPlayer?.destroy()
            self.rejectError(error, call)
        }
        
        // Play new video
        print("Brightcove plugin: playVideo")

        DispatchQueue.main.async {
            self.brightcoveAudioPlayer.destroy()
            self.brightcoveVideoPlayer?.destroy() // To avoid the possibility of having two videos running at the same time
            // instantiate a new player each time we play to prevent having to clean state of the existing one
            // (may change this at some point)


            self.brightcoveVideoPlayer = BrightcoveVideoPlayerViewController(
                setup: self.setup!,
                startPosition: call.getInt("position", 0),
                videoId : fileId,
                subtitle: call.getString("subtitle", "")
            )
            
            if(self.brightcoveVideoPlayer == nil) {
                self.rejectError(CustomError(PluginError.TECHNICAL_ERROR, "playVideo: video player not available"),call)
            }

            self.brightcoveVideoPlayer.loadVideo(local: call.getBool("local", false)) { error in
                if let error = error {
                    self.rejectError(error, call)
                } else {
                    self.bridge?.viewController?.present(self.brightcoveVideoPlayer!, animated: false, completion: {
                        call.resolve(["value": "BrightCove player initialized"])
                    });
                }
            }
        }
        
    }

    @objc func isMediaAvailableLocally(_ call: CAPPluginCall) {
        print("Brightcove plugin: isMediaAvailableLocally")
        do {
            call.resolve(["value": try self.downloadService.isMediaAvailableLocally(fileId: call.getString("fileId"))])
        } catch {
            self.rejectError(error, call)
        }
    }

    @objc func downloadMedia(_ call: CAPPluginCall) {
        print("Brightcove plugin: downloadMedia")

        self.downloadService.download(fileId: call.getString("fileId", "")) { error in
            if let error = error {
                self.rejectError(error, call)
            } else {
                call.resolve()
            }
        }
    }

    @objc func playInternalAudio(_ call: CAPPluginCall) {
        print("Brightcove plugin: playInternalAudio")
        do {
            try self.audioPlayer.playAudio(file : call.getString("file"))
             call.resolve()
        } catch {
            self.rejectError(error, call)
        }
    }

    @objc func deleteAllDownloadedMedias(_ call: CAPPluginCall) {
        print("Brightcove plugin: deleteAllDownloadedMedias")
        do {
            try self.downloadService.deleteAllDownloadedMedias()
            call.resolve()
        } catch {
            self.rejectError(error, call)
        }
    }

    @objc func deleteDownloadedMedia(_ call: CAPPluginCall) {
        print("Brightcove plugin: deleteDownloadedMedia")
        do {
            try self.downloadService.deleteDownloadedMedia(fileId: call.getString("fileId"))
            call.resolve()
        } catch {
            self.rejectError(error, call)
        }
    }

    @objc func getDownloadedMediasState(_ call: CAPPluginCall) {
        print("Brightcove plugin: getDownloadedMediasState")
        do {
            call.resolve(["medias": try self.downloadService.getDownloadedMediasState()])
        } catch {
            self.rejectError(error, call)
        }
    }

    @objc func setDownloadNotifications(_ call: CAPPluginCall) {
        call.unavailable()
    }

    @objc func loadAudio(_ call: CAPPluginCall) {
        print("Brightcove plugin: loadAudio")

        self.brightcoveAudioPlayer.load(fileId: call.getString("fileId", ""), token: call.getString("token", ""), local: call.getBool("local", false), defaultPosterUrl: call.getString("defaultPosterUrl", "")) { error in
            if let error = error {
                self.rejectError(error, call)
            } else {
                call.resolve()
            }
        }
    }

    @objc func destroyAudioPlayer(_ call: CAPPluginCall) {
        print("Brightcove plugin: destroyAudioPlayer")
        self.brightcoveAudioPlayer.destroy()
        call.resolve()
    }

    @objc func stopAudio(_ call: CAPPluginCall) {
        print("Brightcove plugin: stopAudio")
        do {
            try self.brightcoveAudioPlayer.stop()
            call.resolve()
        } catch {
            self.rejectError(error, call)
        }
    }

    @objc func pauseAudio(_ call: CAPPluginCall) {
        print("Brightcove plugin: pauseAudio")
        do {
            try self.brightcoveAudioPlayer.pause()
            call.resolve()
        } catch {
            self.rejectError(error, call)
        }
    }

    @objc func playAudio(_ call: CAPPluginCall) {
        print("Brightcove plugin: playAudio")
        do {
            try self.brightcoveAudioPlayer.play()
            call.resolve()
        } catch {
            self.rejectError(error, call)
        }
    }

    @objc func backwardAudio(_ call: CAPPluginCall) {
        print("Brightcove plugin: backwardAudio")
        do {
            try self.brightcoveAudioPlayer.backward(millis: call.getDouble("amount"))
            call.resolve()
        } catch {
            self.rejectError(error, call)
        }
    }

    @objc func forwardAudio(_ call: CAPPluginCall) {
        print("Brightcove plugin: forwardAudio")
        do {
            try self.brightcoveAudioPlayer.forward(millis: call.getDouble("amount"))
            call.resolve()
        } catch {
            self.rejectError(error, call)
        }
    }

    @objc func seekToAudio(_ call: CAPPluginCall) {
        print("Brightcove plugin: seekToAudio")
        do {
            try self.brightcoveAudioPlayer.seekTo(position: call.getDouble("position"))
            call.resolve()
        } catch {
            self.rejectError(error, call)
        }
    }

    @objc func enableAudioLooping(_ call: CAPPluginCall) {
        print("Brightcove plugin: enableAudioLooping")
        do {
            try self.brightcoveAudioPlayer.enableAudioLooping(time: call.getDouble("time"))
            call.resolve()
        } catch {
            self.rejectError(error, call)
        }
    }

    @objc func disableAudioLooping(_ call: CAPPluginCall) {
        print("Brightcove plugin: disableAudioLooping")
        do {
            try self.brightcoveAudioPlayer.toggleLooping(enabled: false)
            call.resolve()
        } catch {
            self.rejectError(error, call)
        }
    }

    @objc func isAudioLooping(_ call: CAPPluginCall) {
        print("Brightcove plugin: isAudioLooping")
        do {
            call.resolve(["value": try self.brightcoveAudioPlayer.isLooping()])
        } catch {
            self.rejectError(error, call)
        }
    }

    @objc func setAudioNotificationOptions(_ call: CAPPluginCall) {
        print("Brightcove plugin: setAudioNotificationOptions")
        do {
            try self.brightcoveAudioPlayer.setLockScreenIntervals(forwardMillis: call.getInt("forwardIncrementMs"), backwardMillis: call.getInt("rewindIncrementMs"))
            call.resolve()
        } catch {
            self.rejectError(error, call)
        }
    }

    @objc func getAudioPlayerState(_ call: CAPPluginCall) {
        print("Brightcove plugin: getAudioPlayerState")
        do {
            let json = try JSONSerialization.jsonObject(with: self.brightcoveAudioPlayer.getPlayerState().jsonData(), options: [])
            guard let dictionary = json as? [String : Any] else {
                return
            }
            call.resolve(dictionary)
        } catch {
            self.rejectError(error, call)
        }
    }

    private func initEvents() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.notifyCustomListeners(notification:)), name: Notification.Name("downloadStateChange"), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(self.notifyCustomListeners(notification:)), name: Notification.Name("closeVideo"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.notifyCustomListeners(notification:)), name: Notification.Name("videoPositionChange"), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(self.notifyCustomListeners(notification:)), name: Notification.Name("audioStateChange"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.notifyCustomListeners(notification:)), name: Notification.Name("audioPositionChange"), object: nil)
    }

    @objc private func notifyCustomListeners(notification: Notification) {
        self.notifyListeners(notification.name.rawValue, data: notification.userInfo as? [String: Any])
    }

    /**
        We check if the error is a standard error (type CustomError) of the plugin or a native error of swift (type Error)
     */
    private func rejectError(_ error: Any, _ call: CAPPluginCall) {
        if(error is CustomError) {
            call.reject(
                (error as! CustomError).message,
                (error as! CustomError).code.rawValue,
                (error as! CustomError).error
            )
        } else {
            let userInfo = (error as! NSError).userInfo
            var playBackError:String = String(describing: userInfo)
            var playBackErrorCode: String = PluginError.TECHNICAL_ERROR.rawValue

            // Use kBCOVPlaybackServiceErrorKeyAPIErrors to return more relevant error code
            // @TODO Improve this logic to handle all errors described here https://sdks.support.brightcove.com/ios/troubleshooting/error-handling-native-sdk-ios.html
            if let keyAPIErrors = userInfo["kBCOVPlaybackServiceErrorKeyAPIErrors"] as? [[String:Any]] {
                playBackError =  String(describing: (keyAPIErrors))

                if let errorCode = keyAPIErrors.first?["error_code"] as? String {
                    playBackErrorCode = errorCode
                }
            }

            call.reject(
                playBackError,
                playBackErrorCode,
                error as? Error
            )
        }
    }
}
