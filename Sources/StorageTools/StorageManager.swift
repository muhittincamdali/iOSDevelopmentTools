import Foundation
import Security

// MARK: - Storage Manager Protocol
public protocol StorageManagerProtocol {
    func save<T: Codable>(_ object: T, forKey key: String) throws
    func load<T: Codable>(_ type: T.Type, forKey key: String) throws -> T
    func delete(forKey key: String) throws
    func clear() throws
    func exists(forKey key: String) -> Bool
}

// MARK: - Storage Manager Implementation
public class StorageManager: StorageManagerProtocol {
    private let userDefaults = UserDefaults.standard
    private let keychain = KeychainManager()
    private let fileManager = FileManager.default
    
    public init() {}
    
    // MARK: - UserDefaults Storage
    public func save<T: Codable>(_ object: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(object)
        userDefaults.set(data, forKey: key)
    }
    
    public func load<T: Codable>(_ type: T.Type, forKey key: String) throws -> T {
        guard let data = userDefaults.data(forKey: key) else {
            throw StorageError.dataNotFound(key)
        }
        
        return try JSONDecoder().decode(type, from: data)
    }
    
    public func delete(forKey key: String) throws {
        userDefaults.removeObject(forKey: key)
    }
    
    public func clear() throws {
        let domain = Bundle.main.bundleIdentifier!
        userDefaults.removePersistentDomain(forName: domain)
    }
    
    public func exists(forKey key: String) -> Bool {
        return userDefaults.object(forKey: key) != nil
    }
    
    // MARK: - Secure Storage (Keychain)
    public func saveSecurely<T: Codable>(_ object: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(object)
        try keychain.save(data, forKey: key)
    }
    
    public func loadSecurely<T: Codable>(_ type: T.Type, forKey key: String) throws -> T {
        let data = try keychain.load(forKey: key)
        return try JSONDecoder().decode(type, from: data)
    }
    
    public func deleteSecurely(forKey key: String) throws {
        try keychain.delete(forKey: key)
    }
    
    // MARK: - File Storage
    public func saveToFile<T: Codable>(_ object: T, filename: String) throws {
        let data = try JSONEncoder().encode(object)
        let documentsPath = getDocumentsDirectory()
        let filePath = documentsPath.appendingPathComponent(filename)
        
        try data.write(to: filePath)
    }
    
    public func loadFromFile<T: Codable>(_ type: T.Type, filename: String) throws -> T {
        let documentsPath = getDocumentsDirectory()
        let filePath = documentsPath.appendingPathComponent(filename)
        
        let data = try Data(contentsOf: filePath)
        return try JSONDecoder().decode(type, from: data)
    }
    
    public func deleteFile(filename: String) throws {
        let documentsPath = getDocumentsDirectory()
        let filePath = documentsPath.appendingPathComponent(filename)
        
        try fileManager.removeItem(at: filePath)
    }
    
    public func fileExists(filename: String) -> Bool {
        let documentsPath = getDocumentsDirectory()
        let filePath = documentsPath.appendingPathComponent(filename)
        
        return fileManager.fileExists(atPath: filePath.path)
    }
    
    // MARK: - Cache Management
    public func saveToCache<T: Codable>(_ object: T, forKey key: String, expiration: Date? = nil) throws {
        let cacheItem = CacheItem(
            data: try JSONEncoder().encode(object),
            expiration: expiration
        )
        
        let data = try JSONEncoder().encode(cacheItem)
        userDefaults.set(data, forKey: "cache_\(key)")
    }
    
    public func loadFromCache<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
        guard let data = userDefaults.data(forKey: "cache_\(key)") else {
            return nil
        }
        
        let cacheItem = try JSONDecoder().decode(CacheItem.self, from: data)
        
        // Check expiration
        if let expiration = cacheItem.expiration, Date() > expiration {
            try deleteFromCache(forKey: key)
            return nil
        }
        
        return try JSONDecoder().decode(type, from: cacheItem.data)
    }
    
    public func deleteFromCache(forKey key: String) throws {
        userDefaults.removeObject(forKey: "cache_\(key)")
    }
    
    public func clearCache() throws {
        let keys = userDefaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("cache_") }
        keys.forEach { userDefaults.removeObject(forKey: $0) }
    }
    
    // MARK: - Private Methods
    private func getDocumentsDirectory() -> URL {
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

// MARK: - Keychain Manager
public class KeychainManager {
    private let service = "iOSDevelopmentTools"
    
    public init() {}
    
    public func save(_ data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            // Item already exists, update it
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key
            ]
            
            let attributes: [String: Any] = [
                kSecValueData as String: data
            ]
            
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
            
            if updateStatus != errSecSuccess {
                throw StorageError.keychainError(updateStatus)
            }
        } else if status != errSecSuccess {
            throw StorageError.keychainError(status)
        }
    }
    
    public func load(forKey key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            return result as! Data
        } else {
            throw StorageError.keychainError(status)
        }
    }
    
    public func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            throw StorageError.keychainError(status)
        }
    }
}

// MARK: - Cache Item
private struct CacheItem: Codable {
    let data: Data
    let expiration: Date?
}

// MARK: - Storage Error
public enum StorageError: LocalizedError {
    case dataNotFound(String)
    case encodingFailed(Error)
    case decodingFailed(Error)
    case keychainError(OSStatus)
    case fileNotFound(String)
    case fileWriteFailed(Error)
    case fileReadFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .dataNotFound(let key):
            return "Data not found for key: \(key)"
        case .encodingFailed(let error):
            return "Encoding failed: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Decoding failed: \(error.localizedDescription)"
        case .keychainError(let status):
            return "Keychain error: \(status)"
        case .fileNotFound(let filename):
            return "File not found: \(filename)"
        case .fileWriteFailed(let error):
            return "File write failed: \(error.localizedDescription)"
        case .fileReadFailed(let error):
            return "File read failed: \(error.localizedDescription)"
        }
    }
} 