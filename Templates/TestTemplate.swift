// MARK: - Test Template
// Use this template for creating new unit tests

import XCTest
@testable import __MODULE__

final class __NAME__Tests: XCTestCase {
    // MARK: - Properties
    private var sut: __NAME__!
    private var mockDependency: Mock__DEPENDENCY__!
    
    // MARK: - Setup & Teardown
    override func setUp() {
        super.setUp()
        mockDependency = Mock__DEPENDENCY__()
        sut = __NAME__(dependency: mockDependency)
    }
    
    override func tearDown() {
        sut = nil
        mockDependency = nil
        super.tearDown()
    }
    
    // MARK: - Test Cases
    
    // MARK: Initialization Tests
    func test_init_setsDefaultValues() {
        // Given
        let expectedValue = "__EXPECTED__"
        
        // When
        let result = sut.someProperty
        
        // Then
        XCTAssertEqual(result, expectedValue)
    }
    
    // MARK: Success Cases
    func test_fetch_whenSuccessful_returnsData() async throws {
        // Given
        let expectedData = __TYPE__.mock
        mockDependency.fetchResult = .success(expectedData)
        
        // When
        let result = try await sut.fetch()
        
        // Then
        XCTAssertEqual(result, expectedData)
        XCTAssertTrue(mockDependency.fetchCalled)
    }
    
    // MARK: Failure Cases
    func test_fetch_whenFails_throwsError() async {
        // Given
        let expectedError = NSError(domain: "test", code: 1)
        mockDependency.fetchResult = .failure(expectedError)
        
        // When/Then
        do {
            _ = try await sut.fetch()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual((error as NSError).code, expectedError.code)
        }
    }
    
    // MARK: Edge Cases
    func test_fetch_whenEmpty_returnsEmptyArray() async throws {
        // Given
        mockDependency.fetchResult = .success([])
        
        // When
        let result = try await sut.fetchAll()
        
        // Then
        XCTAssertTrue(result.isEmpty)
    }
    
    // MARK: Performance Tests
    func test_fetch_performance() {
        measure {
            // Code to measure
            _ = sut.syncOperation()
        }
    }
}

// MARK: - Mock Objects
final class Mock__DEPENDENCY__: __DEPENDENCY__Protocol {
    var fetchCalled = false
    var fetchResult: Result<__TYPE__, Error> = .success(__TYPE__.mock)
    
    func fetch() async throws -> __TYPE__ {
        fetchCalled = true
        return try fetchResult.get()
    }
}

// MARK: - Test Helpers
extension __TYPE__ {
    static var mock: __TYPE__ {
        __TYPE__(
            id: "test-id",
            name: "Test Name",
            createdAt: Date()
        )
    }
}
