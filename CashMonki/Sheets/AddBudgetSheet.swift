//
//  AddBudgetSheet.swift
//  CashMonki
//
//  Created by Claude on 12/24/25.
//

import SwiftUI

struct AddBudgetSheet: View {
    @Binding var isPresented: Bool
    let walletId: UUID
    let onSave: (Budget) -> Void

    @ObservedObject private var currencyPrefs = CurrencyPreferences.shared

    @State private var selectedCategoryId: UUID?
    @State private var selectedCategoryName: String = ""
    @State private var amountText: String = ""
    @State private var selectedPeriod: BudgetPeriod = .monthly
    @State private var selectedCurrency: Currency
    @State private var showingCurrencyPicker = false
    @State private var applyToAllPeriods: Bool = true

    @FocusState private var isAmountFocused: Bool

    init(isPresented: Binding<Bool>, walletId: UUID, onSave: @escaping (Budget) -> Void) {
        self._isPresented = isPresented
        self.walletId = walletId
        self.onSave = onSave
        self._selectedCurrency = State(initialValue: CurrencyPreferences.shared.primaryCurrency)
    }

    // MARK: - Computed Properties

    private var isFormValid: Bool {
        selectedCategoryId != nil &&
        !amountText.isEmpty &&
        parsedAmount > 0
    }

    private var parsedAmount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            SheetHeader.basic(title: "Add Budget") {
                isPresented = false
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Category Picker
                    AppInputField.budgetCategory(
                        selectedCategoryId: $selectedCategoryId,
                        selectedCategoryName: $selectedCategoryName,
                        size: .md
                    )

                    // Amount Input
                    AppInputField.amount(
                        text: $amountText,
                        selectedCurrency: Binding(
                            get: { selectedCurrency.rawValue },
                            set: { _ in }
                        ),
                        onCurrencyTap: {
                            showingCurrencyPicker = true
                        },
                        size: .md,
                        focusBinding: $isAmountFocused
                    )

                    // Period Selector
                    periodSelectorSection

                    // Calculate for all periods toggle
                    calculateForAllPeriodsSection

                    // Auto-computed estimates (only show when applying to all periods)
                    if applyToAllPeriods && parsedAmount > 0 {
                        estimatesSection
                    }

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }

            // Fixed bottom button
            VStack(spacing: 0) {
                Divider()
                    .background(AppColors.linePrimary)

                AppButton(
                    title: "Save Budget",
                    action: saveBudget,
                    hierarchy: .primary,
                    size: .extraSmall,
                    isEnabled: isFormValid
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isAmountFocused = true
            }
        }
        .sheet(isPresented: $showingCurrencyPicker) {
            CurrencyPickerSheet(
                primaryCurrency: $selectedCurrency,
                isPresented: $showingCurrencyPicker
            )
            .presentationDetents([.fraction(0.98)])
            .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - Period Selector Section

    private var periodSelectorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Budget Period")
                .font(AppFonts.overusedGroteskMedium(size: 16))
                .foregroundStyle(AppColors.foregroundSecondary)

            FlowLayout(spacing: 10) {
                ForEach(BudgetPeriod.allCases, id: \.self) { period in
                    periodChip(period)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func periodChip(_ period: BudgetPeriod) -> some View {
        let isSelected = selectedPeriod == period

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                selectedPeriod = period
            }
        }) {
            Text(period.displayName)
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

    // MARK: - Calculate For All Periods Section

    private var calculateForAllPeriodsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Calculate for all periods?")
                .font(AppFonts.overusedGroteskMedium(size: 16))
                .foregroundStyle(AppColors.foregroundSecondary)

            HStack(spacing: 10) {
                yesNoChip(label: "Yes", isSelected: applyToAllPeriods) {
                    applyToAllPeriods = true
                }
                yesNoChip(label: "No", isSelected: !applyToAllPeriods) {
                    applyToAllPeriods = false
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

    // MARK: - Estimates Section

    private var estimatesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Estimated Budgets")
                .font(AppFonts.overusedGroteskMedium(size: 16))
                .foregroundStyle(AppColors.foregroundSecondary)

            VStack(spacing: 8) {
                ForEach(BudgetPeriod.allCases, id: \.self) { period in
                    if period != selectedPeriod {
                        estimateRow(for: period)
                    }
                }
            }
            .padding(16)
            .background(AppColors.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func estimateRow(for period: BudgetPeriod) -> some View {
        // First convert amount to primary currency if needed
        let amountInPrimaryCurrency: Double
        if selectedCurrency != currencyPrefs.primaryCurrency {
            amountInPrimaryCurrency = CurrencyRateManager.shared.convertAmount(
                parsedAmount,
                from: selectedCurrency,
                to: currencyPrefs.primaryCurrency
            )
        } else {
            amountInPrimaryCurrency = parsedAmount
        }

        // Then convert the period
        let estimatedAmount = BudgetManager.shared.convertAmount(amountInPrimaryCurrency, from: selectedPeriod, to: period)

        return HStack {
            Text(period.displayName)
                .font(AppFonts.overusedGroteskMedium(size: 14))
                .foregroundStyle(AppColors.foregroundSecondary)

            Spacer()

            Text(currencyPrefs.formatPrimaryAmount(estimatedAmount))
                .font(AppFonts.overusedGroteskMedium(size: 14))
                .foregroundStyle(AppColors.foregroundPrimary)
        }
    }

    // MARK: - Actions

    private func saveBudget() {
        guard let categoryId = selectedCategoryId else { return }

        let budget = Budget(
            walletId: walletId,
            categoryId: categoryId,
            categoryName: selectedCategoryName,
            amount: parsedAmount,
            currency: selectedCurrency,
            period: selectedPeriod,
            applyToAllPeriods: applyToAllPeriods
        )

        // Track budget creation
        AnalyticsManager.shared.track(.budgetCreated, properties: [
            "category": selectedCategoryName,
            "amount": parsedAmount,
            "currency": selectedCurrency.rawValue,
            "period": selectedPeriod.rawValue,
            "apply_to_all_periods": applyToAllPeriods
        ])

        onSave(budget)
        isPresented = false
    }
}

// MARK: - Preview

#Preview {
    AddBudgetSheet(
        isPresented: .constant(true),
        walletId: UUID(),
        onSave: { budget in
            print("New budget: \(budget.categoryName) - \(budget.amount)")
        }
    )
}
