//
//  EmailConfirmationViewContainer.swift
//  CashMonki
//
//  Created by Claude on 1/22/25.
//

import SwiftUI

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

struct EmailConfirmationViewContainer: View {
    let email: String
    @Binding var isPresented: Bool
    @Binding var currentStep: OnboardingStep
    @Binding var isNavigatingForward: Bool
    let onBack: (() -> Void)?
    
    var body: some View {
        Group {
            // CRITICAL FIX: Skip email verification for already verified users
            let isAlreadyVerified = checkEmailVerification()
            
            if isAlreadyVerified {
                // Show loading view while auto-advancing
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Email already verified!")
                        .font(.headline)
                        .foregroundColor(.green)
                }
                .onAppear {
                    print("✅ EmailConfirmationViewContainer: User already verified - auto-advancing")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        print("🚀 EmailConfirmationViewContainer: Starting auto-advancement...")
                        
                        // CRITICAL: For already verified users, check if they need progression advancement
                        let currentProgress = UserManager.shared.currentUser.onboardingCompleted
                        print("🔢 EmailConfirmationViewContainer: Current progression: \(currentProgress)")
                        
                        if currentProgress == 0 {
                            print("🔢 EmailConfirmationViewContainer: Setting progression to 1 (email verified)")
                            OnboardingStateManager.shared.setOnboardingProgress(to: 1)
                        }
                        
                        // Get next step using numerical progression system
                        let nextStep = OnboardingStateManager.shared.getCurrentOnboardingStep()
                        print("🔢 EmailConfirmationViewContainer: Next step determined: \(nextStep)")
                        
                        isNavigatingForward = true
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = nextStep
                        }
                    }
                }
            } else {
                EmailConfirmationView(
                    isPresented: $isPresented,
                    email: email,
                    onConfirmed: {
                        print("✅ EmailConfirmationViewContainer: Email confirmation completed")
                        
                        // Set persistent flag for app resume scenarios
                        UserDefaults.standard.set(true, forKey: "hasCompletedEmailVerification")
                        print("💾 EmailConfirmationViewContainer: Email verification completion flag saved to UserDefaults")
                        
                        print("➡️ EmailConfirmationViewContainer: Moving to next step")
                        isNavigatingForward = true
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            // Set progression to 1 (email verified)
                            OnboardingStateManager.shared.setOnboardingProgress(to: 1)
                            let nextStep = OnboardingStateManager.shared.getCurrentOnboardingStep()
                            print("🔢 EmailConfirmationViewContainer: Next step determined: \(nextStep)")
                            currentStep = nextStep
                        }
                    },
                    onBack: onBack
                )
            }
        }
    }
    
    /// Check if the current user's email is already verified
    private func checkEmailVerification() -> Bool {
        #if canImport(FirebaseAuth)
        guard let currentUser = Auth.auth().currentUser else {
            print("❌ EmailConfirmationViewContainer: No current user found")
            return false
        }
        
        let isVerified = currentUser.isEmailVerified
        print("🔍 EmailConfirmationViewContainer: Email verification status: \(isVerified)")
        return isVerified
        #else
        print("⚠️ EmailConfirmationViewContainer: Firebase Auth not available - assuming not verified")
        return false
        #endif
    }
}