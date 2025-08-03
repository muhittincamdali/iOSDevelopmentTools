//
//  NetworkClient.swift
//  iOSDevelopmentTools
//
//  Created by Muhittin Camdali on 2024-01-15.
//  Copyright © 2024 Muhittin Camdali. All rights reserved.
//

import Foundation
import Combine
import Network

// MARK: - Network Client Protocol
public protocol NetworkClientProtocol {
    func perform<T: Codable>(_ request: APIRequest) async throws -> APIResponse<T>
    func get<T: Codable>(_ url: String) async throws -> T
    func post<T: Codable>(_ url: String, body: Any) async throws -> T
    func put<T: Codable>(_ url: String, body: Any) async throws -> T
    func delete<T: Codable>(_ url: String) async throws -> T
    func upload<T: Codable>(_ url: String, data: Data, mimeType: String) async throws -> T
    func download(_ url: String) async throws -> Data
}

// MARK: - Network Configuration
public struct NetworkConfiguration {
    public let baseURL: String
    public let timeout: TimeInterval
    public let retryCount: Int
    public let headers: [String: String]
    public let cachePolicy: URLRequest.CachePolicy
    public let allowsCellularAccess: Bool
    public let allowsExpensiveNetworkAccess: Bool
    public let allowsConstrainedNetworkAccess: Bool
    public let networkServiceType: URLRequest.NetworkServiceType
    public let httpShouldUsePipelining: Bool
    public let httpShouldSetCookies: Bool
    public let httpCookieAcceptPolicy: HTTPCookie.AcceptPolicy
    public let httpCookieStorage: HTTPCookieStorage?
    public let httpMaximumConnectionsPerHost: Int
    public let httpShouldUsePipelining: Bool
    public let httpShouldSetCookies: Bool
    public let httpCookieAcceptPolicy: HTTPCookie.AcceptPolicy
    public let httpCookieStorage: HTTPCookieStorage?
    public let httpMaximumConnectionsPerHost: Int
    
    public init(
        baseURL: String,
        timeout: TimeInterval = 30,
        retryCount: Int = 3,
        headers: [String: String] = [:],
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        allowsCellularAccess: Bool = true,
        allowsExpensiveNetworkAccess: Bool = true,
        allowsConstrainedNetworkAccess: Bool = true,
        networkServiceType: URLRequest.NetworkServiceType = .default,
        httpShouldUsePipelining: Bool = false,
        httpShouldSetCookies: Bool = true,
        httpCookieAcceptPolicy: HTTPCookie.AcceptPolicy = .onlyLoadMainDocumentDomain,
        httpCookieStorage: HTTPCookieStorage? = nil,
        httpMaximumConnectionsPerHost: Int = 6
    ) {
        self.baseURL = baseURL
        self.timeout = timeout
        self.retryCount = retryCount
        self.headers = headers
        self.cachePolicy = cachePolicy
        self.allowsCellularAccess = allowsCellularAccess
        self.allowsExpensiveNetworkAccess = allowsExpensiveNetworkAccess
        self.allowsConstrainedNetworkAccess = allowsConstrainedNetworkAccess
        self.networkServiceType = networkServiceType
        self.httpShouldUsePipelining = httpShouldUsePipelining
        self.httpShouldSetCookies = httpShouldSetCookies
        self.httpCookieAcceptPolicy = httpCookieAcceptPolicy
        self.httpCookieStorage = httpCookieStorage
        self.httpMaximumConnectionsPerHost = httpMaximumConnectionsPerHost
    }
}

// MARK: - API Request
public struct APIRequest {
    public let url: String
    public let method: HTTPMethod
    public let headers: [String: String]
    public let body: Data?
    public let queryParameters: [String: String]
    public let cachePolicy: URLRequest.CachePolicy
    public let timeout: TimeInterval
    
    public init(
        url: String,
        method: HTTPMethod = .GET,
        headers: [String: String] = [:],
        body: Data? = nil,
        queryParameters: [String: String] = [:],
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        timeout: TimeInterval = 30
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.queryParameters = queryParameters
        self.cachePolicy = cachePolicy
        self.timeout = timeout
    }
    
    public var cacheKey: String {
        return "\(method.rawValue)_\(url)_\(queryParameters.description)"
    }
}

// MARK: - API Response
public struct APIResponse<T: Codable> {
    public let data: T
    public let statusCode: Int
    public let headers: [String: String]
    public let originalData: Data
    public let request: APIRequest
    public let responseTime: TimeInterval
    
    public init(
        data: T,
        statusCode: Int,
        headers: [String: String],
        originalData: Data,
        request: APIRequest,
        responseTime: TimeInterval
    ) {
        self.data = data
        self.statusCode = statusCode
        self.headers = headers
        self.originalData = originalData
        self.request = request
        self.responseTime = responseTime
    }
}

