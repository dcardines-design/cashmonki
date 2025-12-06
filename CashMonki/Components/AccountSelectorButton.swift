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
            HStack(alignment: .center, spacing: 4) {
                // Wallet avatar with initials
                Circle()
                    .fill(AppColors.walletAvatar)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(accountManager.currentSubAccount?.initials ?? userManager.currentUser.subAccounts.first?.initials ?? "P")
                            .font(AppFonts.overusedGroteskSemiBold(size: 16))
                            .foregroundColor(.white)
                    )
                
                HStack(alignment: .top, spacing: 4) {
                    VStack(alignment: .leading, spacing: 2) {
                        // First row: Wallet icon + "Wallet" text
                        HStack(alignment: .center, spacing: 4) {
                            Image("wallet-03")
                                .resizable()
                                .renderingMode(.template)
                                .frame(width: 12, height: 12)
                                .foregroundColor(Color(hex: "A0A6B8") ?? AppColors.foregroundSecondary)
                            
                            Text("Wallet")
                                .font(AppFonts.overusedGroteskMedium(size: 14))
                                .foregroundColor(AppColors.foregroundSecondary)
                        }
                        
                        // Second row: Dynamic wallet name flush with icon left edge
                        if let currentAccount = accountManager.currentSubAccount {
                            Text(currentAccount.name)
                                .font(AppFonts.overusedGroteskMedium(size: 16))
                                .foregroundColor(AppColors.foregroundPrimary)
                        } else {
                            // Fallback to first available wallet or create default
                            let fallbackName = userManager.currentUser.subAccounts.first?.name ?? "Personal"
                            Text(fallbackName)
                                .font(AppFonts.overusedGroteskMedium(size: 16))
                                .foregroundColor(AppColors.foregroundPrimary)
                        }
                    }
                }
                .padding(4)
                
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
            .padding(.vertical, 8)
        }
        .frame(width: 400, alignment: .center)
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
                .presentationDragIndicator(.hidden)
        }
        .onChange(of: showingAccountPicker) { _, newValue in
            print("🔄 AccountSelectorButton: showingAccountPicker changed to \(newValue)")
        }
    }
}

struct AccountPickerSheet: View {
    @ObservedObject var userManager = UserManager.shared
    @ObservedObject var accountManager = AccountManager.shared
    @ObservedObject var revenueCatManager = RevenueCatManager.shared
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
                        
                        AccountOptionRow(
                            icon: .initials(account.initials),
                            iconColor: account.color,
                            name: account.name,
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
                onSave: { walletName in
                    print("Creating new wallet: \(walletName)")
                    
                    // Create the actual wallet using AccountManager
                    accountManager.createSubAccount(
                        name: walletName,
                        type: .personal, // Default to personal type
                        currency: .php,  // Default to PHP
                        color: nil,      // Let it use default color
                        makeDefault: false
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
    let showSettings: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onSettingsTap: (() -> Void)?
    
    @State private var isPressed = false
    
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
                
                Text(name)
                    .font(AppFonts.overusedGroteskSemiBold(size: 16))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if showSettings {
                    Button(action: {
                        onSettingsTap?()
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
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