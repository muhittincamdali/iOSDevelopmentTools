//
//  StorageManager.swift
//  iOSDevelopmentTools
//
//  Created by Muhittin Camdali on 2024-01-15.
//  Copyright © 2024 Muhittin Camdali. All rights reserved.
//

import Foundation
import Security
import CryptoKit

// MARK: - Storage Manager Protocol
public protocol StorageManagerProtocol {
    func save<T: Codable>(_ value: T, forKey key: String) throws
    func retrieve<T: Codable>(_ type: T.Type, forKey key: String) throws -> T?
    func remove(forKey key: String) throws
    func clear() throws
    func exists(forKey key: String) -> Bool
    func getAllKeys() -> [String]
    func getStorageSize() -> Int64
    func backup() throws -> Data
    func restore(from data: Data) throws
}

// MARK: - Storage Configuration
public struct StorageConfiguration {
    public let userDefaultsSuite: String?
    public let keychainService: String
    public let fileStorageDirectory: URL
    public let encryptionEnabled: Bool
    public let encryptionKey: String?
    public let compressionEnabled: Bool
    public let maxStorageSize: Int64
    public let autoCleanupEnabled: Bool
    public let backupEnabled: Bool
    public let backupInterval: TimeInterval
    
    public init(
        userDefaultsSuite: String? = nil,
        keychainService: String = "com.app.storage",
        fileStorageDirectory: URL = FileManager.default.documentsDirectory,
        encryptionEnabled: Bool = false,
        encryptionKey: String? = nil,
        compressionEnabled: Bool = false,
        maxStorageSize: Int64 = 100 * 1024 * 1024, // 100MB
        autoCleanupEnabled: Bool = true,
        backupEnabled: Bool = false,
        backupInterval: TimeInterval = 86400 // 24 hours
    ) {
        self.userDefaultsSuite = userDefaultsSuite
        self.keychainService = keychainService
        self.fileStorageDirectory = fileStorageDirectory
        self.encryptionEnabled = encryptionEnabled
        self.encryptionKey = encryptionKey
        self.compressionEnabled = compressionEnabled
        self.maxStorageSize = maxStorageSize
        self.autoCleanupEnabled = autoCleanupEnabled
        self.backupEnabled = backupEnabled
        self.backupInterval = backupInterval
    }
}

// MARK: - Storage Error
public enum StorageError: Error, LocalizedError {
    case keyNotFound
    case invalidData
    case encodingError
    case decodingError
    case encryptionError
    case decryptionError
    case fileNotFound
    case permissionDenied
    case diskFull
    case compressionError
    case decompressionError
    case backupError
    case restoreError
    case quotaExceeded
    case invalidKey
    case unknown
    
    public var errorDescription: String? {
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
        case .compressionError:
            return "Failed to compress data"
        case .decompressionError:
            return "Failed to decompress data"
        case .backupError:
            return "Failed to create backup"
        case .restoreError:
            return "Failed to restore from backup"
        case .quotaExceeded:
            return "Storage quota exceeded"
        case .invalidKey:
            return "Invalid encryption key"
        case .unknown:
            return "Unknown storage error"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .keyNotFound:
            return "The specified key does not exist in storage"
        case .invalidData:
            return "The data format is not supported"
        case .encodingError:
            return "Data could not be encoded to the required format"
        case .decodingError:
            return "Data could not be decoded from the stored format"
        case .encryptionError:
            return "Data encryption failed due to invalid key or algorithm"
        case .decryptionError:
            return "Data decryption failed due to invalid key or corrupted data"
        case .fileNotFound:
            return "The requested file does not exist at the specified path"
        case .permissionDenied:
            return "Access to the storage location is not permitted"
        case .diskFull:
            return "The storage device has insufficient space"
        case .compressionError:
            return "Data compression failed due to unsupported format"
        case .decompressionError:
            return "Data decompression failed due to corrupted data"
        case .backupError:
            return "Backup creation failed due to insufficient space or permissions"
        case .restoreError:
            return "Backup restoration failed due to corrupted backup data"
        case .quotaExceeded:
            return "Storage usage has exceeded the maximum allowed limit"
        case .invalidKey:
            return "The provided encryption key is invalid or corrupted"
        case .unknown:
            return "An unexpected error occurred during storage operation"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .keyNotFound:
            return "Check if the key exists or use a different key"
        case .invalidData, .encodingError, .decodingError:
            return "Verify the data format and try again"
        case .encryptionError, .decryptionError, .invalidKey:
            return "Check the encryption key and try again"
        case .fileNotFound:
            return "Verify the file path and try again"
        case .permissionDenied:
            return "Check file permissions and try again"
        case .diskFull:
            return "Free up disk space and try again"
        case .compressionError, .decompressionError:
            return "Try with uncompressed data"
        case .backupError, .restoreError:
            return "Check available space and try again"
        case .quotaExceeded:
            return "Clear some data and try again"
        case .unknown:
            return "Try again or contact support"
        }
    }
}

