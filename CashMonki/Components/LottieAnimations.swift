//
//  LottieAnimations.swift
//  CashMonki
//
//  Predefined Lottie animations for common app scenarios
//

import SwiftUI

// MARK: - Lottie Animation Manager

struct LottieAnimations {
    
    // MARK: - Receipt Processing Animations
    
    /// Loading animation for receipt analysis
    static func receiptAnalyzing(isPlaying: Binding<Bool> = .constant(true)) -> some View {
        VStack(spacing: 16) {
            LottieView(
                animationName: "receipt-scanning", // Add this .json file to Assets
                loopMode: .loop,
                animationSpeed: 1.2,
                isPlaying: isPlaying
            )
            .frame(width: 120, height: 120)
            
            Text("Analyzing receipt...")
                .font(AppFonts.overusedGroteskMedium(size: 16))
                .foregroundColor(AppColors.foregroundSecondary)
        }
    }
    
    /// Success animation when receipt is processed
    static func receiptSuccess(isPlaying: Binding<Bool> = .constant(true)) -> some View {
        VStack(spacing: 16) {
            LottieView(
                animationName: "checkmark-success", // Add this .json file to Assets
                loopMode: .playOnce,
                animationSpeed: 1.0,
                isPlaying: isPlaying
            )
            .frame(width: 100, height: 100)
            
            Text("Receipt processed!")
                .font(AppFonts.overusedGroteskSemiBold(size: 18))
                .foregroundColor(AppColors.successForeground)
        }
    }
    
    /// Error animation when receipt processing fails
    static func receiptError(isPlaying: Binding<Bool> = .constant(true)) -> some View {
        VStack(spacing: 16) {
            LottieView(
                animationName: "error-warning", // Add this .json file to Assets
                loopMode: .playOnce,
                animationSpeed: 1.0,
                isPlaying: isPlaying
            )
            .frame(width: 100, height: 100)
            
            Text("Processing failed")
                .font(AppFonts.overusedGroteskSemiBold(size: 18))
                .foregroundColor(AppColors.errorForeground)
        }
    }
    
    // MARK: - Transaction & Money Animations
    
    /// Money flowing animation for transaction success
    static func transactionSuccess(isPlaying: Binding<Bool> = .constant(true)) -> some View {
        LottieView(
            animationName: "money-flow", // Add this .json file to Assets
            loopMode: .playOnce,
            animationSpeed: 1.0,
            isPlaying: isPlaying
        )
        .frame(width: 80, height: 80)
    }
    
    /// Coins animation for savings/income
    static func moneyCoins(isPlaying: Binding<Bool> = .constant(true)) -> some View {
        LottieView(
            animationName: "coins-drop", // Add this .json file to Assets
            loopMode: .loop,
            animationSpeed: 0.8,
            isPlaying: isPlaying
        )
        .frame(width: 60, height: 60)
    }
    
    // MARK: - Empty State Animations
    
    /// Empty transactions list
    static func emptyTransactions(isPlaying: Binding<Bool> = .constant(true)) -> some View {
        VStack(spacing: 20) {
            LottieView(
                animationName: "empty-wallet", // Add this .json file to Assets
                loopMode: .loop,
                animationSpeed: 0.6,
                isPlaying: isPlaying
            )
            .frame(width: 200, height: 150)
            
            Text("No transactions yet")
                .font(AppFonts.overusedGroteskSemiBold(size: 20))
                .foregroundColor(AppColors.foregroundPrimary)
            
            Text("Start by scanning a receipt or adding a transaction")
                .font(AppFonts.overusedGroteskMedium(size: 14))
                .foregroundColor(AppColors.foregroundSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    /// Loading data animation
    static func loadingData(isPlaying: Binding<Bool> = .constant(true)) -> some View {
        VStack(spacing: 16) {
            LottieView(
                animationName: "loading-dots", // Add this .json file to Assets
                loopMode: .loop,
                animationSpeed: 1.0,
                isPlaying: isPlaying
            )
            .frame(width: 80, height: 60)
            
            Text("Loading...")
                .font(AppFonts.overusedGroteskMedium(size: 14))
                .foregroundColor(AppColors.foregroundSecondary)
        }
    }
    
    // MARK: - Onboarding Animations
    
    /// Welcome animation for onboarding
    static func welcome(isPlaying: Binding<Bool> = .constant(true)) -> some View {
        LottieView(
            animationName: "welcome-wave", // Add this .json file to Assets
            loopMode: .loop,
            animationSpeed: 1.0,
            isPlaying: isPlaying
        )
        .frame(width: 250, height: 200)
    }
    
    /// Setup complete animation
    static func setupComplete(isPlaying: Binding<Bool> = .constant(true)) -> some View {
        LottieView(
            animationName: "setup-complete", // Add this .json file to Assets
            loopMode: .playOnce,
            animationSpeed: 1.2,
            isPlaying: isPlaying
        )
        .frame(width: 150, height: 150)
    }
    
    // MARK: - Pull to Refresh Animation
    
    /// Pull to refresh indicator
    static func pullToRefresh(isPlaying: Binding<Bool> = .constant(true)) -> some View {
        LottieView(
            animationName: "pull-refresh", // Add this .json file to Assets
            loopMode: .loop,
            animationSpeed: 1.5,
            isPlaying: isPlaying
        )
        .frame(width: 40, height: 40)
    }
}

// MARK: - Usage Examples

#Preview("Receipt Processing") {
    VStack(spacing: 40) {
        LottieAnimations.receiptAnalyzing()
        LottieAnimations.receiptSuccess()
        LottieAnimations.receiptError()
    }
    .padding()
}

#Preview("Empty States") {
    VStack(spacing: 40) {
        LottieAnimations.emptyTransactions()
        LottieAnimations.loadingData()
    }
    .padding()
}