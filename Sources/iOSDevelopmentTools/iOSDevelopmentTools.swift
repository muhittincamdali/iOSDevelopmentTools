import Foundation
import SwiftUI

// MARK: - iOS Development Tools
public struct iOSDevelopmentTools {
    
    // MARK: - Version
    public static let version = "1.0.0"
    
    // MARK: - Initialization
    public static func initialize() {
        print("🚀 iOS Development Tools v\(version) initialized")
    }
    
    // MARK: - Configuration
    public static func configure(
        networkBaseURL: String,
        analyticsEnabled: Bool = true,
        loggingEnabled: Bool = true
    ) {
        print("⚙️ iOS Development Tools configured")
        print("   - Network Base URL: \(networkBaseURL)")
        print("   - Analytics: \(analyticsEnabled ? "✅" : "❌")")
        print("   - Logging: \(loggingEnabled ? "✅" : "❌")")
        
        // Configure network client
        NetworkClient.shared.configure(baseURL: networkBaseURL)
        
        // Configure analytics
        if analyticsEnabled {
            AnalyticsManager.shared.initialize()
        }
        
        // Configure logging
        if loggingEnabled {
            Logger.shared.initialize()
        }
    }
}

// MARK: - Development Tools Manager
public class DevelopmentToolsManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = DevelopmentToolsManager()
    
    // MARK: - Published Properties
    @Published public var isInitialized = false
    @Published public var networkStatus: NetworkStatus = .unknown
    @Published public var analyticsEnabled = false
    @Published public var loggingEnabled = false
    
    // MARK: - Private Properties
    private var networkClient: NetworkClient!
    private var storageManager: StorageManager!
    private var analyticsManager: AnalyticsManager!
    private var logger: Logger!
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Public Methods
    
    /// Initialize all development tools
    public func initialize() {
        networkClient = NetworkClient.shared
        storageManager = StorageManager.shared
        analyticsManager = AnalyticsManager.shared
        logger = Logger.shared
        
        isInitialized = true
        print("✅ Development Tools Manager initialized")
    }
    
    /// Get network tools
    public var networkTools: NetworkClient {
        guard let networkClient = networkClient else {
            fatalError("Development Tools Manager not initialized")
        }
        return networkClient
    }
    
    /// Get storage tools
    public var storageTools: StorageManager {
        guard let storageManager = storageManager else {
            fatalError("Development Tools Manager not initialized")
        }
        return storageManager
    }
    
    /// Get analytics tools
    public var analyticsTools: AnalyticsManager {
        guard let analyticsManager = analyticsManager else {
            fatalError("Development Tools Manager not initialized")
        }
        return analyticsManager
    }
    
    /// Get debug tools
    public var debugTools: Logger {
        guard let logger = logger else {
            fatalError("Development Tools Manager not initialized")
        }
        return logger
    }
    
    /// Get performance tools
    public var performanceTools: PerformanceLogger {
        return PerformanceLogger.shared
    }
    
    /// Get network logging tools
    public var networkLoggingTools: NetworkLogger {
        return NetworkLogger.shared
    }
    
    /// Get memory logging tools
    public var memoryLoggingTools: MemoryLogger {
        return MemoryLogger.shared
    }
    
    /// Get utility tools
    public var utilityTools: UtilityExtensions {
        return UtilityExtensions()
    }
    
    /// Check network connectivity
    public func checkNetworkConnectivity() async -> NetworkStatus {
        do {
            let isConnected = try await networkClient.checkConnectivity()
            networkStatus = isConnected ? .connected : .disconnected
            return networkStatus
        } catch {
            networkStatus = .error
            return .error
        }
    }
    
    /// Get system information
    public func getSystemInfo() -> SystemInfo {
        return SystemInfo(
            deviceName: UIDevice.current.name,
            systemVersion: UIDevice.current.systemVersion,
            modelName: UIDevice.current.model,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        )
    }
    
    /// Get memory usage
    public func getMemoryUsage() -> MemoryUsage {
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
        
        if kerr == KERN_SUCCESS {
            let usedMemory = Double(info.resident_size) / 1024.0 / 1024.0
            return MemoryUsage(usedMemory: usedMemory, totalMemory: 0) // Total memory not easily available on iOS
        } else {
            return MemoryUsage(usedMemory: 0, totalMemory: 0)
        }
    }
    
    /// Get CPU usage
    public func getCPUUsage() -> CPUUsage {
        var info = processor_info_array_t.allocate(capacity: Int(HOST_CPU_LOAD_INFO_COUNT))
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0
        let result = host_processor_info(mach_host_self(),
                                       PROCESSOR_CPU_LOAD_INFO,
                                       &numCpus,
                                       &info,
                                       &numCpuInfo)
        
        if result == KERN_SUCCESS {
            let cpuLoad = info.withMemoryRebound(to: processor_cpu_load_info.self, capacity: Int(numCpus)) { cpuLoadInfo in
                let user = Double(cpuLoadInfo.pointee.cpu_ticks.0)
                let system = Double(cpuLoadInfo.pointee.cpu_ticks.1)
                let idle = Double(cpuLoadInfo.pointee.cpu_ticks.2)
                let nice = Double(cpuLoadInfo.pointee.cpu_ticks.3)
                let total = user + system + idle + nice
                return ((user + system) / total) * 100.0
            }
            info.deallocate()
            return CPUUsage(usage: cpuLoad)
        } else {
            info.deallocate()
            return CPUUsage(usage: 0)
        }
    }
    
    /// Clear all cached data
    public func clearCache() {
        storageManager.clearCache()
        URLCache.shared.removeAllCachedResponses()
        print("🗑️ Cache cleared")
    }
    
    /// Reset all development tools
    public func reset() {
        networkClient = nil
        storageManager = nil
        analyticsManager = nil
        logger = nil
        isInitialized = false
        print("🔄 Development Tools Manager reset")
    }
}