// MARK: - HTTP Method
public enum HTTPMethod: String, CaseIterable {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
    case HEAD = "HEAD"
    case OPTIONS = "OPTIONS"
    case TRACE = "TRACE"
    case CONNECT = "CONNECT"
}

// MARK: - Network Error
public enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noInternetConnection
    case timeout
    case invalidResponse(Int)
    case decodingError
    case invalidData
    case unauthorized
    case forbidden
    case notFound
    case serverError
    case clientError(Int)
    case redirection(Int)
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL provided"
        case .noInternetConnection:
            return "No internet connection available"
        case .timeout:
            return "Request timed out"
        case .invalidResponse(let code):
            return "Invalid response with status code: \(code)"
        case .decodingError:
            return "Failed to decode response data"
        case .invalidData:
            return "Invalid data received"
        case .unauthorized:
            return "Unauthorized access"
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .serverError:
            return "Server error occurred"
        case .clientError(let code):
            return "Client error with status code: \(code)"
        case .redirection(let code):
            return "Redirection with status code: \(code)"
        case .unknown:
            return "Unknown network error"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .invalidURL:
            return "The provided URL is malformed or invalid"
        case .noInternetConnection:
            return "Device is not connected to the internet"
        case .timeout:
            return "Request exceeded the maximum allowed time"
        case .invalidResponse(let code):
            return "Server returned an invalid response with status code \(code)"
        case .decodingError:
            return "Response data could not be decoded to the expected format"
        case .invalidData:
            return "Received data is not in the expected format"
        case .unauthorized:
            return "Authentication is required to access this resource"
        case .forbidden:
            return "Access to this resource is not allowed"
        case .notFound:
            return "The requested resource does not exist"
        case .serverError:
            return "An error occurred on the server"
        case .clientError(let code):
            return "Client made an invalid request (status code: \(code))"
        case .redirection(let code):
            return "Request was redirected (status code: \(code))"
        case .unknown:
            return "An unexpected error occurred"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .invalidURL:
            return "Please check the URL format and try again"
        case .noInternetConnection:
            return "Please check your internet connection and try again"
        case .timeout:
            return "Please try again later or check your connection"
        case .invalidResponse, .decodingError, .invalidData:
            return "Please try again or contact support if the problem persists"
        case .unauthorized:
            return "Please log in again or check your credentials"
        case .forbidden:
            return "Please contact support if you believe this is an error"
        case .notFound:
            return "Please check the URL or contact support"
        case .serverError:
            return "Please try again later or contact support"
        case .clientError:
            return "Please check your request and try again"
        case .redirection:
            return "The request is being processed"
        case .unknown:
            return "Please try again or contact support"
        }
    }
}

// MARK: - Network Client
public class NetworkClient: NetworkClientProtocol {
    
    // MARK: - Properties
    private let configuration: NetworkConfiguration
    private let session: URLSession
    private let monitor: NWPathMonitor
    private let queue: DispatchQueue
    private let logger: Logger?
    private let performanceMonitor: PerformanceMonitor?
    private let cache: NSCache<NSString, CachedResponse>
    private let requestQueue: OperationQueue
    private let responseQueue: DispatchQueue
    private let retryQueue: DispatchQueue
    private let uploadQueue: DispatchQueue
    private let downloadQueue: DispatchQueue
    
    // MARK: - Initialization
    public init(configuration: NetworkConfiguration, logger: Logger? = nil, performanceMonitor: PerformanceMonitor? = nil) {
        self.configuration = configuration
        self.logger = logger
        self.performanceMonitor = performanceMonitor
        
        // Initialize URLSession with custom configuration
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        sessionConfig.timeoutIntervalForResource = configuration.timeout * 2
        sessionConfig.allowsCellularAccess = configuration.allowsCellularAccess
        sessionConfig.allowsExpensiveNetworkAccess = configuration.allowsExpensiveNetworkAccess
        sessionConfig.allowsConstrainedNetworkAccess = configuration.allowsConstrainedNetworkAccess
        sessionConfig.networkServiceType = configuration.networkServiceType
        sessionConfig.httpShouldUsePipelining = configuration.httpShouldUsePipelining
        sessionConfig.httpShouldSetCookies = configuration.httpShouldSetCookies
        sessionConfig.httpCookieAcceptPolicy = configuration.httpCookieAcceptPolicy
        sessionConfig.httpCookieStorage = configuration.httpCookieStorage
        sessionConfig.httpMaximumConnectionsPerHost = configuration.httpMaximumConnectionsPerHost
        
        self.session = URLSession(configuration: sessionConfig)
        
        // Initialize network monitoring
        self.monitor = NWPathMonitor()
        self.queue = DispatchQueue(label: "NetworkClient.monitor")
        
        // Initialize caches and queues
        self.cache = NSCache<NSString, CachedResponse>()
        self.cache.countLimit = 100
        self.cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
        self.requestQueue = OperationQueue()
        self.requestQueue.maxConcurrentOperationCount = 4
        self.requestQueue.qualityOfService = .userInitiated
        
        self.responseQueue = DispatchQueue(label: "NetworkClient.response", qos: .userInitiated)
        self.retryQueue = DispatchQueue(label: "NetworkClient.retry", qos: .utility)
        self.uploadQueue = DispatchQueue(label: "NetworkClient.upload", qos: .userInitiated)
        self.downloadQueue = DispatchQueue(label: "NetworkClient.download", qos: .userInitiated)
        
        // Start network monitoring
        startNetworkMonitoring()
        
        logger?.info("NetworkClient initialized", context: [
            "baseURL": configuration.baseURL,
            "timeout": configuration.timeout,
            "retryCount": configuration.retryCount
        ])
    }
    
