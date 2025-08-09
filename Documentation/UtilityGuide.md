# Utility Guide

<!-- TOC START -->
## Table of Contents
- [Utility Guide](#utility-guide)
- [Introduction](#introduction)
- [Table of Contents](#table-of-contents)
- [Getting Started with Utilities](#getting-started-with-utilities)
  - [Prerequisites](#prerequisites)
  - [Basic Setup](#basic-setup)
  - [Utility Types](#utility-types)
- [Basic Utilities](#basic-utilities)
  - [Common Helper Functions](#common-helper-functions)
  - [Array Utilities](#array-utilities)
  - [Dictionary Utilities](#dictionary-utilities)
- [Advanced Utilities](#advanced-utilities)
  - [Data Transformation](#data-transformation)
  - [Encoding Utilities](#encoding-utilities)
  - [Compression Utilities](#compression-utilities)
- [String Utilities](#string-utilities)
  - [String Manipulation](#string-manipulation)
  - [String Formatting](#string-formatting)
  - [String Validation](#string-validation)
- [Date Utilities](#date-utilities)
  - [Date Creation and Manipulation](#date-creation-and-manipulation)
  - [Date Formatting](#date-formatting)
  - [Date Calculations](#date-calculations)
- [File Utilities](#file-utilities)
  - [File Operations](#file-operations)
  - [Directory Operations](#directory-operations)
  - [File Validation](#file-validation)
- [Device Utilities](#device-utilities)
  - [Device Information](#device-information)
  - [Device Capabilities](#device-capabilities)
  - [Network Information](#network-information)
- [Validation Utilities](#validation-utilities)
  - [Data Validation](#data-validation)
  - [Input Sanitization](#input-sanitization)
  - [Format Validation](#format-validation)
- [Best Practices](#best-practices)
  - [Performance Optimization](#performance-optimization)
  - [Error Handling](#error-handling)
  - [Security Best Practices](#security-best-practices)
  - [Utility Strategy](#utility-strategy)
- [Troubleshooting](#troubleshooting)
  - [Common Issues](#common-issues)
  - [Debugging Utilities](#debugging-utilities)
  - [Getting Help](#getting-help)
<!-- TOC END -->


## Introduction

This comprehensive utility guide covers all aspects of utility functions in iOS applications using the iOS Development Tools framework. From basic utility functions to advanced helper classes and common iOS development utilities, this guide provides everything you need to implement effective utility strategies.

## Table of Contents

1. [Getting Started with Utilities](#getting-started-with-utilities)
2. [Basic Utilities](#basic-utilities)
3. [Advanced Utilities](#advanced-utilities)
4. [String Utilities](#string-utilities)
5. [Date Utilities](#date-utilities)
6. [File Utilities](#file-utilities)
7. [Device Utilities](#device-utilities)
8. [Validation Utilities](#validation-utilities)
9. [Best Practices](#best-practices)
10. [Troubleshooting](#troubleshooting)

## Getting Started with Utilities

### Prerequisites

Before you begin implementing utilities, ensure you have:

- Xcode 15.0 or later
- iOS 15.0+ SDK
- Swift 5.9+
- iOS Development Tools framework installed

### Basic Setup

```swift
import iOSDevelopmentTools

// Initialize utility manager
let utilityManager = UtilityManager()

// Configure utilities
let config = UtilityConfiguration()
config.enableStringUtilities = true
config.enableDateUtilities = true
config.enableFileUtilities = true

// Start utility manager
utilityManager.configure(config)
```

### Utility Types

Understanding different types of utilities:

- **String Utilities**: String manipulation and formatting
- **Date Utilities**: Date and time operations
- **File Utilities**: File system operations
- **Device Utilities**: Device information and capabilities
- **Validation Utilities**: Data validation and sanitization

## Basic Utilities

### Common Helper Functions

Use common helper functions:

```swift
let utilityManager = UtilityManager()

// Generate random string
let randomString = utilityManager.generateRandomString(length: 10)
print("Random string: \(randomString)")

// Generate UUID
let uuid = utilityManager.generateUUID()
print("UUID: \(uuid)")

// Check if string is empty or whitespace
let isEmpty = utilityManager.isStringEmpty("   ")
print("Is empty: \(isEmpty)")

// Capitalize first letter
let capitalized = utilityManager.capitalizeFirstLetter("hello world")
print("Capitalized: \(capitalized)")

// Truncate string
let truncated = utilityManager.truncateString("This is a very long string", maxLength: 10)
print("Truncated: \(truncated)")
```

### Array Utilities

Work with arrays efficiently:

```swift
let utilityManager = UtilityManager()

// Remove duplicates from array
let numbers = [1, 2, 2, 3, 3, 4, 5]
let uniqueNumbers = utilityManager.removeDuplicates(from: numbers)
print("Unique numbers: \(uniqueNumbers)")

// Shuffle array
let shuffledNumbers = utilityManager.shuffleArray(numbers)
print("Shuffled: \(shuffledNumbers)")

// Chunk array into smaller arrays
let largeArray = Array(1...100)
let chunks = utilityManager.chunkArray(largeArray, size: 10)
print("Number of chunks: \(chunks.count)")

// Find common elements
let array1 = [1, 2, 3, 4, 5]
let array2 = [4, 5, 6, 7, 8]
let commonElements = utilityManager.findCommonElements(array1, array2)
print("Common elements: \(commonElements)")
```

### Dictionary Utilities

Work with dictionaries:

```swift
let utilityManager = UtilityManager()

// Merge dictionaries
let dict1 = ["a": 1, "b": 2]
let dict2 = ["c": 3, "d": 4]
let merged = utilityManager.mergeDictionaries(dict1, dict2)
print("Merged: \(merged)")

// Filter dictionary by value
let scores = ["Alice": 85, "Bob": 92, "Charlie": 78, "David": 95]
let highScores = utilityManager.filterDictionary(scores) { $0.value > 80 }
print("High scores: \(highScores)")

// Sort dictionary by value
let sortedScores = utilityManager.sortDictionary(scores, by: { $0.value > $1.value })
print("Sorted scores: \(sortedScores)")

// Get dictionary keys as array
let keys = utilityManager.getDictionaryKeys(scores)
print("Keys: \(keys)")
```

## Advanced Utilities

### Data Transformation

Transform data between formats:

```swift
let utilityManager = UtilityManager()

// Convert data to different formats
let jsonData = ["name": "John", "age": 30]

// Convert to JSON string
let jsonString = utilityManager.toJSONString(jsonData)
print("JSON string: \(jsonString)")

// Convert from JSON string
let parsedData = utilityManager.fromJSONString(jsonString)
print("Parsed data: \(parsedData)")

// Convert to base64
let base64String = utilityManager.toBase64("Hello World")
print("Base64: \(base64String)")

// Convert from base64
let decodedString = utilityManager.fromBase64(base64String)
print("Decoded: \(decodedString)")
```

### Encoding Utilities

Handle different encodings:

```swift
let utilityManager = UtilityManager()

// URL encoding
let urlString = "Hello World & More"
let encodedURL = utilityManager.urlEncode(urlString)
print("URL encoded: \(encodedURL)")

// URL decoding
let decodedURL = utilityManager.urlDecode(encodedURL)
print("URL decoded: \(decodedURL)")

// HTML encoding
let htmlString = "<p>Hello & World</p>"
let encodedHTML = utilityManager.htmlEncode(htmlString)
print("HTML encoded: \(encodedHTML)")

// HTML decoding
let decodedHTML = utilityManager.htmlDecode(encodedHTML)
print("HTML decoded: \(decodedHTML)")
```

### Compression Utilities

Compress and decompress data:

```swift
let utilityManager = UtilityManager()

// Compress data
let originalData = "This is a very long string that needs to be compressed".data(using: .utf8)!
let compressedData = utilityManager.compressData(originalData)
print("Original size: \(originalData.count)")
print("Compressed size: \(compressedData.count)")

// Decompress data
let decompressedData = utilityManager.decompressData(compressedData)
let decompressedString = String(data: decompressedData, encoding: .utf8)
print("Decompressed: \(decompressedString)")

// Check compression ratio
let ratio = utilityManager.getCompressionRatio(originalData, compressedData)
print("Compression ratio: \(ratio)")
```

## String Utilities

### String Manipulation

Manipulate strings effectively:

```swift
let utilityManager = UtilityManager()

// Reverse string
let reversed = utilityManager.reverseString("Hello World")
print("Reversed: \(reversed)")

// Count words
let wordCount = utilityManager.countWords("This is a sample sentence")
print("Word count: \(wordCount)")

// Extract numbers from string
let numbers = utilityManager.extractNumbers("Price: $123.45")
print("Numbers: \(numbers)")

// Check if string contains only letters
let isLettersOnly = utilityManager.isLettersOnly("HelloWorld")
print("Letters only: \(isLettersOnly)")

// Check if string contains only numbers
let isNumbersOnly = utilityManager.isNumbersOnly("12345")
print("Numbers only: \(isNumbersOnly)")
```

### String Formatting

Format strings for different purposes:

```swift
let utilityManager = UtilityManager()

// Format phone number
let phoneNumber = "1234567890"
let formattedPhone = utilityManager.formatPhoneNumber(phoneNumber)
print("Formatted phone: \(formattedPhone)")

// Format credit card number
let cardNumber = "1234567890123456"
let formattedCard = utilityManager.formatCreditCardNumber(cardNumber)
print("Formatted card: \(formattedCard)")

// Format currency
let amount = 1234.56
let formattedCurrency = utilityManager.formatCurrency(amount, currency: "USD")
print("Formatted currency: \(formattedCurrency)")

// Format file size
let fileSize = 1024 * 1024 * 5 // 5MB
let formattedSize = utilityManager.formatFileSize(fileSize)
print("Formatted size: \(formattedSize)")
```

### String Validation

Validate string content:

```swift
let utilityManager = UtilityManager()

// Validate email
let email = "user@example.com"
let isValidEmail = utilityManager.isValidEmail(email)
print("Valid email: \(isValidEmail)")

// Validate URL
let url = "https://example.com"
let isValidURL = utilityManager.isValidURL(url)
print("Valid URL: \(isValidURL)")

// Validate password strength
let password = "MyPassword123!"
let strength = utilityManager.getPasswordStrength(password)
print("Password strength: \(strength)")

// Validate phone number
let phone = "+1-555-123-4567"
let isValidPhone = utilityManager.isValidPhoneNumber(phone)
print("Valid phone: \(isValidPhone)")
```

## Date Utilities

### Date Creation and Manipulation

Work with dates effectively:

```swift
let utilityManager = UtilityManager()

// Create date from components
let date = utilityManager.createDate(year: 2024, month: 1, day: 15)
print("Created date: \(date)")

// Get date components
let components = utilityManager.getDateComponents(date)
print("Year: \(components.year)")
print("Month: \(components.month)")
print("Day: \(components.day)")

// Add time to date
let futureDate = utilityManager.addDays(7, to: date)
print("Future date: \(futureDate)")

// Calculate difference between dates
let difference = utilityManager.daysBetween(date, and: futureDate)
print("Days difference: \(difference)")
```

### Date Formatting

Format dates for different purposes:

```swift
let utilityManager = UtilityManager()

let date = Date()

// Format for display
let displayFormat = utilityManager.formatDate(date, format: "MMM dd, yyyy")
print("Display format: \(displayFormat)")

// Format for API
let apiFormat = utilityManager.formatDate(date, format: "yyyy-MM-dd'T'HH:mm:ss'Z'")
print("API format: \(apiFormat)")

// Format relative time
let relativeTime = utilityManager.formatRelativeTime(date)
print("Relative time: \(relativeTime)")

// Format time ago
let timeAgo = utilityManager.formatTimeAgo(date)
print("Time ago: \(timeAgo)")
```

### Date Calculations

Perform date calculations:

```swift
let utilityManager = UtilityManager()

let date = Date()

// Check if date is today
let isToday = utilityManager.isToday(date)
print("Is today: \(isToday)")

// Check if date is this week
let isThisWeek = utilityManager.isThisWeek(date)
print("Is this week: \(isThisWeek)")

// Check if date is this month
let isThisMonth = utilityManager.isThisMonth(date)
print("Is this month: \(isThisMonth)")

// Get start of week
let startOfWeek = utilityManager.startOfWeek(date)
print("Start of week: \(startOfWeek)")

// Get end of month
let endOfMonth = utilityManager.endOfMonth(date)
print("End of month: \(endOfMonth)")
```

## File Utilities

### File Operations

Perform file operations:

```swift
let utilityManager = UtilityManager()

// Get file size
let fileSize = utilityManager.getFileSize("document.pdf")
print("File size: \(fileSize) bytes")

// Get file extension
let extension = utilityManager.getFileExtension("document.pdf")
print("File extension: \(extension)")

// Get file name without extension
let fileName = utilityManager.getFileNameWithoutExtension("document.pdf")
print("File name: \(fileName)")

// Check if file exists
let exists = utilityManager.fileExists("document.pdf")
print("File exists: \(exists)")

// Get file creation date
let creationDate = utilityManager.getFileCreationDate("document.pdf")
print("Creation date: \(creationDate)")
```

### Directory Operations

Work with directories:

```swift
let utilityManager = UtilityManager()

// Create directory
utilityManager.createDirectory("documents")

// List files in directory
let files = utilityManager.listFiles(in: "documents")
print("Files: \(files)")

// Get directory size
let dirSize = utilityManager.getDirectorySize("documents")
print("Directory size: \(dirSize) bytes")

// Clean up empty directories
utilityManager.cleanupEmptyDirectories()

// Get temporary directory
let tempDir = utilityManager.getTemporaryDirectory()
print("Temp directory: \(tempDir)")
```

### File Validation

Validate files:

```swift
let utilityManager = UtilityManager()

// Check file type
let fileType = utilityManager.getFileType("image.jpg")
print("File type: \(fileType)")

// Validate file size
let isValidSize = utilityManager.isValidFileSize("large_file.pdf", maxSize: 10 * 1024 * 1024)
print("Valid size: \(isValidSize)")

// Check if file is image
let isImage = utilityManager.isImageFile("photo.png")
print("Is image: \(isImage)")

// Check if file is video
let isVideo = utilityManager.isVideoFile("movie.mp4")
print("Is video: \(isVideo)")
```

## Device Utilities

### Device Information

Get device information:

```swift
let utilityManager = UtilityManager()

// Get device model
let deviceModel = utilityManager.getDeviceModel()
print("Device model: \(deviceModel)")

// Get iOS version
let iosVersion = utilityManager.getIOSVersion()
print("iOS version: \(iosVersion)")

// Get app version
let appVersion = utilityManager.getAppVersion()
print("App version: \(appVersion)")

// Get device identifier
let deviceId = utilityManager.getDeviceIdentifier()
print("Device ID: \(deviceId)")

// Get device orientation
let orientation = utilityManager.getDeviceOrientation()
print("Orientation: \(orientation)")
```

### Device Capabilities

Check device capabilities:

```swift
let utilityManager = UtilityManager()

// Check if device has camera
let hasCamera = utilityManager.hasCamera()
print("Has camera: \(hasCamera)")

// Check if device has fingerprint sensor
let hasTouchID = utilityManager.hasTouchID()
print("Has Touch ID: \(hasTouchID)")

// Check if device has Face ID
let hasFaceID = utilityManager.hasFaceID()
print("Has Face ID: \(hasFaceID)")

// Check if device supports haptic feedback
let supportsHaptics = utilityManager.supportsHapticFeedback()
print("Supports haptics: \(supportsHaptics)")

// Get available memory
let availableMemory = utilityManager.getAvailableMemory()
print("Available memory: \(availableMemory) MB")
```

### Network Information

Get network information:

```swift
let utilityManager = UtilityManager()

// Get network type
let networkType = utilityManager.getNetworkType()
print("Network type: \(networkType)")

// Check if connected to WiFi
let isConnectedToWiFi = utilityManager.isConnectedToWiFi()
print("Connected to WiFi: \(isConnectedToWiFi)")

// Get carrier information
let carrierInfo = utilityManager.getCarrierInformation()
print("Carrier: \(carrierInfo)")

// Check if connected to cellular
let isConnectedToCellular = utilityManager.isConnectedToCellular()
print("Connected to cellular: \(isConnectedToCellular)")
```

## Validation Utilities

### Data Validation

Validate different types of data:

```swift
let utilityManager = UtilityManager()

// Validate email
let email = "user@example.com"
let isValidEmail = utilityManager.validateEmail(email)
print("Valid email: \(isValidEmail)")

// Validate phone number
let phone = "+1-555-123-4567"
let isValidPhone = utilityManager.validatePhoneNumber(phone)
print("Valid phone: \(isValidPhone)")

// Validate credit card
let cardNumber = "4111111111111111"
let isValidCard = utilityManager.validateCreditCard(cardNumber)
print("Valid card: \(isValidCard)")

// Validate postal code
let postalCode = "12345"
let isValidPostal = utilityManager.validatePostalCode(postalCode)
print("Valid postal code: \(isValidPostal)")
```

### Input Sanitization

Sanitize user input:

```swift
let utilityManager = UtilityManager()

// Sanitize HTML
let htmlInput = "<script>alert('xss')</script><p>Hello</p>"
let sanitizedHTML = utilityManager.sanitizeHTML(htmlInput)
print("Sanitized HTML: \(sanitizedHTML)")

// Sanitize SQL
let sqlInput = "'; DROP TABLE users; --"
let sanitizedSQL = utilityManager.sanitizeSQL(sqlInput)
print("Sanitized SQL: \(sanitizedSQL)")

// Sanitize file name
let fileName = "file/with\\invalid:chars"
let sanitizedFileName = utilityManager.sanitizeFileName(fileName)
print("Sanitized file name: \(sanitizedFileName)")

// Sanitize URL
let urlInput = "javascript:alert('xss')"
let sanitizedURL = utilityManager.sanitizeURL(urlInput)
print("Sanitized URL: \(sanitizedURL)")
```

### Format Validation

Validate data formats:

```swift
let utilityManager = UtilityManager()

// Validate JSON
let jsonString = "{\"name\": \"John\", \"age\": 30}"
let isValidJSON = utilityManager.validateJSON(jsonString)
print("Valid JSON: \(isValidJSON)")

// Validate XML
let xmlString = "<root><item>value</item></root>"
let isValidXML = utilityManager.validateXML(xmlString)
print("Valid XML: \(isValidXML)")

// Validate base64
let base64String = "SGVsbG8gV29ybGQ="
let isValidBase64 = utilityManager.validateBase64(base64String)
print("Valid base64: \(isValidBase64)")

// Validate UUID
let uuid = "123e4567-e89b-12d3-a456-426614174000"
let isValidUUID = utilityManager.validateUUID(uuid)
print("Valid UUID: \(isValidUUID)")
```

## Best Practices

### Performance Optimization

1. **Caching**: Cache frequently used utility results
2. **Lazy Loading**: Load utilities only when needed
3. **Memory Management**: Properly manage memory for large operations
4. **Background Processing**: Use background queues for heavy operations

### Error Handling

1. **Graceful Degradation**: Handle utility failures gracefully
2. **Input Validation**: Always validate input before processing
3. **Error Logging**: Log utility errors for debugging
4. **Fallback Options**: Provide fallback options when utilities fail

### Security Best Practices

1. **Input Sanitization**: Always sanitize user input
2. **Secure Storage**: Store sensitive data securely
3. **Validation**: Validate all data before processing
4. **Access Control**: Implement proper access controls

### Utility Strategy

1. **Modular Design**: Create modular utility functions
2. **Reusability**: Make utilities reusable across the app
3. **Documentation**: Document all utility functions
4. **Testing**: Test all utility functions thoroughly

## Troubleshooting

### Common Issues

1. **Memory Leaks**: Check for memory leaks in utility functions
2. **Performance Issues**: Optimize slow utility functions
3. **Thread Safety**: Ensure utilities are thread-safe
4. **Compatibility Issues**: Check iOS version compatibility

### Debugging Utilities

```swift
let utilityManager = UtilityManager()

// Enable debug mode
utilityManager.enableDebugMode()

// Check utility status
let status = utilityManager.getUtilityStatus()
print("Utility Status: \(status)")

// Get utility logs
let logs = utilityManager.getUtilityLogs()
for log in logs {
    print("Utility: \(log.name) - Status: \(log.status) - Time: \(log.duration)ms")
}
```

### Getting Help

- Check the [API Documentation](UtilityAPI.md) for detailed information
- Review [Best Practices Guide](BestPracticesGuide.md) for utility guidelines
- Consult the [Troubleshooting Guide](TroubleshootingGuide.md) for common issues
- Join our community for support and discussions 