import XCTest
import Quick
import Nimble
@testable import StorageTools

class StorageManagerTests: QuickSpec {
    
    override func spec() {
        
        describe("StorageManager") {
            
            var storageManager: StorageManager!
            
            beforeEach {
                storageManager = StorageManager.shared
                storageManager.clearAllData()
            }
            
            afterEach {
                storageManager.clearAllData()
            }
            
            context("Initialization") {
                
                it("should initialize successfully") {
                    expect(storageManager).toNot(beNil())
                }
                
                it("should have default configuration") {
                    expect(storageManager.isEnabled).to(beTrue())
                    expect(storageManager.encryptionEnabled).to(beFalse())
                }
            }
            
            context("UserDefaults Storage") {
                
                it("should store and retrieve string values") {
                    let key = "test_string"
                    let value = "test_value"
                    
                    storageManager.setString(value, forKey: key)
                    let retrieved = storageManager.getString(forKey: key)
                    
                    expect(retrieved).to(equal(value))
                }
                
                it("should store and retrieve integer values") {
                    let key = "test_int"
                    let value = 42
                    
                    storageManager.setInteger(value, forKey: key)
                    let retrieved = storageManager.getInteger(forKey: key)
                    
                    expect(retrieved).to(equal(value))
                }
                
                it("should store and retrieve boolean values") {
                    let key = "test_bool"
                    let value = true
                    
                    storageManager.setBool(value, forKey: key)
                    let retrieved = storageManager.getBool(forKey: key)
                    
                    expect(retrieved).to(equal(value))
                }
                
                it("should store and retrieve double values") {
                    let key = "test_double"
                    let value = 3.14
                    
                    storageManager.setDouble(value, forKey: key)
                    let retrieved = storageManager.getDouble(forKey: key)
                    
                    expect(retrieved).to(equal(value))
                }
                
                it("should store and retrieve data values") {
                    let key = "test_data"
                    let value = "test_data".data(using: .utf8)!
                    
                    storageManager.setData(value, forKey: key)
                    let retrieved = storageManager.getData(forKey: key)
                    
                    expect(retrieved).to(equal(value))
                }
                
                it("should store and retrieve array values") {
                    let key = "test_array"
                    let value = ["item1", "item2", "item3"]
                    
                    storageManager.setArray(value, forKey: key)
                    let retrieved = storageManager.getArray(forKey: key) as? [String]
                    
                    expect(retrieved).to(equal(value))
                }
                
                it("should store and retrieve dictionary values") {
                    let key = "test_dict"
                    let value = ["key1": "value1", "key2": "value2"]
                    
                    storageManager.setDictionary(value, forKey: key)
                    let retrieved = storageManager.getDictionary(forKey: key) as? [String: String]
                    
                    expect(retrieved).to(equal(value))
                }
            }
            
            context("Keychain Storage") {
                
                it("should store and retrieve secure string values") {
                    let key = "secure_test_string"
                    let value = "secure_value"
                    
                    storageManager.setSecureString(value, forKey: key)
                    let retrieved = storageManager.getSecureString(forKey: key)
                    
                    expect(retrieved).to(equal(value))
                }
                
                it("should store and retrieve secure data values") {
                    let key = "secure_test_data"
                    let value = "secure_data".data(using: .utf8)!
                    
                    storageManager.setSecureData(value, forKey: key)
                    let retrieved = storageManager.getSecureData(forKey: key)
                    
                    expect(retrieved).to(equal(value))
                }
                
                it("should handle keychain errors gracefully") {
                    let key = "invalid_key"
                    let retrieved = storageManager.getSecureString(forKey: key)
                    
                    expect(retrieved).to(beNil())
                }
            }
            
            context("File Storage") {
                
                it("should store and retrieve file data") {
                    let fileName = "test_file.txt"
                    let content = "Test file content"
                    let data = content.data(using: .utf8)!
                    
                    storageManager.saveFile(data, fileName: fileName)
                    let retrieved = storageManager.loadFile(fileName: fileName)
                    
                    expect(retrieved).to(equal(data))
                }
                
                it("should check if file exists") {
                    let fileName = "test_file.txt"
                    let content = "Test content"
                    let data = content.data(using: .utf8)!
                    
                    expect(storageManager.fileExists(fileName: fileName)).to(beFalse())
                    
                    storageManager.saveFile(data, fileName: fileName)
                    
                    expect(storageManager.fileExists(fileName: fileName)).to(beTrue())
                }
                
                it("should delete file") {
                    let fileName = "test_file.txt"
                    let content = "Test content"
                    let data = content.data(using: .utf8)!
                    
                    storageManager.saveFile(data, fileName: fileName)
                    expect(storageManager.fileExists(fileName: fileName)).to(beTrue())
                    
                    storageManager.deleteFile(fileName: fileName)
                    expect(storageManager.fileExists(fileName: fileName)).to(beFalse())
                }
                
                it("should get file size") {
                    let fileName = "test_file.txt"
                    let content = "Test content"
                    let data = content.data(using: .utf8)!
                    
                    storageManager.saveFile(data, fileName: fileName)
                    let size = storageManager.getFileSize(fileName: fileName)
                    
                    expect(size).to(equal(data.count))
                }
                
                it("should list all files") {
                    let files = ["file1.txt", "file2.txt", "file3.txt"]
                    
                    for fileName in files {
                        let data = "content".data(using: .utf8)!
                        storageManager.saveFile(data, fileName: fileName)
                    }
                    
                    let allFiles = storageManager.getAllFiles()
                    
                    for fileName in files {
                        expect(allFiles).to(contain(fileName))
                    }
                }
            }
            
            context("Cache Management") {
                
                it("should store and retrieve cached data") {
                    let key = "cached_data"
                    let data = "cached content".data(using: .utf8)!
                    
                    storageManager.cacheData(data, forKey: key, expiration: 3600)
                    let retrieved = storageManager.getCachedData(forKey: key)
                    
                    expect(retrieved).to(equal(data))
                }
                
                it("should respect cache expiration") {
                    let key = "expired_data"
                    let data = "expired content".data(using: .utf8)!
                    
                    storageManager.cacheData(data, forKey: key, expiration: 1) // 1 second
                    
                    // Wait for expiration
                    Thread.sleep(forTimeInterval: 2)
                    
                    let retrieved = storageManager.getCachedData(forKey: key)
                    expect(retrieved).to(beNil())
                }
                
                it("should clear expired cache") {
                    let key = "expired_cache"
                    let data = "expired content".data(using: .utf8)!
                    
                    storageManager.cacheData(data, forKey: key, expiration: 1)
                    
                    // Wait for expiration
                    Thread.sleep(forTimeInterval: 2)
                    
                    storageManager.clearExpiredCache()
                    
                    let cacheSize = storageManager.getCacheSize()
                    expect(cacheSize).to(equal(0))
                }
                
                it("should get cache size") {
                    let keys = ["cache1", "cache2", "cache3"]
                    
                    for key in keys {
                        let data = "content".data(using: .utf8)!
                        storageManager.cacheData(data, forKey: key, expiration: 3600)
                    }
                    
                    let size = storageManager.getCacheSize()
                    expect(size).to(beGreaterThan(0))
                }
            }
            
            context("Encryption") {
                
                it("should enable encryption") {
                    storageManager.enableEncryption()
                    expect(storageManager.encryptionEnabled).to(beTrue())
                }
                
                it("should store encrypted data") {
                    storageManager.enableEncryption()
                    
                    let key = "encrypted_data"
                    let value = "sensitive_data"
                    
                    storageManager.setString(value, forKey: key)
                    let retrieved = storageManager.getString(forKey: key)
                    
                    expect(retrieved).to(equal(value))
                }
                
                it("should handle encryption errors") {
                    storageManager.enableEncryption()
                    
                    let key = "invalid_encrypted_data"
                    let retrieved = storageManager.getString(forKey: key)
                    
                    expect(retrieved).to(beNil())
                }
            }
            
            context("Data Migration") {
                
                it("should migrate data between storage types") {
                    let key = "migration_test"
                    let value = "migration_value"
                    
                    // Store in UserDefaults
                    storageManager.setString(value, forKey: key)
                    
                    // Migrate to Keychain
                    storageManager.migrateToKeychain(key: key)
                    
                    let retrieved = storageManager.getSecureString(forKey: key)
                    expect(retrieved).to(equal(value))
                }
                
                it("should backup and restore data") {
                    let key = "backup_test"
                    let value = "backup_value"
                    
                    storageManager.setString(value, forKey: key)
                    
                    let backup = storageManager.createBackup()
                    expect(backup).toNot(beNil())
                    
                    storageManager.clearAllData()
                    storageManager.restoreFromBackup(backup!)
                    
                    let retrieved = storageManager.getString(forKey: key)
                    expect(retrieved).to(equal(value))
                }
            }
            
            context("Performance") {
                
                it("should handle large data efficiently") {
                    let key = "large_data"
                    let largeData = String(repeating: "x", count: 100000).data(using: .utf8)!
                    
                    let startTime = Date()
                    storageManager.setData(largeData, forKey: key)
                    let writeTime = Date().timeIntervalSince(startTime)
                    
                    expect(writeTime).to(beLessThan(1.0)) // Should complete within 1 second
                    
                    let readStartTime = Date()
                    let retrieved = storageManager.getData(forKey: key)
                    let readTime = Date().timeIntervalSince(readStartTime)
                    
                    expect(readTime).to(beLessThan(1.0))
                    expect(retrieved).to(equal(largeData))
                }
                
                it("should handle concurrent access") {
                    let expectation = XCTestExpectation(description: "Concurrent access")
                    expectation.expectedFulfillmentCount = 10
                    
                    DispatchQueue.concurrentPerform(iterations: 10) { index in
                        let key = "concurrent_\(index)"
                        let value = "value_\(index)"
                        
                        storageManager.setString(value, forKey: key)
                        let retrieved = storageManager.getString(forKey: key)
                        
                        expect(retrieved).to(equal(value))
                        expectation.fulfill()
                    }
                    
                    wait(for: [expectation], timeout: 5.0)
                }
            }
            
            context("Error Handling") {
                
                it("should handle invalid keys gracefully") {
                    let invalidKey = ""
                    let value = "test_value"
                    
                    storageManager.setString(value, forKey: invalidKey)
                    let retrieved = storageManager.getString(forKey: invalidKey)
                    
                    expect(retrieved).to(beNil())
                }
                
                it("should handle storage errors") {
                    let key = "error_test"
                    
                    // Simulate storage error by using invalid data
                    let invalidData = Data()
                    
                    storageManager.setData(invalidData, forKey: key)
                    let retrieved = storageManager.getData(forKey: key)
                    
                    expect(retrieved).to(equal(invalidData))
                }
            }
            
            context("Cleanup") {
                
                it("should clear all data") {
                    let keys = ["key1", "key2", "key3"]
                    
                    for key in keys {
                        storageManager.setString("value", forKey: key)
                    }
                    
                    storageManager.clearAllData()
                    
                    for key in keys {
                        let value = storageManager.getString(forKey: key)
                        expect(value).to(beNil())
                    }
                }
                
                it("should remove specific keys") {
                    let key1 = "key1"
                    let key2 = "key2"
                    
                    storageManager.setString("value1", forKey: key1)
                    storageManager.setString("value2", forKey: key2)
                    
                    storageManager.removeValue(forKey: key1)
                    
                    expect(storageManager.getString(forKey: key1)).to(beNil())
                    expect(storageManager.getString(forKey: key2)).toNot(beNil())
                }
            }
        }
    }
}
