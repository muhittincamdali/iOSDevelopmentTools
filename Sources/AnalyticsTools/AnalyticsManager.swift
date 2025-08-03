import Foundation
import Combine

// MARK: - Analytics Manager Protocol
public protocol AnalyticsManagerProtocol {
    func trackEvent(_ name: String, parameters: [String: Any]?)
    func trackScreen(_ name: String, parameters: [String: Any]?)
    func setUserProperty(_ value: String, forKey key: String)
    func setUserId(_ userId: String)
    func trackError(_ error: Error, parameters: [String: Any]?)
}

// MARK: - Analytics Manager Implementation
public class AnalyticsManager: AnalyticsManagerProtocol, ObservableObject {
    public static let shared = AnalyticsManager()
    
    private var analyticsProviders: [AnalyticsProvider] = []
    private var userProperties: [String: String] = [:]
    private var userId: String?
    
    public init() {}
    
    // MARK: - Provider Management
    public func addProvider(_ provider: AnalyticsProvider) {
        analyticsProviders.append(provider)
    }
    
    public func removeProvider(_ provider: AnalyticsProvider) {
        analyticsProviders.removeAll { $0.id == provider.id }
    }
    
    // MARK: - Event Tracking
    public func trackEvent(_ name: String, parameters: [String: Any]? = nil) {
        let event = AnalyticsEvent(
            name: name,
            parameters: parameters ?? [:],
            timestamp: Date(),
            userId: userId
        )
        
        analyticsProviders.forEach { provider in
            provider.trackEvent(event)
        }
    }
    
    public func trackScreen(_ name: String, parameters: [String: Any]? = nil) {
        var screenParameters = parameters ?? [:]
        screenParameters["screen_name"] = name
        screenParameters["screen_class"] = "Screen"
        
        trackEvent("screen_view", parameters: screenParameters)
    }
    
    public func setUserProperty(_ value: String, forKey key: String) {
        userProperties[key] = value
        
        analyticsProviders.forEach { provider in
            provider.setUserProperty(value, forKey: key)
        }
    }
    
    public func setUserId(_ userId: String) {
        self.userId = userId
        
        analyticsProviders.forEach { provider in
            provider.setUserId(userId)
        }
    }
    
    public func trackError(_ error: Error, parameters: [String: Any]? = nil) {
        var errorParameters = parameters ?? [:]
        errorParameters["error_message"] = error.localizedDescription
        errorParameters["error_domain"] = (error as NSError).domain
        errorParameters["error_code"] = (error as NSError).code
        
        trackEvent("app_error", parameters: errorParameters)
    }
    
    // MARK: - Performance Tracking
    public func trackPerformance(_ metric: PerformanceMetric) {
        let parameters: [String: Any] = [
            "metric_name": metric.name,
            "metric_value": metric.value,
            "metric_unit": metric.unit
        ]
        
        trackEvent("performance_metric", parameters: parameters)
    }
    
    // MARK: - User Journey Tracking
    public func trackUserJourney(_ journey: String, step: String, parameters: [String: Any]? = nil) {
        var journeyParameters = parameters ?? [:]
        journeyParameters["journey"] = journey
        journeyParameters["step"] = step
        
        trackEvent("user_journey", parameters: journeyParameters)
    }
    
    // MARK: - Conversion Tracking
    public func trackConversion(_ type: String, value: Double, currency: String = "USD") {
        let parameters: [String: Any] = [
            "conversion_type": type,
            "value": value,
            "currency": currency
        ]
        
        trackEvent("conversion", parameters: parameters)
    }
}

// MARK: - Analytics Provider Protocol
public protocol AnalyticsProvider {
    var id: String { get }
    func trackEvent(_ event: AnalyticsEvent)
    func setUserProperty(_ value: String, forKey key: String)
    func setUserId(_ userId: String)
}

// MARK: - Analytics Event
public struct AnalyticsEvent {
    public let name: String
    public let parameters: [String: Any]
    public let timestamp: Date
    public let userId: String?
    
    public init(name: String, parameters: [String: Any], timestamp: Date, userId: String?) {
        self.name = name
        self.parameters = parameters
        self.timestamp = timestamp
        self.userId = userId
    }
}

// MARK: - Performance Metric
public struct PerformanceMetric {
    public let name: String
    public let value: Double
    public let unit: String
    
    public init(name: String, value: Double, unit: String) {
        self.name = name
        self.value = value
        self.unit = unit
    }
}

// MARK: - Firebase Analytics Provider
public class FirebaseAnalyticsProvider: AnalyticsProvider {
    public let id = "firebase"
    
    public init() {}
    
    public func trackEvent(_ event: AnalyticsEvent) {
        // Firebase Analytics implementation
        print("Firebase Analytics: \(event.name)")
    }
    
    public func setUserProperty(_ value: String, forKey key: String) {
        // Firebase Analytics user property
        print("Firebase Analytics User Property: \(key) = \(value)")
    }
    
    public func setUserId(_ userId: String) {
        // Firebase Analytics user ID
        print("Firebase Analytics User ID: \(userId)")
    }
}

// MARK: - Amplitude Analytics Provider
public class AmplitudeAnalyticsProvider: AnalyticsProvider {
    public let id = "amplitude"
    
    public init() {}
    
    public func trackEvent(_ event: AnalyticsEvent) {
        // Amplitude Analytics implementation
        print("Amplitude Analytics: \(event.name)")
    }
    
    public func setUserProperty(_ value: String, forKey key: String) {
        // Amplitude Analytics user property
        print("Amplitude Analytics User Property: \(key) = \(value)")
    }
    
    public func setUserId(_ userId: String) {
        // Amplitude Analytics user ID
        print("Amplitude Analytics User ID: \(userId)")
    }
}

// MARK: - Mixpanel Analytics Provider
public class MixpanelAnalyticsProvider: AnalyticsProvider {
    public let id = "mixpanel"
    
    public init() {}
    
    public func trackEvent(_ event: AnalyticsEvent) {
        // Mixpanel Analytics implementation
        print("Mixpanel Analytics: \(event.name)")
    }
    
    public func setUserProperty(_ value: String, forKey key: String) {
        // Mixpanel Analytics user property
        print("Mixpanel Analytics User Property: \(key) = \(value)")
    }
    
    public func setUserId(_ userId: String) {
        // Mixpanel Analytics user ID
        print("Mixpanel Analytics User ID: \(userId)")
    }
}

// MARK: - Analytics Error
public enum AnalyticsError: LocalizedError {
    case providerNotFound(String)
    case invalidEvent(String)
    case networkError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .providerNotFound(let id):
            return "Analytics provider not found: \(id)"
        case .invalidEvent(let name):
            return "Invalid event name: \(name)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
} // Analytics improvements
