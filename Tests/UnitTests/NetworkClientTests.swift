//
//  NetworkClientTests.swift
//  iOSDevelopmentToolsTests
//
//  Created by Muhittin Camdali on 2024-01-15.
//  Copyright © 2024 Muhittin Camdali. All rights reserved.
//

import XCTest
@testable import iOSDevelopmentTools

final class NetworkClientTests: XCTestCase {
    
    var networkClient: NetworkClient!
    var mockLogger: MockLogger!
    var mockPerformanceMonitor: MockPerformanceMonitor!
    
    override func setUp() {
        super.setUp()
        mockLogger = MockLogger()
        mockPerformanceMonitor = MockPerformanceMonitor()
        
        let configuration = NetworkConfiguration(
            baseURL: "https://api.example.com",
            timeout: 30,
            retryCount: 3
        )
        
        networkClient = NetworkClient(
            configuration: configuration,
            logger: mockLogger,
            performanceMonitor: mockPerformanceMonitor
        )
    }
    
    override func tearDown() {
        networkClient = nil
        mockLogger = nil
        mockPerformanceMonitor = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    func testNetworkClientInitialization() {
        XCTAssertNotNil(networkClient)
        XCTAssertNotNil(mockLogger)
        XCTAssertNotNil(mockPerformanceMonitor)
    }
    
    func testNetworkConfiguration() {
        let config = NetworkConfiguration(
            baseURL: "https://test.com",
            timeout: 60,
            retryCount: 5,
            headers: ["Authorization": "Bearer token"]
        )
        
        XCTAssertEqual(config.baseURL, "https://test.com")
        XCTAssertEqual(config.timeout, 60)
        XCTAssertEqual(config.retryCount, 5)
        XCTAssertEqual(config.headers["Authorization"], "Bearer token")
    }
    
    // MARK: - API Request Tests
    func testAPIRequestCreation() {
        let request = APIRequest(
            url: "/users",
            method: .GET,
            headers: ["Content-Type": "application/json"],
            queryParameters: ["page": "1", "limit": "10"]
        )
        
        XCTAssertEqual(request.url, "/users")
        XCTAssertEqual(request.method, .GET)
        XCTAssertEqual(request.headers["Content-Type"], "application/json")
        XCTAssertEqual(request.queryParameters["page"], "1")
        XCTAssertEqual(request.queryParameters["limit"], "10")
    }
    
    func testAPIRequestCacheKey() {
        let request = APIRequest(
            url: "/users",
            method: .GET,
            queryParameters: ["page": "1"]
        )
        
        let cacheKey = request.cacheKey
        XCTAssertTrue(cacheKey.contains("GET"))
        XCTAssertTrue(cacheKey.contains("/users"))
        XCTAssertTrue(cacheKey.contains("page"))
    }
    
    // MARK: - HTTP Method Tests
    func testHTTPMethods() {
        XCTAssertEqual(HTTPMethod.GET.rawValue, "GET")
        XCTAssertEqual(HTTPMethod.POST.rawValue, "POST")
        XCTAssertEqual(HTTPMethod.PUT.rawValue, "PUT")
        XCTAssertEqual(HTTPMethod.DELETE.rawValue, "DELETE")
        XCTAssertEqual(HTTPMethod.PATCH.rawValue, "PATCH")
    }
    
    func testHTTPMethodAllCases() {
        let allMethods = HTTPMethod.allCases
        XCTAssertTrue(allMethods.contains(.GET))
        XCTAssertTrue(allMethods.contains(.POST))
        XCTAssertTrue(allMethods.contains(.PUT))
        XCTAssertTrue(allMethods.contains(.DELETE))
        XCTAssertTrue(allMethods.contains(.PATCH))
    }
    
    // MARK: - Network Error Tests
    func testNetworkErrorDescriptions() {
        let invalidURLError = NetworkError.invalidURL
        XCTAssertEqual(invalidURLError.errorDescription, "Invalid URL provided")
        
        let noConnectionError = NetworkError.noInternetConnection
        XCTAssertEqual(noConnectionError.errorDescription, "No internet connection available")
        
        let timeoutError = NetworkError.timeout
        XCTAssertEqual(timeoutError.errorDescription, "Request timed out")
    }
    
    func testNetworkErrorFailureReasons() {
        let invalidURLError = NetworkError.invalidURL
        XCTAssertEqual(invalidURLError.failureReason, "The provided URL is malformed or invalid")
        
        let noConnectionError = NetworkError.noInternetConnection
        XCTAssertEqual(noConnectionError.failureReason, "Device is not connected to the internet")
        
        let timeoutError = NetworkError.timeout
        XCTAssertEqual(timeoutError.failureReason, "Request exceeded the maximum allowed time")
    }
    
    func testNetworkErrorRecoverySuggestions() {
        let invalidURLError = NetworkError.invalidURL
        XCTAssertEqual(invalidURLError.recoverySuggestion, "Please check the URL format and try again")
        
        let noConnectionError = NetworkError.noInternetConnection
        XCTAssertEqual(noConnectionError.recoverySuggestion, "Please check your internet connection and try again")
        
        let timeoutError = NetworkError.timeout
        XCTAssertEqual(timeoutError.recoverySuggestion, "Please try again later or check your connection")
    }
    
    // MARK: - Performance Tests
    func testPerformanceForMultipleRequests() {
        measure {
            // This would test multiple concurrent requests
            // Implementation depends on actual network client
        }
    }
    
    func testPerformanceForLargeDataEncoding() {
        let largeDictionary = (0..<1000).reduce(into: [String: Any]()) { result, index in
            result["key\(index)"] = "value\(index)"
        }
        
        measure {
            _ = try? networkClient.encodeBody(largeDictionary)
        }
    }
}

// MARK: - Mock Classes
class MockLogger: Logger {
    var loggedMessages: [String] = []
    var loggedLevels: [LogLevel] = []
    
    override func log(_ level: LogLevel, _ message: String, context: [String: Any]?) {
        loggedMessages.append(message)
        loggedLevels.append(level)
    }
}

class MockPerformanceMonitor: PerformanceMonitor {
    var timers: [String: Date] = [:]
    var durations: [String: TimeInterval] = [:]
    
    override func startTimer(_ name: String) {
        timers[name] = Date()
    }
    
    override func endTimer(_ name: String) {
        if let startTime = timers[name] {
            durations[name] = Date().timeIntervalSince(startTime)
            timers.removeValue(forKey: name)
        }
    }
    
    override func getTimerDuration(_ name: String) -> TimeInterval {
        return durations[name] ?? 0
    }
} 