// MARK: - Supporting Types

/// Network Status
public enum NetworkStatus {
    case unknown
    case connected
    case disconnected
    case error
}

/// System Information
public struct SystemInfo {
    public let deviceName: String
    public let systemVersion: String
    public let modelName: String
    public let appVersion: String
    public let buildNumber: String
    
    public init(
        deviceName: String,
        systemVersion: String,
        modelName: String,
        appVersion: String,
        buildNumber: String
    ) {
        self.deviceName = deviceName
        self.systemVersion = systemVersion
        self.modelName = modelName
        self.appVersion = appVersion
        self.buildNumber = buildNumber
    }
}

/// Memory Usage
public struct MemoryUsage {
    public let usedMemory: Double // MB
    public let totalMemory: Double // MB
    
    public init(usedMemory: Double, totalMemory: Double) {
        self.usedMemory = usedMemory
        self.totalMemory = totalMemory
    }
    
    public var usedMemoryFormatted: String {
        return String(format: "%.1f MB", usedMemory)
    }
    
    public var totalMemoryFormatted: String {
        return String(format: "%.1f MB", totalMemory)
    }
}

/// CPU Usage
public struct CPUUsage {
    public let usage: Double // Percentage
    
    public init(usage: Double) {
        self.usage = usage
    }
    
    public var usageFormatted: String {
        return String(format: "%.1f%%", usage)
    }
}

/// Development Tools Error
public enum DevelopmentToolsError: LocalizedError {
    case notInitialized
    case networkError(Error)
    case storageError(Error)
    case analyticsError(Error)
    case loggingError(Error)
    case configurationError(String)
    
    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Development Tools Manager not initialized"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .storageError(let error):
            return "Storage error: \(error.localizedDescription)"
        case .analyticsError(let error):
            return "Analytics error: \(error.localizedDescription)"
        case .loggingError(let error):
            return "Logging error: \(error.localizedDescription)"
        case .configurationError(let reason):
            return "Configuration error: \(reason)"
        }
    }
} 