//
//  ValueFeature3OnboardingView.swift
//  CashMonki
//
//  Created by Claude on 1/3/26.
//

import SwiftUI

struct ValueFeature3OnboardingView: View {
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
                currentStep: .valueFeature3,
                isGmailUser: false
            )

            // Continue Button
            FixedBottomGroup.primary(
                title: "Continue",
                action: {
                    print("✨ ValueFeature3: Continue tapped")
                    onContinue()
                }
            )
        }
        .background(AppColors.backgroundWhite)
        .navigationBarHidden(true)
        .onAppear {
            print("✨ ValueFeature3: Showing Smart & Simple Budgeting feature")

            // Track analytics
            AnalyticsManager.shared.track(.onboardingValueFeatureViewed, properties: [
                "feature_number": 3,
                "feature_name": "smart_budgeting"
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
            // Bar Chart Icon
            Image("horizontal-bar-chart-01")
                .resizable()
                .renderingMode(.template)
                .frame(width: 24, height: 24)
                .foregroundColor(AppColors.accentBackground)

            // Tagline
            Text("Budgets that update themselves")
                .font(AppFonts.overusedGroteskSemiBold(size: 18))
                .foregroundColor(AppColors.accentBackground)

            // Title
            Text("Smart & Simple Budgeting")
                .font(AppFonts.overusedGroteskSemiBold(size: 30))
                .multilineTextAlignment(.center)
                .foregroundColor(AppColors.foregroundPrimary)
                .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    // MARK: - Feature Image Section

    private var featureImageSection: some View {
        Image("value-prop-3-categories")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
            .cornerRadius(16)
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        Text("Set a budget once and we automatically calculate daily to yearly limits. Every transaction deducts instantly so your budget stays accurate.")
            .font(AppFonts.overusedGroteskMedium(size: 20))
            .multilineTextAlignment(.center)
            .foregroundColor(AppColors.foregroundSecondary)
            .frame(maxWidth: .infinity, alignment: .top)
    }
}

// MARK: - Preview

#Preview {
    ValueFeature3OnboardingView(
        isPresented: .constant(true),
        onContinue: { print("Continue tapped") },
        onBack: { print("Back tapped") }
    )
}