    // MARK: - Network Monitoring
    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.handleNetworkPathUpdate(path)
        }
        monitor.start(queue: queue)
    }
    
    private func handleNetworkPathUpdate(_ path: NWPath) {
        let isConnected = path.status == .satisfied
        let connectionType = getConnectionType(path)
        
        logger?.info("Network status changed", context: [
            "isConnected": isConnected,
            "connectionType": connectionType,
            "isExpensive": path.isExpensive,
            "isConstrained": path.isConstrained
        ])
        
        if !isConnected {
            logger?.warning("No internet connection available")
        }
    }
    
    private func getConnectionType(_ path: NWPath) -> String {
        if path.usesInterfaceType(.wifi) {
            return "WiFi"
        } else if path.usesInterfaceType(.cellular) {
            return "Cellular"
        } else if path.usesInterfaceType(.wiredEthernet) {
            return "Ethernet"
        } else if path.usesInterfaceType(.loopback) {
            return "Loopback"
        } else {
            return "Unknown"
        }
    }
    
    // MARK: - Public Methods
    public func perform<T: Codable>(_ request: APIRequest) async throws -> APIResponse<T> {
        let startTime = Date()
        
        logger?.debug("Starting network request", context: [
            "url": request.url,
            "method": request.method.rawValue,
            "headers": request.headers
        ])
        
        performanceMonitor?.startTimer("network_request_\(request.url)")
        
        do {
            // Check network connectivity
            guard isNetworkAvailable() else {
                throw NetworkError.noInternetConnection
            }
            
            // Create URL request
            let urlRequest = try createURLRequest(from: request)
            
            // Perform request with retry logic
            let response = try await performRequestWithRetry(urlRequest, request: request)
            
            // Decode response
            let decodedData = try decodeResponse(response.data, to: T.self)
            
            let responseTime = Date().timeIntervalSince(startTime)
            
            let apiResponse = APIResponse(
                data: decodedData,
                statusCode: response.statusCode,
                headers: response.headers,
                originalData: response.data,
                request: request,
                responseTime: responseTime
            )
            
            logger?.info("Network request completed", context: [
                "url": request.url,
                "method": request.method.rawValue,
                "statusCode": response.statusCode,
                "responseTime": responseTime
            ])
            
            performanceMonitor?.endTimer("network_request_\(request.url)")
            
            return apiResponse
            
        } catch {
            logger?.error("Network request failed", context: [
                "url": request.url,
                "method": request.method.rawValue,
                "error": error.localizedDescription
            ])
            
            performanceMonitor?.endTimer("network_request_\(request.url)")
            
            throw error
        }
    }
    
    public func get<T: Codable>(_ url: String) async throws -> T {
        let request = APIRequest(url: url, method: .GET)
        let response: APIResponse<T> = try await perform(request)
        return response.data
    }
    
    public func post<T: Codable>(_ url: String, body: Any) async throws -> T {
        let bodyData = try encodeBody(body)
        let request = APIRequest(url: url, method: .POST, body: bodyData)
        let response: APIResponse<T> = try await perform(request)
        return response.data
    }
    
    public func put<T: Codable>(_ url: String, body: Any) async throws -> T {
        let bodyData = try encodeBody(body)
        let request = APIRequest(url: url, method: .PUT, body: bodyData)
        let response: APIResponse<T> = try await perform(request)
        return response.data
    }
    
    public func delete<T: Codable>(_ url: String) async throws -> T {
        let request = APIRequest(url: url, method: .DELETE)
        let response: APIResponse<T> = try await perform(request)
        return response.data
    }
    
    public func upload<T: Codable>(_ url: String, data: Data, mimeType: String) async throws -> T {
        let request = APIRequest(
            url: url,
            method: .POST,
            body: data,
            headers: ["Content-Type": mimeType]
        )
        let response: APIResponse<T> = try await perform(request)
        return response.data
    }
    
    public func download(_ url: String) async throws -> Data {
        let request = APIRequest(url: url, method: .GET)
        let response: APIResponse<Data> = try await perform(request)
        return response.originalData
    }
    
    // MARK: - Private Methods
    private func isNetworkAvailable() -> Bool {
        return monitor.currentPath.status == .satisfied
    }
    
    private func createURLRequest(from request: APIRequest) throws -> URLRequest {
        guard let url = buildURL(from: request) else {
            throw NetworkError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.timeoutInterval = request.timeout
        urlRequest.cachePolicy = request.cachePolicy
        
        // Set headers
        for (key, value) in configuration.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        // Set body
        if let body = request.body {
            urlRequest.httpBody = body
        }
        
        return urlRequest
    }
    
    private func buildURL(from request: APIRequest) -> URL? {
        var components = URLComponents(string: configuration.baseURL + request.url)
        
        if !request.queryParameters.isEmpty {
            components?.queryItems = request.queryParameters.map { key, value in
                URLQueryItem(name: key, value: value)
            }
        }
        
        return components?.url
    }
    
    private func performRequestWithRetry(_ urlRequest: URLRequest, request: APIRequest) async throws -> NetworkResponse {
        var lastError: Error?
        
        for attempt in 0...configuration.retryCount {
            do {
                return try await performSingleRequest(urlRequest)
            } catch {
                lastError = error
                
                if attempt < configuration.retryCount {
                    let delay = TimeInterval(attempt + 1) * 2.0
                    logger?.warning("Request failed, retrying", context: [
                        "attempt": attempt + 1,
                        "maxAttempts": configuration.retryCount,
                        "delay": delay,
                        "error": error.localizedDescription
                    ])
                    
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? NetworkError.unknown
    }
    
    private func performSingleRequest(_ urlRequest: URLRequest) async throws -> NetworkResponse {
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: urlRequest) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: self.mapError(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    continuation.resume(throwing: NetworkError.invalidResponse(0))
                    return
                }
                
                guard let data = data else {
                    continuation.resume(throwing: NetworkError.invalidData)
                    return
                }
                
                let networkResponse = NetworkResponse(
                    data: data,
                    statusCode: httpResponse.statusCode,
                    headers: httpResponse.allHeaderFields as? [String: String] ?? [:]
                )
                
                continuation.resume(returning: networkResponse)
            }
            
            task.resume()
        }
    }
    
    private func mapError(_ error: Error) -> NetworkError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .noInternetConnection
            case .timedOut:
                return .timeout
            case .cannotFindHost, .cannotConnectToHost:
                return .notFound
            case .badServerResponse:
                return .serverError
            default:
                return .unknown
            }
        }
        
        return .unknown
    }
    
    private func encodeBody(_ body: Any) throws -> Data {
        if let data = body as? Data {
            return data
        }
        
        if let string = body as? String {
            return string.data(using: .utf8) ?? Data()
        }
        
        if let dictionary = body as? [String: Any] {
            return try JSONSerialization.data(withJSONObject: dictionary)
        }
        
        if let encodable = body as? Encodable {
            return try JSONEncoder().encode(encodable)
        }
        
        throw NetworkError.invalidData
    }
    
    private func decodeResponse<T: Codable>(_ data: Data, to type: T.Type) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            logger?.error("Failed to decode response", context: [
                "error": error.localizedDescription,
                "dataSize": data.count
            ])
            throw NetworkError.decodingError
        }
    }
    
    // MARK: - Deinitialization
    deinit {
        monitor.cancel()
        session.invalidateAndCancel()
        cache.removeAllObjects()
    }
}

// MARK: - Network Response
private struct NetworkResponse {
    let data: Data
    let statusCode: Int
    let headers: [String: String]
}

// MARK: - Cached Response
private class CachedResponse {
    let data: Data
    let timestamp: Date
    let expirationInterval: TimeInterval
    
    init(data: Data, timestamp: Date, expirationInterval: TimeInterval = 300) {
        self.data = data
        self.timestamp = timestamp
        self.expirationInterval = expirationInterval
    }
    
    var isValid: Bool {
        return Date().timeIntervalSince(timestamp) < expirationInterval
    }
}

// MARK: - Extensions
extension NetworkClient {
    
    /// Enable debug mode for detailed logging
    public func enableDebugMode() {
        logger?.info("Debug mode enabled for NetworkClient")
    }
    
    /// Clear all cached responses
    public func clearCache() {
        cache.removeAllObjects()
        logger?.info("Network cache cleared")
    }
    
    /// Get cache statistics
    public func getCacheStats() -> [String: Any] {
        return [
            "totalCost": cache.totalCost,
            "count": cache.totalCostLimit,
            "objectCount": cache.countLimit
        ]
    }
} // Performance optimizations
