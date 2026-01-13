//
//  ValueFeature2OnboardingView.swift
//  CashMonki
//
//  Created by Claude on 1/3/26.
//

import SwiftUI

struct ValueFeature2OnboardingView: View {
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
                currentStep: .valueFeature2,
                isGmailUser: false
            )

            // Continue Button
            FixedBottomGroup.primary(
                title: "Continue",
                action: {
                    print("✨ ValueFeature2: Continue tapped")
                    onContinue()
                }
            )
        }
        .background(AppColors.backgroundWhite)
        .navigationBarHidden(true)
        .onAppear {
            print("✨ ValueFeature2: Showing Multi-Currency Support feature")

            // Track analytics
            AnalyticsManager.shared.track(.onboardingValueFeatureViewed, properties: [
                "feature_number": 2,
                "feature_name": "multi_currency_support"
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
            // Currency Icon
            Image("currency-dollar-circle")
                .resizable()
                .renderingMode(.template)
                .frame(width: 24, height: 24)
                .foregroundColor(AppColors.accentBackground)

            // Tagline
            Text("Global spending, local understanding")
                .font(AppFonts.overusedGroteskSemiBold(size: 18))
                .foregroundColor(AppColors.accentBackground)

            // Title
            Text("Multi-Currency Support")
                .font(AppFonts.overusedGroteskSemiBold(size: 30))
                .multilineTextAlignment(.center)
                .foregroundColor(AppColors.foregroundPrimary)
                .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    // MARK: - Feature Image Section

    private var featureImageSection: some View {
        Image("value-prop-2-multicurrency")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
            .cornerRadius(16)
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        Text("Log expenses in multiple currencies and see everything converted into your main currency automatically.")
            .font(AppFonts.overusedGroteskMedium(size: 20))
            .multilineTextAlignment(.center)
            .foregroundColor(AppColors.foregroundSecondary)
            .frame(maxWidth: .infinity, alignment: .top)
    }
}

// MARK: - Preview

#Preview {
    ValueFeature2OnboardingView(
        isPresented: .constant(true),
        onContinue: { print("Continue tapped") },
        onBack: { print("Back tapped") }
    )
}
