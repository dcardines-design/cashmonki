//
//  AddWalletSheet.swift
//  CashMonki
//
//  Created by Claude on 1/22/25.
//

import SwiftUI

struct AddWalletSheet: View {
    @Binding var isPresented: Bool
    let onSave: (String, Double?, Currency, Bool) -> Void

    @ObservedObject private var currencyPrefs = CurrencyPreferences.shared

    @State private var walletName: String = ""
    @State private var balanceText: String = ""
    @State private var selectedCurrency: Currency = CurrencyPreferences.shared.primaryCurrency
    @State private var showBalance: Bool = false
    @State private var showingCurrencyPicker = false
    @FocusState private var isWalletNameFocused: Bool
    @FocusState private var isBalanceFocused: Bool

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

    var body: some View {
        VStack(spacing: 0) {
            // Header - using standard SheetHeader component
            SheetHeader.basic(title: "Add Wallet") {
                isPresented = false
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Wallet Avatar
                    WalletAvatar(initial: walletInitial)

                    // Wallet Name Input
                    AppInputField.text(
                        title: "Wallet Name",
                        text: $walletName,
                        placeholder: "Enter wallet name",
                        size: .md
                    )
                    .focused($isWalletNameFocused)

                    // Starting Balance Input (in PRIMARY currency)
                    VStack(alignment: .leading, spacing: 6) {
                        AppInputField.amount(
                            title: "Starting Balance (Optional)",
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
                        let trimmedName = walletName.trimmingCharacters(in: .whitespacesAndNewlines)
                        // Use current primary currency (in case it changed while sheet is open)
                        onSave(trimmedName, parsedBalance, currencyPrefs.primaryCurrency, showBalance)
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
        onSave: { walletName, balance, currency, showBalance in
            print("New wallet: \(walletName), balance: \(balance ?? 0), currency: \(currency), showBalance: \(showBalance)")
        }
    )
}