//
//  SmoothLottieView.swift
//  CashMonki
//
//  Enhanced Lottie view with smooth easing curves
//

import SwiftUI
import Lottie

struct SmoothLottieView: UIViewRepresentable {
    let animationName: String
    let loopMode: LottieLoopMode
    let easingType: EasingType
    let animationSpeed: CGFloat
    @Binding var isPlaying: Bool
    
    enum EasingType {
        case linear
        case easeIn
        case easeOut
        case easeInOut
        case bounce
        case elastic
        
        var timingFunction: CAMediaTimingFunction {
            switch self {
            case .linear:
                return CAMediaTimingFunction(name: .linear)
            case .easeIn:
                return CAMediaTimingFunction(name: .easeIn)
            case .easeOut:
                return CAMediaTimingFunction(name: .easeOut)
            case .easeInOut:
                return CAMediaTimingFunction(name: .easeInEaseOut)
            case .bounce:
                return CAMediaTimingFunction(controlPoints: 0.68, -0.55, 0.265, 1.55)
            case .elastic:
                return CAMediaTimingFunction(controlPoints: 0.175, 0.885, 0.32, 1.275)
            }
        }
        
        var speedCurve: [Double] {
            switch self {
            case .linear:
                return [1.0] // Constant speed
            case .easeIn:
                return [0.2, 0.5, 0.8, 1.2] // More pronounced slow start, fast end
            case .easeOut:
                return [1.0, 0.6, 0.3] // Fast start, slow end
            case .easeInOut:
                return [0.3, 1.0, 0.3] // Slow-fast-slow
            case .bounce:
                return [0.5, 1.2, 0.8, 1.1, 0.9, 1.0] // Bouncy
            case .elastic:
                return [0.2, 1.3, 0.7, 1.1, 0.9, 1.0] // Elastic
            }
        }
    }
    
    init(
        animationName: String,
        loopMode: LottieLoopMode = .loop,
        easingType: EasingType = .easeInOut,
        animationSpeed: CGFloat = 1.0,
        isPlaying: Binding<Bool> = .constant(true)
    ) {
        self.animationName = animationName
        self.loopMode = loopMode
        self.easingType = easingType
        self.animationSpeed = animationSpeed
        self._isPlaying = isPlaying
    }
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        let animationView = LottieAnimationView()
        
        // Load animation from bundle
        if let animation = LottieAnimation.named(animationName) {
            animationView.animation = animation
        }
        
        animationView.loopMode = loopMode
        animationView.contentMode = .scaleAspectFit
        // Remove problematic respectAnimationFrameRate property
        // animationView.respectAnimationFrameRate = true
        
        // Apply smooth timing and base speed
        animationView.layer.speed = Float(animationSpeed)
        animationView.animationSpeed = animationSpeed
        
        containerView.addSubview(animationView)
        animationView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: containerView.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Store initial animation name hash for comparison
        containerView.tag = animationName.hashValue
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let animationView = uiView.subviews.first as? LottieAnimationView else { return }
        
        // Store current animation name in container view tag for comparison
        let currentAnimationNameHash = animationName.hashValue
        
        // Check if animation needs to be reloaded (animation name changed)
        if uiView.tag != currentAnimationNameHash {
            print("🎬 DEBUG: Animation name changed to: \(animationName), reloading...")
            if let newAnimation = LottieAnimation.named(animationName) {
                animationView.animation = newAnimation
                animationView.loopMode = loopMode
                animationView.animationSpeed = animationSpeed
                uiView.tag = currentAnimationNameHash // Store new animation name hash
                print("🎬 DEBUG: Animation reloaded successfully")
            } else {
                print("❌ DEBUG: Failed to load animation: \(animationName)")
            }
        }
        