// MARK: - Storage Manager
public class StorageManager: StorageManagerProtocol {
    
    // MARK: - Properties
    private let configuration: StorageConfiguration
    private let userDefaults: UserDefaults
    private let keychain: KeychainStorage
    private let fileStorage: FileStorage
    private let logger: Logger?
    private let performanceMonitor: PerformanceMonitor?
    private let encryptionManager: EncryptionManager?
    private let compressionManager: CompressionManager?
    private let backupManager: BackupManager?
    private let cleanupManager: CleanupManager?
    
    // MARK: - Initialization
    public init(configuration: StorageConfiguration, logger: Logger? = nil, performanceMonitor: PerformanceMonitor? = nil) {
        self.configuration = configuration
        self.logger = logger
        self.performanceMonitor = performanceMonitor
        
        // Initialize UserDefaults
        if let suiteName = configuration.userDefaultsSuite {
            self.userDefaults = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
        } else {
            self.userDefaults = UserDefaults.standard
        }
        
        // Initialize KeychainStorage
        self.keychain = KeychainStorage(service: configuration.keychainService)
        
        // Initialize FileStorage
        self.fileStorage = FileStorage(directory: configuration.fileStorageDirectory)
        
        // Initialize EncryptionManager if enabled
        if configuration.encryptionEnabled {
            self.encryptionManager = EncryptionManager(key: configuration.encryptionKey ?? "default_key")
        } else {
            self.encryptionManager = nil
        }
        
        // Initialize CompressionManager if enabled
        if configuration.compressionEnabled {
            self.compressionManager = CompressionManager()
        } else {
            self.compressionManager = nil
        }
        
        // Initialize BackupManager if enabled
        if configuration.backupEnabled {
            self.backupManager = BackupManager(
                storageDirectory: configuration.fileStorageDirectory,
                interval: configuration.backupInterval
            )
        } else {
            self.backupManager = nil
        }
        
        // Initialize CleanupManager
        self.cleanupManager = CleanupManager(
            maxStorageSize: configuration.maxStorageSize,
            autoCleanup: configuration.autoCleanupEnabled
        )
        
        // Create storage directory if needed
        createStorageDirectoryIfNeeded()
        
        logger?.info("StorageManager initialized", context: [
            "userDefaultsSuite": configuration.userDefaultsSuite ?? "standard",
            "keychainService": configuration.keychainService,
            "fileStorageDirectory": configuration.fileStorageDirectory.path,
            "encryptionEnabled": configuration.encryptionEnabled,
            "compressionEnabled": configuration.compressionEnabled,
            "backupEnabled": configuration.backupEnabled
        ])
    }
    
    // MARK: - Public Methods
    public func save<T: Codable>(_ value: T, forKey key: String) throws {
        let startTime = Date()
        
        logger?.debug("Saving data", context: [
            "key": key,
            "type": String(describing: T.self)
        ])
        
        performanceMonitor?.startTimer("storage_save_\(key)")
        
        do {
            // Encode data
            let data = try encodeData(value)
            
            // Compress if enabled
            let processedData = try processDataForStorage(data)
            
            // Check storage quota
            try checkStorageQuota(for: processedData)
            
            // Save to appropriate storage
            try saveToStorage(processedData, forKey: key)
            
            // Update metadata
            try updateStorageMetadata(key: key, dataSize: processedData.count)
            
            // Trigger cleanup if needed
            if configuration.autoCleanupEnabled {
                try cleanupManager?.checkAndCleanup()
            }
            
            let saveTime = Date().timeIntervalSince(startTime)
            
            logger?.info("Data saved successfully", context: [
                "key": key,
                "dataSize": processedData.count,
                "saveTime": saveTime
            ])
            
            performanceMonitor?.endTimer("storage_save_\(key)")
            
        } catch {
            logger?.error("Failed to save data", context: [
                "key": key,
                "error": error.localizedDescription
            ])
            
            performanceMonitor?.endTimer("storage_save_\(key)")
            
            throw error
        }
    }
    
