//
//  ValueFeature1OnboardingView.swift
//  CashMonki
//
//  Created by Claude on 1/3/26.
//

import SwiftUI

struct ValueFeature1OnboardingView: View {
    @Binding var isPresented: Bool
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header (same as other onboarding sheets, no back button on first screen)
            headerSection

            // Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Feature Header Section
                    featureHeaderSection

                    // Feature Image
                    featureImageSection

                    // Description
                    descriptionSection
                }
                .padding(.horizontal, 30)
                .padding(.top, 30)
                .padding(.bottom, 40)
            }

            // Dynamic Progress Bar (same as other onboarding sheets)
            OnboardingProgressBar.dynamic(
                currentStep: .valueFeature1,
                isGmailUser: false
            )

            // Continue Button
            FixedBottomGroup.primary(
                title: "Continue",
                action: {
                    print("✨ ValueFeature1: Continue tapped")
                    onContinue()
                }
            )
        }
        .background(AppColors.backgroundWhite)
        .navigationBarHidden(true)
        .onAppear {
            print("✨ ValueFeature1: Showing AI-Powered Receipt Scanning feature")

            // Track analytics
            AnalyticsManager.shared.track(.onboardingValueFeatureViewed, properties: [
                "feature_number": 1,
                "feature_name": "ai_receipt_scanning"
            ])
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        // No header content on first screen
        Color.clear
            .frame(height: 16)
    }

    // MARK: - Feature Header Section

    private var featureHeaderSection: some View {
        VStack(spacing: 12) {
            // Scan Icon
            Image("scan")
                .resizable()
                .renderingMode(.template)
                .frame(width: 24, height: 24)
                .foregroundColor(AppColors.accentBackground)

            // Tagline
            Text("Snap, analyze, done!")
                .font(AppFonts.overusedGroteskSemiBold(size: 18))
                .foregroundColor(AppColors.accentBackground)

            // Title
            Text("AI-Powered Receipt Scanning")
                .font(AppFonts.overusedGroteskSemiBold(size: 30))
                .multilineTextAlignment(.center)
                .foregroundColor(AppColors.foregroundPrimary)
                .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    // MARK: - Feature Image Section

    private var featureImageSection: some View {
        Image("value-prop-1-scan")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
            .cornerRadius(16)
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        Text("Snap a receipt and your transaction is created automatically with smart categories.")
            .font(AppFonts.overusedGroteskMedium(size: 20))
            .multilineTextAlignment(.center)
            .foregroundColor(AppColors.foregroundSecondary)
            .frame(maxWidth: .infinity, alignment: .top)
    }
}

// MARK: - Preview

#Preview {
    ValueFeature1OnboardingView(
        isPresented: .constant(true),
        onContinue: {
            print("Continue tapped")
        }
    )
}