        if isPlaying {
            // Only start playing if not already playing
            if !animationView.isAnimationPlaying {
                animationView.play { _ in
                    // Animation completed
                }
                // Apply simple easing curve
                print("🎬 DEBUG: Starting animation with easing type: \(easingType), speed: \(animationSpeed)")
                applyEasingCurve(to: animationView)
            }
        } else {
            animationView.pause()
        }
    }
    
    private func applyEasingCurve(to animationView: LottieAnimationView) {
        // Apply the easing curve from the enum
        let speedCurve = easingType.speedCurve
        
        if speedCurve.count > 1 {
            let duration = animationView.animation?.duration ?? 1.0
            
            // For looping animations, apply easing curve to each loop
            if loopMode == .loop {
                applyContinuousEasing(to: animationView, speedCurve: speedCurve, loopDuration: duration)
            } else {
                // For single playback, apply easing once
                applySingleEasing(to: animationView, speedCurve: speedCurve, duration: duration)
            }
        }
    }
    
    private func applyContinuousEasing(to animationView: LottieAnimationView, speedCurve: [Double], loopDuration: Double) {
        // Calculate actual playback duration accounting for speed multiplier
        let actualLoopDuration = loopDuration / Double(animationSpeed)
        let stepDuration = actualLoopDuration / Double(speedCurve.count)
        var currentLoop = 0
        
        print("🎬 DEBUG: Original duration: \(loopDuration)s, Speed: \(animationSpeed)x, Actual duration: \(actualLoopDuration)s")
        
        func scheduleNextLoop() {
            print("🎬 DEBUG: Scheduling loop \(currentLoop) with actual duration \(actualLoopDuration)s")
            // Apply easing curve for this loop
            for (index, speed) in speedCurve.enumerated() {
                let delay = (Double(currentLoop) * actualLoopDuration) + (stepDuration * Double(index))
                print("🎬 DEBUG: Scheduling step \(index) at delay \(delay)s with speed \(speed)")
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    // Only apply if animation is still playing
                    if animationView.isAnimationPlaying {
                        let finalSpeed = CGFloat(speed) * animationSpeed
                        animationView.animationSpeed = finalSpeed
                        print("🎬 APPLIED: Loop \(currentLoop), Step \(index): Speed = \(finalSpeed)")
                    } else {
                        print("🎬 SKIPPED: Animation no longer playing")
                    }
                }
            }
            
            // Schedule next loop
            currentLoop += 1
            let nextLoopDelay = Double(currentLoop) * actualLoopDuration
            DispatchQueue.main.asyncAfter(deadline: .now() + nextLoopDelay) {
                if animationView.isAnimationPlaying {
                    scheduleNextLoop()
                }
            }
        }
        
        scheduleNextLoop()
    }
    
    private func applySingleEasing(to animationView: LottieAnimationView, speedCurve: [Double], duration: Double) {
        let stepDuration = duration / Double(speedCurve.count)
        
        for (index, speed) in speedCurve.enumerated() {
            let delay = stepDuration * Double(index)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                animationView.animationSpeed = CGFloat(speed) * animationSpeed
            }
        }
    }
    
}

// MARK: - Convenience Initializers for Toast

extension SmoothLottieView {
    static func toastScanning(animationSpeed: CGFloat = 2.0, isPlaying: Binding<Bool> = .constant(true)) -> SmoothLottieView {
        SmoothLottieView(
            animationName: "toast-scanning",
            loopMode: .loop,
            easingType: .easeIn,
            animationSpeed: animationSpeed,
            isPlaying: isPlaying
        )
    }
    
    static func toastDone(animationSpeed: CGFloat = 1.5, isPlaying: Binding<Bool> = .constant(true)) -> SmoothLottieView {
        SmoothLottieView(
            animationName: "toast-done",
            loopMode: .playOnce,
            easingType: .bounce,
            animationSpeed: animationSpeed,
            isPlaying: isPlaying
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        Text("Smooth Lottie Animations")
            .font(.title2)
        
        SmoothLottieView.toastScanning()
            .frame(width: 50, height: 50)
        
        SmoothLottieView.toastDone()
            .frame(width: 50, height: 50)
    }
    .padding()
}