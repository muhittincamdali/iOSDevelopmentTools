# Logging Guide

<!-- TOC START -->
## Table of Contents
- [Logging Guide](#logging-guide)
- [Introduction](#introduction)
- [Table of Contents](#table-of-contents)
- [Getting Started with Logging](#getting-started-with-logging)
  - [Prerequisites](#prerequisites)
  - [Basic Setup](#basic-setup)
  - [Log Levels](#log-levels)
- [Basic Logging](#basic-logging)
  - [Console Logging](#console-logging)
  - [Custom Loggers](#custom-loggers)
  - [Contextual Logging](#contextual-logging)
- [Advanced Logging](#advanced-logging)
  - [File Logging](#file-logging)
  - [Log Rotation](#log-rotation)
  - [Log Export](#log-export)
- [Structured Logging](#structured-logging)
  - [Structured Log Entries](#structured-log-entries)
  - [JSON Logging](#json-logging)
- [Remote Logging](#remote-logging)
  - [Remote Logging Setup](#remote-logging-setup)
  - [Batch Logging](#batch-logging)
  - [Authentication](#authentication)
- [Crash Reporting](#crash-reporting)
  - [Crash Reporting Setup](#crash-reporting-setup)
  - [Crash Report Handling](#crash-report-handling)
  - [Custom Crash Data](#custom-crash-data)
- [Performance Logging](#performance-logging)
  - [Operation Logging](#operation-logging)
  - [System Metrics Logging](#system-metrics-logging)
  - [Network Request Logging](#network-request-logging)
  - [Database Operation Logging](#database-operation-logging)
- [Log Management](#log-management)
  - [Log Filtering](#log-filtering)
  - [Log Compression](#log-compression)
  - [Log Cleanup](#log-cleanup)
- [Best Practices](#best-practices)
  - [Log Level Usage](#log-level-usage)
  - [Performance Considerations](#performance-considerations)
  - [Security Considerations](#security-considerations)
  - [Structured Logging Best Practices](#structured-logging-best-practices)
  - [Remote Logging Best Practices](#remote-logging-best-practices)
- [Troubleshooting](#troubleshooting)
  - [Common Issues](#common-issues)
  - [Debugging Logging Issues](#debugging-logging-issues)
  - [Getting Help](#getting-help)
<!-- TOC END -->


## Introduction

This comprehensive logging guide covers all aspects of logging in iOS applications using the iOS Development Tools framework. From basic console logging to advanced remote logging and crash reporting, this guide provides everything you need to implement effective logging strategies.

## Table of Contents

1. [Getting Started with Logging](#getting-started-with-logging)
2. [Basic Logging](#basic-logging)
3. [Advanced Logging](#advanced-logging)
4. [Structured Logging](#structured-logging)
5. [Remote Logging](#remote-logging)
6. [Crash Reporting](#crash-reporting)
7. [Performance Logging](#performance-logging)
8. [Log Management](#log-management)
9. [Best Practices](#best-practices)
10. [Troubleshooting](#troubleshooting)

## Getting Started with Logging

### Prerequisites

Before you begin logging, ensure you have:

- Xcode 15.0 or later
- iOS 15.0+ SDK
- Swift 5.9+
- iOS Development Tools framework installed

### Basic Setup

```swift
import iOSDevelopmentTools

// Initialize logging manager
let loggingManager = AdvancedLoggingManager()

// Configure logging
let config = LoggingConfiguration()
config.enableConsoleLogging = true
config.enableFileLogging = true
config.logLevel = .debug

// Start logging
loggingManager.configure(config)
```

### Log Levels

Understanding log levels is crucial for effective logging:

- **DEBUG**: Detailed information for debugging
- **INFO**: General information about application flow
- **WARNING**: Warning messages for potential issues
- **ERROR**: Error messages for handled exceptions
- **CRITICAL**: Critical errors that require immediate attention

## Basic Logging

### Console Logging

Basic console output logging:

```swift
let loggingManager = AdvancedLoggingManager()

// Configure console logging
let config = LoggingConfiguration()
config.enableConsoleLogging = true
config.logLevel = .info

loggingManager.configure(config)

// Log different types of messages
loggingManager.log(.info, "Application started")
loggingManager.log(.debug, "User data loaded", data: userData)
loggingManager.log(.warning, "Network request failed", error: networkError)
loggingManager.log(.error, "Critical error occurred", error: criticalError)
```

### Custom Loggers

Create custom loggers for specific components:

```swift
let customLogger = loggingManager.createLogger(
    name: "UserManager",
    level: .debug
)

customLogger.info("User logged in successfully")
customLogger.debug("User preferences loaded", data: preferences)
customLogger.error("Failed to save user data", error: saveError)
```

### Contextual Logging

Add context to your logs:

```swift
let userLogger = loggingManager.createLogger(name: "UserService", level: .debug)

// Add user context
userLogger.info("Processing user request", data: [
    "userId": "12345",
    "action": "login",
    "timestamp": Date()
])

// Add session context
userLogger.debug("Session created", data: [
    "sessionId": "abc123",
    "deviceId": "device456",
    "appVersion": "1.0.0"
])
```

## Advanced Logging

### File Logging

Log to files for persistent storage:

```swift
let config = LoggingConfiguration()
config.enableFileLogging = true
config.maxFileSize = 10 * 1024 * 1024 // 10MB
config.maxFileCount = 5

loggingManager.configure(config)

// Log to file
loggingManager.log(.info, "Application event", data: eventData)
```

### Log Rotation

Implement log rotation to manage disk space:

```swift
let fileLogger = FileLogger()

// Configure log rotation
fileLogger.configure(FileConfiguration(
    logDirectory: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!,
    maxFileSize: 10 * 1024 * 1024, // 10MB
    maxFileCount: 5,
    enableCompression: true
))

// Rotate logs when needed
fileLogger.rotateLogs()

// Clean up old logs
fileLogger.cleanupOldLogs()
```

### Log Export

Export logs for analysis:

```swift
let fileLogger = FileLogger()

// Export logs to a specific location
let exportURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("exported_logs.zip")
let success = fileLogger.exportLogs(to: exportURL)

if success {
    print("✅ Logs exported successfully")
} else {
    print("❌ Failed to export logs")
}
```

## Structured Logging

### Structured Log Entries

Use structured logging for better analysis:

```swift
let structuredLogger = StructuredLogger()

// Add global context
structuredLogger.addContext("appVersion", value: "1.0.0")
structuredLogger.addContext("deviceModel", value: UIDevice.current.model)

// Log structured events
structuredLogger.log(.info, "User action performed", fields: [
    "action": "button_tap",
    "screen": "home",
    "button": "login",
    "timestamp": Date().timeIntervalSince1970
])

// Add user-specific context
structuredLogger.addContext("userId", value: "12345")
structuredLogger.addContext("sessionId", value: "abc123")

structuredLogger.log(.info, "User login attempt", fields: [
    "method": "email",
    "success": true,
    "duration": 1.5
])
```

### JSON Logging

Log in JSON format for easy parsing:

```swift
let jsonLogger = StructuredLogger()

jsonLogger.log(.info, "API request", fields: [
    "url": "https://api.example.com/users",
    "method": "GET",
    "statusCode": 200,
    "responseTime": 1.2,
    "userAgent": "MyApp/1.0.0"
])
```

## Remote Logging

### Remote Logging Setup

Configure remote logging to external services:

```swift
let remoteLogger = RemoteLogger()

// Configure remote endpoint
let remoteConfig = RemoteConfiguration(
    endpoint: URL(string: "https://logs.example.com/api/logs")!,
    authentication: Authentication(
        type: .bearer,
        credentials: ["token": "your-api-token"]
    ),
    batchSize: 100,
    batchInterval: 30.0,
    enableRetry: true,
    maxRetryAttempts: 3
)

remoteLogger.configure(remoteConfig)
```

### Batch Logging

Send logs in batches for efficiency:

```swift
let remoteLogger = RemoteLogger()

// Log multiple entries
remoteLogger.log(.info, "User session started", data: sessionData)
remoteLogger.log(.debug, "Feature flag checked", data: featureData)
remoteLogger.log(.info, "API request made", data: apiData)

// Send batch manually
remoteLogger.sendBatch()

// Or let it send automatically based on batch interval
```

### Authentication

Secure your remote logging with authentication:

```swift
// Basic authentication
let basicAuth = Authentication(
    type: .basic,
    credentials: [
        "username": "your-username",
        "password": "your-password"
    ]
)

// Bearer token authentication
let bearerAuth = Authentication(
    type: .bearer,
    credentials: ["token": "your-bearer-token"]
)

// API key authentication
let apiKeyAuth = Authentication(
    type: .apiKey,
    credentials: ["key": "your-api-key"]
)

remoteLogger.setAuthentication(bearerAuth)
```

## Crash Reporting

### Crash Reporting Setup

Enable crash reporting for your app:

```swift
let crashReporter = CrashReporter()

// Enable crash reporting
crashReporter.enableCrashReporting()

// Set user identifier
crashReporter.setUserIdentifier("user123")

// Add custom data
crashReporter.addCustomData([
    "appVersion": "1.0.0",
    "buildNumber": "100",
    "deviceModel": UIDevice.current.model
])
```

### Crash Report Handling

Handle crash reports when they occur:

```swift
crashReporter.onCrashReport { crashReport in
    print("🚨 Crash detected")
    print("Type: \(crashReport.type)")
    print("Stack trace: \(crashReport.stackTrace)")
    print("Device: \(crashReport.deviceInfo.model)")
    print("App version: \(crashReport.appVersion)")
    print("Timestamp: \(crashReport.timestamp)")
    
    // Send crash report to server
    crashReporter.reportCrash(crashReport)
}
```

### Custom Crash Data

Add custom data to crash reports:

```swift
// Add user-specific data
crashReporter.addCustomData([
    "userId": "12345",
    "userEmail": "user@example.com",
    "lastScreen": "home",
    "lastAction": "button_tap"
])

// Add session data
crashReporter.addCustomData([
    "sessionId": "abc123",
    "sessionDuration": 300.0,
    "interactionCount": 15
])
```

## Performance Logging

### Operation Logging

Log performance metrics for operations:

```swift
let performanceLogger = PerformanceLogger()

// Log operation performance
performanceLogger.logOperation("user_login", duration: 1.5)
performanceLogger.logOperation("data_sync", duration: 3.2)
performanceLogger.logOperation("image_load", duration: 0.8)
```

### System Metrics Logging

Log system performance metrics:

```swift
let performanceLogger = PerformanceLogger()

// Log memory usage
performanceLogger.logMemoryUsage(45.2)

// Log CPU usage
performanceLogger.logCPUUsage(12.5)

// Log battery level
performanceLogger.logBatteryLevel(75.0)
```

### Network Request Logging

Log network request performance:

```swift
let performanceLogger = PerformanceLogger()

// Log network request
performanceLogger.logNetworkRequest(NetworkRequest(
    url: "https://api.example.com/users",
    method: "GET",
    duration: 2.3,
    statusCode: 200,
    dataSize: 1024
))
```

### Database Operation Logging

Log database operation performance:

```swift
let performanceLogger = PerformanceLogger()

// Log database operation
performanceLogger.logDatabaseOperation(DatabaseOperation(
    type: "SELECT",
    table: "users",
    duration: 0.5,
    rowCount: 100
))
```

## Log Management

### Log Filtering

Filter logs based on criteria:

```swift
let loggingManager = AdvancedLoggingManager()

// Configure log filtering
let config = LoggingConfiguration()
config.logLevel = .info // Only log info and above
config.enableConsoleLogging = true
config.enableFileLogging = true

loggingManager.configure(config)

// Log with filtering
loggingManager.log(.debug, "Debug message") // Won't be logged
loggingManager.log(.info, "Info message") // Will be logged
loggingManager.log(.error, "Error message") // Will be logged
```

### Log Compression

Compress log files to save space:

```swift
let fileLogger = FileLogger()

// Configure compression
let fileConfig = FileConfiguration(
    logDirectory: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!,
    maxFileSize: 10 * 1024 * 1024,
    maxFileCount: 5,
    enableCompression: true
)

fileLogger.configure(fileConfig)
```

### Log Cleanup

Clean up old log files:

```swift
let fileLogger = FileLogger()

// Get log files
let logFiles = fileLogger.getLogFiles()

// Clean up old files
for logFile in logFiles {
    let age = Date().timeIntervalSince(logFile.createdDate)
    let maxAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    
    if age > maxAge {
        try? FileManager.default.removeItem(at: logFile.path)
        print("🗑️ Removed old log file: \(logFile.name)")
    }
}
```

## Best Practices

### Log Level Usage

1. **DEBUG**: Use for detailed debugging information
2. **INFO**: Use for general application flow information
3. **WARNING**: Use for potential issues that don't stop execution
4. **ERROR**: Use for handled exceptions and errors
5. **CRITICAL**: Use for critical errors that require immediate attention

### Performance Considerations

1. **Async Logging**: Use asynchronous logging for better performance
2. **Batch Processing**: Batch log entries for remote logging
3. **Log Rotation**: Implement log rotation to manage disk space
4. **Compression**: Compress old log files to save space
5. **Filtering**: Filter logs at the source to reduce noise

### Security Considerations

1. **Sensitive Data**: Never log sensitive information like passwords, tokens, or personal data
2. **Authentication**: Use secure authentication for remote logging
3. **Encryption**: Encrypt log files containing sensitive data
4. **Access Control**: Implement proper access controls for log files
5. **Data Retention**: Implement appropriate data retention policies

### Structured Logging Best Practices

1. **Consistent Format**: Use consistent field names and data types
2. **Context**: Include relevant context in structured logs
3. **Searchable**: Make logs easily searchable and filterable
4. **Parseable**: Use formats that are easy to parse and analyze
5. **Meaningful**: Include meaningful information in log entries

### Remote Logging Best Practices

1. **Batch Processing**: Send logs in batches for efficiency
2. **Retry Logic**: Implement retry logic for failed requests
3. **Rate Limiting**: Respect rate limits of remote services
4. **Authentication**: Use secure authentication methods
5. **Fallback**: Have fallback logging when remote service is unavailable

## Troubleshooting

### Common Issues

1. **High Disk Usage**: Implement log rotation and compression
2. **Slow Performance**: Use async logging and batch processing
3. **Network Failures**: Implement retry logic and fallback logging
4. **Memory Leaks**: Ensure proper cleanup of loggers
5. **Security Issues**: Never log sensitive data

### Debugging Logging Issues

```swift
// Enable debug logging for the logging system itself
let debugLogger = loggingManager.createLogger(name: "LoggingSystem", level: .debug)

debugLogger.debug("Logging system initialized")
debugLogger.info("Log file created", data: ["path": logFilePath])
debugLogger.warning("Remote logging failed", error: networkError)
```

### Getting Help

- Check the [API Documentation](LoggingAPI.md) for detailed information
- Review [Best Practices Guide](BestPracticesGuide.md) for logging guidelines
- Consult the [Troubleshooting Guide](TroubleshootingGuide.md) for common issues
- Join our community for support and discussions
