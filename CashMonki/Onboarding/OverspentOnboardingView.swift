//
//  OverspentOnboardingView.swift
//  CashMonki
//
//  Created by Claude on 1/3/26.
//

import SwiftUI

struct OverspentOnboardingView: View {
    @Binding var isPresented: Bool
    let onOverspentSelected: ([String]) -> Void
    let onBack: (() -> Void)?

    @State private var selectedOptions: Set<String> = []

    // Overspent realization options matching the design
    private let overspentOptions = [
        OverspentOption(
            id: "end_of_month",
            title: "End of the month",
            emoji: "🏁"
        ),
        OverspentOption(
            id: "card_declined",
            title: "When my card gets declined",
            emoji: "🙅‍♂️"
        ),
        OverspentOption(
            id: "open_bank_app",
            title: "When I open my bank app",
            emoji: "😯"
        ),
        OverspentOption(
            id: "dont_notice",
            title: "I usually don't notice until it's bad",
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

                    // Overspent Selection Options
                    overspentSelectionSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)
                .padding(.bottom, 40)
            }

            // Dynamic Progress Bar
            OnboardingProgressBar.dynamic(currentStep: .overspentRealization)

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
            print("🙈 OverspentOnboarding: Starting overspent selection process")
        }
    }

    // MARK: - Actions

    private func handleContinue() {
        let overspentValues = Array(selectedOptions)

        if selectedOptions.isEmpty {
            print("🙈 OverspentOnboarding: User skipped overspent selection")
        } else {
            print("🙈 OverspentOnboarding: ======= OVERSPENT SELECTIONS COMPLETED =======")
            print("🙈 OverspentOnboarding: User selected: \(overspentValues.joined(separator: ", "))")
        }

        // Save overspent selection (as comma-separated string for backwards compatibility)
        let overspentString = overspentValues.joined(separator: ",")
        UserDefaults.standard.set(overspentString, forKey: "selectedOverspentRealization")
        UserDefaults.standard.set(true, forKey: "hasCompletedOverspentSelection")

        // Save to user profile
        UserManager.shared.updateUserOverspentRealization(overspentString)
        print("🙈 OverspentOnboarding: Saved: '\(overspentString.isEmpty ? "(skipped)" : overspentString)'")

        // Track analytics
        AnalyticsManager.shared.track(.onboardingOverspentSelected, properties: [
            "overspent_realizations": overspentValues,
            "overspent_realizations_count": overspentValues.count,
            "skipped": selectedOptions.isEmpty
        ])

        onOverspentSelected(overspentValues)
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
            // See-No-Evil Monkey Emoji Icon
            VStack(alignment: .center, spacing: 10) {
                Text("🙈")
                    .font(.system(size: 60))
            }
            .padding(8)
            .frame(width: 100, height: 100, alignment: .center)
            .background(AppColors.surfacePrimary)
            .cornerRadius(200)

            // Title
            VStack(spacing: 6) {
                Text("When do you usually realize you've overspent?")
                    .font(AppFonts.overusedGroteskSemiBold(size: 28))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.foregroundPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    // MARK: - Overspent Selection Section

    private var overspentSelectionSection: some View {
        VStack(spacing: 16) {
            ForEach(overspentOptions, id: \.id) { option in
                ChoiceTile(
                    emoji: option.emoji,
                    title: option.title,
                    isSelected: selectedOptions.contains(option.id),
                    onTap: {
                        if selectedOptions.contains(option.id) {
                            // Deselect if already selected
                            selectedOptions.remove(option.id)
                            print("🙈 OverspentOnboarding: Deselected: \(option.title)")
                        } else {
                            // Add to selection (multi-select)
                            selectedOptions.insert(option.id)
                            print("🙈 OverspentOnboarding: Selected: \(option.title)")
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Overspent Option Model

private struct OverspentOption {
    let id: String
    let title: String
    let emoji: String
}

// MARK: - Preview

#Preview {
    OverspentOnboardingView(
        isPresented: .constant(true),
        onOverspentSelected: { options in
            print("Selected: \(options)")
        },
        onBack: {
            print("Back pressed")
        }
    )
}
