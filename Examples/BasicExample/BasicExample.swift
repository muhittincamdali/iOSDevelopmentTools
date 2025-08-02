import SwiftUI
import iOSDevelopmentTools

// MARK: - Basic Example App
@main
struct BasicExampleApp: App {
    
    init() {
        setupDevelopmentTools()
        setupAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(DevelopmentToolsManager.shared)
        }
    }
    
    // MARK: - Setup Methods
    private func setupDevelopmentTools() {
        // Initialize development tools
        iOSDevelopmentTools.initialize()
        
        // Configure development tools
        iOSDevelopmentTools.configure(
            networkBaseURL: "https://api.example.com",
            analyticsEnabled: true,
            loggingEnabled: true
        )
    }
    
    private func setupAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
}

// MARK: - Content View
struct ContentView: View {
    @StateObject private var developmentTools = DevelopmentToolsManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NetworkDemoView()
                .tabItem {
                    Image(systemName: "network")
                    Text("Network")
                }
                .tag(0)
            
            StorageDemoView()
                .tabItem {
                    Image(systemName: "externaldrive")
                    Text("Storage")
                }
                .tag(1)
            
            AnalyticsDemoView()
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Analytics")
                }
                .tag(2)
            
            DebugDemoView()
                .tabItem {
                    Image(systemName: "ladybug")
                    Text("Debug")
                }
                .tag(3)
            
            UtilityDemoView()
                .tabItem {
                    Image(systemName: "wrench.and.screwdriver")
                    Text("Utility")
                }
                .tag(4)
        }
        .accentColor(.primary)
    }
}

