import Foundation
import UIKit

/// High-performance image caching system for receipt images
/// Optimizes memory usage and loading performance
class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    // MARK: - Cache Configuration
    private let maxMemoryCacheSize: Int = 20 * 1024 * 1024 // 20MB memory cache (reduced for better memory usage)
    private let maxDiskCacheSize: Int = 100 * 1024 * 1024 // 100MB disk cache (reduced)
    private let maxImageSize: CGSize = CGSize(width: 800, height: 800) // Smaller max image dimensions
    private let compressionQuality: CGFloat = 0.7 // Higher compression
    
    // MARK: - Cache Storage
    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCacheURL: URL
    private let cacheQueue = DispatchQueue(label: "com.cashooya.imagecache", qos: .utility)
    
    // MARK: - Performance Metrics
    private var memoryHits = 0
    private var diskHits = 0
    private var misses = 0
    
    private init() {
        // Configure memory cache with conservative limits
        memoryCache.totalCostLimit = maxMemoryCacheSize
        memoryCache.countLimit = 30 // Max 30 images in memory (reduced from 100)
        
        // Setup disk cache directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        diskCacheURL = documentsPath.appendingPathComponent("ReceiptImageCache")
        
        // Create cache directory if needed
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        
        print("📁 ImageCacheManager initialized with cache at: \(diskCacheURL.path)")
        setupMemoryWarningObserver()
    }
    
    // MARK: - Public Interface
    
    /// Store image with automatic optimization and caching
    func storeImage(_ image: UIImage, forKey key: String, completion: @escaping (Bool) -> Void = { _ in }) {
        cacheQueue.async { [weak self] in
            guard let self = self else { 
                DispatchQueue.main.async { completion(false) }
                return 
            }
            
            // Optimize image size and compression
            let optimizedImage = self.optimizeImage(image)
            
            // Store in memory cache
            let cost = self.estimateImageMemorySize(optimizedImage)
            self.memoryCache.setObject(optimizedImage, forKey: key as NSString, cost: cost)
            
            // Store to disk asynchronously
            self.storeToDisk(optimizedImage, key: key) { success in
                DispatchQueue.main.async { completion(success) }
            }
        }
    }
    
    /// Retrieve image with automatic fallback from memory -> disk
    func retrieveImage(forKey key: String, completion: @escaping (UIImage?) -> Void) {
        // Check memory cache first (fastest)
        if let cachedImage = memoryCache.object(forKey: key as NSString) {
            memoryHits += 1
            completion(cachedImage)
            return
        }
        
        // Check disk cache (background thread)
        cacheQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            let diskURL = self.diskCacheURL.appendingPathComponent("\(key).jpg")
            
            if let data = try? Data(contentsOf: diskURL),
               let image = UIImage(data: data) {
                // Found on disk - add back to memory cache
                let cost = self.estimateImageMemorySize(image)
                self.memoryCache.setObject(image, forKey: key as NSString, cost: cost)
                self.diskHits += 1
                
                DispatchQueue.main.async { completion(image) }
            } else {
                self.misses += 1
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
    
    /// Remove image from both memory and disk cache
    func removeImage(forKey key: String) {
        memoryCache.removeObject(forKey: key as NSString)
        
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            let diskURL = self.diskCacheURL.appendingPathComponent("\(key).jpg")
            try? FileManager.default.removeItem(at: diskURL)
        }
    }
    
    /// Clear all cached images
    func clearCache() {
        memoryCache.removeAllObjects()
        
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            try? FileManager.default.removeItem(at: self.diskCacheURL)
            try? FileManager.default.createDirectory(at: self.diskCacheURL, withIntermediateDirectories: true)
        }
        
        // Reset metrics
        memoryHits = 0
        diskHits = 0
        misses = 0
        
        print("🗑️ Image cache cleared")
    }
    
    // MARK: - Cache Statistics
    
    func getCacheStatistics() -> (memoryHits: Int, diskHits: Int, misses: Int, hitRate: Double) {
        let total = memoryHits + diskHits + misses
        let hitRate = total > 0 ? Double(memoryHits + diskHits) / Double(total) * 100 : 0
        return (memoryHits, diskHits, misses, hitRate)
    }
    
    func getCacheSize() -> (memorySize: Int, diskSize: Int) {
        let memorySize = memoryCache.totalCostLimit
        
        var diskSize = 0
        cacheQueue.sync {
            if let files = try? FileManager.default.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: [.fileSizeKey]) {
                for file in files {
                    if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        diskSize += size
                    }
                }
            }
        }
        
        return (memorySize, diskSize)
    }
    
    // MARK: - Private Methods
    
    private func optimizeImage(_ image: UIImage) -> UIImage {
        // Resize if image is too large
        let size = image.size
        if size.width > maxImageSize.width || size.height > maxImageSize.height {
            let scale = min(maxImageSize.width / size.width, maxImageSize.height / size.height)
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return resizedImage ?? image
        }
        
        return image
    }
    
    private func storeToDisk(_ image: UIImage, key: String, completion: @escaping (Bool) -> Void) {
        guard let data = image.jpegData(compressionQuality: compressionQuality) else {
            completion(false)
            return
        }
        
        let diskURL = diskCacheURL.appendingPathComponent("\(key).jpg")
        
        do {
            try data.write(to: diskURL)
            completion(true)
        } catch {
            print("❌ Failed to store image to disk: \(error)")
            completion(false)
        }
    }
    
    private func estimateImageMemorySize(_ image: UIImage) -> Int {
        let size = image.size
        let scale = image.scale
        return Int(size.width * scale * size.height * scale * 4) // 4 bytes per pixel (RGBA)
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    private func handleMemoryWarning() {
        print("⚠️ Memory warning - clearing image cache")
        memoryCache.removeAllObjects()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Convenience Extensions

extension ImageCacheManager {
    /// Generate cache key from transaction ID
    static func cacheKey(for transactionId: UUID) -> String {
        return "receipt_\(transactionId.uuidString)"
    }
    
    /// Store receipt image for transaction
    func storeReceiptImage(_ image: UIImage, for transactionId: UUID, completion: @escaping (Bool) -> Void = { _ in }) {
        let key = ImageCacheManager.cacheKey(for: transactionId)
        storeImage(image, forKey: key, completion: completion)
    }
    
    /// Retrieve receipt image for transaction
    func retrieveReceiptImage(for transactionId: UUID, completion: @escaping (UIImage?) -> Void) {
        let key = ImageCacheManager.cacheKey(for: transactionId)
        retrieveImage(forKey: key, completion: completion)
    }
    
    /// Remove receipt image for transaction
    func removeReceiptImage(for transactionId: UUID) {
        let key = ImageCacheManager.cacheKey(for: transactionId)
        removeImage(forKey: key)
    }
}