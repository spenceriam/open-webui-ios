import Foundation
import CryptoKit
import Security

/// A secure storage service that implements local encryption for conversation data
class SecureStorageService {
    private let keychainService = KeychainService()
    private let encryptionKeyIdentifier = "encryption_key_identifier"
    
    /// Get or create an encryption key stored in the keychain
    private func getOrCreateEncryptionKey() throws -> SymmetricKey {
        do {
            // Try to retrieve existing key
            let existingKey = try keychainService.get(encryptionKeyIdentifier)
            if !existingKey.isEmpty {
                let keyData = Data(base64Encoded: existingKey)!
                return SymmetricKey(data: keyData)
            }
        } catch {
            // Key doesn't exist yet, we'll create a new one
        }
        
        // Generate a new key
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        let keyString = keyData.base64EncodedString()
        
        // Store in keychain
        try keychainService.set(keyString, for: encryptionKeyIdentifier)
        
        return newKey
    }
    
    /// Encrypt data using AES-GCM with a key stored in the keychain
    func encrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateEncryptionKey()
        
        // Create a random nonce
        let nonce = try AES.GCM.Nonce()
        
        // Encrypt the data
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)
        
        // Combine nonce and sealed data into a single data object for storage
        let encryptedData = sealedBox.combined!
        
        return encryptedData
    }
    
    /// Decrypt data that was encrypted using the encrypt method
    func decrypt(_ encryptedData: Data) throws -> Data {
        let key = try getOrCreateEncryptionKey()
        
        // Create a sealed box from the combined data
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        
        // Decrypt the data
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        return decryptedData
    }
    
    /// Encrypt a string and return as Base64 encoded string
    func encryptString(_ string: String) throws -> String {
        guard let data = string.data(using: .utf8) else {
            throw NSError(domain: "SecureStorageService", code: 1, 
                          userInfo: [NSLocalizedDescriptionKey: "Failed to convert string to data"])
        }
        
        let encryptedData = try encrypt(data)
        return encryptedData.base64EncodedString()
    }
    
    /// Decrypt a Base64 encoded string
    func decryptString(_ encryptedString: String) throws -> String {
        guard let data = Data(base64Encoded: encryptedString) else {
            throw NSError(domain: "SecureStorageService", code: 2, 
                          userInfo: [NSLocalizedDescriptionKey: "Failed to decode Base64 string"])
        }
        
        let decryptedData = try decrypt(data)
        
        guard let decryptedString = String(data: decryptedData, encoding: .utf8) else {
            throw NSError(domain: "SecureStorageService", code: 3, 
                          userInfo: [NSLocalizedDescriptionKey: "Failed to convert decrypted data to string"])
        }
        
        return decryptedString
    }
    
    /// Configure secure storage for Core Data
    func configureSecureStorage() {
        // In a full implementation, this would set up Core Data with SQLite store encryption
        // using a database key derived from our encryption key
        
        // This is a placeholder for actually implementing SQLCipher or similar approach
        // for Core Data encryption. The actual implementation would:
        // 1. Create a dictionary of Core Data store options with the encryption key
        // 2. Use this dictionary when setting up the persistent store coordinator
    }
}