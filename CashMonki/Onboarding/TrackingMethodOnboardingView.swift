//
//  TrackingMethodOnboardingView.swift
//  CashMonki
//
//  Created by Claude on 1/3/26.
//

import SwiftUI

struct TrackingMethodOnboardingView: View {
    @Binding var isPresented: Bool
    let onMethodSelected: ([String]) -> Void
    let onBack: (() -> Void)?

    @State private var selectedOptions: Set<String> = []

    // Tracking method options matching the design
    private let methodOptions = [
        MethodOption(
            id: "notes_mental_math",
            title: "Notes app / mental math",
            emoji: "📝"
        ),
        MethodOption(
            id: "excel_sheets",
            title: "Excel / Google Sheets",
            emoji: "💻"
        ),
        MethodOption(
            id: "another_app",
            title: "Another app but i don't stick to it",
            emoji: "📱"
        ),
        MethodOption(
            id: "dont_track",
            title: "I don't... hehe",
            emoji: "🙈"
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

                    // Method Selection Options
                    methodSelectionSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)
                .padding(.bottom, 40)
            }

            // Dynamic Progress Bar
            OnboardingProgressBar.dynamic(currentStep: .trackingMethod)

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
            print("📝 TrackingMethodOnboarding: Starting tracking method selection process")
        }
    }

    // MARK: - Actions

    private func handleContinue() {
        let methodValues = Array(selectedOptions)

        if selectedOptions.isEmpty {
            print("📝 TrackingMethodOnboarding: User skipped tracking method selection")
        } else {
            print("📝 TrackingMethodOnboarding: ======= TRACKING METHODS SELECTED =======")
            print("📝 TrackingMethodOnboarding: User selected: \(methodValues.joined(separator: ", "))")
        }

        // Save tracking method selection (as comma-separated string for backwards compatibility)
        let methodString = methodValues.joined(separator: ",")
        UserDefaults.standard.set(methodString, forKey: "selectedTrackingMethod")
        UserDefaults.standard.set(true, forKey: "hasCompletedTrackingMethodSelection")

        // Save to user profile
        UserManager.shared.updateUserTrackingMethod(methodString)
        print("📝 TrackingMethodOnboarding: Saved: '\(methodString.isEmpty ? "(skipped)" : methodString)'")

        // Track analytics
        AnalyticsManager.shared.track(.onboardingTrackingMethodSelected, properties: [
            "tracking_methods": methodValues,
            "tracking_methods_count": methodValues.count,
            "skipped": selectedOptions.isEmpty
        ])

        onMethodSelected(methodValues)
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
            // Notepad Emoji Icon
            VStack(alignment: .center, spacing: 10) {
                Text("📝")
                    .font(.system(size: 60))
            }
            .padding(8)
            .frame(width: 100, height: 100, alignment: .center)
            .background(AppColors.surfacePrimary)
            .cornerRadius(200)

            // Title
            VStack(spacing: 6) {
                Text("How do you track expenses right now?")
                    .font(AppFonts.overusedGroteskSemiBold(size: 28))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.foregroundPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    // MARK: - Method Selection Section

    private var methodSelectionSection: some View {
        VStack(spacing: 16) {
            ForEach(methodOptions, id: \.id) { option in
                ChoiceTile(
                    emoji: option.emoji,
                    title: option.title,
                    isSelected: selectedOptions.contains(option.id),
                    onTap: {
                        if selectedOptions.contains(option.id) {
                            // Deselect if already selected
                            selectedOptions.remove(option.id)
                            print("📝 TrackingMethodOnboarding: Deselected: \(option.title)")
                        } else {
                            // Add to selection (multi-select)
                            selectedOptions.insert(option.id)
                            print("📝 TrackingMethodOnboarding: Selected: \(option.title)")
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Method Option Model

private struct MethodOption {
    let id: String
    let title: String
    let emoji: String
}

// MARK: - Preview

#Preview {
    TrackingMethodOnboardingView(
        isPresented: .constant(true),
        onMethodSelected: { options in
            print("Selected: \(options)")
        },
        onBack: {
            print("Back pressed")
        }
    )
}
