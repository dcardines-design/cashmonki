//
//  OnboardingProgressBar.swift
//  CashMonki
//
//  Created by Claude on 12/3/25.
//

import SwiftUI

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

/// Reusable progress bar component for onboarding flow
struct OnboardingProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    let percentage: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color(hex: "F3F5F8") ?? Color.gray.opacity(0.3))
                    .frame(height: 4)
                
                // Progress fill
                Rectangle()
                    .fill(Color(hex: "542EFF") ?? Color.blue)
                    .frame(width: geometry.size.width * percentage, height: 4)
                    .animation(.easeInOut(duration: 0.3), value: percentage)
            }
        }
        .frame(height: 4)
        .onAppear {
            print("📊 OnboardingProgressBar: Step \(currentStep) of \(totalSteps) (\(String(format: "%.1f", percentage * 100))%)")
        }
    }
}

/// Extension to provide progress calculation from OnboardingFlow
extension OnboardingProgressBar {
    
    /// Create progress bar with automatic calculation based on current step and user type
    static func dynamic(
        currentStep: OnboardingStep,
        isGmailUser: Bool = false
    ) -> OnboardingProgressBar {
        
        // Calculate progress based on user type
        let progress = calculateDynamicProgress(currentStep: currentStep, isGmailUser: isGmailUser)
        
        return OnboardingProgressBar(
            currentStep: progress.current,
            totalSteps: progress.total,
            percentage: progress.percentage
        )
    }
    
    /// Calculate progress based on current step and user type
    private static func calculateDynamicProgress(
        currentStep: OnboardingStep,
        isGmailUser: Bool
    ) -> (current: Int, total: Int, percentage: Double) {
        
        // CURRENT: No-auth flow - 4 steps only (email step removed)
        // Steps: Name → Currency → Goals → Transaction
        let userSteps: [OnboardingStep] = [
            .nameCollection,
            .currencySelection,
            .goalSelection,
            .transactionAddition
        ]

        // FUTURE: Auth flow - uncomment when re-enabling email verification
        // var userSteps: [OnboardingStep] = [.emailConfirmation]
        // if currentStep == .nameCollection || !isGmailUser || shouldShowNameForGmailUser() {
        //     userSteps.append(.nameCollection)
        // }
        // userSteps.append(contentsOf: [.currencySelection, .goalSelection, .transactionAddition])
        
        // Find current position
        guard let currentIndex = userSteps.firstIndex(of: currentStep) else {
            // If step not found, default to step 1 for safety
            print("⚠️ OnboardingProgressBar: Step \(currentStep) not found in userSteps: \(userSteps)")
            return (current: 1, total: userSteps.count, percentage: Double(1) / Double(userSteps.count))
        }
        
        let currentStepNumber = currentIndex + 1
        let totalSteps = userSteps.count
        let percentage = Double(currentStepNumber) / Double(totalSteps)
        
        print("📊 OnboardingProgressBar: \(currentStep) → Step \(currentStepNumber)/\(totalSteps) (\(String(format: "%.1f", percentage * 100))%)")
        print("   - User steps: \(userSteps)")
        print("   - Is Gmail user: \(isGmailUser)")
        print("   - Current step index: \(currentIndex)")
        print("   - Should show name for Gmail: \(shouldShowNameForGmailUser())")
        
        return (current: currentStepNumber, total: totalSteps, percentage: percentage)
    }
    
    /// Check if Gmail user needs name collection
    /// CURRENT: Always true in no-auth flow
    private static func shouldShowNameForGmailUser() -> Bool {
        // FUTURE: Uncomment when re-enabling authentication
        // #if canImport(FirebaseAuth)
        // guard let currentUser = Auth.auth().currentUser,
        //       let displayName = currentUser.displayName else {
        //     return true
        // }
        // let components = displayName.components(separatedBy: " ")
        // return components.count < 2 || components.contains { $0.isEmpty }
        // #endif
        return true
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        OnboardingProgressBar(currentStep: 1, totalSteps: 4, percentage: 0.25)
        OnboardingProgressBar(currentStep: 2, totalSteps: 4, percentage: 0.5)
        OnboardingProgressBar(currentStep: 3, totalSteps: 4, percentage: 0.75) 
        OnboardingProgressBar(currentStep: 4, totalSteps: 4, percentage: 1.0)
    }
    .padding()
}