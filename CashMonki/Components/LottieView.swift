//
//  LottieView.swift
//  CashMonki
//
//  A SwiftUI wrapper for Lottie animations
//

import SwiftUI
import Lottie

struct LottieView: UIViewRepresentable {
    let animationName: String
    let loopMode: LottieLoopMode
    let animationSpeed: CGFloat
    let contentMode: UIView.ContentMode
    @Binding var isPlaying: Bool
    
    init(
        animationName: String,
        loopMode: LottieLoopMode = .loop,
        animationSpeed: CGFloat = 1.0,
        contentMode: UIView.ContentMode = .scaleAspectFit,
        isPlaying: Binding<Bool> = .constant(true)
    ) {
        self.animationName = animationName
        self.loopMode = loopMode
        self.animationSpeed = animationSpeed
        self.contentMode = contentMode
        self._isPlaying = isPlaying
    }
    
    func makeUIView(context: Context) -> LottieAnimationView {
        let animationView = LottieAnimationView()
        
        // Load animation from bundle
        if let animation = LottieAnimation.named(animationName) {
            animationView.animation = animation
        }
        
        animationView.loopMode = loopMode
        animationView.animationSpeed = animationSpeed
        animationView.contentMode = contentMode
        
        // Remove the problematic respectAnimationFrameRate property
        // animationView.respectAnimationFrameRate = true
        
        return animationView
    }
    
    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        if isPlaying {
            uiView.play()
        } else {
            uiView.pause()
        }
    }
}

// MARK: - Convenience Initializers

extension LottieView {
    // Loading animation
    static func loading(isPlaying: Binding<Bool> = .constant(true)) -> LottieView {
        LottieView(
            animationName: "loading",
            loopMode: .loop,
            animationSpeed: 1.2,
            isPlaying: isPlaying
        )
    }
    
    // Success animation
    static func success(isPlaying: Binding<Bool> = .constant(true)) -> LottieView {
        LottieView(
            animationName: "success",
            loopMode: .playOnce,
            animationSpeed: 1.0,
            isPlaying: isPlaying
        )
    }
    
    // Error animation
    static func error(isPlaying: Binding<Bool> = .constant(true)) -> LottieView {
        LottieView(
            animationName: "error",
            loopMode: .playOnce,
            animationSpeed: 1.0,
            isPlaying: isPlaying
        )
    }
    
    // Empty state animation
    static func emptyState(isPlaying: Binding<Bool> = .constant(true)) -> LottieView {
        LottieView(
            animationName: "empty-state",
            loopMode: .loop,
            animationSpeed: 0.8,
            isPlaying: isPlaying
        )
    }
    
    // Receipt scanning animation
    static func receiptScanning(isPlaying: Binding<Bool> = .constant(true)) -> LottieView {
        LottieView(
            animationName: "receipt-scan",
            loopMode: .loop,
            animationSpeed: 1.0,
            isPlaying: isPlaying
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        Text("Lottie Animations")
            .font(.title)
        
        // Example usage - uncomment after adding animations
        /*
        LottieView.loading()
            .frame(width: 100, height: 100)
        
        LottieView.success()
            .frame(width: 100, height: 100)
        
        LottieView.emptyState()
            .frame(width: 200, height: 150)
        */
        
        Text("Add Lottie animations to Assets.xcassets")
            .foregroundColor(.secondary)
    }
    .padding()
}