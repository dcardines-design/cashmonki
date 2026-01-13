//
//  ValueFeaturePlaceholderView.swift
//  CashMonki
//
//  Created by Claude on 1/3/26.
//
//  Temporary placeholder for value feature screens 2-4
//  Will be replaced with actual implementations
//

import SwiftUI

struct ValueFeaturePlaceholderView: View {
    let featureNumber: Int
    @Binding var isPresented: Bool
    let onContinue: () -> Void
    let onBack: (() -> Void)?

    /// Map feature number to OnboardingStep for progress bar
    private var currentStep: OnboardingStep {
        switch featureNumber {
        case 2: return .valueFeature2
        case 3: return .valueFeature3
        case 4: return .valueFeature4
        default: return .valueFeature2
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header (same as other onboarding sheets)
            headerSection

            // Content
            Spacer()

            VStack(spacing: 24) {
                // Placeholder icon
                ZStack {
                    Circle()
                        .fill(AppColors.surfacePrimary)
                        .frame(width: 100, height: 100)

                    Text("\(featureNumber)")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(AppColors.primary)
                }

                Text("Feature \(featureNumber)")
                    .font(AppFonts.overusedGroteskSemiBold(size: 28))
                    .foregroundColor(AppColors.foregroundPrimary)

                Text("This feature screen will be implemented soon")
                    .font(AppFonts.overusedGroteskMedium(size: 17))
                    .foregroundColor(AppColors.foregroundSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 30)

            Spacer()

            // Dynamic Progress Bar (same as other onboarding sheets)
            OnboardingProgressBar.dynamic(
                currentStep: currentStep,
                isGmailUser: false
            )

            // Continue Button
            FixedBottomGroup.primary(
                title: "Continue",
                action: onContinue
            )
        }
        .background(AppColors.backgroundWhite)
        .navigationBarHidden(true)
        .onAppear {
            print("✨ ValueFeaturePlaceholder: Showing feature \(featureNumber) placeholder")

            // Track analytics
            AnalyticsManager.shared.track(.onboardingValueFeatureViewed, properties: [
                "feature_number": featureNumber,
                "feature_name": "placeholder_\(featureNumber)"
            ])
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            // Back Button (if provided)
            if let onBack = onBack {
                Button(action: onBack) {
                    Image("chevron-left")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 24, height: 24)
                        .foregroundColor(AppColors.foregroundSecondary)
                }
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 24, height: 24)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(AppColors.backgroundWhite)
    }
}

#Preview {
    ValueFeaturePlaceholderView(
        featureNumber: 2,
        isPresented: .constant(true),
        onContinue: { print("Continue") },
        onBack: { print("Back") }
    )
}
