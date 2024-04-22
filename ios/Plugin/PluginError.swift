import Foundation

class CustomError: Error {
    var code: PluginError
    var message: String
    var error: Error?
    
    init(_ code: PluginError, _ message: String = "", _ error: Error? = nil) {
        self.code = code
        self.message = message
        self.error = error
    }
}

enum PluginError: String, Error  {
    case
        NOT_IMPLEMENTED,
        MISSING_POLICYKEY,
        MISSING_ACCOUNTID,
        MISSING_FILEID,
        MISSING_SOURCE_URL,
        REQUIRES_IOS12_OR_HIGHER,
        NO_INTERNET_CONNECTION,
        FILE_NOT_EXIST_AND_NO_INTERNET,
        FILE_NOT_EXIST,
        MISSING_FILE_PARAMETER,
        VIDEO_CANT_BE_DOWNLOADED,
        DOWNLOAD_STATUS_NOT_DETERMINED,
        DOWNLOADED_FILE_NOT_FOUND,
        TECHNICAL_ERROR
}
