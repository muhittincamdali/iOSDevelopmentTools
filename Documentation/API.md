# 📚 API Reference

Complete API documentation for iOS Development Tools.

## 📋 Table of Contents

- [Network Client](#network-client)
- [Storage Manager](#storage-manager)
- [Analytics Manager](#analytics-manager)
- [Logger](#logger)
- [Performance Monitor](#performance-monitor)

## 🌐 Network Client

### **NetworkClient**
Main network client for making HTTP requests.

```swift
class NetworkClient {
    init(configuration: NetworkConfiguration)
    
    func perform<T: Codable>(_ request: APIRequest) async throws -> APIResponse<T>
    func get<T: Codable>(_ url: String) async throws -> T
    func post<T: Codable>(_ url: String, body: Any) async throws -> T
    func put<T: Codable>(_ url: String, body: Any) async throws -> T
    func delete<T: Codable>(_ url: String) async throws -> T
}
```

### **APIRequest**
Represents an HTTP request.

```swift
struct APIRequest {
    let url: String
    let method: HTTPMethod
    let headers: [String: String]
    let body: Data?
    let queryParameters: [String: String]
    
    init(
        url: String,
        method: HTTPMethod = .GET,
        headers: [String: String] = [:],
        body: Data? = nil,
        queryParameters: [String: String] = [:]
    )
}
```

### **APIResponse**
Represents an HTTP response.

```swift
struct APIResponse<T: Codable> {
    let data: T
    let statusCode: Int
    let headers: [String: String]
    let originalData: Data
}
```

### **HTTPMethod**
HTTP method enumeration.

```swift
enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
    case HEAD = "HEAD"
    case OPTIONS = "OPTIONS"
}
```

### **NetworkConfiguration**
Configuration for network client.

```swift
struct NetworkConfiguration {
    let baseURL: String
    let timeout: TimeInterval
    let retryCount: Int
    let headers: [String: String]
    let cachePolicy: URLRequest.CachePolicy
    
    init(
        baseURL: String,
        timeout: TimeInterval = 30,
        retryCount: Int = 3,
        headers: [String: String] = [:],
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    )
}
```

## 💾 Storage Manager

### **StorageManager**
Main storage manager for data persistence.

```swift
class StorageManager {
    init(configuration: StorageConfiguration)
    
    func save<T: Codable>(_ value: T, forKey key: String) throws
    func retrieve<T: Codable>(_ type: T.Type, forKey key: String) throws -> T?
    func remove(forKey key: String) throws
    func clear() throws
    func exists(forKey key: String) -> Bool
}
```

### **UserDefaultsStorage**
UserDefaults wrapper for simple data storage.

```swift
class UserDefaultsStorage {
    init(suiteName: String?)
    
    func save<T: Codable>(_ value: T, forKey key: String) throws
    func retrieve<T: Codable>(_ type: T.Type, forKey key: String) throws -> T?
    func remove(forKey key: String) throws
    func clear() throws
}
```

### **KeychainStorage**
Keychain wrapper for secure data storage.

```swift
class KeychainStorage {
    init(service: String)
    
    func save<T: Codable>(_ value: T, forKey key: String) throws
    func retrieve<T: Codable>(_ type: T.Type, forKey key: String) throws -> T?
    func remove(forKey key: String) throws
    func clear() throws
}
```

### **FileStorage**
File system wrapper for file storage.

```swift
class FileStorage {
    init(directory: URL)
    
    func save(_ data: Data, to path: String) throws
    func load(from path: String) throws -> Data
    func delete(at path: String) throws
    func exists(at path: String) -> Bool
    func listFiles(in directory: String) throws -> [String]
}
```

### **StorageConfiguration**
Configuration for storage manager.

```swift
struct StorageConfiguration {
    let userDefaultsSuite: String?
    let keychainService: String
    let fileStorageDirectory: URL
    let encryptionEnabled: Bool
    
    init(
        userDefaultsSuite: String? = nil,
        keychainService: String = "com.app.storage",
        fileStorageDirectory: URL = FileManager.default.documentsDirectory,
        encryptionEnabled: Bool = false
    )
}
```

## 📊 Analytics Manager

### **AnalyticsManager**
Main analytics manager for event tracking.

```swift
class AnalyticsManager {
    init(configuration: AnalyticsConfiguration)
    
    func trackEvent(_ name: String, properties: [String: Any]?)
    func trackScreen(_ name: String, properties: [String: Any]?)
    func setUserID(_ userID: String)
    func setUserProperty(_ key: String, value: Any)
    func setUserProperties(_ properties: [String: Any])
    func flush()
}
```

### **AnalyticsConfiguration**
Configuration for analytics manager.

```swift
struct AnalyticsConfiguration {
    let enabled: Bool
    let debugMode: Bool
    let batchSize: Int
    let flushInterval: TimeInterval
    let maxQueueSize: Int
    
    init(
        enabled: Bool = true,
        debugMode: Bool = false,
        batchSize: Int = 10,
        flushInterval: TimeInterval = 30,
        maxQueueSize: Int = 1000
    )
}
```

## 📝 Logger

### **Logger**
Main logger for application logging.

```swift
class Logger {
    init(configuration: DebugConfiguration)
    
    func debug(_ message: String, context: [String: Any]?)
    func info(_ message: String, context: [String: Any]?)
    func warning(_ message: String, context: [String: Any]?)
    func error(_ message: String, context: [String: Any]?)
    func critical(_ message: String, context: [String: Any]?)
    func log(_ level: LogLevel, _ message: String, context: [String: Any]?)
}
```

### **LogLevel**
Log level enumeration.

```swift
enum LogLevel: Int, CaseIterable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case critical = 4
}
```

### **DebugConfiguration**
Configuration for logger and debugging.

```swift
struct DebugConfiguration {
    let logLevel: LogLevel
    let enableConsoleLogging: Bool
    let enableFileLogging: Bool
    let logDirectory: String
    let maxLogFileSize: Int
    let maxLogFiles: Int
    
    init(
        logLevel: LogLevel = .info,
        enableConsoleLogging: Bool = true,
        enableFileLogging: Bool = false,
        logDirectory: String = "logs",
        maxLogFileSize: Int = 1024 * 1024, // 1MB
        maxLogFiles: Int = 10
    )
}
```

## ⚡ Performance Monitor

### **PerformanceMonitor**
Main performance monitor for tracking metrics.

```swift
class PerformanceMonitor {
    init()
    
    func startTimer(_ name: String)
    func endTimer(_ name: String)
    func getTimerDuration(_ name: String) -> TimeInterval
    func getAllMetrics() -> [String: TimeInterval]
    func clearMetrics()
    func logMetrics()
}
```

### **MemoryMonitor**
Memory usage monitor.

```swift
class MemoryMonitor {
    init()
    
    func getCurrentMemoryUsage() -> Int64
    func isMemoryPressureHigh() -> Bool
    func logMemoryUsage()
    func getMemoryUsageString() -> String
}
```

### **CPUMonitor**
CPU usage monitor.

```swift
class CPUMonitor {
    init()
    
    func getCurrentCPUUsage() -> Double
    func logCPUUsage()
    func getCPUUsageString() -> String
}
```

## 🛠️ Utility Classes

### **StringValidator**
String validation utilities.

```swift
struct StringValidator {
    static func isValidEmail(_ email: String) -> Bool
    static func isValidPhoneNumber(_ phone: String) -> Bool
    static func isValidPassword(_ password: String) -> Bool
    static func isValidURL(_ url: String) -> Bool
}
```

### **DateFormatter**
Date formatting utilities.

```swift
struct DateFormatter {
    static let shared = DateFormatter()
    
    func format(_ date: Date, style: DateFormatterStyle) -> String
    func format(_ date: Date, format: String) -> String
}
```

### **NumberFormatter**
Number formatting utilities.

```swift
struct NumberFormatter {
    static func formatCurrency(_ amount: Double, currency: String) -> String
    static func formatPercentage(_ value: Double) -> String
    static func formatDecimal(_ value: Double, decimalPlaces: Int) -> String
}
```

### **FileOperations**
File operation utilities.

```swift
struct FileOperations {
    static func save(_ data: Data, to url: URL) throws
    static func load(from url: URL) throws -> Data
    static func delete(at url: URL) throws
    static func copy(from source: URL, to destination: URL) throws
    static func move(from source: URL, to destination: URL) throws
}
```

## ❌ Error Types

### **NetworkError**
Network-related errors.

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
```

### **StorageError**
Storage-related errors.

```swift
enum StorageError: Error {
    case keyNotFound
    case invalidData
    case encodingError
    case decodingError
    case encryptionError
    case decryptionError
    case fileNotFound
    case permissionDenied
    case diskFull
    case unknown
}
```

### **AnalyticsError**
Analytics-related errors.

```swift
enum AnalyticsError: Error {
    case invalidEventName
    case invalidProperties
    case queueFull
    case networkError
    case configurationError
    case unknown
}
```

## 📚 Next Steps

1. **Read [Getting Started](GettingStarted.md)** for quick setup
2. **Check [Network Guide](NetworkGuide.md)** for network utilities
3. **Explore [Storage Guide](StorageGuide.md)** for storage utilities
4. **Review [Analytics Guide](AnalyticsGuide.md)** for analytics utilities
5. **Learn [Utility Guide](UtilityGuide.md)** for utility functions
6. **See [Debugging Guide](DebuggingGuide.md)** for debugging tools

## 🤝 Support

- **Documentation**: [Complete Documentation](Documentation/)
- **Issues**: [GitHub Issues](https://github.com/muhittincamdali/iOSDevelopmentTools/issues)
- **Discussions**: [GitHub Discussions](https://github.com/muhittincamdali/iOSDevelopmentTools/discussions)

---

**Happy developing with iOS Development Tools! 🚀** 