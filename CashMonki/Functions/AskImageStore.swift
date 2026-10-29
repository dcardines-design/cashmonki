//
//  AskImageStore.swift
//  CashMonki
//
//  Photos attached to Ask messages. Stored on this device only (Documents/ask_images),
//  keyed by id. The chat file and its cloud mirror carry just the ids, so a photo only
//  leaves the phone in the request for the turn it was attached to.
//

import UIKit

enum AskImageStore {
    /// Long side of what the model sees: enough to read a receipt, small enough that several
    /// photos stay well under the proxy's request size limit.
    static let maxPixelSize: CGFloat = 1568
    static let jpegQuality: CGFloat = 0.7
    static let maxPhotosPerMessage = 4

    private static var directory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ask_images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func fileURL(for id: String) -> URL {
        directory.appendingPathComponent("\(id).jpg")
    }

    /// Downscales, saves and returns the new id. Heavy: call off the main thread.
    static func save(_ image: UIImage) -> String? {
        guard let data = jpegData(for: image) else { return nil }
        let id = UUID().uuidString
        do {
            try data.write(to: fileURL(for: id), options: .atomic)
        } catch {
            print("🔴 AskImageStore: Failed to save photo: \(error)")
            return nil
        }
        return id
    }

    static func data(for id: String) -> Data? {
        try? Data(contentsOf: fileURL(for: id))
    }

    static func image(for id: String) -> UIImage? {
        data(for: id).flatMap(UIImage.init(data:))
    }

    static func delete(_ ids: [String]) {
        for id in ids {
            try? FileManager.default.removeItem(at: fileURL(for: id))
        }
    }

    /// Removes photos no message refers to any more (trimmed out of the 100-message history).
    /// Files newer than an hour are kept, since the composer may be holding them unsent.
    static func pruneOrphans(keeping referenced: Set<String>) {
        let cutoff = Date().addingTimeInterval(-3600)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        for file in files {
            let id = file.deletingPathExtension().lastPathComponent
            guard !referenced.contains(id) else { continue }
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if let modified, modified > cutoff { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }

    /// Redraws at most `maxPixelSize` on the long side. Drawing also bakes in the camera's
    /// orientation, so the model never sees a sideways receipt.
    private static func jpegData(for image: UIImage) -> Data? {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let longest = max(pixelWidth, pixelHeight)
        guard longest > 0 else { return nil }
        let ratio = min(1, maxPixelSize / longest)
        let target = CGSize(width: (pixelWidth * ratio).rounded(), height: (pixelHeight * ratio).rounded())

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: jpegQuality)
    }
}
