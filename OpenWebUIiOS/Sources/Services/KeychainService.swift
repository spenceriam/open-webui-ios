import Foundation
import Security
import Combine

/// Service for securely storing and retrieving sensitive data using iOS Keychain
class KeychainService {
    enum KeychainError: Error {
        case unexpectedStatus(OSStatus)
        case itemNotFound
        case unhandledError(message: String)
        case dataConversionError
    }
    
    /// Keychain service identifiers
    private enum KeyPrefix: String {
        case apiKey = "com.openwebui.api-key."
        case credentials = "com.openwebui.credentials."
        case secureData = "com.openwebui.secure-data."
    }
    
    // MARK: - API Key Storage
    
    /// Stores an API key for a provider
    func storeAPIKey(_ apiKey: String, for provider: String) -> AnyPublisher<Void, Error> {
        let key = KeyPrefix.apiKey.rawValue + provider
        return storeValue(apiKey, forKey: key)
    }
    
    /// Retrieves an API key for a provider
    func retrieveAPIKey(for provider: String) -> AnyPublisher<String?, Error> {
        let key = KeyPrefix.apiKey.rawValue + provider
        return retrieveValue(forKey: key)
    }
    
    /// Deletes an API key for a provider
    func deleteAPIKey(for provider: String) -> AnyPublisher<Void, Error> {
        let key = KeyPrefix.apiKey.rawValue + provider
        return deleteValue(forKey: key)
    }
    
    // MARK: - Secure Data Storage
    
    /// Stores secure data with a custom key
    func storeSecureData(_ data: Data, forKey customKey: String) -> AnyPublisher<Void, Error> {
        let key = KeyPrefix.secureData.rawValue + customKey
        
        return Future<Void, Error> { promise in
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            
            // First attempt to delete any existing item
            SecItemDelete(query as CFDictionary)
            
            // Then add the new item
            let status = SecItemAdd(query as CFDictionary, nil)
            
            if status == errSecSuccess {
                promise(.success(()))
            } else {
                promise(.failure(KeychainError.unexpectedStatus(status)))
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Retrieves secure data for a custom key
    func retrieveSecureData(forKey customKey: String) -> AnyPublisher<Data?, Error> {
        let key = KeyPrefix.secureData.rawValue + customKey
        
        return Future<Data?, Error> { promise in
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            
            switch status {
            case errSecSuccess:
                if let data = item as? Data {
                    promise(.success(data))
                } else {
                    promise(.failure(KeychainError.dataConversionError))
                }
            case errSecItemNotFound:
                promise(.success(nil))
            default:
                promise(.failure(KeychainError.unexpectedStatus(status)))
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Deletes secure data for a custom key
    func deleteSecureData(forKey customKey: String) -> AnyPublisher<Void, Error> {
        let key = KeyPrefix.secureData.rawValue + customKey
        return deleteValue(forKey: key)
    }
    
    // MARK: - Credential Storage
    
    /// Stores credentials (username/password)
    func storeCredentials(username: String, password: String, for service: String) -> AnyPublisher<Void, Error> {
        let key = KeyPrefix.credentials.rawValue + service
        
        return Future<Void, Error> { promise in
            let passwordData = password.data(using: .utf8)!
            
            let query: [String: Any] = [
                kSecClass as String: kSecClassInternetPassword,
                kSecAttrAccount as String: username,
                kSecAttrServer as String: key,
                kSecValueData as String: passwordData,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            
            // First attempt to delete any existing item
            SecItemDelete(query as CFDictionary)
            
            // Then add the new item
            let status = SecItemAdd(query as CFDictionary, nil)
            
            if status == errSecSuccess {
                promise(.success(()))
            } else {
                promise(.failure(KeychainError.unexpectedStatus(status)))
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Retrieves credentials for a service
    func retrieveCredentials(for service: String, username: String) -> AnyPublisher<String?, Error> {
        let key = KeyPrefix.credentials.rawValue + service
        
        return Future<String?, Error> { promise in
            let query: [String: Any] = [
                kSecClass as String: kSecClassInternetPassword,
                kSecAttrServer as String: key,
                kSecAttrAccount as String: username,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            
            switch status {
            case errSecSuccess:
                guard let passwordData = item as? Data else {
                    promise(.failure(KeychainError.dataConversionError))
                    return
                }
                
                if let password = String(data: passwordData, encoding: .utf8) {
                    promise(.success(password))
                } else {
                    promise(.failure(KeychainError.dataConversionError))
                }
            case errSecItemNotFound:
                promise(.success(nil))
            default:
                promise(.failure(KeychainError.unexpectedStatus(status)))
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Deletes credentials for a service
    func deleteCredentials(for service: String, username: String) -> AnyPublisher<Void, Error> {
        let key = KeyPrefix.credentials.rawValue + service
        
        return Future<Void, Error> { promise in
            let query: [String: Any] = [
                kSecClass as String: kSecClassInternetPassword,
                kSecAttrServer as String: key,
                kSecAttrAccount as String: username
            ]
            
            let status = SecItemDelete(query as CFDictionary)
            
            switch status {
            case errSecSuccess, errSecItemNotFound:
                promise(.success(()))
            default:
                promise(.failure(KeychainError.unexpectedStatus(status)))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Private Helper Methods
    
    private func storeValue(_ value: String, forKey key: String) -> AnyPublisher<Void, Error> {
        guard let data = value.data(using: .utf8) else {
            return Fail(error: KeychainError.dataConversionError).eraseToAnyPublisher()
        }
        
        return Future<Void, Error> { promise in
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            
            // First attempt to delete any existing item
            SecItemDelete(query as CFDictionary)
            
            // Then add the new item
            let status = SecItemAdd(query as CFDictionary, nil)
            
            if status == errSecSuccess {
                promise(.success(()))
            } else {
                promise(.failure(KeychainError.unexpectedStatus(status)))
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func retrieveValue(forKey key: String) -> AnyPublisher<String?, Error> {
        return Future<String?, Error> { promise in
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            
            switch status {
            case errSecSuccess:
                guard let data = item as? Data else {
                    promise(.failure(KeychainError.dataConversionError))
                    return
                }
                
                if let value = String(data: data, encoding: .utf8) {
                    promise(.success(value))
                } else {
                    promise(.failure(KeychainError.dataConversionError))
                }
            case errSecItemNotFound:
                promise(.success(nil))
            default:
                promise(.failure(KeychainError.unexpectedStatus(status)))
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func deleteValue(forKey key: String) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key
            ]
            
            let status = SecItemDelete(query as CFDictionary)
            
            switch status {
            case errSecSuccess, errSecItemNotFound:
                promise(.success(()))
            default:
                promise(.failure(KeychainError.unexpectedStatus(status)))
            }
        }
        .eraseToAnyPublisher()
    }
}