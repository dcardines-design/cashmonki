//
//  NameCollectionView.swift
//  CashMonki
//
//  Created by Claude on 1/22/25.
//

import SwiftUI

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

struct NameCollectionView: View {
    @Binding var isPresented: Bool
    let onNameCollected: (String) -> Void
    let onBack: (() -> Void)?
    let isNewRegistration: Bool
    
    @State private var name: String = ""
    // FUTURE: Uncomment when re-enabling last name
    // @State private var lastName: String = ""
    
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
    
    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // FUTURE: Uncomment when re-enabling last name
    // private var fullName: String {
    //     let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
    //     let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
    //     if trimmedLast.isEmpty { return trimmedFirst }
    //     return "\(trimmedFirst) \(trimmedLast)"
    // }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            // Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Icon and Title Section
                    iconAndTitleSection
                    
                    // Name Input Section
                    nameInputSection
                    
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)
                .padding(.bottom, 40)
            }
            
            // Dynamic Progress Bar
            OnboardingProgressBar.dynamic(
                currentStep: .nameCollection,
                isGmailUser: isGmailUser
            )
            
            // Fixed Bottom Button - Continue (disabled if no name entered)
            FixedBottomGroup.primary(
                title: "Continue",
                action: handleContinue,
                isEnabled: !trimmedName.isEmpty
            )
        }
        .background(AppColors.backgroundWhite)
        .navigationBarHidden(true)
        .onChange(of: name) { _, newValue in
            // Save name immediately as user types (if not empty)
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                print("💾 NameCollection: Auto-saving name: '\(trimmed)'")
                UserManager.shared.updateUserName(trimmed)
            }
        }
        .onAppear {
            print("👤 NameCollection: View appeared")
            // Load any previously saved name
            loadPersistedName()
        }
    }
    
    // MARK: - Actions

    private func handleSkip() {
        // Mark name collection as complete
        UserDefaults.standard.set(true, forKey: "hasCompletedNameCollection")
        print("👤 NameCollection: User skipped name entry")

        // Track analytics
        AnalyticsManager.shared.track(.onboardingNameCollected, properties: [
            "skipped": true,
            "name_length": 0
        ])

        onNameCollected("")
    }

    private func handleContinue() {
        // Mark name collection as complete
        UserDefaults.standard.set(true, forKey: "hasCompletedNameCollection")
        print("👤 NameCollection: User entered name '\(trimmedName)' - marking complete")

        // Track analytics
        AnalyticsManager.shared.track(.onboardingNameCollected, properties: [
            "skipped": false,
            "name_length": trimmedName.count
        ])

        onNameCollected(trimmedName)
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
            Button(action: { handleSkip() }) {
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
        VStack(spacing: 24) {
            // Person Icon with Background
            VStack(alignment: .center, spacing: 10) {
                Text("👋")
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
            
            // Title and Subtitle
            VStack(spacing: 6) {
                Text("What should we call you?")
                    .font(
                        Font.custom("Overused Grotesk", size: 30)
                            .weight(.semibold)
                    )
                    .foregroundColor(AppColors.foregroundPrimary)
                    .multilineTextAlignment(.center)

                Text("Just so we're not strangers....")
                    .font(AppFonts.overusedGroteskMedium(size: 16))
                    .foregroundColor(AppColors.foregroundSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Name Input Section

    private var nameInputSection: some View {
        VStack(spacing: 16) {
            // Name (optional)
            CashMonkiDS.Input.text(
                title: "Name (optional)",
                text: $name,
                placeholder: "John"
            )

            // FUTURE: Uncomment when re-enabling last name
            // CashMonkiDS.Input.text(
            //     title: "Last Name (Optional)",
            //     text: $lastName,
            //     placeholder: "Doe"
            // )
        }
    }
    
    // MARK: - Helper Methods

    /// Load name from UserManager if available
    private func loadPersistedName() {
        let storedName = UserManager.shared.currentUser.name.trimmingCharacters(in: .whitespacesAndNewlines)

        if !storedName.isEmpty {
            name = storedName
            print("👤 NameCollection: Loaded name from UserManager: '\(storedName)'")
        } else {
            print("👤 NameCollection: No stored name - starting fresh")
        }
    }

    // FUTURE: Uncomment when re-enabling Firebase/Google sign-in prefill
    // private func attemptFirebaseDisplayNamePrefill() -> Bool { ... }

}

// MARK: - Preview

#Preview {
    NameCollectionView(
        isPresented: .constant(true),
        onNameCollected: { name in
            print("Name collected: \(name)")
        },
        onBack: {
            print("Back pressed")
        },
        isNewRegistration: true
    )
}