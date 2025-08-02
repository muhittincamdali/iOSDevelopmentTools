# 🌐 Network Guide

Complete network utilities documentation for iOS Development Tools.

## 📋 Table of Contents

- [Network Client](#network-client)
- [API Request](#api-request)
- [Response Handling](#response-handling)
- [Authentication](#authentication)
- [Caching](#caching)
- [Error Handling](#error-handling)

## 🌐 Network Client

### **Basic Usage**
```swift
let networkClient = NetworkClient()

// Simple GET request
let response = try await networkClient.get("/users")

// POST request with body
let user = User(name: "John", email: "john@example.com")
let response = try await networkClient.post("/users", body: user)
```

### **Configuration**
```swift
let config = NetworkConfiguration(
    baseURL: "https://api.example.com",
    timeout: 30,
    retryCount: 3,
    headers: [
        "Content-Type": "application/json",
        "Accept": "application/json"
    ]
)

let networkClient = NetworkClient(configuration: config)
```

## 📡 API Request

### **Request Types**
```swift
// GET request
let getRequest = APIRequest(
    url: "/users",
    method: .GET,
    headers: ["Authorization": "Bearer token"]
)

// POST request
let postRequest = APIRequest(
    url: "/users",
    method: .POST,
    body: userData,
    headers: ["Content-Type": "application/json"]
)

// PUT request
let putRequest = APIRequest(
    url: "/users/123",
    method: .PUT,
    body: updatedUserData
)

// DELETE request
let deleteRequest = APIRequest(
    url: "/users/123",
    method: .DELETE
)
```

### **Request Builder**
```swift
let request = APIRequestBuilder()
    .url("/users")
    .method(.GET)
    .header("Authorization", "Bearer token")
    .queryParameter("page", "1")
    .queryParameter("limit", "10")
    .build()
```

## 📥 Response Handling

### **Response Types**
```swift
struct APIResponse<T: Codable> {
    let data: T
    let statusCode: Int
    let headers: [String: String]
}

struct ErrorResponse: Codable {
    let error: String
    let message: String
    let code: Int
}
```

### **Response Processing**
```swift
do {
    let response: APIResponse<[User]> = try await networkClient.perform(request)
    let users = response.data
    
    // Process users
    for user in users {
        print("User: \(user.name)")
    }
} catch NetworkError.invalidResponse(let statusCode) {
    print("Invalid response: \(statusCode)")
} catch NetworkError.decodingError {
    print("Failed to decode response")
} catch {
    print("Network error: \(error)")
}
```

## 🔐 Authentication

### **Bearer Token**
```swift
class AuthenticatedNetworkClient {
    private let networkClient: NetworkClient
    private var authToken: String?
    
    func setAuthToken(_ token: String) {
        self.authToken = token
    }
    
    func authenticatedRequest<T: Codable>(_ request: APIRequest) async throws -> T {
        var authenticatedRequest = request
        
        if let token = authToken {
            authenticatedRequest.headers["Authorization"] = "Bearer \(token)"
        }
        
        return try await networkClient.perform(authenticatedRequest)
    }
}
```

### **OAuth 2.0**
```swift
class OAuth2Client {
    private let clientId: String
    private let clientSecret: String
    private let redirectURI: String
    
    func authorize() async throws -> String {
        let authURL = "https://auth.example.com/oauth/authorize"
        let params = [
            "client_id": clientId,
            "redirect_uri": redirectURI,
            "response_type": "code",
            "scope": "read write"
        ]
        
        // Implementation for OAuth flow
        return "authorization_code"
    }
    
    func exchangeCodeForToken(_ code: String) async throws -> String {
        let tokenURL = "https://auth.example.com/oauth/token"
        let params = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "code": code,
            "grant_type": "authorization_code"
        ]
        
        // Implementation for token exchange
        return "access_token"
    }
}
```

## 💾 Caching

### **Response Caching**
```swift
class CachedNetworkClient {
    private let networkClient: NetworkClient
    private let cache = NSCache<NSString, CachedResponse>()
    
    func cachedRequest<T: Codable>(_ request: APIRequest, cacheTime: TimeInterval = 300) async throws -> T {
        let cacheKey = request.cacheKey
        
        // Check cache first
        if let cached = cache.object(forKey: cacheKey as NSString),
           cached.isValid(for: cacheTime) {
            return try JSONDecoder().decode(T.self, from: cached.data)
        }
        
        // Make network request
        let response = try await networkClient.perform(request)
        
        // Cache response
        let cachedResponse = CachedResponse(
            data: response.data,
            timestamp: Date()
        )
        cache.setObject(cachedResponse, forKey: cacheKey as NSString)
        
        return try JSONDecoder().decode(T.self, from: response.data)
    }
}

struct CachedResponse {
    let data: Data
    let timestamp: Date
    
    func isValid(for duration: TimeInterval) -> Bool {
        return Date().timeIntervalSince(timestamp) < duration
    }
}
```

### **Image Caching**
```swift
class ImageCache {
    private let cache = NSCache<NSString, UIImage>()
    
    func loadImage(from url: URL) async throws -> UIImage {
        let cacheKey = url.absoluteString as NSString
        
        // Check cache
        if let cachedImage = cache.object(forKey: cacheKey) {
            return cachedImage
        }
        
        // Download image
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: data) else {
            throw NetworkError.invalidData
        }
        
        // Cache image
        cache.setObject(image, forKey: cacheKey)
        
        return image
    }
}
```

## ❌ Error Handling

### **Network Errors**
```swift
enum NetworkError: Error {
    case invalidURL
    case noInternetConnection
    case timeout
    case invalidResponse(Int)
    case decodingError
    case invalidData
    case unauthorized
    case forbidden
    case notFound
    case serverError
    case unknown
}

extension NetworkError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noInternetConnection:
            return "No internet connection"
        case .timeout:
            return "Request timeout"
        case .invalidResponse(let code):
            return "Invalid response: \(code)"
        case .decodingError:
            return "Failed to decode response"
        case .invalidData:
            return "Invalid data"
        case .unauthorized:
            return "Unauthorized"
        case .forbidden:
            return "Forbidden"
        case .notFound:
            return "Not found"
        case .serverError:
            return "Server error"
        case .unknown:
            return "Unknown error"
        }
    }
}
```

### **Error Handling**
```swift
class NetworkErrorHandler {
    static func handle(_ error: Error) {
        switch error {
        case NetworkError.noInternetConnection:
            showNoInternetAlert()
        case NetworkError.unauthorized:
            handleUnauthorized()
        case NetworkError.serverError:
            showServerErrorAlert()
        default:
            showGenericErrorAlert()
        }
    }
    
    private static func showNoInternetAlert() {
        // Show no internet alert
    }
    
    private static func handleUnauthorized() {
        // Redirect to login
    }
    
    private static func showServerErrorAlert() {
        // Show server error alert
    }
    
    private static func showGenericErrorAlert() {
        // Show generic error alert
    }
}
```

## 📊 Monitoring

### **Request Monitoring**
```swift
class NetworkMonitor {
    private var requests: [String: RequestInfo] = [:]
    
    func startMonitoring(_ request: APIRequest) -> String {
        let requestId = UUID().uuidString
        let info = RequestInfo(
            url: request.url,
            method: request.method,
            startTime: Date()
        )
        requests[requestId] = info
        return requestId
    }
    
    func endMonitoring(_ requestId: String) {
        guard var info = requests[requestId] else { return }
        info.endTime = Date()
        info.duration = info.endTime?.timeIntervalSince(info.startTime)
        requests[requestId] = info
    }
    
    func getMetrics() -> [RequestMetrics] {
        return requests.values.map { info in
            RequestMetrics(
                url: info.url,
                method: info.method,
                duration: info.duration ?? 0
            )
        }
    }
}

struct RequestInfo {
    let url: String
    let method: HTTPMethod
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval?
}

struct RequestMetrics {
    let url: String
    let method: HTTPMethod
    let duration: TimeInterval
}
```

## 📚 Next Steps

1. **Read [Getting Started](GettingStarted.md)** for quick setup
2. **Check [Utility Guide](UtilityGuide.md)** for utility functions
3. **Explore [Storage Guide](StorageGuide.md)** for storage utilities
4. **Review [Analytics Guide](AnalyticsGuide.md)** for analytics utilities
5. **Learn [Debugging Guide](DebuggingGuide.md)** for debugging tools
6. **See [API Reference](API.md)** for complete API documentation

## 🤝 Support

- **Documentation**: [Complete Documentation](Documentation/)
- **Issues**: [GitHub Issues](https://github.com/muhittincamdali/iOSDevelopmentTools/issues)
- **Discussions**: [GitHub Discussions](https://github.com/muhittincamdali/iOSDevelopmentTools/discussions)

---

**Happy networking with iOS Development Tools! 🌐** 