// MARK: - Service Template
// Use this template for creating new Services in your project

import Foundation

// MARK: - Protocol
protocol __NAME__ServiceProtocol: Sendable {
    func fetch() async throws -> __TYPE__
    func create(_ item: __TYPE__) async throws -> __TYPE__
    func update(_ item: __TYPE__) async throws -> __TYPE__
    func delete(id: String) async throws
}

// MARK: - Service Implementation
final class __NAME__Service: __NAME__ServiceProtocol, @unchecked Sendable {
    // MARK: - Properties
    private let networkClient: NetworkClientProtocol
    private let cache: CacheProtocol
    private let baseURL: URL
    
    // MARK: - Initialization
    init(
        networkClient: NetworkClientProtocol = NetworkClient.shared,
        cache: CacheProtocol = Cache.shared,
        baseURL: URL = URL(string: "https://api.example.com")!
    ) {
        self.networkClient = networkClient
        self.cache = cache
        self.baseURL = baseURL
    }
    
    // MARK: - Fetch
    func fetch() async throws -> __TYPE__ {
        let endpoint = baseURL.appendingPathComponent("__ENDPOINT__")
        
        // Check cache first
        if let cached: __TYPE__ = try? cache.get(for: endpoint.absoluteString) {
            return cached
        }
        
        let response: __TYPE__ = try await networkClient.get(endpoint)
        try? cache.set(response, for: endpoint.absoluteString)
        return response
    }
    
    // MARK: - Create
    func create(_ item: __TYPE__) async throws -> __TYPE__ {
        let endpoint = baseURL.appendingPathComponent("__ENDPOINT__")
        return try await networkClient.post(endpoint, body: item)
    }
    
    // MARK: - Update
    func update(_ item: __TYPE__) async throws -> __TYPE__ {
        let endpoint = baseURL.appendingPathComponent("__ENDPOINT__/\(item.id)")
        return try await networkClient.put(endpoint, body: item)
    }
    
    // MARK: - Delete
    func delete(id: String) async throws {
        let endpoint = baseURL.appendingPathComponent("__ENDPOINT__/\(id)")
        try await networkClient.delete(endpoint)
        cache.remove(for: endpoint.absoluteString)
    }
}

// MARK: - Error Handling
enum __NAME__ServiceError: LocalizedError {
    case notFound
    case unauthorized
    case serverError(Int)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "The requested resource was not found."
        case .unauthorized:
            return "You are not authorized to perform this action."
        case .serverError(let code):
            return "Server error occurred (code: \(code))."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
