import Foundation
import iOSDevelopmentTools

// MARK: - Profiling Examples
// This file demonstrates how to use the profiling tools provided by iOSDevelopmentTools

class ProfilingExample {
    
    // MARK: - Properties
    private let performanceProfiler = PerformanceProfiler()
    private let memoryProfiler = MemoryProfiler()
    private let networkProfiler = NetworkProfiler()
    private let batteryProfiler = BatteryProfiler()
    
    // MARK: - Initialization
    init() {
        setupProfiling()
    }
    
    // MARK: - Setup
    private func setupProfiling() {
        // Configure performance profiler
        let performanceConfig = PerformanceProfilingConfiguration()
        performanceConfig.enableCPUProfiling = true
        performanceConfig.enableMemoryProfiling = true
        performanceConfig.enableNetworkProfiling = true
        performanceConfig.enableBatteryProfiling = true
        performanceConfig.enableStorageProfiling = true
        performanceConfig.enableUIProfiling = true
        
        performanceProfiler.configure(performanceConfig)
        
        // Configure memory profiler
        let memoryConfig = MemoryProfilingConfiguration()
        memoryConfig.enableLeakDetection = true
        memoryConfig.enableMemoryWarnings = true
        memoryConfig.enableMemoryOptimization = true
        memoryConfig.enableMemoryTracking = true
        
        memoryProfiler.configure(memoryConfig)
        
        // Configure network profiler
        let networkConfig = NetworkProfilingConfiguration()
        networkConfig.enableRequestMonitoring = true
        networkConfig.enableResponseAnalysis = true
        networkConfig.enableErrorTracking = true
        networkConfig.enablePerformanceMetrics = true
        
        networkProfiler.configure(networkConfig)
        
        // Configure battery profiler
        let batteryConfig = BatteryProfilingConfiguration()
        batteryConfig.enableBatteryMonitoring = true
        batteryConfig.enablePowerConsumption = true
        batteryConfig.enableBackgroundTaskTracking = true
        batteryConfig.enableOptimization = true
        
        batteryProfiler.configure(batteryConfig)
    }
    
    // MARK: - Profiling Methods
    
    /// Demonstrates performance profiling
    func demonstratePerformanceProfiling() {
        // Start comprehensive performance profiling
        performanceProfiler.startProfiling { performanceData in
            print("📊 Performance data collected:")
            print("CPU Usage: \(performanceData.cpuUsage)%")
            print("Memory Usage: \(performanceData.memoryUsage)MB")
            print("Network Requests: \(performanceData.networkRequests)")
            print("Battery Usage: \(performanceData.batteryUsage)%")
            print("Storage Usage: \(performanceData.storageUsage)MB")
            print("UI FPS: \(performanceData.uiFPS)")
            
            if performanceData.isPerformanceIssue {
                print("⚠️ Performance issue detected")
                performanceProfiler.generatePerformanceReport()
            }
        }
        
        // Profile specific operations
        performanceProfiler.profileOperation("Data Processing") {
            // Simulate data processing
            for i in 0..<10000 {
                let _ = i * i
            }
        }
        
        // Profile UI operations
        performanceProfiler.profileUIOperation("Table View Scrolling") {
            // Simulate table view scrolling
            for i in 0..<100 {
                let _ = "Cell \(i)"
            }
        }
    }
    
    /// Demonstrates memory profiling
    func demonstrateMemoryProfiling() {
        // Start memory monitoring
        memoryProfiler.startMemoryMonitoring { memoryInfo in
            print("💾 Memory monitoring:")
            print("Used memory: \(memoryInfo.usedMemory)MB")
            print("Available memory: \(memoryInfo.availableMemory)MB")
            print("Memory pressure: \(memoryInfo.pressureLevel)")
            print("Memory warnings: \(memoryInfo.warningCount)")
            
            if memoryInfo.isLowMemory {
                print("⚠️ Low memory warning")
                memoryProfiler.handleLowMemory()
            }
        }
        
        // Detect memory leaks
        memoryProfiler.startLeakDetection { leakInfo in
            print("🔍 Memory leak detected:")
            print("Leaked object: \(leakInfo.objectType)")
            print("Leak size: \(leakInfo.leakSize) bytes")
            print("Retain cycle: \(leakInfo.retainCycle)")
            print("Stack trace: \(leakInfo.stackTrace)")
        }
        
        // Memory optimization
        memoryProfiler.optimizeMemory { optimizationResult in
            print("🔧 Memory optimization:")
            print("Optimized objects: \(optimizationResult.optimizedObjects)")
            print("Freed memory: \(optimizationResult.freedMemory)MB")
            print("Optimization time: \(optimizationResult.optimizationTime)ms")
        }
    }
    
