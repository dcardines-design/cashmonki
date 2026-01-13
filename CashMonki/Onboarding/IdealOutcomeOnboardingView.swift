//
//  IdealOutcomeOnboardingView.swift
//  CashMonki
//
//  Created by Claude on 1/3/26.
//

import SwiftUI

struct IdealOutcomeOnboardingView: View {
    @Binding var isPresented: Bool
    let onOutcomeSelected: ([String]) -> Void
    let onBack: (() -> Void)?

    @State private var selectedOptions: Set<String> = []

    // Ideal outcome options matching the design
    private let outcomeOptions = [
        OutcomeOption(
            id: "feel_calm",
            title: "I'd feel calm about money",
            emoji: "☺️"
        ),
        OutcomeOption(
            id: "stop_overspending",
            title: "I'd stop overspending",
            emoji: "💁‍♀️"
        ),
        OutcomeOption(
            id: "know_where_money_goes",
            title: "I'd actually know where my money goes",
            emoji: "😮"
        ),
        OutcomeOption(
            id: "fewer_surprises",
            title: "Fewer money surprises",
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

                    // Outcome Selection Options
                    outcomeSelectionSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)
                .padding(.bottom, 40)
            }

            // Dynamic Progress Bar
            OnboardingProgressBar.dynamic(currentStep: .idealOutcome)

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
            print("🥳 IdealOutcomeOnboarding: Starting ideal outcome selection process")
        }
    }

    // MARK: - Actions

    private func handleContinue() {
        let outcomeValues = Array(selectedOptions)

        if selectedOptions.isEmpty {
            print("🥳 IdealOutcomeOnboarding: User skipped ideal outcome selection")
        } else {
            print("🥳 IdealOutcomeOnboarding: ======= IDEAL OUTCOMES SELECTED =======")
            print("🥳 IdealOutcomeOnboarding: User selected: \(outcomeValues.joined(separator: ", "))")
        }

        // Save ideal outcome selection (as comma-separated string for backwards compatibility)
        let outcomeString = outcomeValues.joined(separator: ",")
        UserDefaults.standard.set(outcomeString, forKey: "selectedIdealOutcome")
        UserDefaults.standard.set(true, forKey: "hasCompletedIdealOutcomeSelection")

        // Save to user profile
        UserManager.shared.updateUserIdealOutcome(outcomeString)
        print("🥳 IdealOutcomeOnboarding: Saved: '\(outcomeString.isEmpty ? "(skipped)" : outcomeString)'")

        // Track analytics
        AnalyticsManager.shared.track(.onboardingIdealOutcomeSelected, properties: [
            "ideal_outcomes": outcomeValues,
            "ideal_outcomes_count": outcomeValues.count,
            "skipped": selectedOptions.isEmpty
        ])

        onOutcomeSelected(outcomeValues)
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
            // Party Face Emoji Icon
            VStack(alignment: .center, spacing: 10) {
                Text("🥳")
                    .font(.system(size: 60))
            }
            .padding(8)
            .frame(width: 100, height: 100, alignment: .center)
            .background(AppColors.surfacePrimary)
            .cornerRadius(200)

            // Title
            VStack(spacing: 6) {
                Text("If this app worked perfectly, what would change?")
                    .font(AppFonts.overusedGroteskSemiBold(size: 28))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.foregroundPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    // MARK: - Outcome Selection Section

    private var outcomeSelectionSection: some View {
        VStack(spacing: 16) {
            ForEach(outcomeOptions, id: \.id) { option in
                ChoiceTile(
                    emoji: option.emoji,
                    title: option.title,
                    isSelected: selectedOptions.contains(option.id),
                    onTap: {
                        if selectedOptions.contains(option.id) {
                            // Deselect if already selected
                            selectedOptions.remove(option.id)
                            print("🥳 IdealOutcomeOnboarding: Deselected: \(option.title)")
                        } else {
                            // Add to selection (multi-select)
                            selectedOptions.insert(option.id)
                            print("🥳 IdealOutcomeOnboarding: Selected: \(option.title)")
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Outcome Option Model

private struct OutcomeOption {
    let id: String
    let title: String
    let emoji: String
}

// MARK: - Preview

#Preview {
    IdealOutcomeOnboardingView(
        isPresented: .constant(true),
        onOutcomeSelected: { options in
            print("Selected: \(options)")
        },
        onBack: {
            print("Back pressed")
        }
    )
}
