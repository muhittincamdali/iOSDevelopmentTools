import XCTest
import Quick
import Nimble
@testable import DebugTools

class LoggerTests: QuickSpec {
    
    override func spec() {
        
        describe("Logger") {
            
            var logger: Logger!
            
            beforeEach {
                logger = Logger.shared
            }
            
            context("Initialization") {
                
                it("should initialize successfully") {
                    expect(logger).toNot(beNil())
                }
                
                it("should have default configuration") {
                    expect(logger.isEnabled).to(beTrue())
                    expect(logger.logLevel).to(equal(.info))
                }
            }
            
            context("Logging Levels") {
                
                it("should log debug messages") {
                    logger.log(.debug, "Debug message")
                    expect(logger.debugLogsCount).to(beGreaterThan(0))
                }
                
                it("should log info messages") {
                    logger.log(.info, "Info message")
                    expect(logger.infoLogsCount).to(beGreaterThan(0))
                }
                
                it("should log warning messages") {
                    logger.log(.warning, "Warning message")
                    expect(logger.warningLogsCount).to(beGreaterThan(0))
                }
                
                it("should log error messages") {
                    logger.log(.error, "Error message")
                    expect(logger.errorLogsCount).to(beGreaterThan(0))
                }
                
                it("should log critical messages") {
                    logger.log(.critical, "Critical message")
                    expect(logger.criticalLogsCount).to(beGreaterThan(0))
                }
            }
            
            context("Log Filtering") {
                
                it("should filter logs by level") {
                    logger.setLogLevel(.warning)
                    
                    logger.log(.debug, "Debug message")
                    logger.log(.info, "Info message")
                    logger.log(.warning, "Warning message")
                    logger.log(.error, "Error message")
                    
                    expect(logger.debugLogsCount).to(equal(0))
                    expect(logger.infoLogsCount).to(equal(0))
                    expect(logger.warningLogsCount).to(beGreaterThan(0))
                    expect(logger.errorLogsCount).to(beGreaterThan(0))
                }
                
                it("should respect minimum log level") {
                    logger.setLogLevel(.error)
                    
                    logger.log(.info, "Info message")
                    logger.log(.warning, "Warning message")
                    logger.log(.error, "Error message")
                    
                    expect(logger.infoLogsCount).to(equal(0))
                    expect(logger.warningLogsCount).to(equal(0))
                    expect(logger.errorLogsCount).to(beGreaterThan(0))
                }
            }
            
            context("Log Formatting") {
                
                it("should format log messages with timestamp") {
                    let message = "Test message"
                    logger.log(.info, message)
                    
                    let logs = logger.getLogs()
                    expect(logs).toNot(beEmpty())
                    
                    let lastLog = logs.last
                    expect(lastLog).to(contain(message))
                    expect(lastLog).to(contain("INFO"))
                }
                
                it("should include context in log messages") {
                    let context = "UserManager"
                    logger.log(.info, "User logged in", context: context)
                    
                    let logs = logger.getLogs()
                    let lastLog = logs.last
                    expect(lastLog).to(contain(context))
                }
            }
            
            context("Log Storage") {
                
                it("should store logs in memory") {
                    logger.log(.info, "Test message")
                    
                    let logs = logger.getLogs()
                    expect(logs).toNot(beEmpty())
                }
                
                it("should limit log storage") {
                    logger.setMaxLogs(5)
                    
                    for i in 1...10 {
                        logger.log(.info, "Message \(i)")
                    }
                    
                    let logs = logger.getLogs()
                    expect(logs.count).to(beLessThanOrEqualTo(5))
                }
                
                it("should clear logs") {
                    logger.log(.info, "Test message")
                    logger.clearLogs()
                    
                    let logs = logger.getLogs()
                    expect(logs).to(beEmpty())
                }
            }
            
            context("File Logging") {
                
                it("should enable file logging") {
                    logger.enableFileLogging()
                    expect(logger.isFileLoggingEnabled).to(beTrue())
                }
                
                it("should write logs to file") {
                    logger.enableFileLogging()
                    logger.log(.info, "File test message")
                    
                    let logFile = logger.getLogFilePath()
                    expect(logFile).toNot(beNil())
                }
                
                it("should rotate log files") {
                    logger.enableFileLogging()
                    logger.setMaxFileSize(1024) // 1KB
                    
                    // Write large amount of data
                    for i in 1...1000 {
                        logger.log(.info, "Large message \(i) " + String(repeating: "x", count: 100))
                    }
                    
                    let logFiles = logger.getLogFiles()
                    expect(logFiles.count).to(beGreaterThan(1))
                }
            }
            
            context("Remote Logging") {
                
                it("should enable remote logging") {
                    logger.enableRemoteLogging(endpoint: "https://api.example.com/logs")
                    expect(logger.isRemoteLoggingEnabled).to(beTrue())
                }
                
                it("should send logs to remote server") {
                    logger.enableRemoteLogging(endpoint: "https://api.example.com/logs")
                    logger.log(.info, "Remote test message")
                    
                    // Verify remote logging attempt
                    expect(logger.remoteLogsCount).to(beGreaterThan(0))
                }
            }
            
            context("Performance Logging") {
                
                it("should log performance metrics") {
                    logger.logPerformance("api_call", duration: 150.0)
                    
                    let performanceLogs = logger.getPerformanceLogs()
                    expect(performanceLogs).toNot(beEmpty())
                }
                
                it("should log memory usage") {
                    logger.logMemoryUsage()
                    
                    let memoryLogs = logger.getMemoryLogs()
                    expect(memoryLogs).toNot(beEmpty())
                }
                
                it("should log network requests") {
                    logger.logNetworkRequest("GET", url: "https://api.example.com/data", duration: 200.0)
                    
                    let networkLogs = logger.getNetworkLogs()
                    expect(networkLogs).toNot(beEmpty())
                }
            }
            
            context("Error Logging") {
                
                it("should log errors with stack trace") {
                    let error = NSError(domain: "TestDomain", code: 100, userInfo: nil)
                    logger.logError(error)
                    
                    let errorLogs = logger.getErrorLogs()
                    expect(errorLogs).toNot(beEmpty())
                }
                
                it("should log exceptions") {
                    let exception = NSException(name: NSExceptionName("TestException"), reason: "Test reason", userInfo: nil)
                    logger.logException(exception)
                    
                    let exceptionLogs = logger.getExceptionLogs()
                    expect(exceptionLogs).toNot(beEmpty())
                }
            }
            
            context("Configuration") {
                
                it("should enable/disable logging") {
                    logger.setEnabled(false)
                    expect(logger.isEnabled).to(beFalse())
                    
                    logger.log(.info, "This should not be logged")
                    expect(logger.infoLogsCount).to(equal(0))
                    
                    logger.setEnabled(true)
                    expect(logger.isEnabled).to(beTrue())
                }
                
                it("should set log format") {
                    logger.setLogFormat(.detailed)
                    expect(logger.logFormat).to(equal(.detailed))
                }
                
                it("should set timestamp format") {
                    logger.setTimestampFormat("yyyy-MM-dd HH:mm:ss")
                    expect(logger.timestampFormat).to(equal("yyyy-MM-dd HH:mm:ss"))
                }
            }
        }
    }
}
