import Foundation
import Alamofire
import Combine

// MARK: - Network Client Protocol
public protocol NetworkClientProtocol {
    func request<T: Codable>(_ endpoint: APIEndpoint) async throws -> T
    func upload<T: Codable>(_ endpoint: APIEndpoint, data: Data) async throws -> T
    func download(_ endpoint: APIEndpoint) async throws -> Data
}

// MARK: - Network Client Implementation
public class NetworkClient: NetworkClientProtocol {
    private let session: Session
    private let baseURL: String
    private let timeoutInterval: TimeInterval
    
    public init(
        baseURL: String,
        timeoutInterval: TimeInterval = 30,
        configuration: URLSessionConfiguration = .default
    ) {
        self.baseURL = baseURL
        self.timeoutInterval = timeoutInterval
        
        configuration.timeoutIntervalForRequest = timeoutInterval
        configuration.timeoutIntervalForResource = timeoutInterval * 2
        
        self.session = Session(configuration: configuration)
    }
    
    // MARK: - Request Methods
    public func request<T: Codable>(_ endpoint: APIEndpoint) async throws -> T {
        let url = try buildURL(for: endpoint)
        let headers = buildHeaders(for: endpoint)
        
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                url,
                method: endpoint.method,
                parameters: endpoint.parameters,
                encoding: endpoint.encoding,
                headers: headers
            )
            .validate()
            .responseDecodable(of: T.self) { response in
                switch response.result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: NetworkError.requestFailed(error))
                }
            }
        }
    }
    
    public func upload<T: Codable>(_ endpoint: APIEndpoint, data: Data) async throws -> T {
        let url = try buildURL(for: endpoint)
        let headers = buildHeaders(for: endpoint)
        
        return try await withCheckedThrowingContinuation { continuation in
            session.upload(
                multipartFormData: { multipartFormData in
                    multipartFormData.append(data, withName: "file", fileName: "file.jpg", mimeType: "image/jpeg")
                },
                to: url,
                headers: headers
            )
            .validate()
            .responseDecodable(of: T.self) { response in
                switch response.result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: NetworkError.requestFailed(error))
                }
            }
        }
    }
    
    public func download(_ endpoint: APIEndpoint) async throws -> Data {
        let url = try buildURL(for: endpoint)
        let headers = buildHeaders(for: endpoint)
        
        return try await withCheckedThrowingContinuation { continuation in
            session.download(
                url,
                method: endpoint.method,
                parameters: endpoint.parameters,
                encoding: endpoint.encoding,
                headers: headers
            )
            .validate()
            .responseData { response in
                switch response.result {
                case .success(let data):
                    continuation.resume(returning: data)
                case .failure(let error):
                    continuation.resume(throwing: NetworkError.requestFailed(error))
                }
            }
        }
    }
    
    // MARK: - Private Methods
    private func buildURL(for endpoint: APIEndpoint) throws -> URL {
        let fullURL = baseURL + endpoint.path
        
        guard let url = URL(string: fullURL) else {
            throw NetworkError.invalidURL(fullURL)
        }
        
        return url
    }
    
    private func buildHeaders(for endpoint: APIEndpoint) -> HTTPHeaders {
        var headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
        
        // Add custom headers
        endpoint.headers.forEach { key, value in
            headers[key] = value
        }
        
        return headers
    }
}

// MARK: - API Endpoint
public struct APIEndpoint {
    public let path: String
    public let method: HTTPMethod
    public let parameters: [String: Any]?
    public let encoding: ParameterEncoding
    public let headers: [String: String]
    
    public init(
        path: String,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil,
        encoding: ParameterEncoding = URLEncoding.default,
        headers: [String: String] = [:]
    ) {
        self.path = path
        self.method = method
        self.parameters = parameters
        self.encoding = encoding
        self.headers = headers
    }
}

// MARK: - Network Error
public enum NetworkError: LocalizedError {
    case invalidURL(String)
    case requestFailed(Error)
    case noData
    case decodingFailed(Error)
    case serverError(Int)
    case unauthorized
    case forbidden
    case notFound
    case timeout
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        case .noData:
            return "No data received"
        case .decodingFailed(let error):
            return "Decoding failed: \(error.localizedDescription)"
        case .serverError(let code):
            return "Server error: \(code)"
        case .unauthorized:
            return "Unauthorized access"
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .timeout:
            return "Request timeout"
        }
    }
}

// MARK: - Network Monitor
public class NetworkMonitor: ObservableObject {
    @Published public var isConnected = false
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    public init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
} 