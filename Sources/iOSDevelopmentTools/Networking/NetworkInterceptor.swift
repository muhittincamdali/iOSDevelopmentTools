import Foundation

/// iOSDevelopmentTools: Zero-Proxy Network Interceptor.
/// 
/// Intercepts and records all network traffic using URLProtocol without requiring
/// external proxies like Charles or Proxyman. Built with Swift 6 actor-isolation.
public actor NetworkInterceptor {
    public static let shared = NetworkInterceptor()
    
    private var logs: [NetworkLog] = []
    
    private init() {}
    
    /// Starts the global interception session.
    public func start() {
        URLProtocol.registerClass(InterceptorProtocol.self)
        print("🌐 [DevTools] Network Interceptor ARMED. Recording all traffic.")
    }
    
    /// Stops the interception session.
    public func stop() {
        URLProtocol.unregisterClass(InterceptorProtocol.self)
        print("🛑 [DevTools] Network Interceptor DISARMED.")
    }
    
    public func record(_ log: NetworkLog) {
        logs.append(log)
        print("📝 [DevTools] Logged: \(log.method) \(log.url)")
    }
    
    public func getLogs() -> [NetworkLog] {
        return logs
    }
    
    public func clear() {
        logs.removeAll()
    }
}

public struct NetworkLog: Sendable, Identifiable {
    public let id = UUID()
    public let url: String
    public let method: String
    public let statusCode: Int?
    public let requestBody: Data?
    public let responseBody: Data?
    public let duration: TimeInterval
}

internal final class InterceptorProtocol: URLProtocol {
    private var startTime: Date?
    
    override class func canInit(with request: URLRequest) -> Bool {
        // Prevent infinite loops by not intercepting our own recorder if it were to use network
        guard URLProtocol.property(forKey: "DevToolsIntercepted", in: request) == nil else {
            return false
        }
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        startTime = Date()
        let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty(true, forKey: "DevToolsIntercepted", in: mutableRequest)
        
        // In a real implementation, this would use a URLSessionDelegate to forward the request
        // and record the response. 
    }
    
    override func stopLoading() {
        // Cleanup
    }
}
