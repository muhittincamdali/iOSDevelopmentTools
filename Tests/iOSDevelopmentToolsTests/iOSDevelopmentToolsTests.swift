import XCTest
@testable import iOSDevelopmentTools

final class iOSDevelopmentToolsTests: XCTestCase {
    
    var developmentTools: DevelopmentToolsManager!
    
    override func setUp() {
        super.setUp()
        developmentTools = DevelopmentToolsManager.shared
        developmentTools.initialize()
    }
    
    override func tearDown() {
        developmentTools = nil
        super.tearDown()
    }
    
    // MARK: - Development Tools Manager Tests
    
    func testDevelopmentToolsManagerInitialization() {
        XCTAssertNotNil(developmentTools)
        XCTAssertTrue(developmentTools.isInitialized)
    }
    
    func testNetworkToolsAccess() {
        // Given & When & Then
        let networkTools = developmentTools.networkTools
        XCTAssertNotNil(networkTools)
    }
    
    func testStorageToolsAccess() {
        // Given & When & Then
        let storageTools = developmentTools.storageTools
        XCTAssertNotNil(storageTools)
    }
    
    func testAnalyticsToolsAccess() {
        // Given & When & Then
        let analyticsTools = developmentTools.analyticsTools
        XCTAssertNotNil(analyticsTools)
    }
    
    func testDebugToolsAccess() {
        // Given & When & Then
        let debugTools = developmentTools.debugTools
        XCTAssertNotNil(debugTools)
    }
    
    func testPerformanceToolsAccess() {
        // Given & When & Then
        let performanceTools = developmentTools.performanceTools
        XCTAssertNotNil(performanceTools)
    }
    
    func testNetworkLoggingToolsAccess() {
        // Given & When & Then
        let networkLoggingTools = developmentTools.networkLoggingTools
        XCTAssertNotNil(networkLoggingTools)
    }
    
    func testMemoryLoggingToolsAccess() {
        // Given & When & Then
        let memoryLoggingTools = developmentTools.memoryLoggingTools
        XCTAssertNotNil(memoryLoggingTools)
    }
    
    func testUtilityToolsAccess() {
        // Given & When & Then
        let utilityTools = developmentTools.utilityTools
        XCTAssertNotNil(utilityTools)
    }
    
    func testSystemInfo() {
        // Given & When
        let systemInfo = developmentTools.getSystemInfo()
        
        // Then
        XCTAssertNotNil(systemInfo.deviceName)
        XCTAssertNotNil(systemInfo.systemVersion)
        XCTAssertNotNil(systemInfo.modelName)
        XCTAssertNotNil(systemInfo.appVersion)
        XCTAssertNotNil(systemInfo.buildNumber)
    }
    
    func testMemoryUsage() {
        // Given & When
        let memoryUsage = developmentTools.getMemoryUsage()
        
        // Then
        XCTAssertGreaterThanOrEqual(memoryUsage.usedMemory, 0)
        XCTAssertGreaterThanOrEqual(memoryUsage.totalMemory, 0)
        XCTAssertFalse(memoryUsage.usedMemoryFormatted.isEmpty)
        XCTAssertFalse(memoryUsage.totalMemoryFormatted.isEmpty)
    }
    
    func testCPUUsage() {
        // Given & When
        let cpuUsage = developmentTools.getCPUUsage()
        
        // Then
        XCTAssertGreaterThanOrEqual(cpuUsage.usage, 0)
        XCTAssertLessThanOrEqual(cpuUsage.usage, 100)
        XCTAssertFalse(cpuUsage.usageFormatted.isEmpty)
    }
    
    func testClearCache() {
        // Given & When & Then
        // This test verifies that clearCache doesn't crash
        developmentTools.clearCache()
    }
    
    func testReset() {
        // Given
        XCTAssertTrue(developmentTools.isInitialized)
        
        // When
        developmentTools.reset()
        
        // Then
        XCTAssertFalse(developmentTools.isInitialized)
    }
    
    // MARK: - Storage Tests
    
