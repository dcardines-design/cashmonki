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
    @State private var name: String = ""
    @ObservedObject private var userManager = UserManager.shared
    @EnvironmentObject var toastManager: ToastManager

    var body: some View {
        VStack(spacing: 0) {
            // Header with back button only
            SheetHeader.basic(title: "Edit Name") {
                isPresented = false
            }

            // Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Name Input
                    CashMonkiDS.Input.text(
                        title: "Name (Optional)",
                        text: $name,
                        placeholder: "Enter your name"
                    )

                    Spacer(minLength: 100) // Space for potential keyboard
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }

            // Fixed bottom save button (always enabled)
            FixedBottomGroup.primary(
                title: "Save",
                action: {
                    saveName()
                }
            )
        }
        .background(AppColors.backgroundWhite)
        .onAppear {
            loadCurrentUserData()
        }
    }
    
    // MARK: - Functions

    private func loadCurrentUserData() {
        let currentUser = userManager.currentUser
        // Load full name, but show empty if it's the default
        let currentName = currentUser.name
        name = currentName == "Cashmonki User" ? "" : currentName

        print("📝 EditNameSheet: Loaded current user data - Name: '\(name)'")
    }

    private func saveName() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        print("💾 EditNameSheet: Saving name - '\(trimmedName)'")

        // Update user manager (empty name will default to "Cashmonki User")
        userManager.updateUserName(trimmedName)

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
