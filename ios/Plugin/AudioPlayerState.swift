import Foundation

class AudioPlayerState : NSObject, Codable{
    @objc dynamic var state :String
    var currentMillis: Int64
    var totalMillis: Int64
    var error: String
    var remainingTime: Int64
    
    init(
        state: String = State.NONE.rawValue,
        currentMillis: Int64 = 0,
        totalMillis: Int64  = 0,
        error: String = "",
        remainingTime: Int64 = 0
    ) {
        self.state = state
        self.currentMillis = currentMillis
        self.totalMillis = totalMillis
        self.error = error
        self.remainingTime = remainingTime
    }
    
    enum  State: String, Codable {
        case NONE = "NONE",
             ERROR = "ERROR",
             LOADING = "LOADING",
             LOADED = "LOADED",
             RUNNING = "RUNNING",
             PAUSED = "PAUSED",
             STOPPED = "STOPPED",
             ENDED = "ENDED"
    }    
}

extension Encodable {
    func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        //encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
}
