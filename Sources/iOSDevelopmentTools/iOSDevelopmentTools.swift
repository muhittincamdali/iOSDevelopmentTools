import Foundation

// MARK: - iOS Development Tools
public struct iOSDevelopmentTools {
    
    // MARK: - Version
    public static let version = "1.0.0"
    
    // MARK: - Initialize
    public static func initialize() {
        Logger.info("iOS Development Tools initialized - Version \(version)")
    }
    
    // MARK: - Configuration
    public static func configure(
        networkBaseURL: String,
        analyticsEnabled: Bool = true,
        loggingEnabled: Bool = true
    ) {
        // Configure network client
        let networkClient = NetworkClient(baseURL: networkBaseURL)
        
        // Configure analytics
        if analyticsEnabled {
            let analyticsManager = AnalyticsManager.shared
            analyticsManager.addProvider(FirebaseAnalyticsProvider())
            analyticsManager.addProvider(AmplitudeAnalyticsProvider())
            analyticsManager.addProvider(MixpanelAnalyticsProvider())
        }
        
        // Configure logging
        if loggingEnabled {
            Logger.info("Logging enabled")
        }
        
        Logger.info("iOS Development Tools configured successfully")
    }
}

// MARK: - Development Tools Manager
public class DevelopmentToolsManager {
    public static let shared = DevelopmentToolsManager()
    
    private let networkClient: NetworkClient?
    private let storageManager = StorageManager()
    private let analyticsManager = AnalyticsManager.shared
    private let logger = Logger.shared
    private let performanceLogger = PerformanceLogger()
    private let networkLogger = NetworkLogger()
    private let memoryLogger = MemoryLogger()
    
    public init(networkBaseURL: String? = nil) {
        if let baseURL = networkBaseURL {
            self.networkClient = NetworkClient(baseURL: baseURL)
        } else {
            self.networkClient = nil
        }
    }
    
    // MARK: - Network Tools
    public func makeRequest<T: Codable>(_ endpoint: APIEndpoint) async throws -> T {
        guard let networkClient = networkClient else {
            throw DevelopmentToolsError.networkNotConfigured
        }
        
        return try await networkClient.request(endpoint)
    }
    
    // MARK: - Storage Tools
    public func saveData<T: Codable>(_ data: T, forKey key: String) throws {
        try storageManager.save(data, forKey: key)
    }
    
    public func loadData<T: Codable>(_ type: T.Type, forKey key: String) throws -> T {
        return try storageManager.load(type, forKey: key)
    }
    
    public func saveDataSecurely<T: Codable>(_ data: T, forKey key: String) throws {
        try storageManager.saveSecurely(data, forKey: key)
    }
    
    public func loadDataSecurely<T: Codable>(_ type: T.Type, forKey key: String) throws -> T {
        return try storageManager.loadSecurely(type, forKey: key)
    }
    
    // MARK: - Analytics Tools
    public func trackEvent(_ name: String, parameters: [String: Any]? = nil) {
        analyticsManager.trackEvent(name, parameters: parameters)
    }
    
    public func trackScreen(_ name: String, parameters: [String: Any]? = nil) {
        analyticsManager.trackScreen(name, parameters: parameters)
    }
    
    public func setUserProperty(_ value: String, forKey key: String) {
        analyticsManager.setUserProperty(value, forKey: key)
    }
    
    public func setUserId(_ userId: String) {
        analyticsManager.setUserId(userId)
    }
    
    // MARK: - Debug Tools
    public func logDebug(_ message: String) {
        logger.debug(message)
    }
    
    public func logInfo(_ message: String) {
        logger.info(message)
    }
    
    public func logWarning(_ message: String) {
        logger.warning(message)
    }
    
    public func logError(_ message: String) {
        logger.error(message)
    }
    
    public func logCritical(_ message: String) {
        logger.critical(message)
    }
    
    // MARK: - Performance Tools
    public func startPerformanceMeasurement(_ name: String) {
        performanceLogger.startMeasurement(name)
    }
    
    public func endPerformanceMeasurement(_ name: String) {
        performanceLogger.endMeasurement(name)
    }
    
    public func measure<T>(_ name: String, operation: () throws -> T) rethrows -> T {
        return try performanceLogger.measure(name, operation: operation)
    }
    
    public func measureAsync<T>(_ name: String, operation: () async throws -> T) async rethrows -> T {
        return try await performanceLogger.measureAsync(name, operation: operation)
    }
    
    // MARK: - Network Logging
    public func logNetworkRequest(_ request: URLRequest) {
        networkLogger.logRequest(request)
    }
    
    public func logNetworkResponse(_ response: URLResponse, data: Data?, error: Error?) {
        networkLogger.logResponse(response, data: data, error: error)
    }
    
    // MARK: - Memory Logging
    public func logMemoryUsage() {
        memoryLogger.logMemoryUsage()
    }
    
    // MARK: - Utility Tools
    public func validateEmail(_ email: String) -> Bool {
        return email.isValidEmail
    }
    
    public func validatePhoneNumber(_ phoneNumber: String) -> Bool {
        return phoneNumber.isValidPhoneNumber
    }
    
    public func formatDate(_ date: Date, format: String) -> String {
        return date.formattedString(format)
    }
    
    public func timeAgo(_ date: Date) -> String {
        return date.timeAgoDisplay()
    }
    
    public func createColor(hex: String) -> UIColor {
        return UIColor(hex: hex)
    }
    
    public func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        return image.resized(to: size)
    }
}

// MARK: - Development Tools Error
public enum DevelopmentToolsError: LocalizedError {
    case networkNotConfigured
    case analyticsNotConfigured
    case storageNotConfigured
    case invalidConfiguration
    
    public var errorDescription: String? {
        switch self {
        case .networkNotConfigured:
            return "Network client not configured"
        case .analyticsNotConfigured:
            return "Analytics not configured"
        case .storageNotConfigured:
            return "Storage not configured"
        case .invalidConfiguration:
            return "Invalid configuration"
        }
    }
}

// MARK: - Convenience Extensions
public extension iOSDevelopmentTools {
    static func debug(_ message: String) {
        Logger.debug(message)
    }
    
    static func info(_ message: String) {
        Logger.info(message)
    }
    
    static func warning(_ message: String) {
        Logger.warning(message)
    }
    
    static func error(_ message: String) {
        Logger.error(message)
    }
    
    static func critical(_ message: String) {
        Logger.critical(message)
    }
} 