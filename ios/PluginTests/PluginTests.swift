import XCTest
import Capacitor
import BrightcovePlayerSDK

@testable import Plugin

class PluginTests: XCTestCase {
    let plugin = BrightcovePlayer()
    let policyKey = ProcessInfo.processInfo.environment["POLICY_KEY"] ?? nil
    let accountId = ProcessInfo.processInfo.environment["ACCOUNT_ID"] ?? nil
    let mediaId = ProcessInfo.processInfo.environment["MEDIA_ID"] ?? nil
    
    override func setUp() {
        super.setUp()
        self.plugin.load()
        self.plugin.updateBrightcoveAccount(CAPPluginCall(callbackId: "", options: ["accountId": self.accountId!, "policyKey": self.policyKey!], success: {(_, _) in }, error: nil)!)
    }

    override func tearDown() {
        super.tearDown()
        
        // After each test, we destroy audio & video players
        let call = CAPPluginCall(callbackId: "", options: [:], success: { (_, _) in }, error: { (error) in })!
        self.plugin.destroyAudioPlayer(call)
        self.plugin.closeVideo(call)
        self.plugin.deleteAllDownloadedMedias(call)
    }
    
    // ----------- Plugin setup features --------------- //
    func testSetupBrightcoveAccountMissingParam() {
        let call = CAPPluginCall(callbackId: "", options: [:], success: { (_, _) in
            XCTFail("Should fail because of missing parameter")
        }, error: { (error) in
            XCTAssertTrue(error?.code == PluginError.MISSING_ACCOUNTID.rawValue)
        })
        self.plugin.updateBrightcoveAccount(call!)
    }
    
    func testSetupBrightcoveAccount() {
        let call = CAPPluginCall(callbackId: "", options: [
            "accountId": self.accountId!,
            "policyKey": self.policyKey!
        ], success: { (_, _) in
            XCTAssert(true)
        }, error: { (error) in
            XCTFail(error?.message ?? "Error on UpdateBrightcoveAccount")
        })
        self.plugin.updateBrightcoveAccount(call!)
    }
    
    // ----------- Video player features --------------- //
    func testPlayVideo() {
        let expectation = XCTestExpectation(description: "Play video.")
        let call = CAPPluginCall(callbackId: "", options: ["fileId": self.mediaId!], success: nil, error: { error in XCTFail(error?.message ?? "Error on Play Video")})

        self.plugin.playVideo(call!)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            XCTAssertGreaterThan(self.plugin.brightcoveVideoPlayer.currentProgressMillis, 0)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testVideoPositionChangeEvent() {
        self.plugin.playVideo(CAPPluginCall(callbackId: "", options: ["fileId": self.mediaId!], success: nil, error: nil)!)
        wait(for: [XCTNSNotificationExpectation(name: Notification.Name("videoPositionChange"))], timeout: 5.0)
    }
    
    func testVideoCloseVideoEvent() {
        self.plugin.playVideo(CAPPluginCall(callbackId: "test", options: ["fileId": self.mediaId!], success: nil, error: nil)!)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.plugin.closeVideo(CAPPluginCall(callbackId: "", options: [:], success: { (_,_) in }, error: { error in XCTFail(error?.message ?? "Error on Close Video")})!)
        }
        
        wait(for: [XCTNSNotificationExpectation(name: Notification.Name("closeVideo"))], timeout: 10.0)
    }
    
