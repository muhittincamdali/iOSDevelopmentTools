import Foundation
import iOSDevelopmentTools

// MARK: - Debugging Examples
// This file demonstrates how to use the debugging tools provided by iOSDevelopmentTools

class DebuggingExample {
    
    // MARK: - Properties
    private let debugManager = DebuggingManager()
    private let loggingManager = LoggingManager()
    private let crashManager = CrashManager()
    
    // MARK: - Initialization
    init() {
        setupDebugging()
    }
    
    // MARK: - Setup
    private func setupDebugging() {
        // Configure debugging manager
        let debugConfig = DebuggingConfiguration()
        debugConfig.enableConsoleLogging = true
        debugConfig.enableFileLogging = true
        debugConfig.enableRemoteLogging = true
        debugConfig.enableCrashReporting = true
        debugConfig.logLevel = .debug
        
        debugManager.configure(debugConfig)
        
        // Configure logging manager
        let loggingConfig = LoggingConfiguration()
        loggingConfig.enableTimestamp = true
        loggingConfig.enableThreadInfo = true
        loggingConfig.enableFileInfo = true
        loggingConfig.enableFunctionInfo = true
        
        loggingManager.configure(loggingConfig)
        
        // Configure crash manager
        let crashConfig = CrashConfiguration()
        crashConfig.enableAutomaticReporting = true
        crashConfig.enableSymbolication = true
        crashConfig.enableCrashAnalytics = true
        
        crashManager.configure(crashConfig)
    }
    
    // MARK: - Debugging Methods
    
    /// Demonstrates basic logging functionality
    func demonstrateBasicLogging() {
        loggingManager.log(.info, "Application started")
        loggingManager.log(.debug, "User data loaded", data: ["userId": "12345"])
        loggingManager.log(.warning, "Network request failed", error: NetworkError.timeout)
        loggingManager.log(.error, "Critical error occurred", error: CriticalError.databaseConnection)
    }
    
    /// Demonstrates advanced debugging features
    func demonstrateAdvancedDebugging() {
        // Start performance monitoring
        debugManager.startPerformanceMonitoring { metrics in
            print("📊 Performance metrics:")
            print("CPU Usage: \(metrics.cpuUsage)%")
            print("Memory Usage: \(metrics.memoryUsage)MB")
            print("Battery Level: \(metrics.batteryLevel)%")
        }
        
        // Monitor network requests
        debugManager.startNetworkMonitoring { request in
            print("🌐 Network request: \(request.url)")
            print("Method: \(request.method)")
            print("Response time: \(request.responseTime)ms")
        }
        
        // Monitor memory usage
        debugManager.startMemoryMonitoring { memoryInfo in
            print("💾 Memory info:")
            print("Used memory: \(memoryInfo.usedMemory)MB")
            print("Available memory: \(memoryInfo.availableMemory)MB")
            print("Memory pressure: \(memoryInfo.pressureLevel)")
        }
    }
    
    /// Demonstrates crash reporting
    func demonstrateCrashReporting() {
        // Handle crash reports
        crashManager.onCrashReport { crashReport in
            print("🚨 Crash detected:")
            print("Type: \(crashReport.type)")
            print("Stack trace: \(crashReport.stackTrace)")
            print("Device info: \(crashReport.deviceInfo)")
            
            // Send crash report to server
            crashManager.sendCrashReport(crashReport) { result in
                switch result {
                case .success:
                    print("✅ Crash report sent successfully")
                case .failure(let error):
                    print("❌ Failed to send crash report: \(error)")
                }
            }
        }
    }
    
    /// Demonstrates debugging utilities
    func demonstrateDebuggingUtilities() {
        // Create custom logger
        let customLogger = loggingManager.createLogger(name: "UserManager", level: .debug)
        
        customLogger.info("User logged in successfully")
        customLogger.debug("User preferences loaded", data: ["theme": "dark"])
        customLogger.warning("User session expiring soon")
        customLogger.error("Failed to sync user data", error: SyncError.networkUnavailable)
        
        // Debug information
        debugManager.printDebugInfo()
        debugManager.printSystemInfo()
        debugManager.printAppInfo()
    }
}

// MARK: - Error Types
enum NetworkError: Error {
    case timeout
    case noConnection
    case serverError
}

enum CriticalError: Error {
    case databaseConnection
    case fileSystem
    case memoryLeak
}

enum SyncError: Error {
    case networkUnavailable
    case serverUnavailable
    case dataCorruption
}

// MARK: - Usage Example
extension DebuggingExample {
    
    /// Complete debugging setup and usage example
    static func runExample() {
        let example = DebuggingExample()
        
        // Run all demonstrations
        example.demonstrateBasicLogging()
        example.demonstrateAdvancedDebugging()
        example.demonstrateCrashReporting()
        example.demonstrateDebuggingUtilities()
        
        print("✅ Debugging example completed successfully")
    }
} 