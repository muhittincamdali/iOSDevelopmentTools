# 🐛 Debugging Guide

Complete debugging utilities documentation for iOS Development Tools.

## 📋 Table of Contents

- [Logger](#logger)
- [Performance Monitoring](#performance-monitoring)
- [Crash Reporting](#crash-reporting)
- [Network Debugging](#network-debugging)
- [Memory Debugging](#memory-debugging)

## 📝 Logger

### **Basic Usage**
```swift
let logger = Logger()

// Log levels
logger.debug("Debug message")
logger.info("Info message")
logger.warning("Warning message")
logger.error("Error message")
logger.critical("Critical error")
```

### **Configuration**
```swift
let config = DebugConfiguration(
    logLevel: .debug,
    enableConsoleLogging: true,
    enableFileLogging: true,
    logDirectory: "logs"
)

let logger = Logger(configuration: config)
```

### **Advanced Logging**
```swift
// Log with context
logger.debug("User action", context: [
    "user_id": "12345",
    "action": "button_click",
    "screen": "HomeViewController"
])

// Log with error
do {
    try someRiskyOperation()
} catch {
    logger.error("Operation failed", error: error)
}

// Log performance
logger.info("API request completed", context: [
    "duration": "1.2s",
    "endpoint": "/users",
    "status_code": 200
])
```

## ⚡ Performance Monitoring

### **Performance Monitor**
```swift
let performance = PerformanceMonitor()

// Start timer
performance.startTimer("api_request")

// Perform operation
try await networkClient.perform(request)

// End timer
performance.endTimer("api_request")

// Get duration
let duration = performance.getTimerDuration("api_request")
print("API request took: \(duration) seconds")
```

### **Memory Monitoring**
```swift
class MemoryMonitor {
    func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    func isMemoryPressureHigh() -> Bool {
        let usage = getCurrentMemoryUsage()
        return usage > 150 * 1024 * 1024 // 150MB
    }
    
    func logMemoryUsage() {
        let usage = getCurrentMemoryUsage()
        let usageMB = Double(usage) / 1024 / 1024
        logger.info("Memory usage: \(usageMB) MB")
    }
}
```

### **CPU Monitoring**
```swift
class CPUMonitor {
    func getCurrentCPUUsage() -> Double {
        var totalUsageOfCPU: Double = 0.0
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        
        let threadResult = task_threads(mach_task_self_, &threadList, &threadCount)
        
        if threadResult == KERN_SUCCESS, let threadList = threadList {
            for index in 0..<threadCount {
                var threadInfo = thread_basic_info()
                var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
                
                let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        thread_info(threadList[Int(index)],
                                  thread_flavor_t(THREAD_BASIC_INFO),
                                  $0,
                                  &threadInfoCount)
                    }
                }
                
                if infoResult == KERN_SUCCESS {
                    totalUsageOfCPU += Double(threadInfo.cpu_usage) / Double(TH_USAGE_SCALE)
                }
            }
            
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threadList)), vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.size))
        }
        
        return totalUsageOfCPU
    }
}
```

## 💥 Crash Reporting

### **Crash Reporter**
```swift
class CrashReporter {
    private let logger: Logger
    
    init(logger: Logger) {
        self.logger = logger
        setupCrashReporting()
    }
    
    private func setupCrashReporting() {
        // Set up signal handlers
        signal(SIGABRT) { signal in
            CrashReporter.shared.handleCrash(signal: signal)
        }
        
        signal(SIGSEGV) { signal in
            CrashReporter.shared.handleCrash(signal: signal)
        }
        
        signal(SIGBUS) { signal in
            CrashReporter.shared.handleCrash(signal: signal)
        }
    }
    
    func handleCrash(signal: Int32) {
        let crashInfo = CrashInfo(
            signal: signal,
            timestamp: Date(),
            stackTrace: getStackTrace(),
            deviceInfo: getDeviceInfo()
        )
        
        logger.critical("App crashed", context: [
            "signal": signal,
            "stack_trace": crashInfo.stackTrace,
            "device_info": crashInfo.deviceInfo
        ])
        
        // Save crash report
        saveCrashReport(crashInfo)
    }
    
    private func getStackTrace() -> String {
        // Implementation to get stack trace
        return Thread.callStackSymbols.joined(separator: "\n")
    }
    
    private func getDeviceInfo() -> [String: Any] {
        return [
            "device_model": UIDevice.current.model,
            "system_version": UIDevice.current.systemVersion,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ]
    }
    
    private func saveCrashReport(_ crashInfo: CrashInfo) {
        // Implementation to save crash report
    }
}

struct CrashInfo {
    let signal: Int32
    let timestamp: Date
    let stackTrace: String
    let deviceInfo: [String: Any]
}
```

## 🌐 Network Debugging

### **Network Debugger**
```swift
class NetworkDebugger {
    private let logger: Logger
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    func logRequest(_ request: URLRequest) {
        logger.debug("Network Request", context: [
            "url": request.url?.absoluteString ?? "unknown",
            "method": request.httpMethod ?? "unknown",
            "headers": request.allHTTPHeaderFields ?? [:],
            "body": request.httpBody?.count ?? 0
        ])
    }
    
    func logResponse(_ response: URLResponse, data: Data?) {
        logger.debug("Network Response", context: [
            "url": response.url?.absoluteString ?? "unknown",
            "status_code": (response as? HTTPURLResponse)?.statusCode ?? 0,
            "headers": (response as? HTTPURLResponse)?.allHeaderFields ?? [:],
            "data_size": data?.count ?? 0
        ])
    }
    
    func logError(_ error: Error, request: URLRequest?) {
        logger.error("Network Error", context: [
            "error": error.localizedDescription,
            "url": request?.url?.absoluteString ?? "unknown",
            "method": request?.httpMethod ?? "unknown"
        ])
    }
}
```

### **Network Interceptor**
```swift
class NetworkInterceptor: URLProtocol {
    static var requestHandler: ((URLRequest) -> Void)?
    static var responseHandler: ((URLResponse, Data?) -> Void)?
    static var errorHandler: ((Error) -> Void)?
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        NetworkInterceptor.requestHandler?(request)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                NetworkInterceptor.errorHandler?(error)
            } else if let response = response {
                NetworkInterceptor.responseHandler?(response, data)
            }
            
            self.client?.urlProtocolDidFinishLoading(self)
        }
        
        task.resume()
    }
    
    override func stopLoading() {
        // Implementation
    }
}
```

## 🧠 Memory Debugging

### **Memory Leak Detector**
```swift
class MemoryLeakDetector {
    private var trackedObjects: [String: WeakReference] = [:]
    private let logger: Logger
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    func trackObject(_ object: AnyObject, name: String) {
        trackedObjects[name] = WeakReference(object)
    }
    
    func checkForLeaks() {
        for (name, weakRef) in trackedObjects {
            if weakRef.object == nil {
                logger.warning("Potential memory leak detected", context: [
                    "object_name": name
                ])
            }
        }
    }
}

class WeakReference {
    weak var object: AnyObject?
    
    init(_ object: AnyObject) {
        self.object = object
    }
}
```

### **Memory Usage Tracker**
```swift
class MemoryUsageTracker {
    private let logger: Logger
    private var snapshots: [MemorySnapshot] = []
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    func takeSnapshot(_ name: String) {
        let snapshot = MemorySnapshot(
            name: name,
            timestamp: Date(),
            memoryUsage: getCurrentMemoryUsage()
        )
        
        snapshots.append(snapshot)
        
        logger.debug("Memory snapshot taken", context: [
            "name": name,
            "memory_usage": snapshot.memoryUsage
        ])
    }
    
    func compareSnapshots() {
        guard snapshots.count >= 2 else { return }
        
        let first = snapshots.first!
        let last = snapshots.last!
        let difference = last.memoryUsage - first.memoryUsage
        
        logger.info("Memory usage comparison", context: [
            "start": first.name,
            "end": last.name,
            "difference": difference,
            "duration": last.timestamp.timeIntervalSince(first.timestamp)
        ])
    }
    
    private func getCurrentMemoryUsage() -> Int64 {
        // Implementation to get current memory usage
        return 0
    }
}

struct MemorySnapshot {
    let name: String
    let timestamp: Date
    let memoryUsage: Int64
}
```

## 🔧 Debug Tools

### **Debug Menu**
```swift
class DebugMenu {
    private let logger: Logger
    private let performance: PerformanceMonitor
    
    init(logger: Logger, performance: PerformanceMonitor) {
        self.logger = logger
        self.performance = performance
    }
    
    func showDebugMenu() {
        let alert = UIAlertController(title: "Debug Menu", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Log Memory Usage", style: .default) { _ in
            self.logMemoryUsage()
        })
        
        alert.addAction(UIAlertAction(title: "Log Performance Metrics", style: .default) { _ in
            self.logPerformanceMetrics()
        })
        
        alert.addAction(UIAlertAction(title: "Clear Logs", style: .destructive) { _ in
            self.clearLogs()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // Present alert
    }
    
    private func logMemoryUsage() {
        let monitor = MemoryMonitor()
        monitor.logMemoryUsage()
    }
    
    private func logPerformanceMetrics() {
        let metrics = performance.getAllMetrics()
        logger.info("Performance metrics", context: metrics)
    }
    
    private func clearLogs() {
        // Implementation to clear logs
        logger.info("Logs cleared")
    }
}
```

## 📚 Next Steps

1. **Read [Getting Started](GettingStarted.md)** for quick setup
2. **Check [Network Guide](NetworkGuide.md)** for network utilities
3. **Explore [Storage Guide](StorageGuide.md)** for storage utilities
4. **Review [Analytics Guide](AnalyticsGuide.md)** for analytics utilities
5. **Learn [Utility Guide](UtilityGuide.md)** for utility functions
6. **See [API Reference](API.md)** for complete API documentation

## 🤝 Support

- **Documentation**: [Complete Documentation](Documentation/)
- **Issues**: [GitHub Issues](https://github.com/muhittincamdali/iOSDevelopmentTools/issues)
- **Discussions**: [GitHub Discussions](https://github.com/muhittincamdali/iOSDevelopmentTools/discussions)

---

**Happy debugging with iOS Development Tools! 🐛** 