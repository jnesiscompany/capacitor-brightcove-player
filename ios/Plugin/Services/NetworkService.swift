import Network
import Foundation

@available(iOS 12.0, *)
class NetworkService {
    static var isConnected = true
    
    static func initNetwork() {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue.global(qos: .background)
        
        monitor.start(queue: queue)
        monitor.pathUpdateHandler = { path in
            print("Brightcove plugin: Network status changed : \(path.status)")
            if path.status == .satisfied {
                OperationQueue.main.addOperation {
                    NetworkService.isConnected = true
                }
            } else {
                OperationQueue.main.addOperation {
                    NetworkService.isConnected = false
                }
            }
        }
    }
    
    static func checkIfOnline() throws {
        if(!NetworkService.isConnected) {
            throw CustomError(PluginError.NO_INTERNET_CONNECTION,"NetworkService.checkIfOnline: Need internet connection to do this action")
        }
    }
}
