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

    func makeUIView(context: Context) -> GifContainerView {
        let containerView = GifContainerView()
        containerView.configure(gifName: gifName)
        return containerView
    }

    func updateUIView(_ uiView: GifContainerView, context: Context) {
        // Ensure animation keeps playing
        if !uiView.imageView.isAnimating, uiView.imageView.animationImages != nil {
            uiView.imageView.startAnimating()
        }
    }
}

// MARK: - Container View with Auto Layout

class GifContainerView: UIView {
    let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupImageView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupImageView()
    }

    private func setupImageView() {
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        // Pin imageView to all edges of container
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    // Return no intrinsic size to fully defer to SwiftUI's sizing
    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    func configure(gifName: String) {
        if let gifImage = loadGif(name: gifName) {
            imageView.image = gifImage
            if let images = gifImage.images {
                imageView.animationImages = images
                imageView.animationDuration = gifImage.duration
                imageView.animationRepeatCount = 0 // Loop forever
                imageView.startAnimating()
            }
        }
    }

    private func loadGif(name: String) -> UIImage? {
        // Try NSDataAsset first (for assets in xcassets)
        var imageData: Data?

        if let dataAsset = NSDataAsset(name: name) {
            print("✅ GifImageView: Loading '\(name)' from NSDataAsset")
            imageData = dataAsset.data
        }
        // Fallback to bundle resource
        else if let bundleURL = Bundle.main.url(forResource: name, withExtension: "gif") {
            print("✅ GifImageView: Loading '\(name)' from bundle")
            imageData = try? Data(contentsOf: bundleURL)
        }

        guard let data = imageData,
              let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            print("❌ GifImageView: Failed to load '\(name)'")
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