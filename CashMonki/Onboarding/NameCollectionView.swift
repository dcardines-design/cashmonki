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
    
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var isValid: Bool = false
    
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
    
    private var fullName: String {
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedLast.isEmpty {
            return trimmedFirst
        } else {
            return "\(trimmedFirst) \(trimmedLast)"
        }
    }
    
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
                .padding(.top, 40)
                .padding(.bottom, 40)
            }
            
            // Dynamic Progress Bar
            OnboardingProgressBar.dynamic(
                currentStep: .nameCollection,
                isGmailUser: isGmailUser
            )
            
            // Fixed Bottom Button
            FixedBottomGroup.primary(
                title: "Continue",
                action: {
                    onNameCollected(fullName)
                },
                isEnabled: isValid
            )
        }
        .background(AppColors.backgroundWhite)
        .navigationBarHidden(true)
        .onChange(of: firstName) { _, newValue in 
            validateForm()
            // Save first name immediately as user types
            saveNameToUser(firstName: newValue, lastName: lastName)
        }
        .onChange(of: lastName) { _, newValue in 
            validateForm() 
            // Save last name immediately as user types
            saveNameToUser(firstName: firstName, lastName: newValue)
        }
        .onAppear {
            print("👤 NameCollection: View appeared")
            
            // Intelligent name pre-fill: Firebase display name > UserManager stored name > empty
            loadPersistedName()
            
            validateForm()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            // Back button (if onBack callback is provided)
            if let onBack = onBack {
                Button(action: onBack) {
                    Image("chevron-left")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 24, height: 24)
                        .foregroundColor(AppColors.foregroundSecondary)
                }
            } else {
                // Spacer to maintain layout when no back button
                Spacer()
                    .frame(width: 24, height: 24)
            }
            
            Spacer()
            
            // Title
            Text(isNewRegistration ? "Create Account" : "Complete Setup")
                .font(AppFonts.overusedGroteskSemiBold(size: 17))
                .foregroundColor(AppColors.foregroundPrimary)
            
            Spacer()
            
            // Right spacer to balance layout
            Spacer()
                .frame(width: 24, height: 24)
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
                Text("Heya! What's your name?")
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
            // First Name
            CashMonkiDS.Input.text(
                title: "First Name",
                text: $firstName,
                placeholder: "John"
            )
            
            // Last Name
            CashMonkiDS.Input.text(
                title: "Last Name (Optional)",
                text: $lastName,
                placeholder: "Doe"
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func validateForm() {
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        // Only require first name - last name is optional
        isValid = !trimmedFirst.isEmpty
    }
    
    /// Immediately save name changes to UserManager as user types
    private func saveNameToUser(firstName: String, lastName: String) {
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let fullName: String
        if trimmedLast.isEmpty {
            fullName = trimmedFirst
        } else {
            fullName = "\(trimmedFirst) \(trimmedLast)"
        }
        
        // Only update if we have a valid first name
        if !trimmedFirst.isEmpty {
            print("💾 NameCollection: Auto-saving name as user types: '\(fullName)'")
            UserManager.shared.updateUserName(fullName)
        }
    }
    
    /// Intelligent name loading: Firebase display name (Google users) > UserManager stored name > empty
    private func loadPersistedName() {
        // First check if user is a Google sign-in user with Firebase display name
        let prefillResult = attemptFirebaseDisplayNamePrefill()
        
        // If Firebase pre-fill didn't work, try loading from UserManager
        if !prefillResult {
            loadFromUserManager()
        }
        
        print("👤 NameCollection: Final name state after loading:")
        print("   - First name: '\(firstName)'")
        print("   - Last name: '\(lastName)'")
        print("   - Source: \(prefillResult ? "Firebase" : "UserManager/Empty")")
    }
    
    /// Attempt to pre-fill with Firebase display name (Google users only)
    /// Returns true if successfully pre-filled, false otherwise
    private func attemptFirebaseDisplayNamePrefill() -> Bool {
        #if canImport(FirebaseAuth)
        guard let firebaseUser = Auth.auth().currentUser else {
            print("👤 NameCollection: No Firebase user found")
            return false
        }
        
        // Check if user signed in with Google
        let isGoogleSignIn = firebaseUser.providerData.contains { $0.providerID == "google.com" }
        
        print("👤 NameCollection: Authentication check:")
        print("   - Provider data: \(firebaseUser.providerData.map { $0.providerID })")
        print("   - Is Google sign-in: \(isGoogleSignIn)")
        
        // Only pre-fill for Google sign-in users with display name
        if isGoogleSignIn,
           let displayName = firebaseUser.displayName,
           !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            
            let nameComponents = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: " ").filter { !$0.isEmpty }
            
            if nameComponents.count >= 2 {
                firstName = nameComponents[0]
                lastName = nameComponents.dropFirst().joined(separator: " ")
                
                print("👤 NameCollection: Pre-filled from Firebase display name:")
                print("   - First name: '\(firstName)'")
                print("   - Last name: '\(lastName)'")
                print("   - Full name: '\(displayName)'")
                return true
            } else if nameComponents.count == 1 {
                firstName = nameComponents[0]
                lastName = ""
                
                print("👤 NameCollection: Pre-filled single name from Firebase: '\(firstName)'")
                return true
            }
        } else if isGoogleSignIn {
            print("👤 NameCollection: Gmail user but no display name found")
        } else {
            print("👤 NameCollection: Email sign-in user")
        }
        #else
        print("👤 NameCollection: Firebase not available")
        #endif
        
        return false
    }
    
    /// Load name from UserManager if available
    private func loadFromUserManager() {
        let currentUserName = UserManager.shared.currentUser.name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !currentUserName.isEmpty {
            let nameComponents = currentUserName.components(separatedBy: " ").filter { !$0.isEmpty }
            
            if nameComponents.count >= 2 {
                firstName = nameComponents[0]
                lastName = nameComponents.dropFirst().joined(separator: " ")
                
                print("👤 NameCollection: Loaded from UserManager:")
                print("   - First name: '\(firstName)'")
                print("   - Last name: '\(lastName)'")
                print("   - Full name: '\(currentUserName)'")
            } else if nameComponents.count == 1 {
                firstName = nameComponents[0]
                lastName = ""
                
                print("👤 NameCollection: Loaded single name from UserManager: '\(firstName)'")
            } else {
                print("👤 NameCollection: UserManager name is empty - starting fresh")
            }
        } else {
            print("👤 NameCollection: No stored name in UserManager - starting fresh")
        }
    }
    
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