import Foundation
import CoreAudio
import AVFoundation

@available(iOS 12.0, *)
public class AudioPlayer {
    var player: AVPlayer?
    
    func playAudio(file: String?) throws {
        if(file == nil) {
            throw PluginError.MISSING_FILE_PARAMETER
        }
        
        let url = try self.getAudioUrl(file: file!)
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
          
          let playerItem:AVPlayerItem = AVPlayerItem(url: url)
          self.player = AVPlayer(playerItem: playerItem)
          self.player!.play()

        } catch let error {
            throw error
        }
    }
    
    private func getAudioUrl(file: String) throws -> URL {
        let assetPathSplit = file.components(separatedBy: ".")
        guard let filePath = Bundle.main.path(forResource: assetPathSplit[0], ofType: assetPathSplit[1]) else {
            throw CustomError(PluginError.FILE_NOT_EXIST, "AudioPlayer.getAudioUrl: The filePath of this audio was not found (file: \(file))")
            
        }
                
        let fileExist = FileManager.default.fileExists(atPath: filePath)
        
        if(!fileExist) {
            throw CustomError(PluginError.FILE_NOT_EXIST, "AudioPlayer.getAudioUrl: The file of this audio does not exist (filePath: \(filePath)")
        }
        
        guard let url = Bundle.main.url(forResource: "sample", withExtension: "mp3") else {
            throw CustomError(PluginError.FILE_NOT_EXIST, "AudioPlayer.getAudioUrl: Cannot generate url for this audio file")
        }

        return url
    }
    
    private func destroy() {
        self.player?.pause();
        self.player = nil;
    }

    deinit {
        self.destroy();
    }

}
