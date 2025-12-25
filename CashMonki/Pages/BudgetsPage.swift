//
//  BudgetsPage.swift
//  CashMonki
//
//  Created by Dante Cardines III on 12/24/25.
//

import SwiftUI
import Foundation
import Combine

struct BudgetsPage: View {
    @ObservedObject private var userManager = UserManager.shared
    @ObservedObject private var accountManager = AccountManager.shared
    @ObservedObject private var budgetManager = BudgetManager.shared
    @ObservedObject private var currencyPrefs = CurrencyPreferences.shared
    @EnvironmentObject var toastManager: ToastManager

    @State private var selectedPeriodFilter: BudgetPeriod = {
        // Load cached period from UserDefaults
        if let cachedValue = UserDefaults.standard.string(forKey: "cachedBudgetPeriod"),
           let period = BudgetPeriod(rawValue: cachedValue) {
            return period
        }
        return .monthly
    }()
    @State private var dateOffset: Int = 0  // 0 = current period, -1 = previous, etc.
    @State private var showingAddBudget: Bool = false
    @State private var selectedBudgetForEdit: Budget?
    @State private var showingBudgetMenu: Budget?

    // MARK: - Date Navigation

    /// The date for the selected period offset
    private var selectedDate: Date {
        let calendar = Calendar.current
        let now = Date()

        switch selectedPeriodFilter {
        case .daily:
            return calendar.date(byAdding: .day, value: dateOffset, to: now) ?? now
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: dateOffset, to: now) ?? now
        case .monthly:
            return calendar.date(byAdding: .month, value: dateOffset, to: now) ?? now
        case .quarterly:
            return calendar.date(byAdding: .month, value: dateOffset * 3, to: now) ?? now
        case .yearly:
            return calendar.date(byAdding: .year, value: dateOffset, to: now) ?? now
        }
    }

    /// Formatted label for the date navigation
    private var dateNavigationLabel: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()

        switch selectedPeriodFilter {
        case .daily:
            if dateOffset == 0 {
                return "Today"
            } else if dateOffset == -1 {
                return "Yesterday"
            } else {
                formatter.dateFormat = "MMM d"
                return formatter.string(from: selectedDate)
            }
        case .weekly:
            let weekRange = budgetManager.periodRange(for: .weekly, containing: selectedDate)
            formatter.dateFormat = "MMM d"
            let start = formatter.string(from: weekRange.lowerBound)
            let end = formatter.string(from: weekRange.upperBound)
            if dateOffset == 0 {
                return "This Week"
            } else if dateOffset == -1 {
                return "Last Week"
            } else {
                return "\(start) - \(end)"
            }
        case .monthly:
            if dateOffset == 0 {
                return "This Month"
            } else if dateOffset == -1 {
                return "Last Month"
            } else {
                formatter.dateFormat = "MMMM yyyy"
                return formatter.string(from: selectedDate)
            }
        case .quarterly:
            let month = calendar.component(.month, from: selectedDate)
            let year = calendar.component(.year, from: selectedDate)
            let quarter = ((month - 1) / 3) + 1
            if dateOffset == 0 {
                return "This Quarter"
            } else {
                return "Q\(quarter) \(year)"
            }
        case .yearly:
            if dateOffset == 0 {
                return "This Year"
            } else {
                formatter.dateFormat = "yyyy"
                return formatter.string(from: selectedDate)
            }
        }
    }

    // MARK: - Computed Properties

    /// Get budgets for selected wallet filtered by period visibility
    private var budgetsForWallet: [Budget] {
        guard let walletId = accountManager.selectedSubAccountId else {
            return []
        }
        let allBudgets = userManager.getBudgets(for: walletId)

        // Filter: show budget if applyToAllPeriods is true, OR if budget.period matches selected tab
        return allBudgets.filter { budget in
            budget.applyToAllPeriods || budget.period == selectedPeriodFilter
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Period filter tabs (like month tabs in transactions)
            periodTabsSection

            // Date navigation
            dateNavigationSection

            // Budgets content
            if budgetsForWallet.isEmpty {
                emptyStateView
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        budgetListView
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 0)
                    .padding(.bottom, 20)
                }
                .background(AppColors.surfacePrimary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.surfacePrimary)
        .sheet(isPresented: $showingAddBudget) {
            if let walletId = accountManager.selectedSubAccountId {
                AddBudgetSheet(
                    isPresented: $showingAddBudget,
                    walletId: walletId,
                    onSave: { budget in
                        userManager.addBudget(budget)
                        toastManager.showSuccess("Budget added!")
                    }
                )
                .presentationDetents([.fraction(0.98)])
                .presentationDragIndicator(.hidden)
            }
        }
        .sheet(item: $selectedBudgetForEdit) { budget in
            EditBudgetSheet(
                isPresented: Binding(
                    get: { selectedBudgetForEdit != nil },
                    set: { if !$0 { selectedBudgetForEdit = nil } }
                ),
                budget: budget,
                onSave: { updatedBudget in
                    userManager.updateBudget(updatedBudget)
                    toastManager.showSuccess("Budget updated!")
                },
                onDelete: {
                    userManager.deleteBudget(budget)
                    toastManager.showDeleted("Budget deleted")
                }
            )
            .presentationDetents([.fraction(0.98)])
            .presentationDragIndicator(.hidden)
        }
        .confirmationDialog(
            "Budget Options",
            isPresented: Binding(
                get: { showingBudgetMenu != nil },
                set: { if !$0 { showingBudgetMenu = nil } }
            ),
            presenting: showingBudgetMenu
        ) { budget in
            Button("Edit Budget") {
                selectedBudgetForEdit = budget
            }
            Button("Delete Budget", role: .destructive) {
                userManager.deleteBudget(budget)
                toastManager.showDeleted("Budget deleted")
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Period Tabs Section (like month tabs in transactions)

    private var periodTabsSection: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(BudgetPeriod.allCases.enumerated()), id: \.element) { index, period in
                        AppTab(
                            title: period.displayName,
                            action: {
                                selectedPeriodFilter = period
                                dateOffset = 0  // Reset to current when switching tabs
                            },
                            state: selectedPeriodFilter == period ? .selected : .inactive
                        )
                        .id("period_\(index)")
                    }
                }
                .padding(.horizontal, 16)
            }
            .onAppear {
                // Scroll to selected period on appear
                if let index = BudgetPeriod.allCases.firstIndex(of: selectedPeriodFilter) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("period_\(index)", anchor: .center)
                        }
                    }
                }
            }
            .onChange(of: selectedPeriodFilter) { _, newPeriod in
                // Cache the selected period
                UserDefaults.standard.set(newPeriod.rawValue, forKey: "cachedBudgetPeriod")

                // Scroll to the newly selected period
                if let index = BudgetPeriod.allCases.firstIndex(of: newPeriod) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo("period_\(index)", anchor: .center)
                    }
                }
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 0)
        .background(AppColors.backgroundWhite)
        .overlay(
            Rectangle()
                .fill(AppColors.linePrimary)
                .frame(height: 1)
                .frame(maxWidth: .infinity)
            , alignment: .bottom
        )
    }

    // MARK: - Date Navigation Section

    private var dateNavigationSection: some View {
        HStack {
            // Previous button
            AppButton(
                title: "",
                action: { dateOffset -= 1 },
                hierarchy: .secondary,
                size: .doubleExtraSmall,
                leftIcon: "chevron-left",
                iconColorOverride: AppColors.foregroundPrimary
            )
            .frame(width: 80)

            Spacer()

            // Date label
            Text(dateNavigationLabel)
                .font(AppFonts.overusedGroteskSemiBold(size: 18))
                .foregroundStyle(AppColors.foregroundPrimary)

            Spacer()

            // Next button (disabled if at current period)
            AppButton(
                title: "",
                action: { dateOffset += 1 },
                hierarchy: .secondary,
                size: .doubleExtraSmall,
                leftIcon: "chevron-right",
                isEnabled: dateOffset < 0,
                iconColorOverride: AppColors.foregroundPrimary
            )
            .frame(width: 80)
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 26)
        .background(AppColors.surfacePrimary)
    }

    // MARK: - Budget List View

    private var budgetListView: some View {
        VStack(spacing: 24) {
            // Budget Summary Card
            BudgetSummaryCard(
                budgets: budgetsForWallet,
                displayPeriod: selectedPeriodFilter,
                date: selectedDate
            )

            // Add Budget Button
            AppButton(
                title: "Add Budget",
                action: { showingAddBudget = true },
                hierarchy: .secondary,
                size: .extraSmall,
                leftIcon: "plus"
            )

            // Individual Budget Cards (grouped with 14px spacing)
            VStack(spacing: 14) {
                ForEach(budgetsForWallet, id: \.id) { budget in
                    BudgetCard(
                        budget: budget,
                        displayPeriod: selectedPeriodFilter,
                        date: selectedDate,
                        onMenuTap: {
                            showingBudgetMenu = budget
                        }
                    )
                }
            }
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(alignment: .center, spacing: 40) {
            Spacer()

            VStack(spacing: 18) {
                Image("file-question-02")
                    .resizable()
                    .frame(width: 40, height: 40)

                VStack(spacing: 8) {
                    Text("No Budgets")
                        .font(AppFonts.overusedGroteskSemiBold(size: 20))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppColors.foregroundPrimary)
                        .frame(maxWidth: .infinity, alignment: .top)

                    Text("Create a budget to track your spending by category")
                        .font(AppFonts.overusedGroteskMedium(size: 16))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppColors.foregroundSecondary)
                        .frame(maxWidth: .infinity, alignment: .top)
                }
            }

            AppButton(
                title: "Add Budget",
                action: { showingAddBudget = true },
                hierarchy: .primary,
                size: .doubleExtraSmall,
                leftIcon: "plus"
            )

            Spacer()
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(AppColors.surfacePrimary)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .inset(by: 0.5)
                .stroke(AppColors.line1stLine, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        )
    }
}

