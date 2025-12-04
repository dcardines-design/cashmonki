//
//  AnimatedImageView.swift
//  CashMonki
//
//  Supports both GIF and Lottie animations for toast notifications
//

import SwiftUI
import UIKit
import ImageIO

struct AnimatedImageView: UIViewRepresentable {
    let fileName: String
    let animationSpeed: CGFloat
    @Binding var isPlaying: Bool
    
    enum AnimationType {
        case gif
        case lottie
        
        init(fileName: String) {
            if fileName.hasSuffix(".gif") || fileName.contains("-gif") {
                self = .gif
            } else {
                self = .lottie
            }
        }
    }
    
    private var animationType: AnimationType {
        AnimationType(fileName: fileName)
    }
    
    func makeUIView(context: Context) -> UIView {
        print("🏗️ DEBUG: Creating AnimatedImageView with fileName: '\(fileName)'")
        print("🎯 DEBUG: Detected animation type: \(animationType)")
        let containerView = UIView()
        
        switch animationType {
        case .gif:
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            imageView.backgroundColor = UIColor.red.withAlphaComponent(0.2) // Debug background
            containerView.addSubview(imageView)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
                imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
            
            if let gifImage = loadGIF(named: fileName) {
                print("✅ DEBUG: GIF loaded successfully, setting to imageView")
                imageView.image = gifImage
                // Adjust animation speed
                if let animationImages = gifImage.images {
                    imageView.animationImages = animationImages
                    let originalDuration = gifImage.duration
                    imageView.animationDuration = originalDuration / Double(animationSpeed)
                    imageView.animationRepeatCount = 0 // Infinite loop
                    print("🎬 DEBUG: Animation configured - \(animationImages.count) frames, \(originalDuration)s duration")
                }
            } else {
                print("❌ DEBUG: Failed to load GIF, imageView will be empty")
            }
            
        case .lottie:
            // Fall back to SmoothLottieView for Lottie files
            // This will be handled in updateUIView
            break
        }
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        switch animationType {
        case .gif:
            if let imageView = uiView.subviews.first as? UIImageView {
                if isPlaying {
                    imageView.startAnimating()
                } else {
                    imageView.stopAnimating()
                }
            }
            
        case .lottie:
            // For Lottie files, we'll use the existing SmoothLottieView
            // This case shouldn't be reached since we'll use SmoothLottieView directly
            break
        }
    }
    
    private func loadGIF(named name: String) -> UIImage? {
        print("🔍 DEBUG: Attempting to load GIF named: '\(name)'")
        
        // Try multiple NSDataAsset name variations
        let assetNameVariations = [name, name.replacingOccurrences(of: "-gif", with: "")]
        
        for assetName in assetNameVariations {
            if let dataAsset = NSDataAsset(name: assetName) {
                print("✅ Loading GIF from NSDataAsset: \(assetName)")
                let animatedImage = UIImage.animatedImageWithData(dataAsset.data)
                print("🎬 DEBUG: Animated image created: \(animatedImage != nil ? "SUCCESS" : "FAILED")")
                if animatedImage != nil {
                    return animatedImage
                }
            } else {
                print("❌ Could not find NSDataAsset named: \(assetName)")
            }
        }
        
        // Fallback to bundle resource
        let resourceName = name.replacingOccurrences(of: ".gif", with: "")
        guard let bundleURL = Bundle.main.url(forResource: resourceName, withExtension: "gif") else {
            print("❌ Could not find GIF file: \(name)")
            return nil
        }
        
        guard let imageData = try? Data(contentsOf: bundleURL) else {
            print("❌ Could not load GIF data: \(name)")
            return nil
        }
        
        print("✅ Loading GIF from bundle: \(name)")
        return UIImage.animatedImageWithData(imageData)
    }
}

// Extension to create animated UIImage from GIF data
extension UIImage {
    static func animatedImageWithData(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        
        let frameCount = CGImageSourceGetCount(source)
        var images: [UIImage] = []
        var totalDuration: Double = 0
        
        for i in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else {
                continue
            }
            
            let image = UIImage(cgImage: cgImage)
            images.append(image)
            
            // Get frame duration
            guard let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                  let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any],
                  let frameDuration = gifProperties[kCGImagePropertyGIFDelayTime as String] as? Double else {
                totalDuration += 0.1 // Default frame duration
                continue
            }
            
            totalDuration += frameDuration
        }
        
        guard !images.isEmpty else { return nil }
        
        return UIImage.animatedImage(with: images, duration: totalDuration)
    }
}

// MARK: - Toast-specific convenience initializers

extension AnimatedImageView {
    static func toastScanning(animationSpeed: CGFloat = 2.0, isPlaying: Binding<Bool> = .constant(true)) -> AnimatedImageView {
        AnimatedImageView(
            fileName: "toast-scanning.gif", // Change this to your GIF file name
            animationSpeed: animationSpeed,
            isPlaying: isPlaying
        )
    }
    
    static func toastDone(animationSpeed: CGFloat = 1.0, isPlaying: Binding<Bool> = .constant(true)) -> AnimatedImageView {
        AnimatedImageView(
            fileName: "toast-done.gif", // Change this to your GIF file name
            animationSpeed: animationSpeed,
            isPlaying: isPlaying
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        Text("Animated Toast Previews")
            .font(.title2)
        
        AnimatedImageView.toastScanning()
            .frame(width: 109, height: 68)
        
        AnimatedImageView.toastDone()
            .frame(width: 109, height: 68)
    }
    .padding()
}