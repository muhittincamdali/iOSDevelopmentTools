# Storage API

<!-- TOC START -->
## Table of Contents
- [Storage API](#storage-api)
- [Overview](#overview)
- [Core Components](#core-components)
  - [StorageManager](#storagemanager)
  - [StorageConfiguration](#storageconfiguration)
  - [StorageError](#storageerror)
- [File Storage](#file-storage)
  - [Basic File Operations](#basic-file-operations)
  - [File Types](#file-types)
  - [File Management](#file-management)
- [Database Storage](#database-storage)
  - [SQLite Database](#sqlite-database)
  - [Core Data Integration](#core-data-integration)
  - [Database Migrations](#database-migrations)
- [Cloud Storage](#cloud-storage)
  - [iCloud Integration](#icloud-integration)
  - [CloudKit Integration](#cloudkit-integration)
  - [Third-Party Cloud Services](#third-party-cloud-services)
- [Security Storage](#security-storage)
  - [Keychain Storage](#keychain-storage)
  - [Encrypted Storage](#encrypted-storage)
  - [Secure File Storage](#secure-file-storage)
- [Performance Storage](#performance-storage)
  - [Caching](#caching)
  - [Memory Storage](#memory-storage)
  - [Optimized Storage](#optimized-storage)
- [Storage Management](#storage-management)
  - [Storage Monitoring](#storage-monitoring)
  - [Storage Backup](#storage-backup)
  - [Storage Cleanup](#storage-cleanup)
- [Error Handling](#error-handling)
  - [Storage Error Handling](#storage-error-handling)
- [Usage Examples](#usage-examples)
  - [Basic Storage Setup](#basic-storage-setup)
  - [Secure Data Storage](#secure-data-storage)
  - [Cloud Storage Integration](#cloud-storage-integration)
- [Best Practices](#best-practices)
  - [Data Organization](#data-organization)
  - [Performance Optimization](#performance-optimization)
  - [Security Best Practices](#security-best-practices)
  - [Storage Strategy](#storage-strategy)
<!-- TOC END -->


## Overview

The Storage API provides comprehensive data storage capabilities for iOS applications, including file storage, database management, cloud storage integration, and secure data handling.

## Core Components

### StorageManager

Main storage manager class for handling all storage operations.

```swift
public class StorageManager {
    // MARK: - Properties
    private var configuration: StorageConfiguration
    private var fileManager: FileManager
    private var databaseManager: DatabaseManager?
    private var cloudManager: CloudStorageManager?
    
    // MARK: - Initialization
    public init(configuration: StorageConfiguration = StorageConfiguration())
    
    // MARK: - Configuration
    public func configure(_ configuration: StorageConfiguration)
    public func enableEncryption(_ enabled: Bool)
    
    // MARK: - File Operations
    public func saveToFile(_ data: Any, filename: String) throws
    public func loadFromFile(_ filename: String) -> Any?
    public func deleteFile(_ filename: String) throws
    public func fileExists(_ filename: String) -> Bool
    
    // MARK: - Database Operations
    public func saveToDatabase(_ data: Any, key: String) throws
    public func loadFromDatabase(_ key: String) -> Any?
    public func deleteFromDatabase(_ key: String) throws
    
    // MARK: - Cloud Storage
    public func saveToCloud(_ data: Any, filename: String, service: CloudService) throws
    public func loadFromCloud(_ filename: String, service: CloudService) -> Any?
    public func deleteFromCloud(_ filename: String, service: CloudService) throws
    
    // MARK: - Security
    public func saveToKeychain(_ data: String, forKey: String) throws
    public func loadFromKeychain(forKey: String) -> String?
    public func deleteFromKeychain(forKey: String) throws
}
```

### StorageConfiguration

Configuration class for storage settings.

```swift
public struct StorageConfiguration {
    // MARK: - Properties
    public var enableFileStorage: Bool
    public var enableDatabaseStorage: Bool
    public var enableCloudStorage: Bool
    public var enableEncryption: Bool
    public var maxFileSize: Int64
    public var compressionEnabled: Bool
    public var backupEnabled: Bool
    
    // MARK: - Initialization
    public init()
    
    // MARK: - Validation
    public func validate() -> Bool
}
```

### StorageError

Error types for storage operations.

```swift
public enum StorageError: Error {
    case fileNotFound
    case fileExists
    case invalidData
    case encryptionFailed
    case decryptionFailed
    case networkError(Error)
    case databaseError(Error)
    case keychainError(Error)
    case cloudServiceUnavailable
    case quotaExceeded
    case permissionDenied
}
```

## File Storage

### Basic File Operations

Perform basic file operations.

```swift
// Save data to file
let userData = ["name": "John Doe", "email": "john@example.com"]
try storageManager.saveToFile(userData, filename: "user_profile.json")

// Load data from file
if let loadedData = storageManager.loadFromFile("user_profile.json") {
    print("Loaded data: \(loadedData)")
}

// Check if file exists
let exists = storageManager.fileExists("user_profile.json")
print("File exists: \(exists)")

// Delete file
try storageManager.deleteFile("old_file.txt")
```

### File Types

Handle different file types.

```swift
// Save string
try storageManager.saveToFile("Hello World", filename: "greeting.txt")

// Save number
try storageManager.saveToFile(42, filename: "score.dat")

// Save array
let numbers = [1, 2, 3, 4, 5]
try storageManager.saveToFile(numbers, filename: "numbers.json")

// Save dictionary
let settings = ["theme": "dark", "notifications": true]
try storageManager.saveToFile(settings, filename: "settings.json")

// Save binary data
let imageData = UIImage(named: "profile")?.jpegData(compressionQuality: 0.8)
if let data = imageData {
    try storageManager.saveToFile(data, filename: "profile.jpg")
}
```

### File Management

Manage files and directories.

```swift
// Create directory
try storageManager.createDirectory("documents")

// List files in directory
let files = storageManager.listFiles(in: "documents")
print("Files: \(files)")

// Get file size
let fileSize = storageManager.getFileSize("document.pdf")
print("File size: \(fileSize) bytes")

// Get file modification date
let modificationDate = storageManager.getFileModificationDate("document.pdf")
print("Modified: \(modificationDate)")

// Copy file
try storageManager.copyFile(from: "source.txt", to: "destination.txt")

// Move file
try storageManager.moveFile(from: "old_location.txt", to: "new_location.txt")
```

## Database Storage

### SQLite Database

Use SQLite for structured data storage.

```swift
// Initialize database
let database = storageManager.createDatabase("app_data.db")

// Create table
let createTableSQL = """
CREATE TABLE users (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT UNIQUE,
    age INTEGER,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
)
"""
try database.executeSQL(createTableSQL)

// Insert data
let insertSQL = "INSERT INTO users (id, name, email, age) VALUES (?, ?, ?, ?)"
try database.executeSQL(insertSQL, parameters: ["user123", "John Doe", "john@example.com", 30])

// Query data
let querySQL = "SELECT * FROM users WHERE age > ?"
let results = try database.querySQL(querySQL, parameters: [25])
for row in results {
    print("User: \(row["name"] ?? "")")
}

// Update data
let updateSQL = "UPDATE users SET name = ? WHERE id = ?"
try database.executeSQL(updateSQL, parameters: ["John Smith", "user123"])

// Delete data
let deleteSQL = "DELETE FROM users WHERE id = ?"
try database.executeSQL(deleteSQL, parameters: ["user123"])
```

### Core Data Integration

Use Core Data for complex data models.

```swift
// Initialize Core Data stack
let coreDataStack = storageManager.createCoreDataStack(modelName: "AppModel")

// Create managed object context
let context = coreDataStack.managedObjectContext

// Create entity
let user = User(context: context)
user.id = "user123"
user.name = "John Doe"
user.email = "john@example.com"
user.createdAt = Date()

// Save context
do {
    try context.save()
    print("User saved successfully")
} catch {
    print("Error saving user: \(error)")
}

// Fetch data
let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
fetchRequest.predicate = NSPredicate(format: "name == %@", "John Doe")

do {
    let users = try context.fetch(fetchRequest)
    for user in users {
        print("Found user: \(user.name ?? "")")
    }
} catch {
    print("Error fetching users: \(error)")
}

// Delete entity
context.delete(user)
try context.save()
```

### Database Migrations

Handle database schema changes.

```swift
// Define migration
let migration = DatabaseMigration(
    fromVersion: 1,
    toVersion: 2,
    changes: [
        "ALTER TABLE users ADD COLUMN phone TEXT",
        "CREATE INDEX idx_users_email ON users(email)"
    ]
)

// Apply migration
try storageManager.applyMigration(migration, to: "app_data.db")

// Check database version
let currentVersion = storageManager.getDatabaseVersion("app_data.db")
print("Current database version: \(currentVersion)")

// Backup database
try storageManager.backupDatabase("app_data.db", to: "backup.db")

// Restore database
try storageManager.restoreDatabase(from: "backup.db", to: "app_data.db")
```

## Cloud Storage

### iCloud Integration

Store data in iCloud.

```swift
// Configure iCloud
let iCloudConfig = CloudStorageConfiguration()
iCloudConfig.enableiCloud = true
iCloudConfig.containerIdentifier = "iCloud.com.yourapp"

storageManager.configureCloudStorage(iCloudConfig)

// Save to iCloud
let userData = ["name": "John Doe", "email": "john@example.com"]
try storageManager.saveToCloud(userData, filename: "user_profile.json", service: .iCloud)

// Load from iCloud
if let cloudData = storageManager.loadFromCloud("user_profile.json", service: .iCloud) {
    print("Loaded from iCloud: \(cloudData)")
}

// Delete from iCloud
try storageManager.deleteFromCloud("user_profile.json", service: .iCloud)

// Sync with iCloud
storageManager.syncWithCloud(service: .iCloud) { result in
    switch result {
    case .success(let syncedFiles):
        print("Synced \(syncedFiles.count) files")
    case .failure(let error):
        print("Sync error: \(error)")
    }
}
```

### CloudKit Integration

Use CloudKit for advanced cloud storage.

```swift
// Configure CloudKit
let cloudKitConfig = CloudKitConfiguration()
cloudKitConfig.containerIdentifier = "iCloud.com.yourapp"
cloudKitConfig.enablePrivateDatabase = true
cloudKitConfig.enablePublicDatabase = true

storageManager.configureCloudKit(cloudKitConfig)

// Save record to CloudKit
let record = CKRecord(recordType: "User")
record["name"] = "John Doe"
record["email"] = "john@example.com"

storageManager.saveToCloudKit(record) { result in
    switch result {
    case .success(let savedRecord):
        print("Saved record: \(savedRecord.recordID)")
    case .failure(let error):
        print("Save error: \(error)")
    }
}

// Query CloudKit records
let query = CKQuery(recordType: "User", predicate: NSPredicate(value: true))
storageManager.queryCloudKit(query) { result in
    switch result {
    case .success(let records):
        print("Found \(records.count) users")
    case .failure(let error):
        print("Query error: \(error)")
    }
}

// Delete record from CloudKit
storageManager.deleteFromCloudKit(recordID) { result in
    switch result {
    case .success:
        print("Record deleted successfully")
    case .failure(let error):
        print("Delete error: \(error)")
    }
}
```

### Third-Party Cloud Services

Integrate with third-party cloud services.

```swift
// Configure AWS S3
let s3Config = S3Configuration()
s3Config.accessKey = "your-access-key"
s3Config.secretKey = "your-secret-key"
s3Config.bucketName = "your-bucket"
s3Config.region = "us-east-1"

storageManager.configureS3(s3Config)

// Upload to S3
let fileData = "Hello S3".data(using: .utf8)!
storageManager.uploadToS3(fileData, key: "test.txt") { result in
    switch result {
    case .success(let url):
        print("Uploaded to: \(url)")
    case .failure(let error):
        print("Upload error: \(error)")
    }
}

// Download from S3
storageManager.downloadFromS3(key: "test.txt") { result in
    switch result {
    case .success(let data):
        let content = String(data: data, encoding: .utf8)
        print("Downloaded: \(content ?? "")")
    case .failure(let error):
        print("Download error: \(error)")
    }
}

// Delete from S3
storageManager.deleteFromS3(key: "test.txt") { result in
    switch result {
    case .success:
        print("File deleted from S3")
    case .failure(let error):
        print("Delete error: \(error)")
    }
}
```

## Security Storage

### Keychain Storage

Store sensitive data in Keychain.

```swift
// Save to Keychain
try storageManager.saveToKeychain("secret_token", forKey: "auth_token")
try storageManager.saveToKeychain("user_password", forKey: "user_password")

// Load from Keychain
if let token = storageManager.loadFromKeychain(forKey: "auth_token") {
    print("Auth token: \(token)")
}

// Delete from Keychain
try storageManager.deleteFromKeychain(forKey: "old_token")

// Check if key exists
let exists = storageManager.keychainKeyExists("auth_token")
print("Key exists: \(exists)")

// Update keychain item
try storageManager.updateKeychainItem("new_token", forKey: "auth_token")
```

### Encrypted Storage

Store encrypted data.

```swift
// Configure encryption
let encryptionConfig = EncryptionConfiguration()
encryptionConfig.algorithm = .aes256
encryptionConfig.keySize = 256
encryptionConfig.enableKeyDerivation = true

storageManager.configureEncryption(encryptionConfig)

// Save encrypted data
let sensitiveData = "sensitive information"
try storageManager.saveEncryptedData(sensitiveData, filename: "secure_data.enc")

// Load encrypted data
if let decryptedData = storageManager.loadEncryptedData("secure_data.enc") {
    print("Decrypted data: \(decryptedData)")
}

// Change encryption key
storageManager.rotateEncryptionKey { result in
    switch result {
    case .success:
        print("Encryption key rotated successfully")
    case .failure(let error):
        print("Key rotation error: \(error)")
    }
}

// Check encryption status
let isEncrypted = storageManager.isFileEncrypted("secure_data.enc")
print("File is encrypted: \(isEncrypted)")
```

### Secure File Storage

Store files securely.

```swift
// Configure secure storage
let secureConfig = SecureStorageConfiguration()
secureConfig.enableFileEncryption = true
secureConfig.enableAccessControl = true
secureConfig.requireBiometricAuth = true

storageManager.configureSecureStorage(secureConfig)

// Save secure file
let secureData = "confidential information"
try storageManager.saveSecureFile(secureData, filename: "confidential.txt")

// Load secure file
storageManager.loadSecureFile("confidential.txt") { result in
    switch result {
    case .success(let data):
        print("Secure data: \(data)")
    case .failure(let error):
        print("Secure load error: \(error)")
    }
}

// Check secure storage status
let isSecure = storageManager.isSecureStorageEnabled()
print("Secure storage enabled: \(isSecure)")
```

## Performance Storage

### Caching

Implement caching for performance.

```swift
// Configure cache
let cacheConfig = CacheConfiguration()
cacheConfig.maxMemorySize = 100 * 1024 * 1024 // 100MB
cacheConfig.maxDiskSize = 500 * 1024 * 1024 // 500MB
cacheConfig.defaultExpiration = 3600 // 1 hour

storageManager.configureCache(cacheConfig)

// Cache data
storageManager.cacheData("cached_value", forKey: "cache_key")

// Retrieve cached data
if let cachedData = storageManager.getCachedData(forKey: "cache_key") {
    print("Cached data: \(cachedData)")
}

// Clear cache
storageManager.clearCache()

// Get cache statistics
let stats = storageManager.getCacheStatistics()
print("Cache hits: \(stats.hits)")
print("Cache misses: \(stats.misses)")
print("Cache size: \(stats.currentSize)")

// Set cache expiration
storageManager.setCacheExpiration(7200, forKey: "long_lived_cache")
```

### Memory Storage

Use memory storage for fast access.

```swift
// Configure memory storage
let memoryConfig = MemoryStorageConfiguration()
memoryConfig.maxSize = 50 * 1024 * 1024 // 50MB
memoryConfig.enableLRU = true

storageManager.configureMemoryStorage(memoryConfig)

// Store in memory
storageManager.storeInMemory("fast_data", forKey: "memory_key")

// Retrieve from memory
if let memoryData = storageManager.getFromMemory(forKey: "memory_key") {
    print("Memory data: \(memoryData)")
}

// Clear memory
storageManager.clearMemory()

// Get memory usage
let usage = storageManager.getMemoryUsage()
print("Memory used: \(usage.used)")
print("Memory available: \(usage.available)")

// Check memory pressure
let pressure = storageManager.getMemoryPressure()
print("Memory pressure: \(pressure)")
```

### Optimized Storage

Optimize storage performance.

```swift
// Configure optimization
let optimizationConfig = StorageOptimizationConfiguration()
optimizationConfig.enableCompression = true
optimizationConfig.enableDeduplication = true
optimizationConfig.enableIndexing = true

storageManager.configureOptimization(optimizationConfig)

// Optimize storage
storageManager.optimizeStorage { result in
    switch result {
    case .success(let optimization):
        print("Space saved: \(optimization.spaceSaved)")
        print("Files optimized: \(optimization.filesOptimized)")
    case .failure(let error):
        print("Optimization error: \(error)")
    }
}

// Get storage statistics
let stats = storageManager.getStorageStatistics()
print("Total space: \(stats.totalSpace)")
print("Used space: \(stats.usedSpace)")
print("Free space: \(stats.freeSpace)")

// Clean up old files
storageManager.cleanupOldFiles(olderThan: 30 * 24 * 60 * 60) // 30 days
```

## Storage Management

### Storage Monitoring

Monitor storage usage.

```swift
// Start monitoring
storageManager.startStorageMonitoring()

// Set up monitoring callbacks
storageManager.onStorageThresholdReached = { threshold in
    print("Storage threshold reached: \(threshold)%")
}

storageManager.onStorageSpaceLow = { availableSpace in
    print("Low storage space: \(availableSpace) bytes available")
}

// Get current usage
let usage = storageManager.getCurrentStorageUsage()
print("Usage: \(usage.percentage)%")
print("Available: \(usage.availableSpace) bytes")

// Get storage breakdown
let breakdown = storageManager.getStorageBreakdown()
print("Documents: \(breakdown.documents)")
print("Cache: \(breakdown.cache)")
print("Temporary: \(breakdown.temporary)")
```

### Storage Backup

Backup storage data.

```swift
// Create backup
storageManager.createBackup { result in
    switch result {
    case .success(let backup):
        print("Backup created: \(backup.path)")
        print("Backup size: \(backup.size)")
    case .failure(let error):
        print("Backup error: \(error)")
    }
}

// Restore from backup
storageManager.restoreFromBackup("backup_2024_01_01.zip") { result in
    switch result {
    case .success:
        print("Restore completed successfully")
    case .failure(let error):
        print("Restore error: \(error)")
    }
}

// List backups
let backups = storageManager.listBackups()
for backup in backups {
    print("Backup: \(backup.name) - \(backup.date)")
}

// Delete old backups
storageManager.cleanupOldBackups(olderThan: 7 * 24 * 60 * 60) // 7 days
```

### Storage Cleanup

Clean up storage.

```swift
// Clean up old files
storageManager.cleanupOldFiles(olderThan: 30 * 24 * 60 * 60) // 30 days

// Clean up temporary files
storageManager.cleanupTemporaryFiles()

// Clean up cache
storageManager.cleanupCache()

// Get cleanup statistics
let cleanupStats = storageManager.getCleanupStatistics()
print("Files removed: \(cleanupStats.filesRemoved)")
print("Space freed: \(cleanupStats.spaceFreed)")

// Validate storage integrity
storageManager.validateStorageIntegrity { result in
    switch result {
    case .success(let integrity):
        print("Storage integrity: \(integrity)")
    case .failure(let error):
        print("Integrity check error: \(error)")
    }
}
```

## Error Handling

### Storage Error Handling

Handle storage errors gracefully.

```swift
// Handle file operations
do {
    try storageManager.saveToFile(data, filename: "test.txt")
} catch StorageError.fileExists {
    print("File already exists")
} catch StorageError.invalidData {
    print("Invalid data format")
} catch StorageError.encryptionFailed {
    print("Encryption failed")
} catch {
    print("Unknown storage error: \(error)")
}

// Handle database operations
do {
    try storageManager.saveToDatabase(data, key: "user_data")
} catch StorageError.databaseError(let error) {
    print("Database error: \(error)")
} catch {
    print("Unknown database error: \(error)")
}

// Handle cloud operations
do {
    try storageManager.saveToCloud(data, filename: "cloud_file.txt", service: .iCloud)
} catch StorageError.cloudServiceUnavailable {
    print("Cloud service unavailable")
} catch StorageError.networkError(let error) {
    print("Network error: \(error)")
} catch {
    print("Unknown cloud error: \(error)")
}
```

## Usage Examples

### Basic Storage Setup

Set up storage for your app.

```swift
import iOSDevelopmentTools

// Initialize storage
let storageManager = StorageManager()

// Configure storage
let config = StorageConfiguration()
config.enableFileStorage = true
config.enableDatabaseStorage = true
config.enableCloudStorage = true
config.enableEncryption = true
config.maxFileSize = 100 * 1024 * 1024 // 100MB

storageManager.configure(config)

// Save user data
let userData = ["name": "John Doe", "email": "john@example.com"]
try storageManager.saveToFile(userData, filename: "user_profile.json")
```

### Secure Data Storage

Store sensitive data securely.

```swift
// Store authentication token
try storageManager.saveToKeychain("auth_token_123", forKey: "auth_token")

// Store encrypted user data
let sensitiveData = ["ssn": "123-45-6789", "credit_card": "4111-1111-1111-1111"]
try storageManager.saveEncryptedData(sensitiveData, filename: "secure_user_data.enc")

// Store in secure file
try storageManager.saveSecureFile("confidential_document", filename: "document.txt")
```

### Cloud Storage Integration

Integrate with cloud storage.

```swift
// Save to iCloud
let userData = ["name": "John Doe", "email": "john@example.com"]
try storageManager.saveToCloud(userData, filename: "user_profile.json", service: .iCloud)

// Save to CloudKit
let record = CKRecord(recordType: "User")
record["name"] = "John Doe"
record["email"] = "john@example.com"

storageManager.saveToCloudKit(record) { result in
    switch result {
    case .success(let savedRecord):
        print("Saved to CloudKit: \(savedRecord.recordID)")
    case .failure(let error):
        print("CloudKit save error: \(error)")
    }
}
```

## Best Practices

### Data Organization

1. **Logical Structure**: Organize data in logical folders
2. **Naming Conventions**: Use consistent naming conventions
3. **Version Control**: Implement version control for important data
4. **Backup Strategy**: Regular backups of critical data

### Performance Optimization

1. **Caching**: Use caching for frequently accessed data
2. **Compression**: Compress large files to save space
3. **Lazy Loading**: Load data only when needed
4. **Background Processing**: Process data in background

### Security Best Practices

1. **Encryption**: Encrypt sensitive data
2. **Access Control**: Implement proper access controls
3. **Key Management**: Secure key management
4. **Data Minimization**: Store only necessary data

### Storage Strategy

1. **Storage Types**: Choose appropriate storage types
2. **Data Lifecycle**: Implement data lifecycle management
3. **Monitoring**: Monitor storage usage
4. **Cleanup**: Regular cleanup of old data 