import Foundation

class SecureStorage {
    func save(key: String, value: String) {
        // TODO: Implement Keychain saving
        UserDefaults.standard.set(value, forKey: key)
    }
    
    func load(key: String) -> String? {
        // TODO: Implement Keychain loading
        return UserDefaults.standard.string(forKey: key)
    }
}