    func testPauseResumeVideo() {
        let pauseVideoExpectation = XCTestExpectation(description: "Wait 3 seconds before pause video.")
        let pausedVideoExpectation = XCTestExpectation(description: "Paused video.")
        
        let pauseVideoCall = CAPPluginCall(callbackId: "", options: [:], success: { (_,_) in }, error: { (error) in XCTFail(error?.message ?? "Error on Pause Video")})!
        let playVideocall = CAPPluginCall(callbackId: "", options: ["fileId": self.mediaId!], success: { (_,_) in  }, error: { (error) in XCTFail(error?.message ?? "Error on Play Video")})!
        
        self.plugin.playVideo(playVideocall)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            XCTAssertEqual(self.plugin.brightcoveVideoPlayer.currentSession?.player.timeControlStatus, .playing)
            self.plugin.pauseVideo(pauseVideoCall)
            pauseVideoExpectation.fulfill()
        }
        wait(for: [pauseVideoExpectation], timeout: 6.0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            XCTAssertEqual(self.plugin.brightcoveVideoPlayer.currentSession?.player.timeControlStatus, .paused)
            pausedVideoExpectation.fulfill()
        }
        wait(for: [pausedVideoExpectation], timeout: 6.0)
    }
    
    // ----------- Metadata features --------------- //
    func testGetMetadata() async {
      let call = CAPPluginCall(callbackId: "", options: ["fileId": self.mediaId!], success: { (result, _) in
          let optionalMetadata = result?.data?["metadata"]
          XCTAssertNotNil(optionalMetadata)
          let metadata = optionalMetadata! as! [String : Any]
          XCTAssertNotNil(metadata)
          // Check each data coming from the Brightcove API
          
          // Check main metadata
          XCTAssertGreaterThan(metadata["fileSize"] as! Int, 0)
          XCTAssertGreaterThan(metadata["totalMillis"] as! Int, 0)
          XCTAssertNotNil(metadata["thumbnail"])
          XCTAssertNotNil(metadata["posterUrl"])
          XCTAssertFalse(metadata["downloaded"] as! Bool)
          XCTAssertEqual(metadata["mediaId"] as? String, self.mediaId)
          XCTAssertNotNil(metadata["title"])
          
          // Check subtitles - this specific metia must contain english subtitles
          let optionalSubtitles = metadata["subtitles"]
          XCTAssertNotNil(optionalSubtitles)
          
          let subtitles = optionalSubtitles as! Array<[String:String]>
          
          XCTAssertEqual(subtitles.count, 1)
          XCTAssertNotNil(subtitles.first)
          
          XCTAssertEqual(subtitles.first?["language"]!, "en")
          XCTAssertNotNil(subtitles.first?["src"])
      }, error: { error in
          XCTFail(error?.message ?? "Error calling getMetadata")
      })

      self.plugin.getMetadata(call!)
    }
    
    func testMediaAvailableLocally() async {
        let call = CAPPluginCall(callbackId: "", options: ["fileId":self.mediaId!], success: { (result, _) in
            let optionalResponse = result?.data?["value"]
            XCTAssertNotNil(optionalResponse)
            XCTAssertFalse(optionalResponse! as! Bool)
        }, error: { (error) in XCTFail(error?.message ?? "Error calling isMediaAvailableLocally") })
        
        self.plugin.isMediaAvailableLocally(call!)
    }
    
    // ----------- Download features --------------- //
    func testDownloadMedia() {
        // downloadMedia
        let call = CAPPluginCall(callbackId: "", options: ["fileId":self.mediaId!], success: { (result, _) in }, error: { (error) in XCTFail(error?.message ?? "Error calling downloadMedia") })
        
        // Media download is failing because background task (as download) is not available with simulators
        let expectedStates: [DownloadState] = [DownloadState.REQUESTED, DownloadState.FAILED]
        var index = 0
        
        let notificationExpectation = expectation(forNotification: Notification.Name("downloadStateChange"), object: nil, handler: { notification in
            if let userInfo = notification.userInfo, let state = userInfo["status"] as? String {
                XCTAssertEqual(state, expectedStates[index].rawValue)
                index += 1
                return index >= expectedStates.count
            }
            return false
        })
        
        self.plugin.downloadMedia(call!)
        
        wait(for: [notificationExpectation], timeout: 15.0)
    }
    
    func testDeleteAllDownloadedMedias() {
        let call = CAPPluginCall(callbackId: "", options: [:], success: { (_, _) in  }, error: { (error) in XCTFail(error?.message ?? "Error calling deleteAllDownloadedMedias") })
        
        self.plugin.deleteAllDownloadedMedias(call!)
    }
    
    func testGetDownloadedMediasState() {
        let call = CAPPluginCall(callbackId: "", options: [:], success: { (result, _) in
            let optionalResponse = result?.data?["medias"]
            XCTAssertNotNil(optionalResponse)
            XCTAssertTrue((optionalResponse! as! [[String: Any]]).isEmpty)
       
        }, error: { (error) in XCTFail(error?.message ?? "Error calling getDownloadedMediasState") })
        
        self.plugin.getDownloadedMediasState(call!)
    }
    
    func testSetDownloadNotifications() {
        let call = CAPPluginCall(callbackId: "", options: [:], success: { (_, _) in
            XCTFail("setDownloadNotifications should fail because it's not available in iOS")
        }, error: { (error) in XCTAssertEqual(error?.code!, "UNAVAILABLE") })
        
        self.plugin.setDownloadNotifications(call!)
    }
    
    // ----------- Audio player features --------------- //
    func testLoadAudio() {
        let call = CAPPluginCall(callbackId: "", options: ["fileId":self.mediaId!], success: { (_, _) in }, error: { (error) in XCTFail(error?.message ?? "Error calling loadAudio") })
        
        self.plugin.loadAudio(call!)
        
        let expectedStates: [AudioPlayerState.State] = [AudioPlayerState.State.LOADING, AudioPlayerState.State.LOADED]
        var index = 0
        
        let notificationExpectation = expectation(forNotification: Notification.Name("audioStateChange"), object: nil, handler: { notification in
            if let userInfo = notification.userInfo, let state = userInfo["state"] as? String {
                XCTAssertEqual(state, expectedStates[index].rawValue)
                index += 1
                return index >= expectedStates.count
            }
            return false
        })
        
        wait(for: [notificationExpectation], timeout: 5.0)
    }
    
    func testPlayAudio() {
        let playAudioCall = CAPPluginCall(callbackId: "", options: [:], success: { (_, _) in }, error: { error in XCTFail(error?.message ?? "Error calling playAudio")})!
        let loadAudioCall = CAPPluginCall(callbackId: "", options: ["fileId":self.mediaId!], success: { (_, _) in self.plugin.playAudio(playAudioCall) }, error: nil)!
        let notificationExpectation = self.setAudioNotificationExceptation(audioState: AudioPlayerState.State.RUNNING)
        
        self.plugin.loadAudio(loadAudioCall)
        wait(for: [notificationExpectation], timeout: 10.0)
    }
    
    func testSetAudioNotificationOptions() {
        self.loadAudio()
        
        self.plugin.setAudioNotificationOptions(CAPPluginCall(callbackId: "", options: ["forwardIncrementMs": 10000, "rewindIncrementMs": 5000], success: { (_, _) in
            XCTAssertEqual(self.plugin.brightcoveAudioPlayer?.nowPlayingHandler?.center.skipBackwardCommand.preferredIntervals.first, 5)
            XCTAssertEqual(self.plugin.brightcoveAudioPlayer?.nowPlayingHandler?.center.skipForwardCommand.preferredIntervals.first, 10)
        }, error: { (error) in XCTFail(error?.message ?? "Error calling setAudioNotificationOptions") })!)
    }
    
    func testDestroyAudio() {
        let notificationExpectation = self.setAudioNotificationExceptation(audioState: AudioPlayerState.State.NONE)
        
        self.loadAndPlayAudio()
        
        self.plugin.destroyAudioPlayer(CAPPluginCall(callbackId: "", success: { (_,_) in }, error: { error in XCTFail(error?.message ?? "Error calling destroyAudioPlayer") }))
        
        wait(for: [notificationExpectation], timeout: 10.0)
    }
    
    func testStopAudio() {
        self.loadAndPlayAudio()

        let call = CAPPluginCall(callbackId: "", options: [:], success: { (_, _) in }, error: { error in XCTFail(error?.message ?? "Error calling stopAudio") })!
        let notificationExpectation = self.setAudioNotificationExceptation(audioState: AudioPlayerState.State.STOPPED)
        self.plugin.stopAudio(call)
        wait(for: [notificationExpectation], timeout: 10.0)
    }
    
    func testPauseAudio() {
        self.loadAndPlayAudio()
        
        let call = CAPPluginCall(callbackId: "", options: [:], success: { (_, _) in }, error: { error in XCTFail(error?.message ?? "Error calling pauseAudio") })!
        let notificationExpectation = self.setAudioNotificationExceptation(audioState: AudioPlayerState.State.PAUSED)
        self.plugin.pauseAudio(call)
        wait(for: [notificationExpectation], timeout: 10.0)
    }
    
    func testForwardAudio() {
        self.loadAndPlayAudio()
        
        let initialTime = Int((self.plugin.brightcoveAudioPlayer.player?.currentItem?.currentTime().value)!)
        
        let call = CAPPluginCall(callbackId: "", options: [:], success: { (_, _) in
            let finalTime = Int((self.plugin.brightcoveAudioPlayer.player?.currentItem?.currentTime().value)!)
            XCTAssertEqual((initialTime + 15000), finalTime)  // Default forward is 15s
        }, error: { error in
            XCTFail(error?.message ?? "Error calling backwardAudio")
        })!
        
        self.plugin.forwardAudio(call)
    }
    
    func testBackwardAudio() {
        self.loadAndPlayAudio()
        
        let initialTime = Int((self.plugin.brightcoveAudioPlayer.player?.currentItem?.currentTime().value)!)
        
        let call = CAPPluginCall(callbackId: "", options: [:], success: { (_, _) in
            let finalTime = Int((self.plugin.brightcoveAudioPlayer.player?.currentItem?.currentTime().value)!)
            
            if(finalTime != (initialTime - 15000) && finalTime != 0) {
                XCTFail("Error backwardAudio. Should be 0 or initialTime - 15000")
            }
        }, error: { error in XCTFail(error?.message ?? "Error calling backwardAudio") })!
        
        self.plugin.backwardAudio(call)
    }
    
    func testSeekToAudio() {
        self.loadAudio()
        let seekTo = Double(40000)
        
        let call = CAPPluginCall(callbackId: "", options: ["position": seekTo ], success: { (_, _) in
          XCTAssertEqual(Double((self.plugin.brightcoveAudioPlayer.player?.currentItem?.currentTime().value)!), seekTo)
        }, error: { error in
            XCTFail(error?.message ?? "Error calling seekToAudio")
        })!
        
        self.plugin.seekToAudio(call)
    }
    
    func testAudioPlayerState() {
        // Test NONE status
        self.plugin.getAudioPlayerState(CAPPluginCall(callbackId: "", options: [:], success: { (result, _) in
            let optionalPlayerStatus = result?.data!
            XCTAssertNotNil(optionalPlayerStatus)
            
            let playerStatus = optionalPlayerStatus!
            XCTAssertNotNil(playerStatus)
            XCTAssertEqual(playerStatus["remainingTime"] as! Int, 0)
            XCTAssertEqual(playerStatus["totalMillis"] as! Int, 0)
            XCTAssertEqual(playerStatus["currentMillis"] as! Int, 0)
            XCTAssertEqual(playerStatus["error"] as! String, "")
            XCTAssertEqual(playerStatus["state"] as! AudioPlayerState.State.RawValue, AudioPlayerState.State.NONE.rawValue)
        }, error: { error in
            XCTFail(error?.message ?? "Error calling getAudioPlayerState")
        })!)
        
        // Test LOADING status
        self.plugin.loadAudio(CAPPluginCall(callbackId: "", options: ["fileId":self.mediaId!], success: { (_, _) in  }, error: { error in XCTFail("Error load audio")})!)
        wait(for: [setAudioNotificationExceptation(audioState: AudioPlayerState.State.LOADING)], timeout: 5.0)
        
        self.plugin.getAudioPlayerState(CAPPluginCall(callbackId: "", options: [:], success: { (result, _) in
            let optionalPlayerStatus = result?.data!
            XCTAssertNotNil(optionalPlayerStatus)
            let playerStatus = optionalPlayerStatus!
            
            XCTAssertNotNil(playerStatus)
            XCTAssertEqual(playerStatus["remainingTime"] as! Int, 0)
            XCTAssertGreaterThan(playerStatus["totalMillis"] as! Int, 0)
            XCTAssertEqual(playerStatus["currentMillis"] as! Int, 0)
            XCTAssertEqual(playerStatus["error"] as! String, "")
            XCTAssertEqual(playerStatus["state"] as! AudioPlayerState.State.RawValue, AudioPlayerState.State.LOADING.rawValue)
        }, error: { error in
            XCTFail(error?.message ?? "Error calling getAudioPlayerState")
        })!)
        

        // Test LOADED status
        wait(for: [setAudioNotificationExceptation(audioState: AudioPlayerState.State.LOADED)], timeout: 5.0)
        
        self.plugin.getAudioPlayerState(CAPPluginCall(callbackId: "", options: [:], success: { (result, _) in
            let optionalPlayerStatus = result?.data!
            XCTAssertNotNil(optionalPlayerStatus)
            let playerStatus = optionalPlayerStatus!

            XCTAssertNotNil(playerStatus)
            XCTAssertEqual(playerStatus["remainingTime"] as! Int, 0)
            XCTAssertGreaterThan(playerStatus["totalMillis"] as! Int, 0)
            XCTAssertEqual(playerStatus["currentMillis"] as! Int, 0)
            XCTAssertEqual(playerStatus["error"] as! String, "")
            XCTAssertEqual(playerStatus["state"] as! AudioPlayerState.State.RawValue, AudioPlayerState.State.LOADED.rawValue)
        }, error: { error in
            XCTFail(error?.message ?? "Error calling getAudioPlayerState")
        })!)
        
        // Test RUNNING status
        let positionChangeNotificationExpectation = expectation(forNotification: Notification.Name("audioPositionChange"), object: nil, handler: { notification in
            // We wait for some progress
            if let userInfo = notification.userInfo {
                return (userInfo["currentMillis"] as! Int64) > 0
            }
            return false
        })
        
        self.plugin.playAudio(CAPPluginCall(callbackId: "", options: [:], success: { (_, _) in  }, error: { error in XCTFail("Error play audio")})!)
        wait(for: [positionChangeNotificationExpectation], timeout: 15.0)
        
        self.plugin.getAudioPlayerState(CAPPluginCall(callbackId: "", options: [:], success: { (result, _) in
            let optionalPlayerStatus = result?.data!
            XCTAssertNotNil(optionalPlayerStatus)
            let playerStatus = optionalPlayerStatus!

            XCTAssertNotNil(playerStatus)
            // TODO this test should pass
            // XCTAssertGreaterThan(playerStatus["remainingTime"] as! Int, 0)
            XCTAssertGreaterThan(playerStatus["totalMillis"] as! Int, 0)
            XCTAssertGreaterThan(playerStatus["currentMillis"] as! Int, 0)
            XCTAssertEqual(playerStatus["error"] as! String, "")
            XCTAssertEqual(playerStatus["state"] as! AudioPlayerState.State.RawValue, AudioPlayerState.State.RUNNING.rawValue)
        }, error: { error in
            XCTFail(error?.message ?? "Error calling getAudioPlayerState")
        })!)
        
        // Test PAUSED status
        let pauseNotificationExpectation = setAudioNotificationExceptation(audioState: AudioPlayerState.State.PAUSED)
        self.plugin.pauseAudio(CAPPluginCall(callbackId: "", options: [:], success: { (_, _) in  }, error: { error in XCTFail("Error pause audio")})!)
        wait(for: [pauseNotificationExpectation], timeout: 10.0)
        
        self.plugin.getAudioPlayerState(CAPPluginCall(callbackId: "", options: [:], success: { (result, _) in
            let optionalPlayerStatus = result?.data!
            XCTAssertNotNil(optionalPlayerStatus)
            let playerStatus = optionalPlayerStatus!

            XCTAssertNotNil(playerStatus)
            XCTAssertEqual(playerStatus["state"] as! AudioPlayerState.State.RawValue, AudioPlayerState.State.PAUSED.rawValue)
        }, error: { error in
            XCTFail(error?.message ?? "Error calling getAudioPlayerState")
        })!)
        
        // Test STOPPED status
        let stoppedNotificationExpectation = setAudioNotificationExceptation(audioState: AudioPlayerState.State.STOPPED)
        self.plugin.stopAudio(CAPPluginCall(callbackId: "", options: [:], success: { (_, _) in  }, error: { error in XCTFail("Error stop audio")})!)
        wait(for: [stoppedNotificationExpectation], timeout: 5.0)
        
        self.plugin.getAudioPlayerState(CAPPluginCall(callbackId: "", options: [:], success: { (result, _) in
            let optionalPlayerStatus = result?.data!
            XCTAssertNotNil(optionalPlayerStatus)
            let playerStatus = optionalPlayerStatus!

            XCTAssertNotNil(playerStatus)
            XCTAssertGreaterThan(playerStatus["totalMillis"] as! Int, 0)
            XCTAssertEqual(playerStatus["currentMillis"] as! Int, 0)
            XCTAssertEqual(playerStatus["state"] as! AudioPlayerState.State.RawValue, AudioPlayerState.State.STOPPED.rawValue)
        }, error: { error in
            XCTFail(error?.message ?? "Error calling getAudioPlayerState")
        })!)
        
        self.playAudio()
        
        // Test ENDED status
        let endedNotificationExpectation = setAudioNotificationExceptation(audioState: AudioPlayerState.State.ENDED)
        self.plugin.seekToAudio(CAPPluginCall(callbackId: "", options: ["position": Double(self.plugin.brightcoveAudioPlayer.playerState.totalMillis - 1000)], success: { (_, _) in }, error: { error in XCTFail("Error seekToAudio")})!)
        wait(for: [endedNotificationExpectation], timeout: 15.0)
    }
    
    // ** Helpers ** //
    private func loadAudio() {
        let notificationExpectation = setAudioNotificationExceptation(audioState: AudioPlayerState.State.LOADED)
        self.plugin.loadAudio(CAPPluginCall(callbackId: "", options: ["fileId":self.mediaId!], success: { (_, _) in  }, error: { error in XCTFail("Error load audio")})!)
        wait(for: [notificationExpectation], timeout: 5.0)
    }
    
    private func playAudio() {
        let notificationExpectation = setAudioNotificationExceptation(audioState: AudioPlayerState.State.RUNNING)
        self.plugin.playAudio(CAPPluginCall(callbackId: "", options: [:], success: { (_, _) in  }, error: { error in XCTFail("Error play audio")})!)
        wait(for: [notificationExpectation], timeout: 5.0)
    }
    
    private func loadAndPlayAudio() {
        self.loadAudio()
        self.playAudio()
    }
    
    private func pauseAudio() {
        let notificationExpectation = setAudioNotificationExceptation(audioState: AudioPlayerState.State.PAUSED)
        self.plugin.pauseAudio(CAPPluginCall(callbackId: "", options: [:], success: { (_, _) in  }, error: { error in XCTFail("Error pause audio")})!)
        wait(for: [notificationExpectation], timeout: 5.0)
    }
    
    private func setAudioNotificationExceptation(audioState : AudioPlayerState.State) -> XCTestExpectation {
        return expectation(forNotification: Notification.Name("audioStateChange"), object: nil, handler: { notification in
            if let userInfo = notification.userInfo, let state = userInfo["state"] as? String {
                return state == audioState.rawValue
            }
            return false
        })
    }
}
