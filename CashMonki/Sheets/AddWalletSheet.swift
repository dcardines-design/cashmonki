//
//  AddWalletSheet.swift
//  CashMonki
//
//  Created by Claude on 1/22/25.
//

import SwiftUI

struct AddWalletSheet: View {
    @Binding var isPresented: Bool
    let onSave: (String) -> Void
    
    @State private var walletName: String = ""
    @FocusState private var isWalletNameFocused: Bool
    
    private var isValidWalletName: Bool {
        !walletName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var walletInitial: String {
        let trimmedName = walletName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "?" : String(trimmedName.prefix(1)).uppercased()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header - using standard SheetHeader component
            SheetHeader.basic(title: "Add Wallet") {
                isPresented = false
            }
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Wallet Avatar
                    WalletAvatar(initial: walletInitial)
                    
                    // Wallet Name Input
                    AppInputField.text(
                        title: "Wallet Name",
                        text: $walletName,
                        placeholder: "Enter wallet name",
                        size: .md
                    )
                    .fixedSize(horizontal: false, vertical: true)
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
                        let trimmedName = walletName.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(trimmedName)
                        isPresented = false
                    },
                    hierarchy: .primary,
                    size: .extraSmall,
                    isEnabled: isValidWalletName
                )
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 34)
            }
            .background(AppColors.backgroundWhite)
        }
        .background(AppColors.backgroundWhite)
        .onAppear {
            // Auto-focus wallet name input when sheet appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isWalletNameFocused = true
            }
        }
    }
}

// MARK: - Wallet Avatar Component

struct WalletAvatar: View {
    let initial: String
    
    var body: some View {
        ZStack {
            Circle()
                .fill(AppColors.walletAvatar)
                .frame(width: 80, height: 80)
            
            Text(initial)
                .font(AppFonts.overusedGroteskSemiBold(size: 32))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Preview

#Preview {
    AddWalletSheet(
        isPresented: .constant(true),
        onSave: { walletName in
            print("New wallet: \(walletName)")
        }
    )
}