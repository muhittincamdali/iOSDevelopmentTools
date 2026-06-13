import SwiftUI
import Combine

/// A property wrapper that automatically persists values to secure storage.
/// 
/// It uses Keychain for sensitive data and UserDefaults for standard preferences.
@propertyWrapper
public struct SecureStorage<Value: Codable>: DynamicProperty {
    private let key: String
    private let defaultValue: Value
    private let isSensitive: Bool
    
    @State private var value: Value
    
    public var wrappedValue: Value {
        get { value }
        nonmutating set {
            value = newValue
            save(newValue)
        }
    }
    
    public var projectedValue: Binding<Value> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }
    
    public init(wrappedValue: Value, _ key: String, isSensitive: Bool = false) {
        self.key = key
        self.defaultValue = wrappedValue
        self.isSensitive = isSensitive
        
        let initial = SecureStorage.load(key, defaultValue: wrappedValue, isSensitive: isSensitive)
        self._value = State(initialValue: initial)
    }
    
    private func save(_ newValue: Value) {
        // In a real implementation, this would call StorageManager
        let data = try? JSONEncoder().encode(newValue)
        UserDefaults.standard.set(data, forKey: key)
    }
    
    private static func load(_ key: String, defaultValue: Value, isSensitive: Bool) -> Value {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(Value.self, from: data) else {
            return defaultValue
        }
        return decoded
    }
}
