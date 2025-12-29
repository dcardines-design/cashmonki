//
//  DebugSettingsView.swift
//  CashMonki
//
//  Debug and testing settings extracted from SettingsPage
//

import SwiftUI
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

// MARK: - Debug Settings Section

struct DebugSettingsSection: View {
    @Binding var showingDeleteAllConfirmation: Bool
    @Binding var showingDebugOnboarding: Bool
    @Binding var debugOnboardingStartStep: OnboardingStep
    @Binding var showingTransactionOnboarding: Bool
    @Binding var showingCustomPaywall: Bool
    @Binding var showingCurrencyPicker: Bool
    @Binding var showingSecondaryCurrencyPicker: Bool
    @Binding var environmentTestResult: String?

    @ObservedObject var userManager: UserManager
    @EnvironmentObject var toastManager: ToastManager

    var body: some View {
        VStack(spacing: 0) {
            debugSectionHeader("Debug & Testing")

            VStack(spacing: 0) {
                debugConnectionTestRows
                debugDataManagementRows
                debugOnboardingTestRows
                debugCurrencyPickerTestRows
            }
            .background(AppColors.backgroundWhite)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Connection Tests

    private var debugConnectionTestRows: some View {
        Group {
            debugSettingsRow(
                title: "Test Firebase Connection",
                subtitle: "Check if Firebase is working properly",
                icon: "☁️"
            ) {
                userManager.testFirebaseConnection()
            }

            Divider()
                .padding(.leading, 52)

            debugSettingsRow(
                title: "Test Receipt AI Connection",
                subtitle: "Test OpenRouter API for receipt scanning",
                icon: "🧪"
            ) {
                testOpenRouterAPI()
            }

            Divider()
                .padding(.leading, 52)

            debugSettingsRow(
                title: "Test Environment & API Keys",
                subtitle: environmentTestResult ?? "Check environment variables and API key loading",
                icon: "🔑"
            ) {
                testEnvironmentAndAPIKeys()
            }
        }
    }

    // MARK: - Data Management

    private var debugDataManagementRows: some View {
        Group {
            Divider()
                .padding(.leading, 52)

            debugSettingsRow(
                title: "Delete All Transactions",
                subtitle: "Remove all transactions from Firebase",
                icon: "🗑️"
            ) {
                showingDeleteAllConfirmation = true
            }

            Divider()
                .padding(.leading, 52)

            debugSettingsRow(
                title: "Debug Firebase Data",
                subtitle: "Check Firebase data for current user",
                icon: "🕵️"
            ) {
                userManager.debugFirebaseDataForUser()
            }

            Divider()
                .padding(.leading, 52)

            debugSettingsRow(
                title: "Force Sync to Firebase",
                subtitle: "Manually push current data to Firebase",
                icon: "🔧"
            ) {
                userManager.forceManualSyncToFirebase()
            }
        }
    }

    // MARK: - Onboarding Tests

    private var debugOnboardingTestRows: some View {
        Group {
            Divider()
                .padding(.leading, 52)

            debugSettingsRow(
                title: "Test Email Verification Onboarding",
                subtitle: "Debug email verification onboarding screen",
                icon: "📧"
            ) {
                debugOnboardingStartStep = .emailConfirmation
                showingDebugOnboarding = true
            }

            Divider()
                .padding(.leading, 52)

            debugSettingsRow(
                title: "Test Name Collection Onboarding",
                subtitle: "Debug name collection onboarding screen",
                icon: "👤"
            ) {
                debugOnboardingStartStep = .nameCollection
                showingDebugOnboarding = true
            }

            Divider()
                .padding(.leading, 52)

            debugSettingsRow(
                title: "Test Currency Selection Onboarding",
                subtitle: "Debug currency selection onboarding screen",
                icon: "💰"
            ) {
                debugOnboardingStartStep = .currencySelection
                showingDebugOnboarding = true
            }

            Divider()
                .padding(.leading, 52)

            debugSettingsRow(
                title: "Test Transaction Onboarding",
                subtitle: "Show the transaction addition onboarding sheet",
                icon: "💳"
            ) {
                showingTransactionOnboarding = true
            }

            Divider()
                .padding(.leading, 52)

            debugSettingsRow(
                title: "Reset Onboarding State",
                subtitle: "Clear all onboarding flags and goal data for testing",
                icon: "🔄"
            ) {
                OnboardingStateManager.shared.resetOnboardingState()
                toastManager.showSuccess("Onboarding state reset successfully")
            }

            Divider()
                .padding(.leading, 52)

            debugSettingsRow(
                title: "Test Trial-Ended Paywall",
                subtitle: "Shows 'Continue with Pro' button",
                icon: "⏰"
            ) {
                RevenueCatManager.shared.forceDebugLapsedTrial()
                showingCustomPaywall = true
            }

            Divider()
                .padding(.leading, 52)

            debugSettingsRow(
                title: "Test New User Paywall",
                subtitle: "Shows 'Start my free week' button",
                icon: "🆕"
            ) {
                RevenueCatManager.shared.forceDebugNewUser()
                showingCustomPaywall = true
            }

            Divider()
                .padding(.leading, 52)

            debugSettingsRow(
                title: "Reset Debug State",
                subtitle: "Use real RevenueCat data",
                icon: "🔧"
            ) {
                RevenueCatManager.shared.resetDebugTrialState()
                toastManager.showSuccess("Using real subscription data")
            }
        }
    }

    // MARK: - Currency Picker Tests

    private var debugCurrencyPickerTestRows: some View {
        Group {
            Divider()
                .padding(.leading, 52)

            debugSettingsRow(
                title: "Test Primary Currency Picker",
                subtitle: "Open primary currency picker sheet",
                icon: "🌍"
            ) {
                showingCurrencyPicker = true
            }

            Divider()
                .padding(.leading, 52)

            debugSettingsRow(
                title: "Test Secondary Currency Picker",
                subtitle: "Open secondary currency picker sheet",
                icon: "🏳️"
            ) {
                showingSecondaryCurrencyPicker = true
            }
        }
    }

    // MARK: - Helper Views

    private func debugSectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(
                    Font.custom("Overused Grotesk", size: 14)
                        .weight(.medium)
                )
                .foregroundColor(AppColors.foregroundSecondary)
            Spacer()
        }
        .padding(.bottom, 8)
    }