    /// Demonstrates network profiling
    func demonstrateNetworkProfiling() {
        // Monitor network requests
        networkProfiler.startMonitoring { networkData in
            print("🌐 Network profiling:")
            print("URL: \(networkData.url)")
            print("Method: \(networkData.method)")
            print("Response time: \(networkData.responseTime)ms")
            print("Status code: \(networkData.statusCode)")
            print("Data size: \(networkData.dataSize) bytes")
            print("Bandwidth: \(networkData.bandwidth) Mbps")
            
            if networkData.isSlowRequest {
                print("⚠️ Slow network request detected")
                networkProfiler.analyzeSlowRequest(networkData)
            }
        }
        
        // Analyze network performance
        networkProfiler.analyzeNetworkPerformance { analysis in
            print("📈 Network performance analysis:")
            print("Average response time: \(analysis.averageResponseTime)ms")
            print("Success rate: \(analysis.successRate)%")
            print("Error rate: \(analysis.errorRate)%")
            print("Bandwidth usage: \(analysis.bandwidthUsage) Mbps")
        }
    }
    
    /// Demonstrates battery profiling
    func demonstrateBatteryProfiling() {
        // Monitor battery usage
        batteryProfiler.startBatteryMonitoring { batteryInfo in
            print("🔋 Battery profiling:")
            print("Battery level: \(batteryInfo.level)%")
            print("Battery state: \(batteryInfo.state)")
            print("Power consumption: \(batteryInfo.powerConsumption) mW")
            print("Estimated time remaining: \(batteryInfo.estimatedTimeRemaining) minutes")
            
            if batteryInfo.isLowBattery {
                print("⚠️ Low battery warning")
                batteryProfiler.handleLowBattery()
            }
        }
        
        // Track background tasks
        batteryProfiler.trackBackgroundTasks { taskInfo in
            print("🔄 Background task tracking:")
            print("Task name: \(taskInfo.name)")
            print("Task duration: \(taskInfo.duration)ms")
            print("Power impact: \(taskInfo.powerImpact)%")
            print("CPU usage: \(taskInfo.cpuUsage)%")
        }
        
        // Battery optimization
        batteryProfiler.optimizeBatteryUsage { optimizationResult in
            print("🔧 Battery optimization:")
            print("Optimized tasks: \(optimizationResult.optimizedTasks)")
            print("Power saved: \(optimizationResult.powerSaved) mW")
            print("Extended battery life: \(optimizationResult.extendedLife) minutes")
        }
    }
    
    /// Demonstrates profiling utilities
    func demonstrateProfilingUtilities() {
        // Generate comprehensive report
        performanceProfiler.generateComprehensiveReport { report in
            print("📋 Comprehensive profiling report:")
            print("Report ID: \(report.id)")
            print("Generated at: \(report.generatedAt)")
            print("Performance score: \(report.performanceScore)/100")
            print("Recommendations: \(report.recommendations.count)")
            
            for recommendation in report.recommendations {
                print("- \(recommendation.description)")
            }
        }
        
        // Export profiling data
        performanceProfiler.exportProfilingData { result in
            switch result {
            case .success(let data):
                print("✅ Profiling data exported successfully")
                print("Data size: \(data.size) bytes")
                print("Export format: \(data.format)")
            case .failure(let error):
                print("❌ Failed to export profiling data: \(error)")
            }
        }
    }
}

// MARK: - Usage Example
extension ProfilingExample {
    
    /// Complete profiling setup and usage example
    static func runExample() {
        let example = ProfilingExample()
        
        // Run all profiling demonstrations
        example.demonstratePerformanceProfiling()
        example.demonstrateMemoryProfiling()
        example.demonstrateNetworkProfiling()
        example.demonstrateBatteryProfiling()
        example.demonstrateProfilingUtilities()
        
        print("✅ Profiling example completed successfully")
    }
} 