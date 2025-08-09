# Logging API

<!-- TOC START -->
## Table of Contents
- [Logging API](#logging-api)
- [Overview](#overview)
- [Core Components](#core-components)
  - [AdvancedLoggingManager](#advancedloggingmanager)
  - [LoggingConfiguration](#loggingconfiguration)
  - [LogLevel](#loglevel)
  - [Logger](#logger)
- [Console Logging](#console-logging)
  - [ConsoleLogger](#consolelogger)
  - [Console Configuration](#console-configuration)
- [File Logging](#file-logging)
  - [FileLogger](#filelogger)
  - [LogFile](#logfile)
  - [File Configuration](#file-configuration)
- [Remote Logging](#remote-logging)
  - [RemoteLogger](#remotelogger)
  - [Remote Configuration](#remote-configuration)
  - [Authentication](#authentication)
- [Crash Reporting](#crash-reporting)
  - [CrashReporter](#crashreporter)
  - [CrashReport](#crashreport)
  - [DeviceInfo](#deviceinfo)
- [Structured Logging](#structured-logging)
  - [StructuredLogger](#structuredlogger)
  - [LogEntry](#logentry)
- [Performance Logging](#performance-logging)
  - [PerformanceLogger](#performancelogger)
  - [PerformanceMetrics](#performancemetrics)
- [Error Handling](#error-handling)
  - [LoggingError](#loggingerror)
- [Usage Examples](#usage-examples)
  - [Basic Logging Setup](#basic-logging-setup)
  - [Custom Logger](#custom-logger)
  - [Structured Logging](#structured-logging)
  - [Performance Logging](#performance-logging)
  - [Crash Reporting](#crash-reporting)
  - [Remote Logging](#remote-logging)
- [Best Practices](#best-practices)
  - [Log Level Usage](#log-level-usage)
  - [Performance Considerations](#performance-considerations)
  - [Security Considerations](#security-considerations)
  - [Integration](#integration)
<!-- TOC END -->


## Overview

The Logging API provides comprehensive logging capabilities for iOS applications, including console logging, file logging, remote logging, and crash reporting.

## Core Components

### AdvancedLoggingManager

The main manager for logging operations.

```swift
public class AdvancedLoggingManager {
    public func configure(_ configuration: LoggingConfiguration)
    public func log(_ level: LogLevel, _ message: String, data: Any? = nil, error: Error? = nil)
    public func createLogger(name: String, level: LogLevel) -> Logger
    public func enableCrashReporting()
    public func generateLogReport()
}
```

### LoggingConfiguration

Configuration options for logging setup.

```swift
public struct LoggingConfiguration {
    public var enableConsoleLogging: Bool
    public var enableFileLogging: Bool
    public var enableRemoteLogging: Bool
    public var enableCrashReporting: Bool
    public var logLevel: LogLevel
    public var maxFileSize: Int
    public var maxFileCount: Int
    public var remoteEndpoint: URL?
}
```

### LogLevel

Enumeration for log levels.

```swift
public enum LogLevel: Int, CaseIterable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case critical = 4
    
    public var description: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }
}
```

### Logger

Individual logger instance for specific components.

```swift
public class Logger {
    public let name: String
    public let level: LogLevel
    
    public func debug(_ message: String, data: Any? = nil)
    public func info(_ message: String, data: Any? = nil)
    public func warning(_ message: String, data: Any? = nil)
    public func error(_ message: String, error: Error? = nil, data: Any? = nil)
    public func critical(_ message: String, error: Error? = nil, data: Any? = nil)
}
```

## Console Logging

### ConsoleLogger

Handles console output logging.

```swift
public class ConsoleLogger {
    public func log(_ level: LogLevel, _ message: String, data: Any? = nil)
    public func enableColorOutput()
    public func disableColorOutput()
    public func setTimestampFormat(_ format: String)
}
```

### Console Configuration

```swift
public struct ConsoleConfiguration {
    public var enableColors: Bool
    public var showTimestamp: Bool
    public var showLogLevel: Bool
    public var showLoggerName: Bool
    public var timestampFormat: String
    public var minimumLevel: LogLevel
}
```

## File Logging

### FileLogger

Handles file-based logging.

```swift
public class FileLogger {
    public func log(_ level: LogLevel, _ message: String, data: Any? = nil)
    public func rotateLogs()
    public func cleanupOldLogs()
    public func getLogFiles() -> [LogFile]
    public func exportLogs(to url: URL) -> Bool
}
```

### LogFile

Represents a log file.

```swift
public struct LogFile {
    public let name: String
    public let path: URL
    public let size: Int
    public let createdDate: Date
    public let lastModifiedDate: Date
    public let entryCount: Int
}
```

### File Configuration

```swift
public struct FileConfiguration {
    public var logDirectory: URL
    public var maxFileSize: Int
    public var maxFileCount: Int
    public var enableCompression: Bool
    public var logFormat: LogFormat
    public var minimumLevel: LogLevel
}
```

## Remote Logging

### RemoteLogger

Handles remote logging to external services.

```swift
public class RemoteLogger {
    public func log(_ level: LogLevel, _ message: String, data: Any? = nil)
    public func sendBatch()
    public func configureEndpoint(_ url: URL)
    public func setAuthentication(_ auth: Authentication)
    public func enableRetry()
}
```

### Remote Configuration

```swift
public struct RemoteConfiguration {
    public var endpoint: URL
    public var authentication: Authentication?
    public var batchSize: Int
    public var batchInterval: TimeInterval
    public var enableRetry: Bool
    public var maxRetryAttempts: Int
    public var minimumLevel: LogLevel
}
```

### Authentication

Authentication for remote logging.

```swift
public struct Authentication {
    public let type: AuthType
    public let credentials: [String: String]
    
    public enum AuthType {
        case basic
        case bearer
        case apiKey
        case custom
    }
}
```

## Crash Reporting

### CrashReporter

Handles crash reporting and analysis.

```swift
public class CrashReporter {
    public func enableCrashReporting()
    public func reportCrash(_ crash: CrashReport)
    public func setUserIdentifier(_ identifier: String)
    public func addCustomData(_ data: [String: Any])
    public func generateCrashReport() -> CrashReport?
}
```

### CrashReport

Represents a crash report.

```swift
public struct CrashReport {
    public let type: CrashType
    public let stackTrace: [String]
    public let deviceInfo: DeviceInfo
    public let appVersion: String
    public let timestamp: Date
    public let customData: [String: Any]
    
    public enum CrashType {
        case exception
        case signal
        case memory
        case watchdog
    }
}
```

### DeviceInfo

Device information for crash reports.

```swift
public struct DeviceInfo {
    public let model: String
    public let systemVersion: String
    public let memorySize: Int
    public let diskSpace: Int
    public let batteryLevel: Double
    public let isCharging: Bool
}
```

## Structured Logging

### StructuredLogger

Provides structured logging capabilities.

```swift
public class StructuredLogger {
    public func log(_ level: LogLevel, _ message: String, fields: [String: Any])
    public func addContext(_ key: String, value: Any)
    public func removeContext(_ key: String)
    public func clearContext()
}
```

### LogEntry

Represents a structured log entry.

```swift
public struct LogEntry {
    public let level: LogLevel
    public let message: String
    public let timestamp: Date
    public let loggerName: String
    public let fields: [String: Any]
    public let error: Error?
    public let data: Any?
}
```

## Performance Logging

### PerformanceLogger

Specialized logger for performance metrics.

```swift
public class PerformanceLogger {
    public func logOperation(_ name: String, duration: TimeInterval)
    public func logMemoryUsage(_ usage: Double)
    public func logCPUUsage(_ usage: Double)
    public func logNetworkRequest(_ request: NetworkRequest)
    public func logDatabaseOperation(_ operation: DatabaseOperation)
}
```

### PerformanceMetrics

Performance metrics for logging.

```swift
public struct PerformanceMetrics {
    public let operationName: String
    public let duration: TimeInterval
    public let memoryUsage: Double?
    public let cpuUsage: Double?
    public let timestamp: Date
    public let metadata: [String: Any]
}
```

## Error Handling

### LoggingError

Error types for logging operations.

```swift
public enum LoggingError: Error {
    case configurationError(String)
    case fileError(String)
    case networkError(String)
    case permissionError(String)
    case quotaExceededError(String)
    case invalidFormatError(String)
}
```

## Usage Examples

### Basic Logging Setup

```swift
let loggingManager = AdvancedLoggingManager()

let config = LoggingConfiguration()
config.enableConsoleLogging = true
config.enableFileLogging = true
config.logLevel = .debug

loggingManager.configure(config)

// Log different types of messages
loggingManager.log(.info, "Application started")
loggingManager.log(.debug, "User data loaded", data: userData)
loggingManager.log(.warning, "Network request failed", error: networkError)
loggingManager.log(.error, "Critical error occurred", error: criticalError)
```

### Custom Logger

```swift
let customLogger = loggingManager.createLogger(
    name: "UserManager",
    level: .debug
)

customLogger.info("User logged in successfully")
customLogger.debug("User preferences loaded", data: preferences)
customLogger.error("Failed to save user data", error: saveError)
```

### Structured Logging

```swift
let structuredLogger = StructuredLogger()

structuredLogger.addContext("userId", value: "12345")
structuredLogger.addContext("sessionId", value: "abc123")

structuredLogger.log(.info, "User action performed", fields: [
    "action": "button_tap",
    "screen": "home",
    "button": "login"
])
```

### Performance Logging

```swift
let performanceLogger = PerformanceLogger()

performanceLogger.logOperation("user_login", duration: 1.5)
performanceLogger.logMemoryUsage(45.2)
performanceLogger.logCPUUsage(12.5)

performanceLogger.logNetworkRequest(NetworkRequest(
    url: "https://api.example.com/login",
    method: "POST",
    duration: 2.3,
    statusCode: 200
))
```

### Crash Reporting

```swift
let crashReporter = CrashReporter()

crashReporter.enableCrashReporting()
crashReporter.setUserIdentifier("user123")
crashReporter.addCustomData(["screen": "login", "action": "submit"])

// Handle crash reports
crashReporter.onCrashReport { crashReport in
    print("🚨 Crash detected")
    print("Type: \(crashReport.type)")
    print("Stack trace: \(crashReport.stackTrace)")
    print("Device: \(crashReport.deviceInfo.model)")
    print("App version: \(crashReport.appVersion)")
}
```

### Remote Logging

```swift
let remoteLogger = RemoteLogger()

let remoteConfig = RemoteConfiguration(
    endpoint: URL(string: "https://logs.example.com/api/logs")!,
    authentication: Authentication(
        type: .bearer,
        credentials: ["token": "your-api-token"]
    ),
    batchSize: 100,
    batchInterval: 30.0
)

remoteLogger.configure(remoteConfig)
remoteLogger.log(.info, "Application event", data: eventData)
```

## Best Practices

### Log Level Usage

1. **DEBUG**: Detailed information for debugging
2. **INFO**: General information about application flow
3. **WARNING**: Warning messages for potential issues
4. **ERROR**: Error messages for handled exceptions
5. **CRITICAL**: Critical errors that require immediate attention

### Performance Considerations

1. **Async Logging**: Use asynchronous logging for better performance
2. **Batch Processing**: Batch log entries for remote logging
3. **Log Rotation**: Implement log rotation to manage disk space
4. **Compression**: Compress old log files to save space
5. **Filtering**: Filter logs at the source to reduce noise

### Security Considerations

1. **Sensitive Data**: Never log sensitive information
2. **Authentication**: Use secure authentication for remote logging
3. **Encryption**: Encrypt log files containing sensitive data
4. **Access Control**: Implement proper access controls for log files
5. **Data Retention**: Implement appropriate data retention policies

### Integration

The Logging API integrates seamlessly with other development tools:

- **Debugging Tools**: Correlate logs with debugging sessions
- **Profiling Tools**: Include performance metrics in logs
- **Testing Tools**: Log test execution and results
- **Analytics Tools**: Send structured logs to analytics platforms