// MARK: - Network Demo View
struct NetworkDemoView: View {
    @State private var responseData: String = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Network Status
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Network Status")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        HStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 12, height: 12)
                            Text("Connected")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    // API Test
                    VStack(alignment: .leading, spacing: 12) {
                        Text("API Test")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Button("Test GET Request") {
                            testGetRequest()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Test POST Request") {
                            testPostRequest()
                        }
                        .buttonStyle(.bordered)
                        
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                        
                        if !responseData.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Response:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text(responseData)
                                    .font(.caption)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .padding()
            }
            .navigationTitle("Network Tools")
            .alert("Network Error", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func testGetRequest() {
        isLoading = true
        responseData = ""
        
        Task {
            do {
                let endpoint = APIEndpoint(
                    path: "/users/1",
                    method: .get,
                    parameters: nil
                )
                
                let user: MockUser = try await DevelopmentToolsManager.shared.networkTools.request(endpoint)
                await MainActor.run {
                    responseData = "User: \(user.name) (\(user.email))"
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showAlert = true
                    isLoading = false
                }
            }
        }
    }
    
    private func testPostRequest() {
        isLoading = true
        responseData = ""
        
        Task {
            do {
                let userData = ["name": "John Doe", "email": "john@example.com"]
                let endpoint = APIEndpoint(
                    path: "/users",
                    method: .post,
                    parameters: userData
                )
                
                let response: MockResponse = try await DevelopmentToolsManager.shared.networkTools.request(endpoint)
                await MainActor.run {
                    responseData = "Created: \(response.message)"
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showAlert = true
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Storage Demo View
struct StorageDemoView: View {
    @State private var userInput = ""
    @State private var storedData = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // User Input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Store Data")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        TextField("Enter data to store", text: $userInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        HStack {
                            Button("Save to UserDefaults") {
                                saveToUserDefaults()
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Save to Keychain") {
                                saveToKeychain()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    // Stored Data
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Retrieve Data")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        HStack {
                            Button("Load from UserDefaults") {
                                loadFromUserDefaults()
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Load from Keychain") {
                                loadFromKeychain()
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        if !storedData.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Retrieved Data:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text(storedData)
                                    .font(.caption)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    // Clear Data
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Clear Data")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Button("Clear All Data") {
                            clearAllData()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .padding()
            }
            .navigationTitle("Storage Tools")
            .alert("Storage Error", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func saveToUserDefaults() {
        do {
            try DevelopmentToolsManager.shared.storageTools.save(userInput, forKey: "demo_data")
            alertMessage = "Data saved to UserDefaults successfully!"
            showAlert = true
        } catch {
            alertMessage = "Failed to save data: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func saveToKeychain() {
        do {
            try DevelopmentToolsManager.shared.storageTools.saveSecure(userInput, forKey: "secure_demo_data")
            alertMessage = "Data saved to Keychain successfully!"
            showAlert = true
        } catch {
            alertMessage = "Failed to save data: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func loadFromUserDefaults() {
        do {
            let data: String = try DevelopmentToolsManager.shared.storageTools.load(forKey: "demo_data")
            storedData = data
        } catch {
            alertMessage = "Failed to load data: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func loadFromKeychain() {
        do {
            let data: String = try DevelopmentToolsManager.shared.storageTools.loadSecure(forKey: "secure_demo_data")
            storedData = data
        } catch {
            alertMessage = "Failed to load data: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func clearAllData() {
        do {
            try DevelopmentToolsManager.shared.storageTools.delete(forKey: "demo_data")
            try DevelopmentToolsManager.shared.storageTools.delete(forKey: "secure_demo_data")
            storedData = ""
            alertMessage = "All data cleared successfully!"
            showAlert = true
        } catch {
            alertMessage = "Failed to clear data: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

// MARK: - Analytics Demo View
struct AnalyticsDemoView: View {
    @State private var eventName = ""
    @State private var eventProperties = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Track Event
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Track Event")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        TextField("Event name", text: $eventName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        TextField("Event properties (JSON)", text: $eventProperties)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("Track Event") {
                            trackEvent()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    // Track Screen
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Track Screen")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Button("Track Current Screen") {
                            trackScreen()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Track User Properties") {
                            trackUserProperties()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    // Performance Tracking
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Performance Tracking")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Button("Track Performance") {
                            trackPerformance()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .padding()
            }
            .navigationTitle("Analytics Tools")
            .alert("Analytics", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func trackEvent() {
        guard !eventName.isEmpty else {
            alertMessage = "Please enter an event name"
            showAlert = true
            return
        }
        
        var properties: [String: Any] = [:]
        if !eventProperties.isEmpty {
            if let data = eventProperties.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                properties = json
            }
        }
        
        DevelopmentToolsManager.shared.analyticsTools.trackEvent(
            name: eventName,
            properties: properties
        )
        
        alertMessage = "Event '\(eventName)' tracked successfully!"
        showAlert = true
        eventName = ""
        eventProperties = ""
    }
    
    private func trackScreen() {
        DevelopmentToolsManager.shared.analyticsTools.trackScreen(
            name: "Analytics Demo",
            properties: ["source": "demo_app"]
        )
        
        alertMessage = "Screen 'Analytics Demo' tracked successfully!"
        showAlert = true
    }
    
    private func trackUserProperties() {
        DevelopmentToolsManager.shared.analyticsTools.setUserProperty(
            key: "demo_user",
            value: "true"
        )
        
        alertMessage = "User property 'demo_user' set successfully!"
        showAlert = true
    }
    
    private func trackPerformance() {
        DevelopmentToolsManager.shared.analyticsTools.trackPerformance(
            name: "demo_operation",
            duration: 1.5
        )
        
        alertMessage = "Performance 'demo_operation' tracked successfully!"
        showAlert = true
    }
}

// MARK: - Debug Demo View
struct DebugDemoView: View {
    @State private var logMessage = ""
    @State private var logLevel: LogLevel = .info
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Logging
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Logging")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        TextField("Log message", text: $logMessage)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Picker("Log Level", selection: $logLevel) {
                            Text("Debug").tag(LogLevel.debug)
                            Text("Info").tag(LogLevel.info)
                            Text("Warning").tag(LogLevel.warning)
                            Text("Error").tag(LogLevel.error)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        Button("Log Message") {
                            logMessage()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    // Performance Monitoring
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Performance Monitoring")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Button("Start Performance Monitoring") {
                            startPerformanceMonitoring()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Stop Performance Monitoring") {
                            stopPerformanceMonitoring()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    // Memory Monitoring
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Memory Monitoring")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Button("Check Memory Usage") {
                            checkMemoryUsage()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .padding()
            }
            .navigationTitle("Debug Tools")
            .alert("Debug", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func logMessage() {
        guard !logMessage.isEmpty else {
            alertMessage = "Please enter a log message"
            showAlert = true
            return
        }
        
        DevelopmentToolsManager.shared.debugTools.log(
            message: logMessage,
            level: logLevel
        )
        
        alertMessage = "Message logged successfully!"
        showAlert = true
        logMessage = ""
    }
    
    private func startPerformanceMonitoring() {
        DevelopmentToolsManager.shared.debugTools.startPerformanceMonitoring()
        alertMessage = "Performance monitoring started!"
        showAlert = true
    }
    
    private func stopPerformanceMonitoring() {
        DevelopmentToolsManager.shared.debugTools.stopPerformanceMonitoring()
        alertMessage = "Performance monitoring stopped!"
        showAlert = true
    }
    
    private func checkMemoryUsage() {
        let memoryUsage = DevelopmentToolsManager.shared.debugTools.getMemoryUsage()
        alertMessage = "Memory usage: \(memoryUsage) MB"
        showAlert = true
    }
}

// MARK: - Utility Demo View
struct UtilityDemoView: View {
    @State private var inputText = ""
    @State private var resultText = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // String Utilities
                    VStack(alignment: .leading, spacing: 12) {
                        Text("String Utilities")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        TextField("Enter text", text: $inputText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        HStack {
                            Button("Validate Email") {
                                validateEmail()
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Validate Phone") {
                                validatePhone()
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Button("Generate UUID") {
                            generateUUID()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    // Date Utilities
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Date Utilities")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Button("Format Current Date") {
                            formatCurrentDate()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Get Time Ago") {
                            getTimeAgo()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    // Color Utilities
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Color Utilities")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Button("Create Color from Hex") {
                            createColorFromHex()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    // Results
                    if !resultText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Result:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(resultText)
                                .font(.caption)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                }
                .padding()
            }
            .navigationTitle("Utility Tools")
            .alert("Utility", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func validateEmail() {
        let isValid = inputText.isValidEmail
        resultText = "Email validation: \(isValid ? "Valid" : "Invalid")"
    }
    
    private func validatePhone() {
        let isValid = inputText.isValidPhoneNumber
        resultText = "Phone validation: \(isValid ? "Valid" : "Invalid")"
    }
    
    private func generateUUID() {
        resultText = "Generated UUID: \(UUID().uuidString)"
    }
    
    private func formatCurrentDate() {
        let formattedDate = Date().formattedString(format: "yyyy-MM-dd HH:mm:ss")
        resultText = "Formatted date: \(formattedDate)"
    }
    
    private func getTimeAgo() {
        let timeAgo = Date().addingTimeInterval(-3600).timeAgoString
        resultText = "Time ago: \(timeAgo)"
    }
    
    private func createColorFromHex() {
        let color = UIColor(hex: "#FF6B6B")
        resultText = "Color created from hex: #FF6B6B"
    }
}

// MARK: - Mock Models
struct MockUser: Codable {
    let id: Int
    let name: String
    let email: String
}

struct MockResponse: Codable {
    let message: String
    let success: Bool
} 