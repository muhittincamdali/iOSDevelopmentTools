import XCTest
@testable import iOSDevelopmentTools

final class iOSDevelopmentToolsTests: XCTestCase {
    
    var developmentTools: DevelopmentToolsManager!
    
    override func setUp() {
        super.setUp()
        developmentTools = DevelopmentToolsManager(networkBaseURL: "https://api.example.com")
    }
    
    override func tearDown() {
        developmentTools = nil
        super.tearDown()
    }
    
    // MARK: - Storage Tests
    func testSaveAndLoadData() throws {
        let testData = TestModel(name: "Test", value: 42)
        
        // Save data
        try developmentTools.saveData(testData, forKey: "test_key")
        
        // Load data
        let loadedData = try developmentTools.loadData(TestModel.self, forKey: "test_key")
        
        XCTAssertEqual(loadedData.name, testData.name)
        XCTAssertEqual(loadedData.value, testData.value)
    }
    
    func testSaveAndLoadSecureData() throws {
        let testData = TestModel(name: "Secure Test", value: 100)
        
        // Save secure data
        try developmentTools.saveDataSecurely(testData, forKey: "secure_test_key")
        
        // Load secure data
        let loadedData = try developmentTools.loadDataSecurely(TestModel.self, forKey: "secure_test_key")
        
        XCTAssertEqual(loadedData.name, testData.name)
        XCTAssertEqual(loadedData.value, testData.value)
    }
    
    // MARK: - Validation Tests
    func testEmailValidation() {
        let validEmails = [
            "test@example.com",
            "user.name@domain.co.uk",
            "user+tag@example.org"
        ]
        
        let invalidEmails = [
            "invalid-email",
            "@example.com",
            "test@",
            "test@.com"
        ]
        
        for email in validEmails {
            XCTAssertTrue(developmentTools.validateEmail(email), "Email should be valid: \(email)")
        }
        
        for email in invalidEmails {
            XCTAssertFalse(developmentTools.validateEmail(email), "Email should be invalid: \(email)")
        }
    }
    
    func testPhoneNumberValidation() {
        let validPhoneNumbers = [
            "1234567890",
            "12345678901",
            "123456789012"
        ]
        
        let invalidPhoneNumbers = [
            "123",
            "123456789012345",
            "abc1234567",
            "123-456-7890"
        ]
        
        for phoneNumber in validPhoneNumbers {
            XCTAssertTrue(developmentTools.validatePhoneNumber(phoneNumber), "Phone number should be valid: \(phoneNumber)")
        }
        
        for phoneNumber in invalidPhoneNumbers {
            XCTAssertFalse(developmentTools.validatePhoneNumber(phoneNumber), "Phone number should be invalid: \(phoneNumber)")
        }
    }
    
    // MARK: - Date Formatting Tests
    func testDateFormatting() {
        let date = Date()
        let formatted = developmentTools.formatDate(date, format: "yyyy-MM-dd")
        
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertEqual(formatted.count, 10) // yyyy-MM-dd format
    }
    
    func testTimeAgo() {
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        
        let timeAgo = developmentTools.timeAgo(oneHourAgo)
        
        XCTAssertFalse(timeAgo.isEmpty)
        XCTAssertTrue(timeAgo.contains("hour") || timeAgo.contains("minute"))
    }
    
    // MARK: - Color Tests
    func testColorCreation() {
        let color = developmentTools.createColor(hex: "#FF0000")
        
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        XCTAssertEqual(red, 1.0, accuracy: 0.01)
        XCTAssertEqual(green, 0.0, accuracy: 0.01)
        XCTAssertEqual(blue, 0.0, accuracy: 0.01)
        XCTAssertEqual(alpha, 1.0, accuracy: 0.01)
    }
    
    // MARK: - Performance Tests
    func testPerformanceMeasurement() {
        let expectation = XCTestExpectation(description: "Performance measurement")
        
        developmentTools.startPerformanceMeasurement("test_operation")
        
        // Simulate some work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.developmentTools.endPerformanceMeasurement("test_operation")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testMeasureOperation() throws {
        let result = try developmentTools.measure("test_measure") {
            // Simulate some work
            Thread.sleep(forTimeInterval: 0.01)
            return "test_result"
        }
        
        XCTAssertEqual(result, "test_result")
    }
    
    // MARK: - Error Handling Tests
    func testNetworkNotConfiguredError() async {
        let toolsWithoutNetwork = DevelopmentToolsManager()
        
        do {
            let endpoint = APIEndpoint(path: "/test")
            _ = try await toolsWithoutNetwork.makeRequest(endpoint)
            XCTFail("Should throw networkNotConfigured error")
        } catch DevelopmentToolsError.networkNotConfigured {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - Test Model
struct TestModel: Codable, Equatable {
    let name: String
    let value: Int
} 