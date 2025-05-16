import UIKit
import SwiftUI

/// A memory and disk cache for efficiently storing and retrieving images
final class ImageCache {
    static let shared = ImageCache()
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        // Set memory cache limits to prevent excessive memory usage
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        memoryCache.countLimit = 100
        
        // Create persistent cache directory
        let cacheURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cacheURL.appendingPathComponent("ImageCache")
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Set up memory warning notification handler
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    /// Cache an image in both memory and disk
    func cacheImage(_ image: UIImage, forKey key: String) {
        // Store in memory cache
        memoryCache.setObject(image, forKey: key as NSString)
        
        // Also save to disk with compression
        if let data = compressImage(image) {
            let fileURL = cacheDirectory.appendingPathComponent(key)
            try? data.write(to: fileURL)
        }
    }
    
    /// Retrieve an image from cache (first memory, then disk)
    func getImage(forKey key: String) -> UIImage? {
        // Check memory cache first
        if let cachedImage = memoryCache.object(forKey: key as NSString) {
            return cachedImage
        }
        
        // If not in memory, try disk cache
        return loadImageFromDisk(forKey: key)
    }
    
    /// Compress an image for efficient storage
    private func compressImage(_ image: UIImage) -> Data? {
        // Use more aggressive compression for larger images
        let size = image.size.width * image.size.height
        let compressionQuality: CGFloat = size > 1000000 ? 0.3 : 0.6
        
        return image.jpegData(compressionQuality: compressionQuality)
    }
    
    /// Load an image from disk cache
    private func loadImageFromDisk(forKey key: String) -> UIImage? {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        
        // Restore to memory cache for future access
        memoryCache.setObject(image, forKey: key as NSString)
        return image
    }
    
    /// Clear memory cache in response to system memory warnings
    @objc private func handleMemoryWarning() {
        memoryCache.removeAllObjects()
        print("Memory warning received - clearing image cache")
    }
    
    /// Clear memory cache manually
    func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }
    
    /// Clear both memory and disk cache
    func clearCache() {
        // Clear memory cache
        memoryCache.removeAllObjects()
        
        // Clear disk cache
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    /// Get estimated memory usage of the cache
    func memoryUsage() -> UInt64 {
        // This is an estimate as NSCache doesn't expose exact memory usage
        return UInt64(memoryCache.totalCostLimit * memoryCache.totalCostLimit / memoryCache.countLimit)
    }
    
    /// Get disk usage of the cache
    func diskUsage() -> UInt64 {
        let keys: [URLResourceKey] = [.fileSizeKey]
        let urls = (try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: keys,
            options: .skipsHiddenFiles
        )) ?? []
        
        return urls.reduce(0) { sum, url in
            guard let resourceValues = try? url.resourceValues(forKeys: Set(keys)),
                  let fileSize = resourceValues.fileSize else {
                return sum
            }
            return sum + UInt64(fileSize)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// SwiftUI extension for Image loading with caching
extension Image {
    /// Load an image from URL with caching
    static func cached(_ url: URL) -> Image {
        let key = url.absoluteString
        
        if let cachedImage = ImageCache.shared.getImage(forKey: key) {
            return Image(uiImage: cachedImage)
        } else {
            // If not cached, use a placeholder and start loading
            // This would normally use URLSession, but for simplicity:
            if let data = try? Data(contentsOf: url),
               let uiImage = UIImage(data: data) {
                ImageCache.shared.cacheImage(uiImage, forKey: key)
                return Image(uiImage: uiImage)
            }
            return Image(systemName: "photo")
        }
    }
}