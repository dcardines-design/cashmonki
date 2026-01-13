//
//  GoalsOnboardingView.swift
//  CashMonki
//
//  Created by Claude on 1/26/25.
//

import SwiftUI

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

struct GoalsOnboardingView: View {
    @Binding var isPresented: Bool
    let onGoalSelected: (String) -> Void
    let onBack: (() -> Void)?
    
    @State private var selectedGoals: Set<String> = []
    
    /// Check if current user is Gmail user
    /// CURRENT: Always false in no-auth flow
    private var isGmailUser: Bool {
        // FUTURE: Uncomment when re-enabling authentication
        // #if canImport(FirebaseAuth)
        // if let currentUser = Auth.auth().currentUser {
        //     return currentUser.providerData.contains { $0.providerID == "google.com" }
        // }
        // #endif
        return false
    }
    
    // Goal options matching the design
    private let goalOptions = [
        Goal(
            id: "track_spending",
            title: "Track daily spending",
            emoji: "📝"
        ),
        Goal(
            id: "stick_budget",
            title: "Stick to a budget",
            emoji: "📊"
        ),
        Goal(
            id: "save_money",
            title: "Save more money",
            emoji: "🐷"
        ),
        Goal(
            id: "manage_wallets",
            title: "Manage multiple wallets",
            emoji: "💼"
        ),
        Goal(
            id: "none_of_above",
            title: "None of the above",
            emoji: "⭕"
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
                    
                    // Goal Selection Options
                    goalSelectionSection
                    
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)
                .padding(.bottom, 40)
            }
            
            // Dynamic Progress Bar
            OnboardingProgressBar.dynamic(
                currentStep: .goalSelection,
                isGmailUser: isGmailUser
            )

            // Fixed Bottom Button - Continue (disabled if no selection)
            FixedBottomGroup.primary(
                title: "Continue",
                action: handleContinue,
                isEnabled: !selectedGoals.isEmpty
            )
        }
        .background(AppColors.backgroundWhite)
        .navigationBarHidden(true)
        .onAppear {
            print("🔥 TRANSITION DEBUG: GoalsOnboardingView appeared")
            print("🎯 GoalsOnboarding: Starting goal selection process")
        }
        .onDisappear {
            print("🔥 TRANSITION DEBUG: GoalsOnboardingView disappeared")
        }
    }

    // MARK: - Actions

    private func handleContinue() {
        let goalsString = Array(selectedGoals).joined(separator: ",")

        if selectedGoals.isEmpty {
            print("🎯 GoalsOnboarding: User skipped goal selection")
        } else {
            print("🎯 GoalsOnboarding: ======= GOAL SELECTION COMPLETED =======")
            print("🎯 GoalsOnboarding: User selected goals: \(Array(selectedGoals))")
        }

        // Save goals (empty string if skipped) and mark completion
        UserDefaults.standard.set(goalsString, forKey: "selectedPrimaryGoals")
        UserDefaults.standard.set(true, forKey: "hasCompletedGoalSelection")

        // Save to user profile
        UserManager.shared.updateUserGoals(goalsString)
        print("🎯 GoalsOnboarding: ✅ Goals saved: '\(goalsString.isEmpty ? "(skipped)" : goalsString)'")

        // Track goals selection
        AnalyticsManager.shared.track(.onboardingGoalsSelected, properties: [
            "goals": Array(selectedGoals),
            "goals_count": selectedGoals.count,
            "skipped": selectedGoals.isEmpty,
            "track_spending": selectedGoals.contains("track_spending"),
            "stick_budget": selectedGoals.contains("stick_budget"),
            "save_money": selectedGoals.contains("save_money"),
            "manage_wallets": selectedGoals.contains("manage_wallets"),
            "none_of_above": selectedGoals.contains("none_of_above")
        ])

        onGoalSelected(goalsString)
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
            // Target Icon
            VStack(alignment: .center, spacing: 10) {
                Text("🎯")
                    .font(
                        Font.custom("Overused Grotesk", size: 60)
                            .weight(.medium)
                    )
                    .foregroundColor(AppColors.foregroundPrimary)
            }
            .padding(8)
            .frame(width: 100, height: 100, alignment: .center)
            .background(AppColors.surfacePrimary)
            .cornerRadius(200)
            
            // Title
            VStack(spacing: 6) {
                // Main Title
                Text("What's your main goal?")
                    .font(
                        Font.custom("Overused Grotesk", size: 30)
                            .weight(.semibold)
                    )
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.foregroundPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    // MARK: - Goal Selection Section
    
    private var goalSelectionSection: some View {
        VStack(spacing: 16) {
            ForEach(goalOptions, id: \.id) { goal in
                goalOptionRow(goal: goal)
            }
        }
    }
    
    private func goalOptionRow(goal: Goal) -> some View {
        ChoiceTile(
            emoji: goal.emoji,
            title: goal.title,
            isSelected: selectedGoals.contains(goal.id),
            onTap: {
                if selectedGoals.contains(goal.id) {
                    // Deselect if already selected
                    selectedGoals.remove(goal.id)
                    print("🎯 GoalsOnboarding: Deselected goal: \(goal.title)")
                } else {
                    // Select if not selected
                    selectedGoals.insert(goal.id)
                    print("🎯 GoalsOnboarding: Selected goal: \(goal.title)")
                }
                print("🎯 GoalsOnboarding: Currently selected: \(Array(selectedGoals))")
            }
        )
    }
}


// MARK: - Goal Model

private struct Goal {
    let id: String
    let title: String
    let emoji: String
}

// MARK: - Preview

#Preview {
    GoalsOnboardingView(
        isPresented: .constant(true),
        onGoalSelected: { goal in
            print("Selected goal: \(goal)")
        },
        onBack: {
            print("Back pressed")
        }
    )
}