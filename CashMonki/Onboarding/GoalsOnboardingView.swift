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
    private var isGmailUser: Bool {
        #if canImport(FirebaseAuth)
        if let currentUser = Auth.auth().currentUser {
            return currentUser.providerData.contains { $0.providerID == "google.com" }
        }
        return false
        #else
        return false
        #endif
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
                    
                    Spacer(minLength: 80) // Space for bottom button
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
                .padding(.bottom, 120) // Space for fixed bottom button
            }
            
            // Dynamic Progress Bar
            OnboardingProgressBar.dynamic(
                currentStep: .goalSelection,
                isGmailUser: isGmailUser
            )
            
            // Fixed Bottom Button
            FixedBottomGroup.primary(
                title: "Continue",
                action: {
                    guard !selectedGoals.isEmpty else { 
                        print("🎯 GoalsOnboarding: ❌ Cannot proceed - no goals selected")
                        return 
                    }
                    
                    print("🎯 GoalsOnboarding: ======= GOAL SELECTION COMPLETED =======")
                    print("🎯 GoalsOnboarding: User selected goals: \(Array(selectedGoals))")
                    print("🎯 GoalsOnboarding: Timestamp: \(Date())")
                    print("🎯 GoalsOnboarding: Thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")")
                    print("🎯 GoalsOnboarding: Saving goal completion to UserDefaults AND user profile...")
                    
                    // Save goals as comma-separated string and mark completion
                    let goalsString = Array(selectedGoals).joined(separator: ",")
                    UserDefaults.standard.set(goalsString, forKey: "selectedPrimaryGoals")
                    UserDefaults.standard.set(true, forKey: "hasCompletedGoalSelection")
                    
                    // Note: hasSetPrimaryCurrency should only be set when user actually confirms currency
                    // This flag is properly set in CurrencyOnboardingView when user confirms selection
                    print("🎯 GoalsOnboarding: Currency completion handled by CurrencyOnboardingView")
                    
                    // 🎯 SAVE TO USER PROFILE: Add goals to user's preferences
                    print("🎯 GoalsOnboarding: Saving goals to user profile...")
                    UserManager.shared.updateUserGoals(goalsString)
                    print("🎯 GoalsOnboarding: ✅ Goals saved to user profile")
                    
                    // Verify the save
                    let savedGoals = UserDefaults.standard.string(forKey: "selectedPrimaryGoals")
                    let savedCompletion = UserDefaults.standard.bool(forKey: "hasCompletedGoalSelection")
                    let userGoals = UserManager.shared.currentUser.goals
                    print("🎯 GoalsOnboarding: ✅ Verification - Goals saved to UserDefaults: '\(savedGoals ?? "nil")'")
                    print("🎯 GoalsOnboarding: ✅ Verification - Completion saved: \(savedCompletion)")
                    print("🎯 GoalsOnboarding: ✅ Verification - Goals saved to user profile: '\(userGoals ?? "nil")'")
                    print("🎯 GoalsOnboarding: 🚨 DEBUG: About to call onGoalSelected - this will trigger onboarding completion")
                    print("🎯 GoalsOnboarding: 🚨 DEBUG: If onboarding sheet reappears, check ContentView validation after this point")
                    
                    onGoalSelected(goalsString)
                },
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
            
            // Title
            Text("Complete Setup")
                .font(AppFonts.overusedGroteskSemiBold(size: 17))
                .foregroundColor(AppColors.foregroundPrimary)
            
            Spacer()
            
            // Invisible element for balance
            Rectangle()
                .fill(Color.clear)
                .frame(width: 24, height: 24)
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