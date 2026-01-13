//
//  TrackingFrequencyOnboardingView.swift
//  CashMonki
//
//  Created by Claude on 1/3/26.
//

import SwiftUI

struct TrackingFrequencyOnboardingView: View {
    @Binding var isPresented: Bool
    let onFrequencySelected: ([String]) -> Void
    let onBack: (() -> Void)?

    @State private var selectedOptions: Set<String> = []

    // Tracking frequency options matching the design
    private let frequencyOptions = [
        FrequencyOption(
            id: "pretty_much_never",
            title: "Pretty much never",
            emoji: "🙈"
        ),
        FrequencyOption(
            id: "only_when_broke",
            title: "Only when I feel broke",
            emoji: "🥴"
        ),
        FrequencyOption(
            id: "weekly",
            title: "Weekly",
            emoji: "🗓"
        ),
        FrequencyOption(
            id: "few_times_month",
            title: "A few times a month",
            emoji: "🤙"
        ),
        FrequencyOption(
            id: "almost_every_day",
            title: "Almost every day",
            emoji: "😊"
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

                    // Frequency Selection Options
                    frequencySelectionSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)
                .padding(.bottom, 40)
            }

            // Dynamic Progress Bar
            OnboardingProgressBar.dynamic(currentStep: .trackingFrequency)

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
            print("🕐 TrackingFrequencyOnboarding: Starting tracking frequency selection process")
        }
    }

    // MARK: - Actions

    private func handleContinue() {
        let frequencyValues = Array(selectedOptions)

        if selectedOptions.isEmpty {
            print("🕐 TrackingFrequencyOnboarding: User skipped tracking frequency selection")
        } else {
            print("🕐 TrackingFrequencyOnboarding: ======= TRACKING FREQUENCIES SELECTED =======")
            print("🕐 TrackingFrequencyOnboarding: User selected: \(frequencyValues.joined(separator: ", "))")
        }

        // Save tracking frequency selection (as comma-separated string for backwards compatibility)
        let frequencyString = frequencyValues.joined(separator: ",")
        UserDefaults.standard.set(frequencyString, forKey: "selectedTrackingFrequency")
        UserDefaults.standard.set(true, forKey: "hasCompletedTrackingFrequencySelection")

        // Save to user profile
        UserManager.shared.updateUserTrackingFrequency(frequencyString)
        print("🕐 TrackingFrequencyOnboarding: Saved: '\(frequencyString.isEmpty ? "(skipped)" : frequencyString)'")

        // Track analytics
        AnalyticsManager.shared.track(.onboardingTrackingFrequencySelected, properties: [
            "tracking_frequencies": frequencyValues,
            "tracking_frequencies_count": frequencyValues.count,
            "skipped": selectedOptions.isEmpty
        ])

        onFrequencySelected(frequencyValues)
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
            // Clock Emoji Icon
            VStack(alignment: .center, spacing: 10) {
                Text("🕐")
                    .font(.system(size: 60))
            }
            .padding(8)
            .frame(width: 100, height: 100, alignment: .center)
            .background(AppColors.surfacePrimary)
            .cornerRadius(200)

            // Title
            VStack(spacing: 6) {
                Text("How often do you currently keep track of your spending?")
                    .font(AppFonts.overusedGroteskSemiBold(size: 28))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.foregroundPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    // MARK: - Frequency Selection Section

    private var frequencySelectionSection: some View {
        VStack(spacing: 16) {
            ForEach(frequencyOptions, id: \.id) { option in
                ChoiceTile(
                    emoji: option.emoji,
                    title: option.title,
                    isSelected: selectedOptions.contains(option.id),
                    onTap: {
                        if selectedOptions.contains(option.id) {
                            // Deselect if already selected
                            selectedOptions.remove(option.id)
                            print("🕐 TrackingFrequencyOnboarding: Deselected: \(option.title)")
                        } else {
                            // Add to selection (multi-select)
                            selectedOptions.insert(option.id)
                            print("🕐 TrackingFrequencyOnboarding: Selected: \(option.title)")
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Frequency Option Model

private struct FrequencyOption {
    let id: String
    let title: String
    let emoji: String
}

// MARK: - Preview

#Preview {
    TrackingFrequencyOnboardingView(
        isPresented: .constant(true),
        onFrequencySelected: { options in
            print("Selected: \(options)")
        },
        onBack: {
            print("Back pressed")
        }
    )
}