// MARK: - Edit Budget Sheet

struct EditBudgetSheet: View {
    @Binding var isPresented: Bool
    let budget: Budget
    let onSave: (Budget) -> Void
    let onDelete: () -> Void

    @ObservedObject private var currencyPrefs = CurrencyPreferences.shared

    @State private var selectedCategoryId: UUID?
    @State private var selectedCategoryName: String
    @State private var amountText: String
    @State private var selectedPeriod: BudgetPeriod
    @State private var selectedCurrency: Currency
    @State private var showingCurrencyPicker = false
    @State private var applyToAllPeriods: Bool

    @FocusState private var isAmountFocused: Bool

    init(isPresented: Binding<Bool>, budget: Budget, onSave: @escaping (Budget) -> Void, onDelete: @escaping () -> Void) {
        self._isPresented = isPresented
        self.budget = budget
        self.onSave = onSave
        self.onDelete = onDelete

        // Initialize state with budget values
        self._selectedCategoryId = State(initialValue: budget.categoryId)
        self._selectedCategoryName = State(initialValue: budget.categoryName)
        self._amountText = State(initialValue: String(format: "%.0f", budget.amount))
        self._selectedPeriod = State(initialValue: budget.period)
        self._selectedCurrency = State(initialValue: budget.currency)
        self._applyToAllPeriods = State(initialValue: budget.applyToAllPeriods)
    }