    private func debugSettingsRow(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(icon)
                    .font(AppFonts.overusedGroteskMedium(size: 24))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFonts.overusedGroteskMedium(size: 16))
                        .foregroundColor(AppColors.foregroundPrimary)

                    Text(subtitle)
                        .font(AppFonts.overusedGroteskMedium(size: 13))
                        .foregroundColor(AppColors.foregroundSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.foregroundTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Test Functions

    private func testOpenRouterAPI() {
        let analyzer = AIReceiptAnalyzer.shared
        analyzer.testAPIConnection { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let message):
                    toastManager.showSuccess("Receipt AI connected: \(message)")
                case .failure(let error):
                    toastManager.showError("API Error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func testEnvironmentAndAPIKeys() {
        var results: [String] = []

        // Check for environment variable
        if let envKey = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"] {
            results.append("ENV: \(envKey.prefix(8))...")
        } else {
            results.append("ENV: Not set")
        }

        // Check Info.plist
        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "OpenRouterAPIKey") as? String,
           !plistKey.isEmpty {
            results.append("Plist: \(plistKey.prefix(8))...")
        } else {
            results.append("Plist: Empty or not found")
        }

        // Check what Config returns
        if let configKey = Config.openRouterAPIKey, !configKey.isEmpty {
            results.append("Config: \(configKey.prefix(8))...")
            environmentTestResult = results.joined(separator: " | ")
            toastManager.showSuccess("API Key loaded successfully")
        } else {
            results.append("Config: Empty")
            environmentTestResult = results.joined(separator: " | ")
            toastManager.showError("No API key found!")
        }
    }
}

// MARK: - Duplicate Account Debug Section

struct DuplicateAccountDebugSection: View {
    @ObservedObject var authManager: AuthenticationManager

    var body: some View {
        VStack(spacing: 0) {
            debugSectionHeader("Account Debug (Temporary)")

            VStack(spacing: 0) {
                // Analyze Auth Providers Button
                debugSettingsRow(
                    title: "Analyze Auth Providers",
                    subtitle: "Check for duplicate Google/Email accounts",
                    icon: "🔍"
                ) {
                    print("User tapped: Analyze Auth Providers")
                    authManager.debugAuthenticationProviders()
                }

                Divider()
                    .background(AppColors.foregroundTertiary.opacity(0.1))
                    .padding(.leading, 52)

                // Cleanup Duplicate Account Button
                debugSettingsRow(
                    title: "Cleanup Duplicate Account",
                    subtitle: "Remove email provider, keep Google only",
                    icon: "🧹"
                ) {
                    print("User tapped: Cleanup Duplicate Account")
                    Task {
                        await authManager.cleanupDuplicateAccount()
                    }
                }

                Divider()
                    .background(AppColors.foregroundTertiary.opacity(0.1))
                    .padding(.leading, 52)

                // Force Refresh Auth State Button
                debugSettingsRow(
                    title: "Refresh Auth State",
                    subtitle: "Reload Firebase authentication state",
                    icon: "🔄"
                ) {
                    print("User tapped: Refresh Auth State")
                    #if canImport(FirebaseAuth)
                    if let firebaseUser = Auth.auth().currentUser {
                        Task {
                            do {
                                try await firebaseUser.reload()
                                print("Firebase user state refreshed")
                                authManager.debugAuthenticationProviders()
                            } catch {
                                print("Failed to refresh Firebase user: \(error.localizedDescription)")
                            }
                        }
                    } else {
                        print("No Firebase user to refresh")
                    }
                    #endif
                }
            }
            .background(AppColors.surfaceSecondary)
            .cornerRadius(12)
        }
    }

    // MARK: - Helper Views

    private func debugSectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(
                    Font.custom("Overused Grotesk", size: 14)
                        .weight(.medium)
                )
                .foregroundColor(AppColors.foregroundSecondary)
            Spacer()
        }
        .padding(.bottom, 8)
    }

    private func debugSettingsRow(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(icon)
                    .font(AppFonts.overusedGroteskMedium(size: 24))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFonts.overusedGroteskMedium(size: 16))
                        .foregroundColor(AppColors.foregroundPrimary)

                    Text(subtitle)
                        .font(AppFonts.overusedGroteskMedium(size: 13))
                        .foregroundColor(AppColors.foregroundSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.foregroundTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
