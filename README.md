# iOS Development Tools

<p align="center">
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-5.9+-F05138?style=flat&logo=swift&logoColor=white" alt="Swift"></a>
  <a href="https://developer.apple.com/ios/"><img src="https://img.shields.io/badge/iOS-15.0+-000000?style=flat&logo=apple&logoColor=white" alt="iOS"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License"></a>
</p>

<p align="center">
  <b>Essential utilities and helpers for iOS development.</b>
</p>

---

## Features

- **Extensions** — Useful extensions for Foundation and UIKit/SwiftUI
- **Utilities** — Common helper functions and types
- **Debugging** — Debug tools and logging utilities
- **Storage** — UserDefaults, Keychain, and file management helpers
- **Validation** — Input validation and formatting

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/muhittincamdali/iOSDevelopmentTools.git", from: "1.0.0")
]
```

## Quick Start

### String Extensions

```swift
import iOSDevelopmentTools

// Email validation
"test@example.com".isValidEmail // true
"invalid-email".isValidEmail // false

// URL validation  
"https://example.com".isValidURL // true

// Phone formatting
"5551234567".formatAsPhoneNumber // "(555) 123-4567"

// Truncation
"Long text here".truncated(to: 8) // "Long tex..."

// Localization
"welcome_message".localized // Fetches from Localizable.strings
```

### Date Extensions

```swift
// Relative time
let date = Date().addingTimeInterval(-3600)
date.timeAgoDisplay // "1 hour ago"

// Formatting
Date().formatted(.short) // "1/28/25"
Date().formatted(.full) // "Tuesday, January 28, 2025"

// Components
Date().isToday // true
Date().isWeekend // depends on day
Date().startOfDay // 00:00:00
Date().endOfDay // 23:59:59
```

### Collection Extensions

```swift
// Safe subscript
let array = [1, 2, 3]
array[safe: 10] // nil instead of crash

// Unique elements
[1, 2, 2, 3, 3, 3].unique // [1, 2, 3]

// Chunking
[1, 2, 3, 4, 5].chunked(into: 2) // [[1, 2], [3, 4], [5]]
```

### View Extensions (SwiftUI)

```swift
// Conditional modifier
Text("Hello")
    .if(isHighlighted) { view in
        view.foregroundStyle(.yellow)
    }

// Hide keyboard
.hideKeyboardOnTap()

// Corner radius for specific corners
.cornerRadius(16, corners: [.topLeft, .topRight])

// Read frame
.readFrame { frame in
    print(frame.size)
}
```

### UIKit Extensions

```swift
// UIColor from hex
let color = UIColor(hex: "#FF5733")
let color2 = UIColor(hex: "007AFF")

// UIView helpers
view.roundCorners(radius: 12)
view.addShadow(color: .black, opacity: 0.2, radius: 8)
view.addBorder(color: .gray, width: 1)

// UIImage helpers
image.resized(to: CGSize(width: 100, height: 100))
image.cropped(to: CGRect(x: 0, y: 0, width: 50, height: 50))
image.withTintColor(.red)
```

### UserDefaults Wrapper

```swift
@UserDefault("hasSeenOnboarding", defaultValue: false)
var hasSeenOnboarding: Bool

@UserDefault("username", defaultValue: nil)
var username: String?

// Usage
hasSeenOnboarding = true
print(username ?? "Guest")
```

### Keychain Helper

```swift
let keychain = KeychainHelper.shared

// Save
try keychain.save("secret_token", forKey: "authToken")

// Read
let token: String? = try keychain.read(forKey: "authToken")

// Delete
try keychain.delete(forKey: "authToken")
```

### Logger

```swift
let logger = Logger(subsystem: "com.myapp", category: "networking")

logger.debug("Debug message")
logger.info("Info message")
logger.warning("Warning message")
logger.error("Error message")

// With context
logger.info("User logged in", metadata: ["userId": "123"])
```

### Device Info

```swift
let device = DeviceInfo.shared

device.modelName // "iPhone 15 Pro"
device.systemVersion // "17.2"
device.isSimulator // true/false
device.hasNotch // true/false
device.screenSize // .large, .medium, .small
```

### Debouncer & Throttler

```swift
// Debounce - execute after delay, resets on each call
let searchDebouncer = Debouncer(delay: 0.3)
textField.addTarget(self, action: #selector(textChanged), for: .editingChanged)

@objc func textChanged() {
    searchDebouncer.debounce {
        performSearch()
    }
}

// Throttle - execute at most once per interval
let scrollThrottler = Throttler(interval: 0.1)
scrollThrottler.throttle {
    updateUI()
}
```

### Validation

```swift
let validator = Validator()

// Email
validator.validate("test@example.com", rules: [.email]) // .valid
validator.validate("invalid", rules: [.email]) // .invalid("Invalid email")

// Password
validator.validate("pass", rules: [.minLength(8)]) // .invalid("Minimum 8 characters")

// Combined rules
validator.validate("Test123!", rules: [
    .minLength(8),
    .containsUppercase,
    .containsLowercase,
    .containsNumber,
    .containsSpecialCharacter
]) // .valid
```

## Project Structure

```
iOSDevelopmentTools/
├── Sources/
│   ├── Extensions/
│   │   ├── String+Extensions.swift
│   │   ├── Date+Extensions.swift
│   │   ├── Collection+Extensions.swift
│   │   └── View+Extensions.swift
│   ├── Utilities/
│   │   ├── Debouncer.swift
│   │   ├── Throttler.swift
│   │   └── Validator.swift
│   ├── Storage/
│   │   ├── UserDefaultsWrapper.swift
│   │   └── KeychainHelper.swift
│   └── Debugging/
│       └── Logger.swift
├── Examples/
└── Tests/
```

## Requirements

- iOS 15.0+ / macOS 12.0+
- Xcode 15.0+
- Swift 5.9+

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT License. See [LICENSE](LICENSE).

## Author

**Muhittin Camdali** — [@muhittincamdali](https://github.com/muhittincamdali)

---

<p align="center">
  <sub>Tools every iOS developer needs ❤️</sub>
</p>