    private var isFormValid: Bool {
        selectedCategoryId != nil && !amountText.isEmpty && parsedAmount > 0
    }

    private var parsedAmount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    private var hasChanges: Bool {
        selectedCategoryId != budget.categoryId || selectedCategoryName != budget.categoryName || parsedAmount != budget.amount || selectedPeriod != budget.period || selectedCurrency != budget.currency || applyToAllPeriods != budget.applyToAllPeriods
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with delete button
            SheetHeader.withCustomAction(
                title: "Edit Budget",
                onBackTap: { isPresented = false },
                rightIcon: "trash-04",
                rightSystemIcon: "trash",
                onRightTap: {
                    onDelete()
                    isPresented = false
                }
            )

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
                    title: "Save Changes",
                    action: saveChanges,
                    hierarchy: .primary,
                    size: .extraSmall,
                    isEnabled: isFormValid && hasChanges
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

    private func saveChanges() {
        guard let categoryId = selectedCategoryId else { return }

        // Create new budget with updated values
        let newBudget = Budget(
            id: budget.id,
            walletId: budget.walletId,
            categoryId: categoryId,
            categoryName: selectedCategoryName,
            amount: parsedAmount,
            currency: selectedCurrency,
            period: selectedPeriod,
            applyToAllPeriods: applyToAllPeriods,
            isActive: budget.isActive,
            createdAt: budget.createdAt,
            updatedAt: Date()
        )

        onSave(newBudget)
        isPresented = false
    }
}
