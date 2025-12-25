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
    @State private var balanceText: String
    @State private var selectedCurrency: Currency
    @State private var showBalance: Bool
    @State private var showingDeleteConfirmation = false
    @State private var showingCurrencyPicker = false
    @State private var showingBalanceConfirmation = false
    @State private var changesSaved = false
    @FocusState private var isWalletNameFocused: Bool
    @FocusState private var isBalanceFocused: Bool
    @ObservedObject private var accountManager = AccountManager.shared
    @ObservedObject private var userManager = UserManager.shared
    @ObservedObject private var currencyPrefs = CurrencyPreferences.shared

    init(isPresented: Binding<Bool>, wallet: SubAccount, onWalletUpdated: @escaping (SubAccount) -> Void, onWalletDeleted: @escaping () -> Void) {
        self._isPresented = isPresented
        self.wallet = wallet
        self.onWalletUpdated = onWalletUpdated
        self.onWalletDeleted = onWalletDeleted
        self._walletName = State(initialValue: wallet.name)

        // Show computed balance converted to PRIMARY currency
        let transactions = UserManager.shared.currentUser.transactions
        let primaryCurrency = CurrencyPreferences.shared.primaryCurrency

        let computedBalanceInPrimary: Double? = {
            guard let startingBalance = wallet.balance else { return nil }

            // Convert starting balance to primary currency
            let startingInPrimary: Double
            if wallet.currency != primaryCurrency {
                startingInPrimary = CurrencyRateManager.shared.convertAmount(startingBalance, from: wallet.currency, to: primaryCurrency)
            } else {
                startingInPrimary = startingBalance
            }

            // Transaction amounts are already in primary currency
            let transactionTotal = transactions
                .filter { $0.walletID == wallet.id }
                .reduce(0) { $0 + $1.amount }

            return startingInPrimary + transactionTotal
        }()

        self._balanceText = State(initialValue: computedBalanceInPrimary != nil ? String(format: "%.0f", computedBalanceInPrimary!) : "")

        self._selectedCurrency = State(initialValue: primaryCurrency)  // Use primary currency for display
        self._showBalance = State(initialValue: wallet.showBalance)
    }

    private var isValidWalletName: Bool {
        !walletName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var walletInitial: String {
        let trimmedName = walletName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "?" : String(trimmedName.prefix(1)).uppercased()
    }

    private var parsedBalance: Double? {
        let cleaned = balanceText.replacingOccurrences(of: ",", with: "")
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }

    // Compute original current balance in PRIMARY currency for comparison
    private var originalCurrentBalance: Double? {
        guard let startingBalance = wallet.balance else { return nil }
        let primaryCurrency = currencyPrefs.primaryCurrency
        let transactions = userManager.currentUser.transactions

        // Convert starting balance to primary currency
        let startingInPrimary: Double
        if wallet.currency != primaryCurrency {
            startingInPrimary = CurrencyRateManager.shared.convertAmount(startingBalance, from: wallet.currency, to: primaryCurrency)
        } else {
            startingInPrimary = startingBalance
        }

        // Transaction amounts are already in primary currency
        let transactionTotal = transactions
            .filter { $0.walletID == wallet.id }
            .reduce(0) { $0 + $1.amount }

        return startingInPrimary + transactionTotal
    }

    // Check if balance field value has changed from original current balance
    private var hasBalanceChanged: Bool {
        parsedBalance != originalCurrentBalance
    }

    private var hasChanges: Bool {
        walletName.trimmingCharacters(in: .whitespacesAndNewlines) != wallet.name ||
        hasBalanceChanged ||
        showBalance != wallet.showBalance
    }

    // Format the new balance for display in confirmation dialog (uses primary currency)
    private var formattedNewBalance: String {
        guard let balance = parsedBalance else { return "" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        let formattedAmount = formatter.string(from: NSNumber(value: balance)) ?? "\(balance)"
        return "\(currencyPrefs.primaryCurrency.symbol)\(formattedAmount)"
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

                    // Current Balance Input (shown in PRIMARY currency)
                    VStack(alignment: .leading, spacing: 6) {
                        AppInputField.amount(
                            title: "Current Balance (Optional)",
                            text: $balanceText,
                            selectedCurrency: Binding(
                                get: { currencyPrefs.primaryCurrency.rawValue },
                                set: { _ in }
                            ),
                            onCurrencyTap: { },
                            size: .md,
                            focusBinding: $isBalanceFocused,
                            isCurrencyDisabled: true
                        )

                        Text("You can change wallet currency in Profile")
                            .font(AppFonts.overusedGroteskMedium(size: 14))
                            .foregroundColor(AppColors.foregroundSecondary)
                    }

                    // Show balance in preview toggle
                    showBalanceSection
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
                        // Show confirmation if balance changed, otherwise save directly
                        if hasBalanceChanged && parsedBalance != nil {
                            showingBalanceConfirmation = true
                        } else {
                            saveChanges()
                            isPresented = false
                        }
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
        .alert("Update Balance?", isPresented: $showingBalanceConfirmation) {
            Button("Nevermind", role: .cancel) { }
            Button("Do it") {
                saveChanges()
                isPresented = false
            }
        } message: {
            Text("Setting your balance to \(formattedNewBalance) will adjust your starting balance. Your future spending will update from here.")
        }
        .sheet(isPresented: $showingCurrencyPicker) {
            CurrencyPickerSheet(
                primaryCurrency: $selectedCurrency,
                isPresented: $showingCurrencyPicker
            )
            .presentationDetents([.fraction(0.98)])
            .presentationDragIndicator(.hidden)
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
    
    // MARK: - Show Balance Section

    private var showBalanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Show balance in preview?")
                .font(AppFonts.overusedGroteskMedium(size: 16))
                .foregroundStyle(AppColors.foregroundSecondary)

            HStack(spacing: 10) {
                yesNoChip(label: "Yes", isSelected: showBalance) {
                    showBalance = true
                }
                yesNoChip(label: "No", isSelected: !showBalance) {
                    showBalance = false
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func yesNoChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                action()
            }
        }) {
            Text(label)
                .font(AppFonts.overusedGroteskMedium(size: 16))
                .foregroundStyle(isSelected ? AppColors.primary : AppColors.foregroundSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? Color(red: 0.33, green: 0.18, blue: 1).opacity(0.1) : Color.clear)
                .background(isSelected ? .white : AppColors.surfacePrimary)
                .cornerRadius(12)
                .animation(.easeInOut(duration: 0.1), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Helper Methods

    private func saveChanges() {
        // Prevent duplicate saves (can be triggered by both Save button and onDisappear)
        guard !changesSaved else { return }

        let trimmedName = walletName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty && hasChanges else { return }

        changesSaved = true

        let primaryCurrency = currencyPrefs.primaryCurrency

        // Calculate the new starting balance by back-calculating from entered current balance
        // User enters balance in PRIMARY currency, we need to convert to WALLET's native currency
        var newStartingBalance: Double? = nil
        if let enteredBalanceInPrimary = parsedBalance {
            let transactions = userManager.currentUser.transactions
            // Transaction amounts are already in primary currency
            let transactionTotalInPrimary = transactions
                .filter { $0.walletID == wallet.id }
                .reduce(0) { $0 + $1.amount }

            // Calculate starting balance in PRIMARY currency
            let startingBalanceInPrimary = enteredBalanceInPrimary - transactionTotalInPrimary

            // Convert starting balance from PRIMARY to WALLET's native currency
            if wallet.currency != primaryCurrency {
                newStartingBalance = CurrencyRateManager.shared.convertAmount(startingBalanceInPrimary, from: primaryCurrency, to: wallet.currency)
                print("💰 EditWalletSheet: Back-calculated starting balance: \(enteredBalanceInPrimary) - \(transactionTotalInPrimary) = \(startingBalanceInPrimary) \(primaryCurrency.rawValue)")
                print("💰 EditWalletSheet: Converted to wallet currency: \(newStartingBalance!) \(wallet.currency.rawValue)")
            } else {
                newStartingBalance = startingBalanceInPrimary
                print("💰 EditWalletSheet: Back-calculated starting balance: \(enteredBalanceInPrimary) - \(transactionTotalInPrimary) = \(newStartingBalance!)")
            }
        }

        // Create updated wallet with back-calculated starting balance (keep wallet's original currency!)
        let updatedWallet = SubAccount(
            id: wallet.id,
            parentUserId: wallet.parentUserId,
            name: trimmedName,
            type: wallet.type,
            currency: wallet.currency,  // Keep wallet's original currency, NOT selectedCurrency
            colorHex: wallet.colorHex,
            isDefault: wallet.isDefault,
            balance: newStartingBalance,
            showBalance: showBalance
        )

        // Update through AccountManager
        accountManager.updateSubAccount(updatedWallet)

        // Notify parent
        onWalletUpdated(updatedWallet)

        // Show changes saved toast
        toastManager.showChangesSaved()

        print("💾 EditWalletSheet: Saved wallet changes for '\(trimmedName)'")
    }
    
    private func deleteWallet() {
        print("🗑️ EditWalletSheet: Deleting wallet '\(wallet.name)' with ID: \(wallet.id.uuidString.prefix(8))")

        // Delete through AccountManager (handles transactions and Firebase sync)
        accountManager.deleteSubAccount(wallet.id)

        // Notify parent and dismiss
        onWalletDeleted()
        isPresented = false

        // Show deleted toast
        toastManager.showDeleted("Wallet deleted")

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