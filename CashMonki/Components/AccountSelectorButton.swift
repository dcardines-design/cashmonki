//
//  AccountSelectorButton.swift
//  CashMonki
//
//  Created by Claude on 1/22/25.
//

import SwiftUI

struct AccountSelectorButton: View {
    @ObservedObject var userManager = UserManager.shared
    @ObservedObject var accountManager = AccountManager.shared
    @ObservedObject var currencyPrefs = CurrencyPreferences.shared  // Observe for currency changes
    @State private var showingAccountPicker = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            print("🔘 AccountSelectorButton: Button tapped - current state: \(showingAccountPicker)")
            print("🔘 AccountSelectorButton: Available accounts: \(userManager.currentUser.subAccounts.map { $0.name })")
            print("🔘 AccountSelectorButton: Account count: \(userManager.currentUser.subAccounts.count)")
            print("🔘 AccountSelectorButton: Raw accounts: \(userManager.currentUser.accounts.map { $0.name })")
            showingAccountPicker = true
            print("🔘 AccountSelectorButton: State set to: \(showingAccountPicker)")
        }) {
            HStack(alignment: .center, spacing: 12) {
                // Wallet avatar with initials
                Circle()
                    .fill(AppColors.walletAvatar)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(accountManager.currentSubAccount?.initials ?? userManager.currentUser.subAccounts.first?.initials ?? "P")
                            .font(AppFonts.overusedGroteskSemiBold(size: 16))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    // Wallet name
                    if let currentAccount = accountManager.currentSubAccount {
                        Text(currentAccount.name)
                            .font(AppFonts.overusedGroteskSemiBold(size: 16))
                            .foregroundColor(AppColors.foregroundPrimary)
                    } else {
                        let fallbackName = userManager.currentUser.subAccounts.first?.name ?? "Personal"
                        Text(fallbackName)
                            .font(AppFonts.overusedGroteskSemiBold(size: 16))
                            .foregroundColor(AppColors.foregroundPrimary)
                    }

                    // Second row: Wallet icon + Balance (only if balance exists)
                    if let currentAccount = accountManager.currentSubAccount ?? userManager.currentUser.subAccounts.first,
                       currentAccount.balance != nil {
                        HStack(alignment: .center, spacing: 4) {
                            Image("wallet-03")
                                .resizable()
                                .renderingMode(.template)
                                .frame(width: 14, height: 14)
                                .foregroundColor(Color(hex: "A0A6B8") ?? AppColors.foregroundSecondary)

                            Text(formatWalletBalance(account: currentAccount))
                                .font(AppFonts.overusedGroteskMedium(size: 14))
                                .foregroundColor(AppColors.foregroundSecondary)
                        }
                    }
                }

                Spacer()

                // Dropdown arrow - 24px size with #72788A color
                Image("chevron-selector-vertical")
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 24, height: 24)
                    .foregroundColor(Color(hex: "72788A") ?? AppColors.foregroundSecondary)
            }
            .padding(.leading, 10)
            .padding(.trailing, 18)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .background(isPressed ? AppColors.surfacePrimary : .white)
        .cornerRadius(200)
        .shadow(color: isPressed ? .clear : Color(red: 0.86, green: 0.89, blue: 0.96), radius: 0, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 200)
                .inset(by: 0.5)
                .stroke(AppColors.linePrimary, lineWidth: 1)
        )
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {
            // Long press action (same as tap for this button)
            print("🔘 AccountSelectorButton: Button tapped - current state: \(showingAccountPicker)")
            print("🔘 AccountSelectorButton: Available accounts: \(userManager.currentUser.subAccounts.map { $0.name })")
            showingAccountPicker = true
            print("🔘 AccountSelectorButton: State set to: \(showingAccountPicker)")
        })
        .sheet(isPresented: $showingAccountPicker) {
            AccountPickerSheet(isPresented: $showingAccountPicker)
                .presentationDetents([.fraction(0.98)])
                .presentationCornerRadius(20)
                .presentationDragIndicator(.hidden)
        }
        .onChange(of: showingAccountPicker) { _, newValue in
            print("🔄 AccountSelectorButton: showingAccountPicker changed to \(newValue)")
        }
    }

    // Format wallet balance for display (computed: starting balance + transactions, converted to primary currency)
    private func formatWalletBalance(account: SubAccount) -> String {
        // Only show balance if user has set a starting balance
        guard let startingBalance = account.balance else { return "" }

        if !account.showBalance {
            return "********"
        }

        let primaryCurrency = currencyPrefs.primaryCurrency

        // Debug logging
        print("💰 formatWalletBalance: account.currency=\(account.currency.rawValue), primaryCurrency=\(primaryCurrency.rawValue), startingBalance=\(startingBalance)")

        // Convert starting balance from wallet currency to primary currency FIRST
        let startingBalanceInPrimary: Double
        if account.currency != primaryCurrency {
            startingBalanceInPrimary = CurrencyRateManager.shared.convertAmount(startingBalance, from: account.currency, to: primaryCurrency)
            print("💰 formatWalletBalance: Converted \(startingBalance) \(account.currency.rawValue) → \(startingBalanceInPrimary) \(primaryCurrency.rawValue)")
        } else {
            startingBalanceInPrimary = startingBalance
            print("💰 formatWalletBalance: No conversion needed (same currency)")
        }

        // Convert each transaction to primary currency (subscription transactions may be in different currencies)
        let transactions = userManager.currentUser.transactions
        let transactionTotal = transactions
            .filter { $0.walletID == account.id }
            .reduce(0.0) { total, txn in
                let converted = txn.primaryCurrency == primaryCurrency
                    ? txn.amount
                    : CurrencyRateManager.shared.convertAmount(txn.amount, from: txn.primaryCurrency, to: primaryCurrency)
                return total + converted
            }

        // Now both are in primary currency - safe to add
        let displayBalance = startingBalanceInPrimary + transactionTotal

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","

        let formattedAmount = formatter.string(from: NSNumber(value: displayBalance)) ?? "\(displayBalance)"
        return "\(primaryCurrency.symbol)\(formattedAmount)"
    }
}