    func testSaveAndLoadData() throws {
        // Given
        let testData = "Test data"
        let key = "test_key"
        
        // When
        try developmentTools.storageTools.save(testData, forKey: key)
        let loadedData: String = try developmentTools.storageTools.load(forKey: key)
        
        // Then
        XCTAssertEqual(loadedData, testData)
    }
    
    func testSaveAndLoadSecureData() throws {
        // Given
        let testData = "Secure test data"
        let key = "secure_test_key"
        
        // When
        try developmentTools.storageTools.saveSecure(testData, forKey: key)
        let loadedData: String = try developmentTools.storageTools.loadSecure(forKey: key)
        
        // Then
        XCTAssertEqual(loadedData, testData)
    }
    
    func testDeleteData() throws {
        // Given
        let testData = "Test data to delete"
        let key = "delete_test_key"
        try developmentTools.storageTools.save(testData, forKey: key)
        
        // When
        try developmentTools.storageTools.delete(forKey: key)
        
        // Then
        do {
            let _: String = try developmentTools.storageTools.load(forKey: key)
            XCTFail("Data should be deleted")
        } catch {
            // Expected error
        }
    }
    
    // MARK: - Utility Tests
    
    func testEmailValidation() {
        // Given & When & Then
        XCTAssertTrue("test@example.com".isValidEmail)
        XCTAssertTrue("user.name@domain.co.uk".isValidEmail)
        XCTAssertFalse("invalid-email".isValidEmail)
        XCTAssertFalse("test@".isValidEmail)
        XCTAssertFalse("@example.com".isValidEmail)
    }
    
    func testPhoneNumberValidation() {
        // Given & When & Then
        XCTAssertTrue("+1234567890".isValidPhoneNumber)
        XCTAssertTrue("123-456-7890".isValidPhoneNumber)
        XCTAssertFalse("123".isValidPhoneNumber)
        XCTAssertFalse("abc-def-ghij".isValidPhoneNumber)
    }
    
    func testDateFormatting() {
        // Given
        let date = Date()
        
        // When
        let formattedDate = date.formattedString(format: "yyyy-MM-dd")
        
        // Then
        XCTAssertFalse(formattedDate.isEmpty)
        XCTAssertEqual(formattedDate.count, 10) // yyyy-MM-dd format
    }
    
    func testTimeAgo() {
        // Given
        let pastDate = Date().addingTimeInterval(-3600) // 1 hour ago
        
        // When
        let timeAgo = pastDate.timeAgoString
        
        // Then
        XCTAssertFalse(timeAgo.isEmpty)
        XCTAssertTrue(timeAgo.contains("hour") || timeAgo.contains("minute"))
    }
    
