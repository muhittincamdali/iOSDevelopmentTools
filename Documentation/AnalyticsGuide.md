# 📊 Analytics Guide

Complete analytics utilities documentation for iOS Development Tools.

## 📋 Table of Contents

- [Analytics Manager](#analytics-manager)
- [Event Tracking](#event-tracking)
- [Screen Tracking](#screen-tracking)
- [User Properties](#user-properties)
- [Custom Analytics](#custom-analytics)

## 📊 Analytics Manager

### **Basic Usage**
```swift
let analytics = AnalyticsManager()

// Track event
analytics.trackEvent("user_login", properties: [
    "method": "email",
    "timestamp": Date()
])

// Track screen
analytics.trackScreen("ProfileViewController")

// Set user property
analytics.setUserProperty("premium", value: true)
```

### **Configuration**
```swift
let config = AnalyticsConfiguration(
    enabled: true,
    debugMode: false,
    batchSize: 10,
    flushInterval: 30
)

let analytics = AnalyticsManager(configuration: config)
```

## 📈 Event Tracking

### **Event Types**
```swift
// User events
analytics.trackEvent("user_signup")
analytics.trackEvent("user_login", properties: ["method": "email"])
analytics.trackEvent("user_logout")

// App events
analytics.trackEvent("app_launch")
analytics.trackEvent("app_background")
analytics.trackEvent("app_foreground")

// Feature events
analytics.trackEvent("feature_used", properties: ["feature": "search"])
analytics.trackEvent("button_clicked", properties: ["button": "save"])

// Error events
analytics.trackEvent("error_occurred", properties: [
    "error_type": "network",
    "error_message": "Connection failed"
])
```

### **Event Properties**
```swift
// Basic properties
let properties: [String: Any] = [
    "user_id": "12345",
    "timestamp": Date(),
    "version": "1.0.0",
    "platform": "iOS"
]

analytics.trackEvent("custom_event", properties: properties)

// Complex properties
let complexProperties: [String: Any] = [
    "user": [
        "id": "12345",
        "name": "John Doe",
        "email": "john@example.com"
    ],
    "session": [
        "id": "session_123",
        "duration": 300
    ],
    "device": [
        "model": "iPhone 14",
        "os_version": "16.0"
    ]
]

analytics.trackEvent("user_session", properties: complexProperties)
```

## 📱 Screen Tracking

### **Screen Views**
```swift
// Track screen view
analytics.trackScreen("HomeViewController")

// Track screen with properties
analytics.trackScreen("ProductViewController", properties: [
    "product_id": "123",
    "category": "electronics"
])

// Track screen duration
analytics.trackScreen("ProfileViewController", properties: [
    "duration": 120 // seconds
])
```

### **Screen Manager**
```swift
class ScreenTrackingManager {
    private let analytics: AnalyticsManager
    private var screenStartTimes: [String: Date] = [:]
    
    init(analytics: AnalyticsManager) {
        self.analytics = analytics
    }
    
    func trackScreenStart(_ screenName: String) {
        screenStartTimes[screenName] = Date()
        analytics.trackScreen(screenName, properties: ["action": "start"])
    }
    
    func trackScreenEnd(_ screenName: String) {
        guard let startTime = screenStartTimes[screenName] else { return }
        
        let duration = Date().timeIntervalSince(startTime)
        analytics.trackScreen(screenName, properties: [
            "action": "end",
            "duration": duration
        ])
        
        screenStartTimes.removeValue(forKey: screenName)
    }
}
```

## 👤 User Properties

### **User Identification**
```swift
// Set user ID
analytics.setUserID("user_12345")

// Set user properties
analytics.setUserProperty("name", value: "John Doe")
analytics.setUserProperty("email", value: "john@example.com")
analytics.setUserProperty("age", value: 30)
analytics.setUserProperty("premium", value: true)

// Set multiple properties
let userProperties: [String: Any] = [
    "name": "John Doe",
    "email": "john@example.com",
    "age": 30,
    "premium": true,
    "subscription_type": "monthly"
]

analytics.setUserProperties(userProperties)
```

### **User Segmentation**
```swift
class UserSegmentation {
    private let analytics: AnalyticsManager
    
    init(analytics: AnalyticsManager) {
        self.analytics = analytics
    }
    
    func segmentUser(_ user: User) {
        // Set basic properties
        analytics.setUserProperty("user_id", value: user.id)
        analytics.setUserProperty("name", value: user.name)
        analytics.setUserProperty("email", value: user.email)
        
        // Set demographic properties
        analytics.setUserProperty("age_group", value: getAgeGroup(user.age))
        analytics.setUserProperty("location", value: user.location)
        analytics.setUserProperty("language", value: user.language)
        
        // Set behavioral properties
        analytics.setUserProperty("signup_date", value: user.signupDate)
        analytics.setUserProperty("last_login", value: user.lastLogin)
        analytics.setUserProperty("login_count", value: user.loginCount)
        
        // Set subscription properties
        analytics.setUserProperty("subscription_status", value: user.subscriptionStatus)
        analytics.setUserProperty("subscription_type", value: user.subscriptionType)
        analytics.setUserProperty("subscription_start", value: user.subscriptionStart)
    }
    
    private func getAgeGroup(_ age: Int) -> String {
        switch age {
        case 13...17: return "teen"
        case 18...24: return "young_adult"
        case 25...34: return "adult"
        case 35...44: return "mature_adult"
        case 45...54: return "middle_age"
        case 55...: return "senior"
        default: return "unknown"
        }
    }
}
```

## 🎯 Custom Analytics

### **Conversion Tracking**
```swift
class ConversionTracker {
    private let analytics: AnalyticsManager
    
    init(analytics: AnalyticsManager) {
        self.analytics = analytics
    }
    
    func trackSignup() {
        analytics.trackEvent("conversion", properties: [
            "type": "signup",
            "funnel_step": "completed"
        ])
    }
    
    func trackPurchase(amount: Double, product: String) {
        analytics.trackEvent("conversion", properties: [
            "type": "purchase",
            "amount": amount,
            "product": product,
            "currency": "USD"
        ])
    }
    
    func trackSubscription(type: String, amount: Double) {
        analytics.trackEvent("conversion", properties: [
            "type": "subscription",
            "subscription_type": type,
            "amount": amount,
            "currency": "USD"
        ])
    }
}
```

### **Funnel Tracking**
```swift
class FunnelTracker {
    private let analytics: AnalyticsManager
    
    init(analytics: AnalyticsManager) {
        self.analytics = analytics
    }
    
    func trackFunnelStep(_ step: String, funnel: String) {
        analytics.trackEvent("funnel_step", properties: [
            "funnel": funnel,
            "step": step,
            "step_number": getStepNumber(step, funnel: funnel)
        ])
    }
    
    func trackFunnelCompletion(_ funnel: String) {
        analytics.trackEvent("funnel_completed", properties: [
            "funnel": funnel,
            "completion_time": Date()
        ])
    }
    
    private func getStepNumber(_ step: String, funnel: String) -> Int {
        // Implementation to get step number
        return 1
    }
}
```

### **A/B Testing**
```swift
class ABTestTracker {
    private let analytics: AnalyticsManager
    
    init(analytics: AnalyticsManager) {
        self.analytics = analytics
    }
    
    func trackExperiment(_ experiment: String, variant: String) {
        analytics.trackEvent("experiment_viewed", properties: [
            "experiment": experiment,
            "variant": variant
        ])
    }
    
    func trackExperimentConversion(_ experiment: String, variant: String) {
        analytics.trackEvent("experiment_conversion", properties: [
            "experiment": experiment,
            "variant": variant
        ])
    }
}
```

## 📊 Analytics Dashboard

### **Metrics Collection**
```swift
class MetricsCollector {
    private let analytics: AnalyticsManager
    
    init(analytics: AnalyticsManager) {
        self.analytics = analytics
    }
    
    func trackAppLaunch() {
        analytics.trackEvent("app_launch", properties: [
            "timestamp": Date(),
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ])
    }
    
    func trackSessionDuration(_ duration: TimeInterval) {
        analytics.trackEvent("session_ended", properties: [
            "duration": duration,
            "timestamp": Date()
        ])
    }
    
    func trackFeatureUsage(_ feature: String) {
        analytics.trackEvent("feature_used", properties: [
            "feature": feature,
            "timestamp": Date()
        ])
    }
    
    func trackError(_ error: Error) {
        analytics.trackEvent("error_occurred", properties: [
            "error_type": String(describing: type(of: error)),
            "error_message": error.localizedDescription,
            "timestamp": Date()
        ])
    }
}
```

## 📚 Next Steps

1. **Read [Getting Started](GettingStarted.md)** for quick setup
2. **Check [Network Guide](NetworkGuide.md)** for network utilities
3. **Explore [Storage Guide](StorageGuide.md)** for storage utilities
4. **Review [Utility Guide](UtilityGuide.md)** for utility functions
5. **Learn [Debugging Guide](DebuggingGuide.md)** for debugging tools
6. **See [API Reference](API.md)** for complete API documentation

## 🤝 Support

- **Documentation**: [Complete Documentation](Documentation/)
- **Issues**: [GitHub Issues](https://github.com/muhittincamdali/iOSDevelopmentTools/issues)
- **Discussions**: [GitHub Discussions](https://github.com/muhittincamdali/iOSDevelopmentTools/discussions)

---

**Happy analyzing with iOS Development Tools! 📊** 