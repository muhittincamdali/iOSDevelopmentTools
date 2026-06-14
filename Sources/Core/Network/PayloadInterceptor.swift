import Foundation

/// iOSDevelopmentTools: Network Payload Interceptor
public actor PayloadInterceptor {
    public init() {}
    public func intercept(request: URLRequest) {
        print("🛠️ [DevTools] Payload intercepted.")
    }
}