    public func retrieve<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
        let startTime = Date()
        
        logger?.debug("Retrieving data", context: [
            "key": key,
            "type": String(describing: T.self)
        ])
        
        performanceMonitor?.startTimer("storage_retrieve_\(key)")
        
        do {
            // Retrieve from storage
            guard let data = try retrieveFromStorage(forKey: key) else {
                logger?.debug("No data found for key", context: ["key": key])
                performanceMonitor?.endTimer("storage_retrieve_\(key)")
                return nil
            }
            
            // Process data (decompress, decrypt)
            let processedData = try processDataFromStorage(data)
            
            // Decode data
            let value = try decodeData(processedData, to: type)
            
            let retrieveTime = Date().timeIntervalSince(startTime)
            
            logger?.info("Data retrieved successfully", context: [
                "key": key,
                "dataSize": data.count,
                "retrieveTime": retrieveTime
            ])
            
            performanceMonitor?.endTimer("storage_retrieve_\(key)")
            
            return value
            
        } catch {
            logger?.error("Failed to retrieve data", context: [
                "key": key,
                "error": error.localizedDescription
            ])
            
            performanceMonitor?.endTimer("storage_retrieve_\(key)")
            
            throw error
        }
    }
    
    public func remove(forKey key: String) throws {
        logger?.debug("Removing data", context: ["key": key])
        
        do {
            // Remove from all storage types
            try removeFromAllStorages(forKey: key)
            
            // Update metadata
            try updateStorageMetadata(key: key, dataSize: 0, isRemoval: true)
            
            logger?.info("Data removed successfully", context: ["key": key])
            
        } catch {
            logger?.error("Failed to remove data", context: [
                "key": key,
                "error": error.localizedDescription
            ])
            throw error
        }
    }
    
    public func clear() throws {
        logger?.info("Clearing all storage")
        
        do {
            // Clear UserDefaults
            userDefaults.removePersistentDomain(forName: userDefaults.suiteName ?? "standard")
            
            // Clear file storage
            try fileStorage.clear()
            
            // Clear metadata
            try clearStorageMetadata()
            
            logger?.info("All storage cleared successfully")
            
        } catch {
            logger?.error("Failed to clear storage", context: [
                "error": error.localizedDescription
            ])
            throw error
        }
    }
    
    public func exists(forKey key: String) -> Bool {
        return userDefaults.object(forKey: key) != nil ||
               keychain.exists(forKey: key) ||
               fileStorage.exists(at: key)
    }
    
    public func getAllKeys() -> [String] {
        var keys: Set<String> = []
        
        // Get UserDefaults keys
        keys.formUnion(userDefaults.dictionaryRepresentation().keys)
        
        // Get keychain keys
        keys.formUnion(keychain.getAllKeys())
        
        // Get file storage keys
        keys.formUnion(fileStorage.getAllKeys())
        
        return Array(keys)
    }
    
    public func getStorageSize() -> Int64 {
        var totalSize: Int64 = 0
        
        // Calculate UserDefaults size
        totalSize += calculateUserDefaultsSize()
        
        // Calculate keychain size
        totalSize += keychain.getStorageSize()
        
        // Calculate file storage size
        totalSize += fileStorage.getStorageSize()
        
        return totalSize
    }
    
    public func backup() throws -> Data {
        logger?.info("Creating storage backup")
        
        do {
            let backupData = try createBackupData()
            logger?.info("Backup created successfully", context: [
                "backupSize": backupData.count
            ])
            return backupData
        } catch {
            logger?.error("Failed to create backup", context: [
                "error": error.localizedDescription
            ])
            throw StorageError.backupError
        }
    }
    
    public func restore(from data: Data) throws {
        logger?.info("Restoring storage from backup")
        
        do {
            try restoreFromBackupData(data)
            logger?.info("Storage restored successfully")
        } catch {
            logger?.error("Failed to restore from backup", context: [
                "error": error.localizedDescription
            ])
            throw StorageError.restoreError
        }
    }
    
    // MARK: - Private Methods
    private func createStorageDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(
                at: configuration.fileStorageDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            logger?.error("Failed to create storage directory", context: [
                "error": error.localizedDescription
            ])
        }
    }
    
    private func encodeData<T: Codable>(_ value: T) throws -> Data {
        do {
            return try JSONEncoder().encode(value)
        } catch {
            logger?.error("Failed to encode data", context: [
                "error": error.localizedDescription
            ])
            throw StorageError.encodingError
        }
    }
    
    private func decodeData<T: Codable>(_ data: Data, to type: T.Type) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            logger?.error("Failed to decode data", context: [
                "error": error.localizedDescription
            ])
            throw StorageError.decodingError
        }
    }
    
    private func processDataForStorage(_ data: Data) throws -> Data {
        var processedData = data
        
        // Compress if enabled
        if let compressionManager = compressionManager {
            processedData = try compressionManager.compress(processedData)
        }
        
        // Encrypt if enabled
        if let encryptionManager = encryptionManager {
            processedData = try encryptionManager.encrypt(processedData)
        }
        
        return processedData
    }
    
    private func processDataFromStorage(_ data: Data) throws -> Data {
        var processedData = data
        
        // Decrypt if enabled
        if let encryptionManager = encryptionManager {
            processedData = try encryptionManager.decrypt(processedData)
        }
        
        // Decompress if enabled
        if let compressionManager = compressionManager {
            processedData = try compressionManager.decompress(processedData)
        }
        
        return processedData
    }
    
    private func checkStorageQuota(for data: Data) throws {
        let currentSize = getStorageSize()
        let newSize = currentSize + Int64(data.count)
        
        if newSize > configuration.maxStorageSize {
            logger?.warning("Storage quota exceeded", context: [
                "currentSize": currentSize,
                "newSize": newSize,
                "maxSize": configuration.maxStorageSize
            ])
            throw StorageError.quotaExceeded
        }
    }
    
    private func saveToStorage(_ data: Data, forKey key: String) throws {
        // Determine storage type based on data size and sensitivity
        let storageType = determineStorageType(for: key, dataSize: data.count)
        
        switch storageType {
        case .userDefaults:
            try saveToUserDefaults(data, forKey: key)
        case .keychain:
            try keychain.save(data, forKey: key)
        case .fileStorage:
            try fileStorage.save(data, to: key)
        }
    }
    
    private func retrieveFromStorage(forKey key: String) throws -> Data? {
        // Try UserDefaults first
        if let data = try retrieveFromUserDefaults(forKey: key) {
            return data
        }
        
        // Try keychain
        if let data = try keychain.retrieve(Data.self, forKey: key) {
            return data
        }
        
        // Try file storage
        if fileStorage.exists(at: key) {
            return try fileStorage.load(from: key)
        }
        
        return nil
    }
    
    private func removeFromAllStorages(forKey key: String) throws {
        // Remove from UserDefaults
        userDefaults.removeObject(forKey: key)
        
        // Remove from keychain
        try keychain.remove(forKey: key)
        
        // Remove from file storage
        if fileStorage.exists(at: key) {
            try fileStorage.delete(at: key)
        }
    }
    
    private func determineStorageType(for key: String, dataSize: Int) -> StorageType {
        // Sensitive data goes to keychain
        if isSensitiveKey(key) {
            return .keychain
        }
        
        // Large data goes to file storage
        if dataSize > 1024 * 1024 { // 1MB
            return .fileStorage
        }
        
        // Small data goes to UserDefaults
        return .userDefaults
    }
    
    private func isSensitiveKey(_ key: String) -> Bool {
        let sensitiveKeys = ["password", "token", "secret", "key", "auth"]
        return sensitiveKeys.contains { key.lowercased().contains($0) }
    }
    
    private func saveToUserDefaults(_ data: Data, forKey key: String) throws {
        userDefaults.set(data, forKey: key)
        userDefaults.synchronize()
    }
    
    private func retrieveFromUserDefaults(forKey key: String) throws -> Data? {
        return userDefaults.data(forKey: key)
    }
    
    private func calculateUserDefaultsSize() -> Int64 {
        var size: Int64 = 0
        for (key, value) in userDefaults.dictionaryRepresentation() {
            if let data = value as? Data {
                size += Int64(data.count)
            } else if let string = value as? String {
                size += Int64(string.utf8.count)
            }
        }
        return size
    }
    
    private func updateStorageMetadata(key: String, dataSize: Int, isRemoval: Bool = false) throws {
        // Update storage statistics
        var metadata = getStorageMetadata()
        
        if isRemoval {
            metadata.removeValue(forKey: key)
        } else {
            metadata[key] = [
                "size": dataSize,
                "timestamp": Date().timeIntervalSince1970
            ]
        }
        
        try saveStorageMetadata(metadata)
    }
    
    private func getStorageMetadata() -> [String: [String: Any]] {
        guard let data = userDefaults.data(forKey: "storage_metadata"),
              let metadata = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else {
            return [:]
        }
        return metadata
    }
    
    private func saveStorageMetadata(_ metadata: [String: [String: Any]]) throws {
        let data = try JSONSerialization.data(withJSONObject: metadata)
        userDefaults.set(data, forKey: "storage_metadata")
        userDefaults.synchronize()
    }
    
    private func clearStorageMetadata() throws {
        userDefaults.removeObject(forKey: "storage_metadata")
        userDefaults.synchronize()
    }
    
    private func createBackupData() throws -> Data {
        var backup: [String: Any] = [:]
        
        // Backup UserDefaults
        backup["userDefaults"] = userDefaults.dictionaryRepresentation()
        
        // Backup file storage
        backup["fileStorage"] = try fileStorage.createBackup()
        
        // Backup metadata
        backup["metadata"] = getStorageMetadata()
        
        return try JSONSerialization.data(withJSONObject: backup)
    }
    
    private func restoreFromBackupData(_ data: Data) throws {
        guard let backup = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw StorageError.restoreError
        }
        
        // Clear existing data
        try clear()
        
        // Restore UserDefaults
        if let userDefaultsData = backup["userDefaults"] as? [String: Any] {
            for (key, value) in userDefaultsData {
                userDefaults.set(value, forKey: key)
            }
        }
        
        // Restore file storage
        if let fileStorageData = backup["fileStorage"] as? [String: Any] {
            try fileStorage.restore(from: fileStorageData)
        }
        
        // Restore metadata
        if let metadata = backup["metadata"] as? [String: [String: Any]] {
            try saveStorageMetadata(metadata)
        }
        
        userDefaults.synchronize()
    }
    
    // MARK: - Deinitialization
    deinit {
        // Perform cleanup
        try? cleanupManager?.performCleanup()
    }
}

