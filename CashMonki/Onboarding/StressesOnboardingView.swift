//
//  StressesOnboardingView.swift
//  CashMonki
//
//  Created by Claude on 1/3/26.
//

import SwiftUI

struct StressesOnboardingView: View {
    @Binding var isPresented: Bool
    let onStressSelected: (String) -> Void
    let onBack: (() -> Void)?

    @State private var selectedStress: String? = nil

    // Stress options matching the design
    private let stressOptions = [
        StressOption(
            id: "dont_know_where_money_goes",
            title: "I don't know where my money goes",
            emoji: "🤷‍♂️"
        ),
        StressOption(
            id: "anxious_checking_balance",
            title: "I feel anxious checking my balance",
            emoji: "😱"
        ),
        StressOption(
            id: "surprise_expenses",
            title: "Surprise expenses keep hitting me",
            emoji: "🥳"
        ),
        StressOption(
            id: "cant_save",
            title: "I can't seem to save",
            emoji: "💸"
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

                    // Stress Selection Options
                    stressSelectionSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)
                .padding(.bottom, 40)
            }

            // Dynamic Progress Bar
            OnboardingProgressBar.dynamic(currentStep: .stressSelection)

            // Fixed Bottom Button - Continue (disabled if no selection)
            FixedBottomGroup.primary(
                title: "Continue",
                action: handleContinue,
                isEnabled: selectedStress != nil
            )
        }
        .background(AppColors.backgroundWhite)
        .navigationBarHidden(true)
        .onAppear {
            print("😫 StressesOnboarding: Starting stress selection process")
        }
    }

    // MARK: - Actions

    private func handleContinue() {
        let stressValue = selectedStress ?? ""

        if selectedStress == nil {
            print("😫 StressesOnboarding: User skipped stress selection")
        } else {
            print("😫 StressesOnboarding: ======= STRESS SELECTION COMPLETED =======")
            print("😫 StressesOnboarding: User selected stress: \(stressValue)")
        }

        // Save stress selection
        UserDefaults.standard.set(stressValue, forKey: "selectedMoneyStress")
        UserDefaults.standard.set(true, forKey: "hasCompletedStressSelection")

        // Save to user profile
        UserManager.shared.updateUserStress(stressValue)
        print("😫 StressesOnboarding: Stress saved: '\(stressValue.isEmpty ? "(skipped)" : stressValue)'")

        // Track analytics
        AnalyticsManager.shared.track(.onboardingStressSelected, properties: [
            "stress": stressValue,
            "skipped": selectedStress == nil
        ])

        onStressSelected(stressValue)
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
            // Stressed Emoji Icon
            VStack(alignment: .center, spacing: 10) {
                Text("😫")
                    .font(.system(size: 60))
            }
            .padding(8)
            .frame(width: 100, height: 100, alignment: .center)
            .background(AppColors.surfacePrimary)
            .cornerRadius(200)

            // Title
            VStack(spacing: 6) {
                Text("What stresses you most about money right now?")
                    .font(AppFonts.overusedGroteskSemiBold(size: 28))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.foregroundPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    // MARK: - Stress Selection Section

    private var stressSelectionSection: some View {
        VStack(spacing: 16) {
            ForEach(stressOptions, id: \.id) { option in
                ChoiceTile(
                    emoji: option.emoji,
                    title: option.title,
                    isSelected: selectedStress == option.id,
                    onTap: {
                        if selectedStress == option.id {
                            // Deselect if already selected
                            selectedStress = nil
                            print("😫 StressesOnboarding: Deselected stress: \(option.title)")
                        } else {
                            // Select this option (single select)
                            selectedStress = option.id
                            print("😫 StressesOnboarding: Selected stress: \(option.title)")
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Stress Option Model

private struct StressOption {
    let id: String
    let title: String
    let emoji: String
}

// MARK: - Preview

#Preview {
    StressesOnboardingView(
        isPresented: .constant(true),
        onStressSelected: { stress in
            print("Selected stress: \(stress)")
        },
        onBack: {
            print("Back pressed")
        }
    )
}
