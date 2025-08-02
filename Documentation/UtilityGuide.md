# 🛠️ Utility Guide

Complete utility documentation for iOS Development Tools.

## 📋 Table of Contents

- [String Utilities](#string-utilities)
- [Date Utilities](#date-utilities)
- [File Utilities](#file-utilities)
- [Validation Utilities](#validation-utilities)
- [Formatting Utilities](#formatting-utilities)
- [Security Utilities](#security-utilities)

## 📝 String Utilities

### **String Extensions**
```swift
extension String {
    // Check if string is valid email
    var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: self)
    }
    
    // Check if string is valid phone number
    var isValidPhoneNumber: Bool {
        let phoneRegex = "^[0-9+]{0,1}+[0-9]{5,16}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: self)
    }
    
    // Capitalize first letter
    var capitalizedFirst: String {
        return prefix(1).uppercased() + dropFirst()
    }
    
    // Remove whitespace and newlines
    var trimmed: String {
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Convert to URL
    var asURL: URL? {
        return URL(string: self)
    }
}
```

### **String Validation**
```swift
struct StringValidator {
    static func isValidEmail(_ email: String) -> Bool {
        return email.isValidEmail
    }
    
    static func isValidPhoneNumber(_ phone: String) -> Bool {
        return phone.isValidPhoneNumber
    }
    
    static func isValidPassword(_ password: String) -> Bool {
        // At least 8 characters, 1 uppercase, 1 lowercase, 1 number
        let passwordRegex = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)[a-zA-Z\\d]{8,}$"
        let passwordPredicate = NSPredicate(format: "SELF MATCHES %@", passwordRegex)
        return passwordPredicate.evaluate(with: password)
    }
    
    static func isValidURL(_ url: String) -> Bool {
        return url.asURL != nil
    }
}
```

## 📅 Date Utilities

### **Date Extensions**
```swift
extension Date {
    // Format date to string
    func formatted(format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
    
    // Get relative time string
    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    // Check if date is today
    var isToday: Bool {
        return Calendar.current.isDateInToday(self)
    }
    
    // Check if date is yesterday
    var isYesterday: Bool {
        return Calendar.current.isDateInYesterday(self)
    }
    
    // Get start of day
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }
    
    // Get end of day
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }
}
```

### **Date Formatter**
```swift
struct DateFormatter {
    static let shared = DateFormatter()
    
    func format(_ date: Date, style: DateFormatterStyle) -> String {
        let formatter = Foundation.DateFormatter()
        
        switch style {
        case .short:
            formatter.dateStyle = .short
            formatter.timeStyle = .short
        case .medium:
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
        case .long:
            formatter.dateStyle = .long
            formatter.timeStyle = .long
        case .full:
            formatter.dateStyle = .full
            formatter.timeStyle = .full
        case .custom(let format):
            formatter.dateFormat = format
        }
        
        return formatter.string(from: date)
    }
}

enum DateFormatterStyle {
    case short
    case medium
    case long
    case full
    case custom(String)
}
```

## 📁 File Utilities

### **File Manager Extensions**
```swift
extension FileManager {
    // Get documents directory
    var documentsDirectory: URL {
        return urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    // Get cache directory
    var cacheDirectory: URL {
        return urls(for: .cachesDirectory, in: .userDomainMask).first!
    }
    
    // Get temporary directory
    var temporaryDirectory: URL {
        return temporaryDirectory
    }
    
    // Check if file exists
    func fileExists(at url: URL) -> Bool {
        return fileExists(atPath: url.path)
    }
    
    // Create directory
    func createDirectory(at url: URL) throws {
        try createDirectory(at: url, withIntermediateDirectories: true)
    }
    
    // Get file size
    func fileSize(at url: URL) -> Int64? {
        guard let attributes = try? attributesOfItem(atPath: url.path) else {
            return nil
        }
        return attributes[.size] as? Int64
    }
}
```

### **File Operations**
```swift
struct FileOperations {
    static func save(_ data: Data, to url: URL) throws {
        try data.write(to: url)
    }
    
    static func load(from url: URL) throws -> Data {
        return try Data(contentsOf: url)
    }
    
    static func delete(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
    
    static func copy(from source: URL, to destination: URL) throws {
        try FileManager.default.copyItem(at: source, to: destination)
    }
    
    static func move(from source: URL, to destination: URL) throws {
        try FileManager.default.moveItem(at: source, to: destination)
    }
}
```

## ✅ Validation Utilities

### **Input Validator**
```swift
struct InputValidator {
    // Validate email
    static func validateEmail(_ email: String) -> ValidationResult {
        if email.isEmpty {
            return .failure("Email cannot be empty")
        }
        
        if !email.isValidEmail {
            return .failure("Invalid email format")
        }
        
        return .success
    }
    
    // Validate password
    static func validatePassword(_ password: String) -> ValidationResult {
        if password.isEmpty {
            return .failure("Password cannot be empty")
        }
        
        if password.count < 8 {
            return .failure("Password must be at least 8 characters")
        }
        
        if !password.matches(regex: ".*[A-Z].*") {
            return .failure("Password must contain at least one uppercase letter")
        }
        
        if !password.matches(regex: ".*[a-z].*") {
            return .failure("Password must contain at least one lowercase letter")
        }
        
        if !password.matches(regex: ".*\\d.*") {
            return .failure("Password must contain at least one number")
        }
        
        return .success
    }
    
    // Validate phone number
    static func validatePhoneNumber(_ phone: String) -> ValidationResult {
        if phone.isEmpty {
            return .failure("Phone number cannot be empty")
        }
        
        if !phone.isValidPhoneNumber {
            return .failure("Invalid phone number format")
        }
        
        return .success
    }
}

enum ValidationResult {
    case success
    case failure(String)
}

extension String {
    func matches(regex: String) -> Bool {
        let predicate = NSPredicate(format: "SELF MATCHES %@", regex)
        return predicate.evaluate(with: self)
    }
}
```

## 🎨 Formatting Utilities

### **Number Formatter**
```swift
struct NumberFormatter {
    static func formatCurrency(_ amount: Double, currency: String = "USD") -> String {
        let formatter = Foundation.NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
    
    static func formatPercentage(_ value: Double) -> String {
        let formatter = Foundation.NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)%"
    }
    
    static func formatDecimal(_ value: Double, decimalPlaces: Int = 2) -> String {
        let formatter = Foundation.NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimalPlaces
        formatter.maximumFractionDigits = decimalPlaces
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
```

### **Text Formatter**
```swift
struct TextFormatter {
    static func formatPhoneNumber(_ phone: String) -> String {
        let cleaned = phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        switch cleaned.count {
        case 10:
            return "(\(cleaned.prefix(3))) \(cleaned.dropFirst(3).prefix(3))-\(cleaned.dropFirst(6))"
        case 11:
            return "+\(cleaned.prefix(1)) (\(cleaned.dropFirst(1).prefix(3))) \(cleaned.dropFirst(4).prefix(3))-\(cleaned.dropFirst(7))"
        default:
            return phone
        }
    }
    
    static func formatCreditCard(_ card: String) -> String {
        let cleaned = card.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        var formatted = ""
        for (index, character) in cleaned.enumerated() {
            if index > 0 && index % 4 == 0 {
                formatted += " "
            }
            formatted += String(character)
        }
        
        return formatted
    }
    
    static func truncate(_ text: String, to length: Int, suffix: String = "...") -> String {
        if text.count <= length {
            return text
        }
        
        let truncated = text.prefix(length - suffix.count)
        return String(truncated) + suffix
    }
}
```

## 🔒 Security Utilities

### **Encryption**
```swift
struct Encryption {
    static func encrypt(_ data: Data, with key: String) throws -> Data {
        // Implementation for AES encryption
        return data
    }
    
    static func decrypt(_ data: Data, with key: String) throws -> Data {
        // Implementation for AES decryption
        return data
    }
    
    static func hash(_ string: String, algorithm: HashAlgorithm = .sha256) -> String {
        // Implementation for hashing
        return string
    }
}

enum HashAlgorithm {
    case md5
    case sha1
    case sha256
    case sha512
}
```

### **Keychain Utilities**
```swift
struct KeychainUtilities {
    static func save(_ data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed
        }
    }
    
    static func load(forKey key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            throw KeychainError.loadFailed
        }
        
        return data
    }
    
    static func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed
        }
    }
}

enum KeychainError: Error {
    case saveFailed
    case loadFailed
    case deleteFailed
}
```

## 📚 Next Steps

1. **Read [Getting Started](GettingStarted.md)** for quick setup
2. **Check [Network Guide](NetworkGuide.md)** for network utilities
3. **Explore [Storage Guide](StorageGuide.md)** for storage utilities
4. **Review [Analytics Guide](AnalyticsGuide.md)** for analytics utilities
5. **Learn [Debugging Guide](DebuggingGuide.md)** for debugging tools
6. **See [API Reference](API.md)** for complete API documentation

## 🤝 Support

- **Documentation**: [Complete Documentation](Documentation/)
- **Issues**: [GitHub Issues](https://github.com/muhittincamdali/iOSDevelopmentTools/issues)
- **Discussions**: [GitHub Discussions](https://github.com/muhittincamdali/iOSDevelopmentTools/discussions)

---

**Happy developing with iOS Development Tools! 🚀** 