struct AccountPickerSheet: View {
    @ObservedObject var userManager = UserManager.shared
    @ObservedObject var accountManager = AccountManager.shared
    @ObservedObject var revenueCatManager = RevenueCatManager.shared
    @ObservedObject var currencyPrefs = CurrencyPreferences.shared  // Observe for currency changes
    @Binding var isPresented: Bool
    @State private var showingAddWallet = false
    @State private var showingEditWallet = false
    @State private var showingCustomPaywall = false
    @State private var selectedWalletForEdit: SubAccount?
    
    // Check if user has reached wallet limit (2 for free users)
    private var hasReachedWalletLimit: Bool {
        let currentWalletCount = userManager.currentUser.subAccounts.count
        let limit = revenueCatManager.isProUser ? Int.max : 2
        return currentWalletCount >= limit
    }
    
    var body: some View {
        let _ = print("🏦 AccountPickerSheet.body: Rendering with \(userManager.currentUser.subAccounts.count) accounts: \(userManager.currentUser.subAccounts.map { $0.name })")
        
        VStack(spacing: 0) {
            // Header using the same component as CategoryPickerSheet
            SheetHeader.withCustomAction(
                title: "Wallets",
                onBackTap: { 
                    print("🔙 AccountPickerSheet: Back button tapped")
                    isPresented = false 
                },
                rightIcon: "plus",
                rightSystemIcon: "plus",
                onRightTap: {
                    if hasReachedWalletLimit {
                        showingCustomPaywall = true
                    } else {
                        showingAddWallet = true
                    }
                }
            )
            
            // Scrollable content area
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    // Individual sub-accounts
                    ForEach(userManager.currentUser.subAccounts, id: \.id) { account in
                        let isSelected = accountManager.selectedSubAccountId == account.id
                        let _ = print("🔍 AccountPickerSheet: Account '\(account.name)' (ID: \(account.id.uuidString.prefix(8))) - Selected: \(isSelected) (SelectedID: \(accountManager.selectedSubAccountId?.uuidString.prefix(8) ?? "nil"))")

                        // Compute current balance properly:
                        // 1. Convert starting balance to primary currency
                        // 2. Add transaction total (already in primary currency)
                        let primaryCurrency = currencyPrefs.primaryCurrency
                        let transactions = userManager.currentUser.transactions
                        let computedBalance: Double? = {
                            guard let startingBalance = account.balance else { return nil }

                            // Convert starting balance to primary currency
                            let startingInPrimary: Double
                            if account.currency != primaryCurrency {
                                startingInPrimary = CurrencyRateManager.shared.convertAmount(startingBalance, from: account.currency, to: primaryCurrency)
                            } else {
                                startingInPrimary = startingBalance
                            }

                            // Convert each transaction to primary currency
                            let transactionTotal = transactions
                                .filter { $0.walletID == account.id }
                                .reduce(0.0) { total, txn in
                                    let converted = txn.primaryCurrency == primaryCurrency
                                        ? txn.amount
                                        : CurrencyRateManager.shared.convertAmount(txn.amount, from: txn.primaryCurrency, to: primaryCurrency)
                                    return total + converted
                                }

                            return startingInPrimary + transactionTotal
                        }()

                        AccountOptionRow(
                            icon: .initials(account.initials),
                            iconColor: account.color,
                            name: account.name,
                            balance: computedBalance,
                            currency: primaryCurrency,  // Balance is already converted to primary
                            showBalanceInPreview: account.showBalance,
                            showSettings: true,
                            isSelected: isSelected,
                            onTap: {
                                print("👤 AccountPickerSheet: Account '\(account.name)' (ID: \(account.id.uuidString.prefix(8))) selected")
                                accountManager.selectAccount(account)
                                isPresented = false
                            },
                            onSettingsTap: {
                                print("⚙️ AccountPickerSheet: Settings tapped for wallet '\(account.name)' (ID: \(account.id.uuidString.prefix(8)))")
                                selectedWalletForEdit = account
                                print("⚙️ selectedWalletForEdit set to: \(account.name)")
                                showingEditWallet = true
                                print("⚙️ showingEditWallet set to: true")
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
        }
        .background(AppColors.backgroundWhite)
        .sheet(isPresented: $showingAddWallet) {
            AddWalletSheet(
                isPresented: $showingAddWallet,
                onSave: { walletName, balance, currency, showBalance in
                    print("Creating new wallet: \(walletName)")

                    // Create the actual wallet using AccountManager
                    accountManager.createSubAccount(
                        name: walletName,
                        type: .personal, // Default to personal type
                        currency: currency,
                        color: nil,      // Let it use default color
                        makeDefault: false,
                        balance: balance,
                        showBalance: showBalance
                    )

                    print("✅ Wallet '\(walletName)' created successfully")

                    // Force UI refresh after account creation
                    DispatchQueue.main.async {
                        accountManager.objectWillChange.send()
                        userManager.objectWillChange.send()
                    }
                }
            )
            .presentationDetents([.fraction(0.98)])
            .presentationCornerRadius(20)
            .presentationDragIndicator(.hidden)
        }
        .onChange(of: showingEditWallet) { _, newValue in
            print("🔄 showingEditWallet changed to: \(newValue)")
            if newValue {
                print("🔍 selectedWalletForEdit when sheet opens: \(selectedWalletForEdit?.name ?? "nil")")
            }
        }
        .sheet(isPresented: $showingEditWallet) {
            Group {
                if let wallet = selectedWalletForEdit {
                    EditWalletSheet(
                        isPresented: $showingEditWallet,
                        wallet: wallet,
                        onWalletUpdated: { updatedWallet in
                            print("✅ Wallet '\(updatedWallet.name)' updated successfully")
                            
                            // Force UI refresh after account update
                            DispatchQueue.main.async {
                                accountManager.objectWillChange.send()
                                userManager.objectWillChange.send()
                            }
                        },
                        onWalletDeleted: {
                            print("✅ Wallet deleted successfully")
                            
                            // Close the wallet picker since wallet was deleted
                            isPresented = false
                            
                            // Force UI refresh after account deletion
                            DispatchQueue.main.async {
                                accountManager.objectWillChange.send()
                                userManager.objectWillChange.send()
                            }
                        }
                    )
                    .onAppear {
                        print("✅ EditWalletSheet presenting with wallet: \(wallet.name)")
                    }
                } else {
                    VStack(spacing: 16) {
                        Text("DEBUG: No wallet selected")
                            .font(.headline)
                            .foregroundColor(AppColors.destructiveForeground)
                        Text("selectedWalletForEdit is nil")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Button("Close") {
                            showingEditWallet = false
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white)
                    .onAppear {
                        print("❌ EditWalletSheet: selectedWalletForEdit is nil when sheet presents!")
                    }
                }
            }
            .presentationDetents([.fraction(0.98)])
            .presentationCornerRadius(20)
            .presentationDragIndicator(.hidden)

            /* BOTTOM SHEET REFERENCE FOR FUTURE DESIGNS:
            .presentationDetents([.height(400)])  // Fixed height bottom sheet
            .presentationDetents([.height(350)])  // Smaller bottom sheet
            .presentationDetents([.height(450)])  // Larger bottom sheet
            .presentationDetents([.height(380)])  // Compact bottom sheet
            .presentationDetents([.fraction(0.5)]) // 50% screen height
            .presentationDetents([.fraction(0.4)]) // 40% screen height
            */
        }
        .fullScreenCover(isPresented: $showingCustomPaywall) {
            CustomPaywallSheet(isPresented: $showingCustomPaywall)
        }
    }
    
}

enum AccountIcon {
    case systemIcon(String)
    case initials(String)
}

struct AccountOptionRow: View {
    let icon: AccountIcon
    let iconColor: Color
    let name: String
    let balance: Double?
    let currency: Currency
    let showBalanceInPreview: Bool
    let showSettings: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onSettingsTap: (() -> Void)?

    @State private var isPressed = false

    // Format balance for display (converted to primary currency)
    private var balanceText: String {
        guard let balance = balance else { return "" }

        if !showBalanceInPreview {
            return "********"
        }

        // Convert to primary currency if different
        let primaryCurrency = CurrencyPreferences.shared.primaryCurrency
        let displayBalance: Double
        if currency != primaryCurrency {
            displayBalance = CurrencyRateManager.shared.convertAmount(balance, from: currency, to: primaryCurrency)
        } else {
            displayBalance = balance
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","

        let formattedAmount = formatter.string(from: NSNumber(value: displayBalance)) ?? "\(displayBalance)"
        return "\(primaryCurrency.symbol)\(formattedAmount)"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Account icon
                Circle()
                    .fill(AppColors.walletAvatar)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Group {
                            switch icon {
                            case .systemIcon(let systemName):
                                Image(systemName: systemName)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                            case .initials(let initials):
                                Text(initials)
                                    .font(AppFonts.overusedGroteskSemiBold(size: 16))
                                    .foregroundColor(.white)
                            }
                        }
                    )

                // Name and balance
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(AppFonts.overusedGroteskSemiBold(size: 16))
                        .foregroundColor(AppColors.foregroundPrimary)

                    if balance != nil {
                        Text(balanceText)
                            .font(AppFonts.overusedGroteskMedium(size: 14))
                            .foregroundColor(AppColors.foregroundSecondary)
                    }
                }

                Spacer()

                if showSettings {
                    Button(action: {
                        onSettingsTap?()
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.foregroundSecondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isPressed ? AppColors.surfacePrimary : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? AppColors.accentBackground : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {
            onTap()
        })
    }
}

// MARK: - AccountOptionRow Extensions

extension AccountOptionRow {
    init(icon: AccountIcon, iconColor: Color, name: String, showSettings: Bool, isSelected: Bool, onTap: @escaping () -> Void) {
        self.icon = icon
        self.iconColor = iconColor
        self.name = name
        self.balance = nil
        self.currency = .php
        self.showBalanceInPreview = true
        self.showSettings = showSettings
        self.isSelected = isSelected
        self.onTap = onTap
        self.onSettingsTap = nil
    }
}

#Preview {
    AccountSelectorButton()
        .padding()
        .background(Color.gray.opacity(0.1))
}