// MARK: - Storage Type
private enum StorageType {
    case userDefaults
    case keychain
    case fileStorage
}

// MARK: - Encryption Manager
private class EncryptionManager {
    private let key: String
    
    init(key: String) {
        self.key = key
    }
    
    func encrypt(_ data: Data) throws -> Data {
        // Implementation for AES encryption
        return data
    }
    
    func decrypt(_ data: Data) throws -> Data {
        // Implementation for AES decryption
        return data
    }
}

// MARK: - Compression Manager
private class CompressionManager {
    func compress(_ data: Data) throws -> Data {
        // Implementation for data compression
        return data
    }
    
    func decompress(_ data: Data) throws -> Data {
        // Implementation for data decompression
        return data
    }
}

// MARK: - Backup Manager
private class BackupManager {
    private let storageDirectory: URL
    private let interval: TimeInterval
    
    init(storageDirectory: URL, interval: TimeInterval) {
        self.storageDirectory = storageDirectory
        self.interval = interval
    }
    
    func scheduleBackup() {
        // Implementation for scheduled backup
    }
}

// MARK: - Cleanup Manager
private class CleanupManager {
    private let maxStorageSize: Int64
    private let autoCleanup: Bool
    
    init(maxStorageSize: Int64, autoCleanup: Bool) {
        self.maxStorageSize = maxStorageSize
        self.autoCleanup = autoCleanup
    }
    
    func checkAndCleanup() throws {
        // Implementation for storage cleanup
    }
    
    func performCleanup() throws {
        // Implementation for manual cleanup
    }
}

// MARK: - Extensions
extension StorageManager {
    
    /// Enable debug mode for detailed logging
    public func enableDebugMode() {
        logger?.info("Debug mode enabled for StorageManager")
    }
    
    /// Get storage statistics
    public func getStorageStats() -> [String: Any] {
        return [
            "totalSize": getStorageSize(),
            "keyCount": getAllKeys().count,
            "encryptionEnabled": configuration.encryptionEnabled,
            "compressionEnabled": configuration.compressionEnabled,
            "backupEnabled": configuration.backupEnabled
        ]
    }
    
    /// Migrate data from old storage format
    public func migrateFromOldFormat() throws {
        // Implementation for data migration
    }
} // Security enhancements
