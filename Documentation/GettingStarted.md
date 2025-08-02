# 🚀 Getting Started

Quick start guide for iOS Development Tools.

## 📋 Table of Contents

- [Installation](#installation)
- [Basic Usage](#basic-usage)
- [Configuration](#configuration)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)

## 📦 Installation

### **Swift Package Manager**
Add the following dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/muhittincamdali/iOSDevelopmentTools.git", from: "1.0.0")
]
```

### **CocoaPods**
Add to your `Podfile`:

```ruby
pod 'iOSDevelopmentTools'
```

### **Carthage**
Add to your `Cartfile`:

```
github "muhittincamdali/iOSDevelopmentTools"
```

## 🎯 Basic Usage

### **Import the Framework**
```swift
import iOSDevelopmentTools
```

### **Network Utilities**
```swift
// Create network client
let networkClient = NetworkClient()

// Make API request
let request = APIRequest(
    url: "https://api.example.com/users",
    method: .GET,
    headers: ["Authorization": "Bearer token"]
)

do {
    let response = try await networkClient.perform(request)
    print("Response: \(response)")
} catch {
    print("Error: \(error)")
}
```

### **Storage Utilities**
```swift
// UserDefaults wrapper
let storage = UserDefaultsStorage()

// Save data
try storage.save("value", forKey: "key")

// Retrieve data
let value = try storage.retrieve(String.self, forKey: "key")

// Keychain storage
let keychain = KeychainStorage()

// Save sensitive data
try keychain.save("secret", forKey: "password")

// Retrieve sensitive data
let secret = try keychain.retrieve(String.self, forKey: "password")
```

### **Analytics Utilities**
```swift
// Initialize analytics
let analytics = AnalyticsManager()

// Track event
analytics.trackEvent("user_login", properties: [
    "method": "email",
    "timestamp": Date()
])

// Track screen view
analytics.trackScreen("ProfileViewController")

// Track user property
analytics.setUserProperty("premium", value: true)
```

### **Debugging Utilities**
```swift
// Logger
let logger = Logger()

logger.debug("Debug message")
logger.info("Info message")
logger.warning("Warning message")
logger.error("Error message")

// Performance monitoring
let performance = PerformanceMonitor()

performance.startTimer("api_request")
// ... perform API request
performance.endTimer("api_request")

let duration = performance.getTimerDuration("api_request")
print("API request took: \(duration) seconds")
```

## ⚙️ Configuration

### **Network Configuration**
```swift
let networkConfig = NetworkConfiguration(
    baseURL: "https://api.example.com",
    timeout: 30,
    retryCount: 3,
    headers: [
        "Content-Type": "application/json",
        "Accept": "application/json"
    ]
)

let networkClient = NetworkClient(configuration: networkConfig)
```

### **Storage Configuration**
```swift
let storageConfig = StorageConfiguration(
    userDefaultsSuite: "com.yourapp.storage",
    keychainService: "com.yourapp.keychain",
    encryptionEnabled: true
)

let storage = StorageManager(configuration: storageConfig)
```

### **Analytics Configuration**
```swift
let analyticsConfig = AnalyticsConfiguration(
    enabled: true,
    debugMode: false,
    batchSize: 10,
    flushInterval: 30
)

let analytics = AnalyticsManager(configuration: analyticsConfig)
```

### **Debugging Configuration**
```swift
let debugConfig = DebugConfiguration(
    logLevel: .debug,
    enableConsoleLogging: true,
    enableFileLogging: true,
    logDirectory: "logs"
)

let logger = Logger(configuration: debugConfig)
```

## 📝 Examples

### **Complete App Setup**
```swift
import iOSDevelopmentTools

@main
struct MyApp: App {
    let networkClient: NetworkClient
    let storage: StorageManager
    let analytics: AnalyticsManager
    let logger: Logger
    
    init() {
        // Initialize network client
        let networkConfig = NetworkConfiguration(
            baseURL: "https://api.example.com",
            timeout: 30
        )
        self.networkClient = NetworkClient(configuration: networkConfig)
        
        // Initialize storage
        let storageConfig = StorageConfiguration(
            userDefaultsSuite: "com.yourapp.storage"
        )
        self.storage = StorageManager(configuration: storageConfig)
        
        // Initialize analytics
        let analyticsConfig = AnalyticsConfiguration(
            enabled: true,
            debugMode: false
        )
        self.analytics = AnalyticsManager(configuration: analyticsConfig)
        
        // Initialize logger
        let debugConfig = DebugConfiguration(
            logLevel: .info,
            enableConsoleLogging: true
        )
        self.logger = Logger(configuration: debugConfig)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(networkClient)
                .environmentObject(storage)
                .environmentObject(analytics)
                .environmentObject(logger)
        }
    }
}
```

### **API Service Example**
```swift
class UserService {
    private let networkClient: NetworkClient
    
    init(networkClient: NetworkClient) {
        self.networkClient = networkClient
    }
    
    func fetchUsers() async throws -> [User] {
        let request = APIRequest(
            url: "/users",
            method: .GET
        )
        
        let response = try await networkClient.perform(request)
        return try JSONDecoder().decode([User].self, from: response.data)
    }
    
    func createUser(_ user: User) async throws -> User {
        let request = APIRequest(
            url: "/users",
            method: .POST,
            body: try JSONEncoder().encode(user)
        )
        
        let response = try await networkClient.perform(request)
        return try JSONDecoder().decode(User.self, from: response.data)
    }
}
```

### **Storage Service Example**
```swift
class UserStorageService {
    private let storage: StorageManager
    
    init(storage: StorageManager) {
        self.storage = storage
    }
    
    func saveUser(_ user: User) throws {
        try storage.save(user, forKey: "current_user")
    }
    
    func getUser() throws -> User? {
        return try storage.retrieve(User.self, forKey: "current_user")
    }
    
    func clearUser() throws {
        try storage.remove(forKey: "current_user")
    }
}
```

### **Analytics Service Example**
```swift
class AnalyticsService {
    private let analytics: AnalyticsManager
    
    init(analytics: AnalyticsManager) {
        self.analytics = analytics
    }
    
    func trackUserLogin(method: String) {
        analytics.trackEvent("user_login", properties: [
            "method": method,
            "timestamp": Date()
        ])
    }
    
    func trackScreenView(_ screenName: String) {
        analytics.trackScreen(screenName)
    }
    
    func setUserProperties(_ properties: [String: Any]) {
        for (key, value) in properties {
            analytics.setUserProperty(key, value: value)
        }
    }
}
```

## 🔧 Troubleshooting

### **Common Issues**

#### **Network Request Fails**
```swift
// Check network configuration
let config = NetworkConfiguration(
    baseURL: "https://api.example.com",
    timeout: 30,
    retryCount: 3
)

// Enable debug logging
let logger = Logger(configuration: DebugConfiguration(
    logLevel: .debug,
    enableConsoleLogging: true
))

// Check request format
let request = APIRequest(
    url: "/endpoint",
    method: .GET,
    headers: ["Authorization": "Bearer token"]
)
```

#### **Storage Operations Fail**
```swift
// Check storage configuration
let config = StorageConfiguration(
    userDefaultsSuite: "com.yourapp.storage",
    keychainService: "com.yourapp.keychain"
)

// Handle errors properly
do {
    try storage.save(value, forKey: "key")
} catch StorageError.keyNotFound {
    print("Key not found")
} catch StorageError.invalidData {
    print("Invalid data")
} catch {
    print("Unknown error: \(error)")
}
```

#### **Analytics Not Working**
```swift
// Check analytics configuration
let config = AnalyticsConfiguration(
    enabled: true,
    debugMode: true,
    batchSize: 1,
    flushInterval: 1
)

// Force flush events
analytics.flush()

// Check event tracking
analytics.trackEvent("test_event", properties: ["test": "value"])
```

### **Debug Mode**
```swift
// Enable debug mode for all components
let debugConfig = DebugConfiguration(
    logLevel: .debug,
    enableConsoleLogging: true,
    enableFileLogging: true
)

let logger = Logger(configuration: debugConfig)

// Network debug
networkClient.enableDebugMode()

// Storage debug
storage.enableDebugMode()

// Analytics debug
analytics.enableDebugMode()
```

### **Performance Monitoring**
```swift
let performance = PerformanceMonitor()

// Monitor app launch
performance.startTimer("app_launch")

// Monitor specific operations
performance.startTimer("api_request")
// ... perform API request
performance.endTimer("api_request")

// Get performance metrics
let metrics = performance.getAllMetrics()
print("Performance metrics: \(metrics)")
```

## 📚 Next Steps

1. **Read [Utility Guide](UtilityGuide.md)** for detailed utility documentation
2. **Check [Network Guide](NetworkGuide.md)** for network utilities
3. **Explore [Storage Guide](StorageGuide.md)** for storage utilities
4. **Review [Analytics Guide](AnalyticsGuide.md)** for analytics utilities
5. **Learn [Debugging Guide](DebuggingGuide.md)** for debugging tools
6. **See [API Reference](API.md)** for complete API documentation

## 🤝 Support

- **Documentation**: [Complete Documentation](Documentation/)
- **Issues**: [GitHub Issues](https://github.com/muhittincamdali/iOSDevelopmentTools/issues)
- **Discussions**: [GitHub Discussions](https://github.com/muhittincamdali/iOSDevelopmentTools/discussions)

---

**Happy developing with iOS Development Tools! 🚀** 