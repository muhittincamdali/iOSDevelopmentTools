# 💾 Storage Guide

Complete storage utilities documentation for iOS Development Tools.

## 📋 Table of Contents

- [UserDefaults Storage](#userdefaults-storage)
- [Keychain Storage](#keychain-storage)
- [File Storage](#file-storage)
- [Core Data](#core-data)
- [Data Encryption](#data-encryption)

## 💾 UserDefaults Storage

### **Basic Usage**
```swift
let storage = UserDefaultsStorage()

// Save data
try storage.save("value", forKey: "key")

// Retrieve data
let value = try storage.retrieve(String.self, forKey: "key")

// Remove data
try storage.remove(forKey: "key")
```

### **Advanced Usage**
```swift
class UserDefaultsManager {
    private let storage: UserDefaultsStorage
    
    init() {
        self.storage = UserDefaultsStorage()
    }
    
    // Save user preferences
    func saveUserPreferences(_ preferences: UserPreferences) throws {
        try storage.save(preferences, forKey: "user_preferences")
    }
    
    // Load user preferences
    func loadUserPreferences() throws -> UserPreferences? {
        return try storage.retrieve(UserPreferences.self, forKey: "user_preferences")
    }
    
    // Save app settings
    func saveAppSettings(_ settings: AppSettings) throws {
        try storage.save(settings, forKey: "app_settings")
    }
    
    // Load app settings
    func loadAppSettings() throws -> AppSettings? {
        return try storage.retrieve(AppSettings.self, forKey: "app_settings")
    }
}
```

## 🔐 Keychain Storage

### **Secure Storage**
```swift
let keychain = KeychainStorage()

// Save sensitive data
try keychain.save("secret_token", forKey: "auth_token")

// Retrieve sensitive data
let token = try keychain.retrieve(String.self, forKey: "auth_token")

// Remove sensitive data
try keychain.remove(forKey: "auth_token")
```

### **Keychain Manager**
```swift
class KeychainManager {
    private let keychain: KeychainStorage
    
    init() {
        self.keychain = KeychainStorage()
    }
    
    // Save authentication token
    func saveAuthToken(_ token: String) throws {
        try keychain.save(token, forKey: "auth_token")
    }
    
    // Get authentication token
    func getAuthToken() throws -> String? {
        return try keychain.retrieve(String.self, forKey: "auth_token")
    }
    
    // Save user credentials
    func saveCredentials(username: String, password: String) throws {
        try keychain.save(username, forKey: "username")
        try keychain.save(password, forKey: "password")
    }
    
    // Get user credentials
    func getCredentials() throws -> (username: String?, password: String?) {
        let username = try keychain.retrieve(String.self, forKey: "username")
        let password = try keychain.retrieve(String.self, forKey: "password")
        return (username, password)
    }
    
    // Clear all credentials
    func clearCredentials() throws {
        try keychain.remove(forKey: "auth_token")
        try keychain.remove(forKey: "username")
        try keychain.remove(forKey: "password")
    }
}
```

## 📁 File Storage

### **File Operations**
```swift
let fileStorage = FileStorage()

// Save file
try fileStorage.save(data, to: "documents/file.txt")

// Load file
let data = try fileStorage.load(from: "documents/file.txt")

// Delete file
try fileStorage.delete(at: "documents/file.txt")

// Check if file exists
let exists = fileStorage.exists(at: "documents/file.txt")
```

### **File Manager**
```swift
class FileManager {
    private let fileStorage: FileStorage
    
    init() {
        self.fileStorage = FileStorage()
    }
    
    // Save user data
    func saveUserData(_ data: Data, filename: String) throws {
        let path = "users/\(filename)"
        try fileStorage.save(data, to: path)
    }
    
    // Load user data
    func loadUserData(filename: String) throws -> Data {
        let path = "users/\(filename)"
        return try fileStorage.load(from: path)
    }
    
    // Save image
    func saveImage(_ image: UIImage, filename: String) throws {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw StorageError.invalidData
        }
        
        let path = "images/\(filename)"
        try fileStorage.save(data, to: path)
    }
    
    // Load image
    func loadImage(filename: String) throws -> UIImage {
        let path = "images/\(filename)"
        let data = try fileStorage.load(from: path)
        
        guard let image = UIImage(data: data) else {
            throw StorageError.invalidData
        }
        
        return image
    }
}
```

## 🗄️ Core Data

### **Core Data Stack**
```swift
class CoreDataStack {
    static let shared = CoreDataStack()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "DataModel")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data error: \(error)")
            }
        }
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Core Data save error: \(error)")
            }
        }
    }
}
```

### **Core Data Manager**
```swift
class CoreDataManager {
    private let coreDataStack: CoreDataStack
    
    init() {
        self.coreDataStack = CoreDataStack.shared
    }
    
    // Save user
    func saveUser(_ user: User) throws {
        let userEntity = UserEntity(context: coreDataStack.context)
        userEntity.id = user.id
        userEntity.name = user.name
        userEntity.email = user.email
        
        try coreDataStack.context.save()
    }
    
    // Fetch users
    func fetchUsers() throws -> [User] {
        let request: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        let entities = try coreDataStack.context.fetch(request)
        
        return entities.map { entity in
            User(
                id: entity.id ?? "",
                name: entity.name ?? "",
                email: entity.email ?? ""
            )
        }
    }
    
    // Delete user
    func deleteUser(_ user: User) throws {
        let request: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", user.id)
        
        let entities = try coreDataStack.context.fetch(request)
        for entity in entities {
            coreDataStack.context.delete(entity)
        }
        
        try coreDataStack.context.save()
    }
}
```

## 🔒 Data Encryption

### **Encrypted Storage**
```swift
class EncryptedStorage {
    private let keychain: KeychainStorage
    private let encryptionKey: String
    
    init() {
        self.keychain = KeychainStorage()
        self.encryptionKey = "your_encryption_key"
    }
    
    // Save encrypted data
    func saveEncrypted(_ data: Data, forKey key: String) throws {
        let encryptedData = try Encryption.encrypt(data, with: encryptionKey)
        try keychain.save(encryptedData, forKey: key)
    }
    
    // Load encrypted data
    func loadEncrypted(forKey key: String) throws -> Data {
        let encryptedData = try keychain.retrieve(Data.self, forKey: key)
        return try Encryption.decrypt(encryptedData, with: encryptionKey)
    }
    
    // Save encrypted object
    func saveEncryptedObject<T: Codable>(_ object: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(object)
        try saveEncrypted(data, forKey: key)
    }
    
    // Load encrypted object
    func loadEncryptedObject<T: Codable>(_ type: T.Type, forKey key: String) throws -> T {
        let data = try loadEncrypted(forKey: key)
        return try JSONDecoder().decode(type, from: data)
    }
}
```

### **Storage Errors**
```swift
enum StorageError: Error {
    case keyNotFound
    case invalidData
    case encodingError
    case decodingError
    case encryptionError
    case decryptionError
    case fileNotFound
    case permissionDenied
    case diskFull
    case unknown
}

extension StorageError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .keyNotFound:
            return "Key not found in storage"
        case .invalidData:
            return "Invalid data format"
        case .encodingError:
            return "Failed to encode data"
        case .decodingError:
            return "Failed to decode data"
        case .encryptionError:
            return "Failed to encrypt data"
        case .decryptionError:
            return "Failed to decrypt data"
        case .fileNotFound:
            return "File not found"
        case .permissionDenied:
            return "Permission denied"
        case .diskFull:
            return "Disk is full"
        case .unknown:
            return "Unknown storage error"
        }
    }
}
```

## 📚 Next Steps

1. **Read [Getting Started](GettingStarted.md)** for quick setup
2. **Check [Network Guide](NetworkGuide.md)** for network utilities
3. **Explore [Utility Guide](UtilityGuide.md)** for utility functions
4. **Review [Analytics Guide](AnalyticsGuide.md)** for analytics utilities
5. **Learn [Debugging Guide](DebuggingGuide.md)** for debugging tools
6. **See [API Reference](API.md)** for complete API documentation

## 🤝 Support

- **Documentation**: [Complete Documentation](Documentation/)
- **Issues**: [GitHub Issues](https://github.com/muhittincamdali/iOSDevelopmentTools/issues)
- **Discussions**: [GitHub Discussions](https://github.com/muhittincamdali/iOSDevelopmentTools/discussions)

---

**Happy storing with iOS Development Tools! 💾** 