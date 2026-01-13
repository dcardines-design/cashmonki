//
//  ValueFeature4OnboardingView.swift
//  CashMonki
//
//  Created by Claude on 1/3/26.
//

import SwiftUI

struct ValueFeature4OnboardingView: View {
    @Binding var isPresented: Bool
    let onContinue: () -> Void
    let onBack: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Header
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

            // Dynamic Progress Bar
            OnboardingProgressBar.dynamic(
                currentStep: .valueFeature4,
                isGmailUser: false
            )

            // Continue Button
            FixedBottomGroup.primary(
                title: "Continue",
                action: {
                    print("✨ ValueFeature4: Continue tapped")
                    onContinue()
                }
            )
        }
        .background(AppColors.backgroundWhite)
        .navigationBarHidden(true)
        .onAppear {
            print("✨ ValueFeature4: Showing Privacy Focused Local Storage feature")

            // Track analytics
            AnalyticsManager.shared.track(.onboardingValueFeatureViewed, properties: [
                "feature_number": 4,
                "feature_name": "privacy_local_storage"
            ])
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            // Back Button
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

    // MARK: - Feature Header Section

    private var featureHeaderSection: some View {
        VStack(spacing: 12) {
            // Lock Icon
            Image("lock-01")
                .resizable()
                .renderingMode(.template)
                .frame(width: 24, height: 24)
                .foregroundColor(AppColors.accentBackground)

            // Tagline
            Text("Your data stays on your phone")
                .font(AppFonts.overusedGroteskSemiBold(size: 18))
                .foregroundColor(AppColors.accentBackground)

            // Title
            Text("Privacy Focused Local Storage")
                .font(AppFonts.overusedGroteskSemiBold(size: 30))
                .multilineTextAlignment(.center)
                .foregroundColor(AppColors.foregroundPrimary)
                .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    // MARK: - Feature Image Section

    private var featureImageSection: some View {
        Image("value-prop-4-privacy")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
            .cornerRadius(16)
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        Text("Your data stays on your phone, not on our servers. You're in full control.")
            .font(AppFonts.overusedGroteskMedium(size: 20))
            .multilineTextAlignment(.center)
            .foregroundColor(AppColors.foregroundSecondary)
            .frame(maxWidth: .infinity, alignment: .top)
    }
}

// MARK: - Preview

#Preview {
    ValueFeature4OnboardingView(
        isPresented: .constant(true),
        onContinue: { print("Continue tapped") },
        onBack: { print("Back tapped") }
    )
}
