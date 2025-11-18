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
                    
                    Spacer(minLength: 100) // Space for bottom button
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
                .padding(.bottom, 120) // Space for fixed bottom button
            }
            
            // Progress Bar - full width
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(hex: "F3F5F8") ?? Color.gray.opacity(0.3))
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(Color(hex: "542EFF") ?? Color.blue)
                        .frame(width: geometry.size.width * (1.0/3.0), height: 4) // Step 1 of 3
                }
            }
            .frame(height: 4)
            
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
        .onChange(of: firstName) { _, _ in validateForm() }
        .onChange(of: lastName) { _, _ in validateForm() }
        .onAppear {
            print("👤 NameCollection: View appeared")
            
            // Pre-fill with Firebase display name for Gmail users
            prefillWithFirebaseDisplayName()
            
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
    
    // MARK: - Helper Functions
    
    /// Pre-fill name fields with Firebase display name for Gmail users only
    private func prefillWithFirebaseDisplayName() {
        #if canImport(FirebaseAuth)
        guard let firebaseUser = Auth.auth().currentUser else {
            print("👤 NameCollection: No Firebase user found")
            return
        }
        
        // Check if user signed in with Google
        let isGoogleSignIn = firebaseUser.providerData.contains { $0.providerID == "google.com" }
        
        print("👤 NameCollection: Authentication check:")
        print("   - Provider data: \(firebaseUser.providerData.map { $0.providerID })")
        print("   - Is Google sign-in: \(isGoogleSignIn)")
        
        // Only pre-fill for Google sign-in users
        if isGoogleSignIn,
           let displayName = firebaseUser.displayName,
           !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            
            let nameComponents = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: " ").filter { !$0.isEmpty }
            
            if nameComponents.count >= 2 {
                firstName = nameComponents[0]
                lastName = nameComponents.dropFirst().joined(separator: " ")
                
                print("👤 NameCollection: Pre-filled Gmail user with Firebase display name:")
                print("   - First name: '\(firstName)'")
                print("   - Last name: '\(lastName)'")
                print("   - Full name: '\(displayName)'")
            } else if nameComponents.count == 1 {
                firstName = nameComponents[0]
                lastName = ""
                
                print("👤 NameCollection: Pre-filled Gmail user with single Firebase name: '\(firstName)'")
            }
        } else if isGoogleSignIn {
            print("👤 NameCollection: Gmail user but no display name found - fields remain empty")
        } else {
            print("👤 NameCollection: Email sign-in user - fields remain empty for manual entry")
        }
        #else
        print("👤 NameCollection: Firebase not available - fields remain empty")
        #endif
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