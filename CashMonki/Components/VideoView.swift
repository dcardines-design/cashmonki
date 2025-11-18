//
//  VideoView.swift
//  CashMonki
//
//  SwiftUI wrapper for displaying MP4 video animations
//

import SwiftUI
import AVKit
import AVFoundation

struct VideoView: UIViewRepresentable {
    let videoName: String
    let shouldLoop: Bool
    let size: CGSize
    @Binding var isPlaying: Bool
    
    init(
        videoName: String,
        shouldLoop: Bool = true,
        size: CGSize = CGSize(width: 24, height: 24),
        isPlaying: Binding<Bool> = .constant(true)
    ) {
        self.videoName = videoName
        self.shouldLoop = shouldLoop
        self.size = size
        self._isPlaying = isPlaying
    }
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        
        guard let path = Bundle.main.path(forResource: videoName, ofType: "mp4") else {
            print("❌ Could not find video: \(videoName).mp4")
            return containerView
        }
        
        let url = URL(fileURLWithPath: path)
        let player = AVPlayer(url: url)
        let playerLayer = AVPlayerLayer(player: player)
        
        // Configure player layer
        playerLayer.videoGravity = .resizeAspect
        playerLayer.frame = CGRect(origin: .zero, size: size)
        
        // Store player reference in the view
        containerView.layer.addSublayer(playerLayer)
        containerView.tag = player.hashValue // Store player reference
        
        // Set up looping if needed
        if shouldLoop {
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { _ in
                player.seek(to: .zero)
                if self.isPlaying {
                    player.play()
                }
            }
        }
        
        // Auto-play if needed
        if isPlaying {
            player.play()
        }
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Find the player layer
        guard let playerLayer = uiView.layer.sublayers?.first as? AVPlayerLayer,
              let player = playerLayer.player else { return }
        
        if isPlaying {
            player.play()
        } else {
            player.pause()
        }
    }
}

// MARK: - Convenience Initializers

extension VideoView {
    static func scanning(
        size: CGSize = CGSize(width: 24, height: 24),
        isPlaying: Binding<Bool> = .constant(true)
    ) -> VideoView {
        VideoView(
            videoName: "toast-scanning",
            shouldLoop: true,
            size: size,
            isPlaying: isPlaying
        )
    }
    
    static func done(
        size: CGSize = CGSize(width: 24, height: 24),
        isPlaying: Binding<Bool> = .constant(true)
    ) -> VideoView {
        VideoView(
            videoName: "toast-done",
            shouldLoop: false,
            size: size,
            isPlaying: isPlaying
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        VideoView.scanning(size: CGSize(width: 50, height: 50))
        VideoView.done(size: CGSize(width: 50, height: 50))
    }
    .padding()
}