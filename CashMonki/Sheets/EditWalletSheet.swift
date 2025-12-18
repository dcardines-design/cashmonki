//
//  EditWalletSheet.swift
//  CashMonki
//
//  Created by Claude on 1/22/25.
//

import SwiftUI

struct EditWalletSheet: View {
    @EnvironmentObject var toastManager: ToastManager
    @Binding var isPresented: Bool
    let wallet: SubAccount
    let onWalletUpdated: (SubAccount) -> Void
    let onWalletDeleted: () -> Void

    @State private var walletName: String
    @State private var showingDeleteConfirmation = false
    @State private var changesSaved = false
    @FocusState private var isWalletNameFocused: Bool
    @ObservedObject private var accountManager = AccountManager.shared
    
    init(isPresented: Binding<Bool>, wallet: SubAccount, onWalletUpdated: @escaping (SubAccount) -> Void, onWalletDeleted: @escaping () -> Void) {
        self._isPresented = isPresented
        self.wallet = wallet
        self.onWalletUpdated = onWalletUpdated
        self.onWalletDeleted = onWalletDeleted
        self._walletName = State(initialValue: wallet.name)
    }
    
    private var isValidWalletName: Bool {
        !walletName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var walletInitial: String {
        let trimmedName = walletName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "?" : String(trimmedName.prefix(1)).uppercased()
    }
    
    private var hasChanges: Bool {
        walletName.trimmingCharacters(in: .whitespacesAndNewlines) != wallet.name
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with delete button
            SheetHeader.withCustomAction(
                title: "Edit Wallet",
                onBackTap: { 
                    if hasChanges {
                        saveChanges()
                    }
                    isPresented = false 
                },
                rightIcon: "trash-04",
                rightSystemIcon: "trash",
                onRightTap: {
                    showingDeleteConfirmation = true
                }
            )
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Wallet Avatar
                    ZStack {
                        Circle()
                            .fill(Color(red: 0x00/255.0, green: 0x80/255.0, blue: 0x80/255.0))
                            .frame(width: 80, height: 80)
                        
                        Text(walletInitial)
                            .font(AppFonts.overusedGroteskSemiBold(size: 32))
                            .foregroundColor(.white)
                    }
                    
                    // Wallet Name Input
                    CashMonkiDS.Input.text(
                        title: "Wallet Name",
                        text: $walletName,
                        placeholder: "Enter wallet name"
                    )
                    .focused($isWalletNameFocused)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 100) // Space for fixed button
            }
            
            // Fixed bottom button
            VStack(spacing: 0) {
                Divider()
                    .background(AppColors.linePrimary)
                
                AppButton(
                    title: "Save",
                    action: {
                        saveChanges()
                        isPresented = false
                    },
                    hierarchy: .primary,
                    size: .extraSmall,
                    isEnabled: hasChanges
                )
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 34)
            }
            .background(AppColors.backgroundWhite)
        }
        .background(AppColors.backgroundWhite)
        .confirmationDialog("Delete Wallet", isPresented: $showingDeleteConfirmation) {
            Button("Delete Wallet", role: .destructive) {
                deleteWallet()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete the wallet and all its transactions. This action cannot be undone.")
        }
        .onAppear {
            // Auto-focus wallet name input when sheet appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isWalletNameFocused = true
            }
        }
        .onDisappear {
            // Save changes when sheet is dismissed
            if hasChanges {
                saveChanges()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func saveChanges() {
        // Prevent duplicate saves (can be triggered by both Save button and onDisappear)
        guard !changesSaved else { return }

        let trimmedName = walletName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty && trimmedName != wallet.name else { return }

        changesSaved = true

        // Create updated wallet
        let updatedWallet = SubAccount(
            id: wallet.id,
            parentUserId: wallet.parentUserId,
            name: trimmedName,
            type: wallet.type,
            currency: wallet.currency,
            colorHex: wallet.colorHex,
            isDefault: wallet.isDefault
        )

        // Update through AccountManager
        accountManager.updateSubAccount(updatedWallet)

        // Notify parent
        onWalletUpdated(updatedWallet)

        // Show changes saved toast
        toastManager.showChangesSaved()

        print("💾 EditWalletSheet: Saved wallet name change from '\(wallet.name)' to '\(trimmedName)'")
    }
    
    private func deleteWallet() {
        print("🗑️ EditWalletSheet: Deleting wallet '\(wallet.name)' with ID: \(wallet.id.uuidString.prefix(8))")
        
        // Delete through AccountManager (handles transactions and Firebase sync)
        accountManager.deleteSubAccount(wallet.id)
        
        // Notify parent and dismiss
        onWalletDeleted()
        isPresented = false
        
        print("✅ EditWalletSheet: Wallet deletion completed")
    }
}


// MARK: - Preview

#Preview {
    EditWalletSheet(
        isPresented: .constant(true),
        wallet: SubAccount.createPersonalAccount(for: UUID()),
        onWalletUpdated: { _ in print("Wallet updated") },
        onWalletDeleted: { print("Wallet deleted") }
    )
}