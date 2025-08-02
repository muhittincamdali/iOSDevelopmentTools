import Foundation
import os.log

// MARK: - Log Level
public enum LogLevel: String, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
    
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
}

// MARK: - Logger Protocol
public protocol LoggerProtocol {
    func log(_ level: LogLevel, message: String, file: String, function: String, line: Int)
    func debug(_ message: String, file: String, function: String, line: Int)
    func info(_ message: String, file: String, function: String, line: Int)
    func warning(_ message: String, file: String, function: String, line: Int)
    func error(_ message: String, file: String, function: String, line: Int)
    func critical(_ message: String, file: String, function: String, line: Int)
}

// MARK: - Logger Implementation
public class Logger: LoggerProtocol {
    public static let shared = Logger()
    
    private let osLog: OSLog
    private let dateFormatter: DateFormatter
    private let queue = DispatchQueue(label: "com.iosdevelopmenttools.logger", qos: .utility)
    
    public init(subsystem: String = Bundle.main.bundleIdentifier ?? "iOSDevelopmentTools") {
        self.osLog = OSLog(subsystem: subsystem, category: "Logger")
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }
    
    // MARK: - Logging Methods
    public func log(_ level: LogLevel, message: String, file: String, function: String, line: Int) {
        let timestamp = dateFormatter.string(from: Date())
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        
        let logMessage = "\(level.emoji) [\(timestamp)] [\(level.rawValue)] [\(fileName):\(line)] \(function): \(message)"
        
        // Console output
        print(logMessage)
        
        // OS Log
        os_log("%{public}@", log: osLog, type: level.osLogType, logMessage)
        
        // File logging (if enabled)
        writeToFile(logMessage)
        
        // Remote logging (if enabled)
        sendToRemote(level: level, message: message, file: fileName, function: function, line: line)
    }
    
    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message: message, file: file, function: function, line: line)
    }
    
    public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message: message, file: file, function: function, line: line)
    }
    
    public func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message: message, file: file, function: function, line: line)
    }
    
    public func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message: message, file: file, function: function, line: line)
    }
    
    public func critical(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.critical, message: message, file: file, function: function, line: line)
    }
    
    // MARK: - Private Methods
    private func writeToFile(_ message: String) {
        queue.async {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let logFile = documentsPath.appendingPathComponent("app.log")
            
            let logEntry = message + "\n"
            
            if let data = logEntry.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: logFile.path) {
                    if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
                } else {
                    try? data.write(to: logFile)
                }
            }
        }
    }
    
    private func sendToRemote(level: LogLevel, message: String, file: String, function: String, line: Int) {
        // Remote logging implementation (e.g., Crashlytics, Sentry)
        if level == .error || level == .critical {
            // Send to crash reporting service
            print("Sending to remote logging service: \(message)")
        }
    }
}

// MARK: - Performance Logger
public class PerformanceLogger {
    private var measurements: [String: TimeInterval] = [:]
    private let logger = Logger.shared
    
    public init() {}
    
    public func startMeasurement(_ name: String) {
        measurements[name] = CFAbsoluteTimeGetCurrent()
        logger.debug("Started measurement: \(name)")
    }
    
    public func endMeasurement(_ name: String) {
        guard let startTime = measurements[name] else {
            logger.warning("No start time found for measurement: \(name)")
            return
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        measurements.removeValue(forKey: name)
        
        logger.info("Measurement '\(name)' completed in \(String(format: "%.3f", duration))s")
    }
    
    public func measure<T>(_ name: String, operation: () throws -> T) rethrows -> T {
        startMeasurement(name)
        defer { endMeasurement(name) }
        return try operation()
    }
    
    public func measureAsync<T>(_ name: String, operation: () async throws -> T) async rethrows -> T {
        startMeasurement(name)
        defer { endMeasurement(name) }
        return try await operation()
    }
}

// MARK: - Network Logger
public class NetworkLogger {
    private let logger = Logger.shared
    
    public init() {}
    
    public func logRequest(_ request: URLRequest) {
        let url = request.url?.absoluteString ?? "Unknown URL"
        let method = request.httpMethod ?? "Unknown Method"
        
        logger.info("🌐 Network Request: \(method) \(url)")
        
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            logger.debug("📋 Headers: \(headers)")
        }
        
        if let body = request.httpBody {
            logger.debug("📦 Body: \(String(data: body, encoding: .utf8) ?? "Unable to decode")")
        }
    }
    
    public func logResponse(_ response: URLResponse, data: Data?, error: Error?) {
        let url = response.url?.absoluteString ?? "Unknown URL"
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        
        if let error = error {
            logger.error("❌ Network Error: \(statusCode) \(url) - \(error.localizedDescription)")
        } else {
            logger.info("✅ Network Response: \(statusCode) \(url)")
            
            if let data = data {
                logger.debug("📦 Response Data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            }
        }
    }
}

// MARK: - Memory Logger
public class MemoryLogger {
    private let logger = Logger.shared
    
    public init() {}
    
    public func logMemoryUsage() {
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
            let memoryUsageMB = Double(info.resident_size) / 1024 / 1024
            logger.info("💾 Memory Usage: \(String(format: "%.2f", memoryUsageMB)) MB")
        } else {
            logger.warning("Unable to get memory usage")
        }
    }
}

// MARK: - Convenience Extensions
public extension Logger {
    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        shared.debug(message, file: file, function: function, line: line)
    }
    
    static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        shared.info(message, file: file, function: function, line: line)
    }
    
    static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        shared.warning(message, file: file, function: function, line: line)
    }
    
    static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        shared.error(message, file: file, function: function, line: line)
    }
    
    static func critical(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        shared.critical(message, file: file, function: function, line: line)
    }
} 