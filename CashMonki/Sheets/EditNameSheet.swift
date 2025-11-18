//
//  EditNameSheet.swift
//  Cashooya Playground
//
//  Created by Claude on 1/26/25.
//  Sheet for editing user name with first/last name inputs
//

import SwiftUI

struct EditNameSheet: View {
    @Binding var isPresented: Bool
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var showingValidationError: Bool = false
    @ObservedObject private var userManager = UserManager.shared
    @EnvironmentObject var toastManager: ToastManager
    
    /// Check if the form is valid for saving
    private var isFormValid: Bool {
        return !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button only
            SheetHeader.basic(title: "Edit Name") {
                isPresented = false
            }
            
            // Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // First Name Input
                    CashMonkiDS.Input.text(
                        title: "First Name",
                        text: $firstName,
                        placeholder: "Enter your first name"
                    )
                    
                    // Last Name Input
                    CashMonkiDS.Input.text(
                        title: "Last Name (Optional)",
                        text: $lastName,
                        placeholder: "Enter your last name"
                    )
                    
                    // Validation Error
                    if showingValidationError {
                        HStack {
                            Text("You need to have at least a first name")
                                .font(AppFonts.overusedGroteskMedium(size: 14))
                                .foregroundColor(AppColors.destructiveForeground)
                            Spacer()
                        }
                        .transition(.opacity)
                    }
                    
                    Spacer(minLength: 100) // Space for potential keyboard
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            
            // Fixed bottom save button
            FixedBottomGroup.primary(
                title: "Save",
                action: {
                    if isFormValid {
                        saveName()
                    } else {
                        showingValidationError = true
                    }
                },
                isEnabled: isFormValid
            )
        }
        .background(AppColors.backgroundWhite)
        .onAppear {
            loadCurrentUserData()
        }
        .onChange(of: firstName) { _, _ in
            // Hide validation error when user starts typing
            if showingValidationError {
                showingValidationError = false
            }
        }
    }
    
    // MARK: - Functions
    
    private func loadCurrentUserData() {
        let currentUser = userManager.currentUser
        let fullName = currentUser.name
        
        // Split full name into first and last name
        let nameComponents = fullName.components(separatedBy: " ")
        if nameComponents.count > 0 {
            firstName = nameComponents[0]
        }
        if nameComponents.count > 1 {
            lastName = nameComponents.dropFirst().joined(separator: " ")
        }
        
        print("📝 EditNameSheet: Loaded current user data - First: '\(firstName)', Last: '\(lastName)'")
    }
    
    private func saveName() {
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Construct full name
        let newFullName: String
        if trimmedLast.isEmpty {
             newFullName = trimmedFirst
        } else {
            newFullName = "\(trimmedFirst) \(trimmedLast)"
        }
        
        print("💾 EditNameSheet: Saving name - '\(newFullName)'")
        
        // Update user manager
        userManager.updateUserName(newFullName)
        
        // Show success toast
        toastManager.showSuccess("Name updated!")
        
        // Dismiss keyboard and sheet
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        isPresented = false
        
        print("✅ EditNameSheet: Name saved successfully")
    }
}

#Preview {
    EditNameSheet(isPresented: .constant(true))
        .environmentObject(ToastManager())
}
