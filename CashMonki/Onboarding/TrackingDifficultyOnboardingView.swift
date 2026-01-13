//
//  TrackingDifficultyOnboardingView.swift
//  CashMonki
//
//  Created by Claude on 1/3/26.
//

import SwiftUI

struct TrackingDifficultyOnboardingView: View {
    @Binding var isPresented: Bool
    let onDifficultySelected: ([String]) -> Void
    let onBack: (() -> Void)?

    @State private var selectedOptions: Set<String> = []

    // Tracking difficulty options matching the design
    private let difficultyOptions = [
        DifficultyOption(
            id: "too_much_effort",
            title: "It takes too much effort",
            emoji: "😡"
        ),
        DifficultyOption(
            id: "forget_to_log",
            title: "I forget to log things",
            emoji: "🤷‍♂️"
        ),
        DifficultyOption(
            id: "apps_confusing",
            title: "Apps feel confusing or cluttered",
            emoji: "🥺"
        ),
        DifficultyOption(
            id: "dont_want_details",
            title: "I don't want to track every detail",
            emoji: "😅"
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            // Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 40) {
                    // Icon and Title Section
                    iconAndTitleSection

                    // Difficulty Selection Options
                    difficultySelectionSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)
                .padding(.bottom, 40)
            }

            // Dynamic Progress Bar
            OnboardingProgressBar.dynamic(currentStep: .trackingDifficulty)

            // Fixed Bottom Button - Continue (disabled if no selection)
            FixedBottomGroup.primary(
                title: "Continue",
                action: handleContinue,
                isEnabled: !selectedOptions.isEmpty
            )
        }
        .background(AppColors.backgroundWhite)
        .navigationBarHidden(true)
        .onAppear {
            print("😣 TrackingDifficultyOnboarding: Starting tracking difficulty selection process")
        }
    }

    // MARK: - Actions

    private func handleContinue() {
        let difficultyValues = Array(selectedOptions)

        if selectedOptions.isEmpty {
            print("😣 TrackingDifficultyOnboarding: User skipped tracking difficulty selection")
        } else {
            print("😣 TrackingDifficultyOnboarding: ======= TRACKING DIFFICULTIES SELECTED =======")
            print("😣 TrackingDifficultyOnboarding: User selected: \(difficultyValues.joined(separator: ", "))")
        }

        // Save tracking difficulty selection (as comma-separated string for backwards compatibility)
        let difficultyString = difficultyValues.joined(separator: ",")
        UserDefaults.standard.set(difficultyString, forKey: "selectedTrackingDifficulty")
        UserDefaults.standard.set(true, forKey: "hasCompletedTrackingDifficultySelection")

        // Save to user profile
        UserManager.shared.updateUserTrackingDifficulty(difficultyString)
        print("😣 TrackingDifficultyOnboarding: Saved: '\(difficultyString.isEmpty ? "(skipped)" : difficultyString)'")

        // Track analytics
        AnalyticsManager.shared.track(.onboardingTrackingDifficultySelected, properties: [
            "tracking_difficulties": difficultyValues,
            "tracking_difficulties_count": difficultyValues.count,
            "skipped": selectedOptions.isEmpty
        ])

        onDifficultySelected(difficultyValues)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            // Back Button
            Button(action: {
                if let onBack = onBack {
                    onBack()
                } else {
                    isPresented = false
                }
            }) {
                Image("chevron-left")
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 24, height: 24)
                    .foregroundColor(AppColors.foregroundSecondary)
            }

            Spacer()

            // Skip Button (top-right)
            Button(action: { handleContinue() }) {
                Text("Skip")
                    .font(
                        Font.custom("Overused Grotesk", size: 16)
                            .weight(.semibold)
                    )
                    .foregroundColor(AppColors.foregroundPrimary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(AppColors.backgroundWhite)
    }

    // MARK: - Icon and Title Section

    private var iconAndTitleSection: some View {
        VStack(spacing: 18) {
            // Confounded Face Emoji Icon
            VStack(alignment: .center, spacing: 10) {
                Text("😖")
                    .font(.system(size: 60))
            }
            .padding(8)
            .frame(width: 100, height: 100, alignment: .center)
            .background(AppColors.surfacePrimary)
            .cornerRadius(200)

            // Title
            VStack(spacing: 6) {
                Text("What makes expense tracking hard for you?")
                    .font(AppFonts.overusedGroteskSemiBold(size: 28))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.foregroundPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    // MARK: - Difficulty Selection Section

    private var difficultySelectionSection: some View {
        VStack(spacing: 16) {
            ForEach(difficultyOptions, id: \.id) { option in
                ChoiceTile(
                    emoji: option.emoji,
                    title: option.title,
                    isSelected: selectedOptions.contains(option.id),
                    onTap: {
                        if selectedOptions.contains(option.id) {
                            // Deselect if already selected
                            selectedOptions.remove(option.id)
                            print("😣 TrackingDifficultyOnboarding: Deselected: \(option.title)")
                        } else {
                            // Add to selection (multi-select)
                            selectedOptions.insert(option.id)
                            print("😣 TrackingDifficultyOnboarding: Selected: \(option.title)")
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Difficulty Option Model

private struct DifficultyOption {
    let id: String
    let title: String
    let emoji: String
}

// MARK: - Preview

#Preview {
    TrackingDifficultyOnboardingView(
        isPresented: .constant(true),
        onDifficultySelected: { options in
            print("Selected: \(options)")
        },
        onBack: {
            print("Back pressed")
        }
    )
}