    func testColorCreation() {
        // Given & When & Then
        let color = UIColor(hex: "#FF0000")
        XCTAssertNotNil(color)
        
        let invalidColor = UIColor(hex: "invalid")
        XCTAssertNotNil(invalidColor) // Should return default color
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceMeasurement() {
        // Given
        let performanceLogger = developmentTools.performanceTools
        
        // When & Then
        measure {
            performanceLogger.startMeasurement(name: "test_operation")
            // Simulate some work
            Thread.sleep(forTimeInterval: 0.1)
            performanceLogger.stopMeasurement(name: "test_operation")
        }
    }
    
    func testMeasureOperation() throws {
        // Given
        let performanceLogger = developmentTools.performanceTools
        
        // When & Then
        let result = try performanceLogger.measureOperation(name: "test_operation") {
            // Simulate some work
            Thread.sleep(forTimeInterval: 0.1)
            return "test result"
        }
        
        XCTAssertEqual(result, "test result")
    }
    
    // MARK: - Error Tests
    
    func testNetworkNotConfiguredError() async {
        // Given
        let networkClient = NetworkClient.shared
        
        // When & Then
        do {
            let endpoint = APIEndpoint(path: "/test", method: .get, parameters: nil)
            let _: String = try await networkClient.request(endpoint)
            XCTFail("Expected error for unconfigured network client")
        } catch {
            // Expected error
            XCTAssertTrue(error.localizedDescription.contains("not configured"))
        }
    }
    
    // MARK: - iOS Development Tools Tests
    
    func testiOSDevelopmentToolsVersion() {
        // Given & When & Then
        XCTAssertEqual(iOSDevelopmentTools.version, "1.0.0")
    }
    
    func testiOSDevelopmentToolsInitialization() {
        // Given & When & Then
        // This test verifies that initialization doesn't crash
        iOSDevelopmentTools.initialize()
    }
    
    func testiOSDevelopmentToolsConfiguration() {
        // Given & When & Then
        // This test verifies that configuration doesn't crash
        iOSDevelopmentTools.configure(
            networkBaseURL: "https://api.example.com",
            analyticsEnabled: true,
            loggingEnabled: true
        )
    }
    
    // MARK: - Supporting Types Tests
    
    func testSystemInfoInitialization() {
        // Given
        let deviceName = "Test Device"
        let systemVersion = "15.0"
        let modelName = "iPhone"
        let appVersion = "1.0.0"
        let buildNumber = "1"
        
        // When
        let systemInfo = SystemInfo(
            deviceName: deviceName,
            systemVersion: systemVersion,
            modelName: modelName,
            appVersion: appVersion,
            buildNumber: buildNumber
        )
        
        // Then
        XCTAssertEqual(systemInfo.deviceName, deviceName)
        XCTAssertEqual(systemInfo.systemVersion, systemVersion)
        XCTAssertEqual(systemInfo.modelName, modelName)
        XCTAssertEqual(systemInfo.appVersion, appVersion)
        XCTAssertEqual(systemInfo.buildNumber, buildNumber)
    }
    
    func testMemoryUsageInitialization() {
        // Given
        let usedMemory: Double = 512.0
        let totalMemory: Double = 4096.0
        
        // When
        let memoryUsage = MemoryUsage(usedMemory: usedMemory, totalMemory: totalMemory)
        
        // Then
        XCTAssertEqual(memoryUsage.usedMemory, usedMemory)
        XCTAssertEqual(memoryUsage.totalMemory, totalMemory)
        XCTAssertEqual(memoryUsage.usedMemoryFormatted, "512.0 MB")
        XCTAssertEqual(memoryUsage.totalMemoryFormatted, "4096.0 MB")
    }
    
    func testCPUUsageInitialization() {
        // Given
        let usage: Double = 25.5
        
        // When
        let cpuUsage = CPUUsage(usage: usage)
        
        // Then
        XCTAssertEqual(cpuUsage.usage, usage)
        XCTAssertEqual(cpuUsage.usageFormatted, "25.5%")
    }
    
    func testDevelopmentToolsErrorDescriptions() {
        // Given & When & Then
        let notInitializedError = DevelopmentToolsError.notInitialized
        XCTAssertNotNil(notInitializedError.errorDescription)
        XCTAssertTrue(notInitializedError.errorDescription!.contains("not initialized"))
        
        let networkError = DevelopmentToolsError.networkError(NSError(domain: "test", code: 0))
        XCTAssertNotNil(networkError.errorDescription)
        XCTAssertTrue(networkError.errorDescription!.contains("Network error"))
        
        let storageError = DevelopmentToolsError.storageError(NSError(domain: "test", code: 0))
        XCTAssertNotNil(storageError.errorDescription)
        XCTAssertTrue(storageError.errorDescription!.contains("Storage error"))
        
        let analyticsError = DevelopmentToolsError.analyticsError(NSError(domain: "test", code: 0))
        XCTAssertNotNil(analyticsError.errorDescription)
        XCTAssertTrue(analyticsError.errorDescription!.contains("Analytics error"))
        
        let loggingError = DevelopmentToolsError.loggingError(NSError(domain: "test", code: 0))
        XCTAssertNotNil(loggingError.errorDescription)
        XCTAssertTrue(loggingError.errorDescription!.contains("Logging error"))
        
        let configurationError = DevelopmentToolsError.configurationError("test reason")
        XCTAssertNotNil(configurationError.errorDescription)
        XCTAssertTrue(configurationError.errorDescription!.contains("test reason"))
    }
}

// MARK: - Test Models

struct TestModel: Codable, Equatable {
    let id: String
    let name: String
    let value: Int
    
    init(id: String, name: String, value: Int) {
        self.id = id
        self.name = name
        self.value = value
    }
} 