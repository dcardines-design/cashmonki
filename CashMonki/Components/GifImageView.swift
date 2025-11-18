//
//  GifImageView.swift
//  CashMonki
//
//  SwiftUI wrapper for displaying GIF animations
//

import SwiftUI
import UIKit
import ImageIO

struct GifImageView: UIViewRepresentable {
    let gifName: String
    let size: CGSize
    
    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        
        if let gifImage = loadGif(name: gifName) {
            imageView.image = gifImage
        }
        
        return imageView
    }
    
    func updateUIView(_ uiView: UIImageView, context: Context) {
        // No updates needed for static gif loading
    }
    
    private func loadGif(name: String) -> UIImage? {
        guard let bundleURL = Bundle.main.url(forResource: name, withExtension: "gif"),
              let imageData = try? Data(contentsOf: bundleURL),
              let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return nil
        }
        
        var images: [UIImage] = []
        let count = CGImageSourceGetCount(source)
        var totalDuration: TimeInterval = 0
        
        for i in 0..<count {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                let image = UIImage(cgImage: cgImage)
                images.append(image)
                
                // Get frame duration
                if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                   let gifDict = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any],
                   let frameDuration = gifDict[kCGImagePropertyGIFDelayTime as String] as? Double {
                    totalDuration += frameDuration
                } else {
                    totalDuration += 0.1 // Default frame duration
                }
            }
        }
        
        return UIImage.animatedImage(with: images, duration: totalDuration)
    }
}

// MARK: - Convenience Initializers

extension GifImageView {
    static func scanning(size: CGSize = CGSize(width: 24, height: 24)) -> GifImageView {
        GifImageView(gifName: "toast-scanning", size: size)
    }
    
    static func done(size: CGSize = CGSize(width: 24, height: 24)) -> GifImageView {
        GifImageView(gifName: "toast-done", size: size)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        GifImageView.scanning(size: CGSize(width: 50, height: 50))
        GifImageView.done(size: CGSize(width: 50, height: 50))
    }
    .padding()
}