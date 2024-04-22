import Foundation
import BrightcovePlayerSDK

public class BrightcoveSetup {
    public let sharedSDKManager: BCOVPlayerSDKManager = BCOVPlayerSDKManager.shared()!
    public let playbackService: BCOVPlaybackService

    init(accountId: String, policyKey: String) {
        playbackService = BCOVPlaybackService(accountId: accountId, policyKey: policyKey)
    }
}
