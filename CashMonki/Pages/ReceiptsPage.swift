//
//  ReceiptsPage.swift
//  CashMonki
//
//  Created by Dante Cardines III on 9/5/25.
//

import SwiftUI
import Foundation
import Combine

struct ReceiptsPage: View {
    @ObservedObject private var userManager = UserManager.shared
    @ObservedObject private var accountManager = AccountManager.shared
    @ObservedObject private var currencyPrefs = CurrencyPreferences.shared
    @ObservedObject private var rateManager = CurrencyRateManager.shared
    @EnvironmentObject var toastManager: ToastManager
    @State private var selectedTransactionForDetail: Txn?
    @State private var selectedPeriodIndex: Int = 10  // Default to current month (Sep 2025)
    @State private var selectedTransactionType: TransactionTypeFilter = .balance
    @State private var selectedCategoryFilter: String? = nil  // Category filter - nil means show all

    // Special constant for "All Others" filter
    private let allOthersFilterKey = "__ALL_OTHERS__"

    // Caching to prevent excessive AccountManager calls
    @State private var cachedTransactions: [Txn] = []
    @State private var lastCacheKey: String = ""
    
    // Cache invalidation
    private func invalidateTransactionCache() {
        lastCacheKey = ""
        cachedTransactions = []
    }
    
    enum TransactionTypeFilter: String, CaseIterable {
        case balance = "All"
        case income = "Income" 
        case expense = "Expense"
    }
    
    // Generate available periods - 10 months before current month + current month + Future
    var availablePeriods: [String] {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        
        var periods: [String] = []
        let currentDate = Date()
        
        // Add 10 months before current month (going backwards)
        for i in (1...10).reversed() {
            if let pastDate = cal.date(byAdding: .month, value: -i, to: currentDate) {
                periods.append(formatter.string(from: pastDate))
            }
        }
        
        // Add current month (Sep 2025)
        periods.append(formatter.string(from: currentDate))
        
        // Add Future tab
        periods.append("Future")
        
        return periods
    }
    
    // Filter transactions based on selected period, transaction type, and account
    var filteredTransactions: [Txn] {
        // Create a cache key from all relevant state
        let cacheKey = "\(selectedPeriodIndex)-\(selectedTransactionType.rawValue)-\(accountManager.selectedSubAccountId)-\(accountManager.showingAllAccounts)"
        
        // Return cached result if key hasn't changed
        if cacheKey == lastCacheKey {
            return cachedTransactions
        }
        
        // Recalculate and cache
        let allTransactions = accountManager.filteredTransactions
        
        guard !availablePeriods.isEmpty, selectedPeriodIndex < availablePeriods.count else {
            lastCacheKey = cacheKey
            cachedTransactions = allTransactions
            return allTransactions
        }
        
        let selectedPeriod = availablePeriods[selectedPeriodIndex]
        
        // Handle Future tab - return empty array for now
        if selectedPeriod == "Future" {
            lastCacheKey = cacheKey
            cachedTransactions = []
            return []
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        
        // First filter by period
        let periodFiltered = allTransactions.filter { transaction in
            formatter.string(from: transaction.date) == selectedPeriod
        }
        
        // Then filter by transaction type
        let result: [Txn]
        switch selectedTransactionType {
        case .balance:
            result = periodFiltered // Show all transactions (both income and expense)
        case .income:
            result = periodFiltered.filter { $0.amount > 0 } // Only positive amounts (income)
        case .expense:
            result = periodFiltered.filter { $0.amount < 0 } // Only negative amounts (expenses)
        }
        
        // Cache and return result
        lastCacheKey = cacheKey
        cachedTransactions = result
        return result
    }

    /// Transactions filtered by selected category (if any)
    /// When filtering by a parent category, includes all subcategory transactions too
    /// When filtering by "All Others", shows all transactions NOT in the top 4 categories
    var displayTransactions: [Txn] {
        guard let categoryFilter = selectedCategoryFilter else {
            return filteredTransactions
        }

        // Handle "All Others" filter - show everything except top 4 categories
        if categoryFilter == allOthersFilterKey {
            let top4Categories = getTop4Categories()
            return filteredTransactions.filter { txn in
                let effectiveCategory = getEffectiveCategory(for: txn)
                return !top4Categories.contains(effectiveCategory)
            }
        }

        // Filter includes transactions where:
        // 1. The category exactly matches the filter
        // 2. The category is a subcategory of the filter (parent matches)
        return filteredTransactions.filter { txn in
            // Direct match
            if txn.category == categoryFilter {
                return true
            }
            // Check if transaction's category is a subcategory of the filter
            let effectiveCategory = getEffectiveCategory(for: txn)
            return effectiveCategory == categoryFilter
        }
    }

    /// Get the top 4 category names based on current transaction type filter
    private func getTop4Categories() -> Set<String> {
        let categorizedTransactions: [Txn]

        switch selectedTransactionType {
        case .balance:
            categorizedTransactions = filteredTransactions
        case .income:
            categorizedTransactions = filteredTransactions.filter { $0.amount > 0 }
        case .expense:
            categorizedTransactions = filteredTransactions.filter { $0.amount < 0 }
        }

        // Group by PARENT category (subcategories roll up into their parent) with currency conversion
        let categoryTotals = Dictionary(grouping: categorizedTransactions) { getEffectiveCategory(for: $0) }
            .mapValues { transactions in
                transactions.reduce(0.0) { total, txn in
                    let converted = txn.primaryCurrency == currencyPrefs.primaryCurrency
                        ? txn.amount
                        : rateManager.convertAmount(txn.amount, from: txn.primaryCurrency, to: currencyPrefs.primaryCurrency)
                    return total + abs(converted)
                }
            }

        let sortedCategories = categoryTotals.sorted { $0.value > $1.value }
        let topCategories = Array(sortedCategories.prefix(4))

        return Set(topCategories.map { $0.key })
    }

    var grouped: [(String, [Txn])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: displayTransactions) { cal.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { day in
            let title: String
            if cal.isDateInToday(day) { title = "Today" }
            else if cal.isDateInYesterday(day) { title = "Yesterday" }
            else { let df = DateFormatter(); df.dateFormat = "EEEE, MMM d, yyyy"; title = df.string(from: day) }
            return (title, groups[day]!.sorted { $0.createdAt > $1.createdAt })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Period filter tabs
            if !availablePeriods.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 24) {
                            ForEach(Array(availablePeriods.enumerated()), id: \.offset) { index, period in
                                AppTab(
                                    title: period,
                                    action: {
                                        selectedPeriodIndex = index
                                        selectedCategoryFilter = nil  // Clear category filter when changing period
                                        print("Selected period: \(period)")
                                    },
                                    state: selectedPeriodIndex == index ? .selected : .inactive
                                )
                                .id("tab_\(index)")  // Unique ID for each tab
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 0)  // No bottom padding to make tabs flush
                    .background(AppColors.backgroundWhite)
                    .overlay(
                        // Bottom border
                        Rectangle()
                            .fill(AppColors.linePrimary)
                            .frame(height: 1)  // 1px for container border
                            .frame(maxWidth: .infinity)
                        , alignment: .bottom
                    )
                    .onAppear {
                        // Scroll to show the selected tab (Sep 2025) on load
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                proxy.scrollTo("tab_\(selectedPeriodIndex)", anchor: .center)
                            }
                        }
                    }
                    .onChange(of: selectedPeriodIndex) { _, newIndex in
                        // Scroll to the newly selected tab
                        proxy.scrollTo("tab_\(newIndex)", anchor: .center)
                    }
                }
            }
            
            // Transactions list
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Transaction type filter tabs (All, Income, Expense)
                    HStack(spacing: 8) {
                        ForEach(TransactionTypeFilter.allCases, id: \.rawValue) { filter in
                            TabChip.basic(
                                title: filter.rawValue,
                                isSelected: selectedTransactionType == filter
                            ) {
                                selectedTransactionType = filter
                                selectedCategoryFilter = nil  // Clear category filter when changing type
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(6)
                    .background(AppColors.backgroundWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    
                    // Monthly total section
                    monthlyTotalSection
                        .animation(.easeInOut(duration: 0.3), value: selectedTransactionType)
                    
                    
                ForEach(Array(grouped.enumerated()), id: \.offset) { _, section in
                    let dailyTotal = section.1.reduce(0.0) { $0 + convertedAmount($1) }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(section.0)
                                .font(AppFonts.overusedGroteskMedium(size: 14))
                                .foregroundStyle(AppColors.foregroundSecondary)
                            
                            Spacer()
                            
                            Text(currencyPrefs.formatPrimaryAmount(dailyTotal))
                                .font(AppFonts.overusedGroteskMedium(size: 16))
                                .foregroundStyle(AppColors.foregroundSecondary)
                        }
                        
                        VStack(spacing: 0) {
                        ForEach(Array(section.1.enumerated()), id: \.element.id) { index, txn in
                            UnifiedTransactionDisplay.row(
                                transaction: txn,
                                onTap: {
                                    selectedTransactionForDetail = txn
                                },
                                onTransactionUpdate: { updatedTransaction in
                                    userManager.updateTransaction(updatedTransaction)
                                    
                                    // If transaction type changed and we're not on Balance tab,
                                    // automatically switch to Balance tab to keep transaction visible
                                    let originalIsIncome = txn.amount > 0
                                    let updatedIsIncome = updatedTransaction.amount > 0
                                    
                                    if originalIsIncome != updatedIsIncome && selectedTransactionType != .balance {
                                        selectedTransactionType = .balance
                                    }
                                }
                            )
                            if index < section.1.count - 1 { Divider().padding(.leading, 64) }
                        }
                        }
                        .background(AppColors.backgroundWhite)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
                .padding(.horizontal, 16)
                .padding(.top, 20)  // Updated to 20px
                .padding(.bottom, 20)  // Updated to 20px
                .background(AppColors.surfacePrimary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.surfacePrimary)
        .onChange(of: accountManager.selectedSubAccountId) { _, _ in
            print("🏦 ReceiptsPage: Account selection changed - refreshing transactions list")
        }
        .sheet(item: $selectedTransactionForDetail) { transaction in
            ReceiptDetailSheet(
                transaction: transaction,
                onTransactionUpdate: { updatedTransaction in
                    userManager.updateTransaction(updatedTransaction)
                    
                    // If transaction type changed and we're not on Balance tab,
                    // automatically switch to Balance tab to keep transaction visible
                    let originalIsIncome = transaction.amount > 0
                    let updatedIsIncome = updatedTransaction.amount > 0
                    
                    if originalIsIncome != updatedIsIncome && selectedTransactionType != .balance {
                        selectedTransactionType = .balance
                    }
                },
                onTransactionDelete: { deletedTransaction in
                    userManager.removeTransaction(withId: deletedTransaction.id)
                    selectedTransactionForDetail = nil
                    
                    // Show deletion toast
                    toastManager.showDeleted("Transaction deleted")
                },
                onDismiss: {
                    selectedTransactionForDetail = nil
                }
            )
            .presentationDetents([.fraction(0.98)])
            .presentationCornerRadius(20)
            .presentationDragIndicator(.hidden)
        }
        .onChange(of: accountManager.selectedSubAccountId) { _, _ in
            print("🏦 ReceiptsPage: Account selection changed - refreshing transactions")
            invalidateTransactionCache()
        }
        .onChange(of: accountManager.showingAllAccounts) { _, _ in
            print("🏦 ReceiptsPage: All accounts toggle changed - refreshing transactions")
            invalidateTransactionCache()
        }
        .onChange(of: userManager.currentUser.transactions) { _, _ in
            print("🔄 ReceiptsPage: User transactions changed - invalidating cache")
            invalidateTransactionCache()
        }
    }

    // Helper function to convert transaction amount to user's primary currency
    private func convertedAmount(_ txn: Txn) -> Double {
        let primaryCurrency = currencyPrefs.primaryCurrency
        if txn.primaryCurrency == primaryCurrency {
            return txn.amount
        } else {
            return rateManager.convertAmount(txn.amount, from: txn.primaryCurrency, to: primaryCurrency)
        }
    }

    var monthlyTotalSection: some View {
        let selectedPeriod = availablePeriods[selectedPeriodIndex]

        // Calculate totals for all transaction types (with currency conversion)
        let allTransactions = filteredTransactions
        let incomeTotal = allTransactions.filter { $0.amount > 0 }.reduce(0.0) { $0 + convertedAmount($1) }
        let expenseTotal = allTransactions.filter { $0.amount < 0 }.reduce(0.0) { $0 + abs(convertedAmount($1)) }
        let netBalance = incomeTotal - expenseTotal
        
        // Calculate totals based on selected transaction type for display
        let monthlyTotal: Double
        let titleText: String
        
        switch selectedTransactionType {
        case .balance:
            monthlyTotal = netBalance
            titleText = "Balance \(selectedPeriod == "Future" ? "Future" : selectedPeriod)"
        case .income:
            monthlyTotal = incomeTotal
            titleText = "Total income \(selectedPeriod == "Future" ? "Future" : selectedPeriod)"
        case .expense:
            monthlyTotal = expenseTotal
            titleText = "Total expenses \(selectedPeriod == "Future" ? "Future" : selectedPeriod)"
        }
        
        
        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(titleText)
                            .font(AppFonts.overusedGroteskMedium(size: 18))
                            .foregroundStyle(AppColors.foregroundSecondary)
                        
                        Text(currencyPrefs.formatPrimaryAmount(monthlyTotal))
                            .font(AppFonts.overusedGroteskSemiBold(size: 34))
                            .foregroundStyle(AppColors.foregroundPrimary)
                    }
                    
                    Spacer()
                }
                
                // Category bar chart (tappable segments)
                categoryBarChart(selectedType: selectedTransactionType, selectedCategory: $selectedCategoryFilter)
                    .animation(.easeInOut(duration: 0.15), value: selectedTransactionType)
                    .animation(.easeInOut(duration: 0.15), value: selectedCategoryFilter)
            }

            // Top Categories list
            categoryList(selectedType: selectedTransactionType, selectedCategory: $selectedCategoryFilter)
                .animation(.easeInOut(duration: 0.15), value: selectedTransactionType)
                .animation(.easeInOut(duration: 0.15), value: selectedCategoryFilter)
        }
        .padding(20)
        .background(AppColors.backgroundWhite)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    /// Get the effective category for grouping - returns parent category name if this is a subcategory
    private func getEffectiveCategory(for transaction: Txn) -> String {
        let categoriesManager = CategoriesManager.shared
        let result = categoriesManager.findCategoryOrSubcategory(by: transaction.category)

        // If it's a subcategory, return the parent category name
        if result.isSubcategory, let parent = result.parent {
            return parent.name
        }

        // Otherwise return the original category
        return transaction.category
    }

    func categoryBarChart(selectedType: TransactionTypeFilter, selectedCategory: Binding<String?>) -> some View {
        // Get top 4 categories + "All Others" for the selected transaction type
        let categorizedTransactions: [Txn]

        switch selectedType {
        case .balance:
            categorizedTransactions = filteredTransactions
        case .income:
            categorizedTransactions = filteredTransactions.filter { $0.amount > 0 }
        case .expense:
            categorizedTransactions = filteredTransactions.filter { $0.amount < 0 }
        }

        // Group by PARENT category (subcategories roll up into their parent) with currency conversion
        let categoryTotals = Dictionary(grouping: categorizedTransactions) { getEffectiveCategory(for: $0) }
            .mapValues { transactions in
                transactions.reduce(0.0) { total, txn in
                    let converted = txn.primaryCurrency == currencyPrefs.primaryCurrency
                        ? txn.amount
                        : rateManager.convertAmount(txn.amount, from: txn.primaryCurrency, to: currencyPrefs.primaryCurrency)
                    return total + abs(converted)
                }
            }
        
        let sortedCategories = categoryTotals.sorted { $0.value > $1.value }
        let topCategories = Array(sortedCategories.prefix(4))
        let totalAmount = categoryTotals.values.reduce(0, +)
        
        // Calculate "All Others" amount
        let topCategoriesTotal = topCategories.reduce(0) { $0 + $1.value }
        let allOthersAmount = totalAmount - topCategoriesTotal
        
        // Define colors based on transaction type
        let colors: [Color]
        
        if selectedType == .balance {
            // For balance view, use overall ranking position but appropriate color palette based on category type
            let incomeColors = [
                AppColors.chartIncome1,  // Income position 1
                AppColors.chartIncome2,  // Income position 2  
                AppColors.chartIncome3,  // Income position 3
                AppColors.chartIncome4   // Income position 4
            ]
            let expenseColors = [
                AppColors.chartExpense1,  // Expense position 1
                AppColors.chartExpense2,  // Expense position 2
                AppColors.chartExpense3,  // Expense position 3
                AppColors.chartExpense4   // Expense position 4
            ]
            
            // Determine if each category is income or expense by checking sample transactions
            let categoryTypes: [String: String] = Dictionary(uniqueKeysWithValues: topCategories.compactMap { categoryData -> (String, String)? in
                let category = categoryData.key
                // Use getEffectiveCategory to match against parent category names
                let sampleTransaction = filteredTransactions.first { getEffectiveCategory(for: $0) == category }
                guard let transaction = sampleTransaction else { return nil }
                return (category, transaction.amount > 0 ? "income" : "expense")
            })
            
            // Assign colors based on overall ranking position and category type
            colors = topCategories.enumerated().map { index, categoryData in
                let category = categoryData.key
                let position = index  // Overall ranking position (0-based)
                
                if let categoryType = categoryTypes[category] {
                    if categoryType == "income" && position < incomeColors.count {
                        return incomeColors[position]
                    } else if categoryType == "expense" && position < expenseColors.count {
                        return expenseColors[position]
                    }
                }
                return AppColors.linePrimary  // Fallback
            } + [AppColors.linePrimary]  // All Others color
            
        } else if selectedType == .income {
            colors = [
                Color(hex: "008F75") ?? AppColors.successForeground,  // Top 1
                Color(hex: "08AD93") ?? AppColors.successForeground,  // Top 2  
                Color(hex: "12CBAE") ?? AppColors.successForeground,  // Top 3
                Color(hex: "12B6CB") ?? AppColors.successForeground,  // Top 4
                AppColors.linePrimary      // All Others
            ]
        } else {
            colors = [
                Color(hex: "DE4706") ?? AppColors.destructiveForeground,  // Top 1
                Color(hex: "FF6C29") ?? AppColors.destructiveForeground,  // Top 2
                Color(hex: "FFA100") ?? AppColors.destructiveForeground,  // Top 3
                Color(hex: "F7CD07") ?? AppColors.destructiveForeground,  // Top 4
                AppColors.linePrimary           // All Others
            ]
        }
        
        if totalAmount == 0 {
            // Show empty state
            return AnyView(
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppColors.linePrimary)
                    .frame(height: 20)
                    .frame(maxWidth: .infinity)
            )
        }
        
        return AnyView(
            GeometryReader { geometry in
                HStack(spacing: 1) { // 1px spacing between segments
                    // Top categories segments
                    ForEach(Array(topCategories.enumerated()), id: \.offset) { index, categoryData in
                        let percentage = totalAmount > 0 ? abs(categoryData.value) / abs(totalAmount) : 0
                        let frameWidth = max(0, min(geometry.size.width, geometry.size.width * percentage))
                        // Dim non-selected categories to 10% when a category is selected
                        let isSelected = selectedCategory.wrappedValue == nil || categoryData.key == selectedCategory.wrappedValue
                        let segmentOpacity: Double = isSelected ? 1.0 : 0.1

                        if percentage > 0 && frameWidth > 0 {
                            Rectangle() // No individual radius
                                .fill(colors.count > index ? colors[index] : AppColors.linePrimary)
                                .opacity(segmentOpacity)
                                .frame(width: frameWidth)
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        // Toggle selection: tap again to deselect
                                        if selectedCategory.wrappedValue == categoryData.key {
                                            selectedCategory.wrappedValue = nil
                                        } else {
                                            selectedCategory.wrappedValue = categoryData.key
                                        }
                                    }
                                }
                        }
                    }

                    // All Others segment (if > 0) - NOW TAPPABLE
                    if allOthersAmount > 0 && totalAmount > 0 {
                        let allOthersPercentage = abs(allOthersAmount) / abs(totalAmount)
                        let frameWidth = max(0, min(geometry.size.width, geometry.size.width * allOthersPercentage))
                        // "All Others" is highlighted when selected, dimmed when another category is selected
                        let isAllOthersSelected = selectedCategory.wrappedValue == allOthersFilterKey
                        let segmentOpacity: Double = selectedCategory.wrappedValue == nil || isAllOthersSelected ? 1.0 : 0.1

                        Rectangle() // No individual radius
                            .fill(colors.count > 4 ? colors[4] : AppColors.linePrimary)
                            .opacity(segmentOpacity)
                            .frame(width: frameWidth)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    // Toggle selection: tap again to deselect
                                    if selectedCategory.wrappedValue == allOthersFilterKey {
                                        selectedCategory.wrappedValue = nil
                                    } else {
                                        selectedCategory.wrappedValue = allOthersFilterKey
                                    }
                                }
                            }
                    }
                }
            }
            .frame(height: 20) // Updated to 20px
            .frame(maxWidth: .infinity) // Take full width
            .clipShape(RoundedRectangle(cornerRadius: 4)) // 4px radius for overall bar
        )
    }
    
    func categoryList(selectedType: TransactionTypeFilter, selectedCategory: Binding<String?>) -> some View {
        // Get top 4 categories + "All Others" for the selected transaction type
        let categorizedTransactions: [Txn]

        switch selectedType {
        case .balance:
            categorizedTransactions = filteredTransactions
        case .income:
            categorizedTransactions = filteredTransactions.filter { $0.amount > 0 }
        case .expense:
            categorizedTransactions = filteredTransactions.filter { $0.amount < 0 }
        }

        // Group by PARENT category (subcategories roll up into their parent) with currency conversion
        let categoryTotals = Dictionary(grouping: categorizedTransactions) { getEffectiveCategory(for: $0) }
            .mapValues { transactions in
                transactions.reduce(0.0) { total, txn in
                    let converted = txn.primaryCurrency == currencyPrefs.primaryCurrency
                        ? txn.amount
                        : rateManager.convertAmount(txn.amount, from: txn.primaryCurrency, to: currencyPrefs.primaryCurrency)
                    return total + abs(converted)
                }
            }
        
        let sortedCategories = categoryTotals.sorted { $0.value > $1.value }
        let topCategories = Array(sortedCategories.prefix(4))
        let totalAmount = categoryTotals.values.reduce(0, +)
        
        // Calculate "All Others" amount
        let topCategoriesTotal = topCategories.reduce(0) { $0 + $1.value }
        let allOthersAmount = totalAmount - topCategoriesTotal
        
        // Define colors based on transaction type
        let colors: [Color]
        
        if selectedType == .balance {
            // For balance view, use overall ranking position but appropriate color palette based on category type
            let incomeColors = [
                AppColors.chartIncome1,  // Income position 1
                AppColors.chartIncome2,  // Income position 2  
                AppColors.chartIncome3,  // Income position 3
                AppColors.chartIncome4   // Income position 4
            ]
            let expenseColors = [
                AppColors.chartExpense1,  // Expense position 1
                AppColors.chartExpense2,  // Expense position 2
                AppColors.chartExpense3,  // Expense position 3
                AppColors.chartExpense4   // Expense position 4
            ]
            
            // Determine if each category is income or expense by checking sample transactions
            let categoryTypes: [String: String] = Dictionary(uniqueKeysWithValues: topCategories.compactMap { categoryData -> (String, String)? in
                let category = categoryData.key
                // Use getEffectiveCategory to match against parent category names
                let sampleTransaction = filteredTransactions.first { getEffectiveCategory(for: $0) == category }
                guard let transaction = sampleTransaction else { return nil }
                return (category, transaction.amount > 0 ? "income" : "expense")
            })
            
            // Assign colors based on overall ranking position and category type
            colors = topCategories.enumerated().map { index, categoryData in
                let category = categoryData.key
                let position = index  // Overall ranking position (0-based)
                
                if let categoryType = categoryTypes[category] {
                    if categoryType == "income" && position < incomeColors.count {
                        return incomeColors[position]
                    } else if categoryType == "expense" && position < expenseColors.count {
                        return expenseColors[position]
                    }
                }
                return AppColors.linePrimary  // Fallback
            } + [AppColors.linePrimary]  // All Others color
            
        } else if selectedType == .income {
            colors = [
                Color(hex: "008F75") ?? AppColors.successForeground,  // Top 1
                Color(hex: "08AD93") ?? AppColors.successForeground,  // Top 2  
                Color(hex: "12CBAE") ?? AppColors.successForeground,  // Top 3
                Color(hex: "12B6CB") ?? AppColors.successForeground,  // Top 4
                AppColors.linePrimary      // All Others
            ]
        } else {
            colors = [
                Color(hex: "DE4706") ?? AppColors.destructiveForeground,  // Top 1
                Color(hex: "FF6C29") ?? AppColors.destructiveForeground,  // Top 2
                Color(hex: "FFA100") ?? AppColors.destructiveForeground,  // Top 3
                Color(hex: "F7CD07") ?? AppColors.destructiveForeground,  // Top 4
                AppColors.linePrimary           // All Others
            ]
        }
        
        return VStack(spacing: 12) {
            // Top 4 categories
            ForEach(Array(topCategories.enumerated()), id: \.offset) { index, categoryData in
                let percentage = totalAmount > 0 ? (categoryData.value / totalAmount) * 100 : 0
                // Get categoryId from a sample transaction for UUID-based emoji lookup
                let sampleTransaction = filteredTransactions.first { $0.category == categoryData.key }
                let emoji = sampleTransaction?.categoryId != nil
                    ? TxnCategoryIcon.emojiFor(categoryId: sampleTransaction!.categoryId!, categoryName: categoryData.key)
                    : TxnCategoryIcon.emojiFor(category: categoryData.key)
                // Determine if this category is selected (20% opacity for non-selected)
                let isSelected = selectedCategory.wrappedValue == nil || categoryData.key == selectedCategory.wrappedValue
                let rowOpacity: Double = isSelected ? 1.0 : 0.2

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        // Toggle selection: tap again to deselect
                        if selectedCategory.wrappedValue == categoryData.key {
                            selectedCategory.wrappedValue = nil
                        } else {
                            selectedCategory.wrappedValue = categoryData.key
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        // Color indicator
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colors.count > index ? colors[index] : AppColors.linePrimary)
                            .frame(width: 4, height: 16)

                        // Category emoji (UUID-first lookup)
                        Text(emoji)
                            .font(Font.custom("Overused Grotesk", size: 16).weight(.medium))

                        // Category name
                        Text(categoryData.key)
                            .font(AppFonts.overusedGroteskMedium(size: 16))
                            .foregroundStyle(AppColors.foregroundPrimary)

                        Spacer()

                        // Amount and percentage
                        HStack(spacing: 4) {
                            Text(currencyPrefs.formatPrimaryAmount(categoryData.value))
                                .font(AppFonts.overusedGroteskMedium(size: 16))
                                .foregroundStyle(AppColors.foregroundSecondary)

                            Text("·")
                                .font(AppFonts.overusedGroteskMedium(size: 16))
                                .foregroundStyle(AppColors.foregroundSecondary)

                            Text("\(Int(percentage.rounded()))%")
                                .font(AppFonts.overusedGroteskMedium(size: 16))
                                .foregroundStyle(AppColors.foregroundSecondary)
                        }
                    }
                    .opacity(rowOpacity)
                }
                .buttonStyle(PlainButtonStyle())
            }

            // All Others row (if there are remaining categories) - NOW TAPPABLE
            if allOthersAmount > 0 {
                let percentage = totalAmount > 0 ? (allOthersAmount / totalAmount) * 100 : 0
                // "All Others" is highlighted when selected, dimmed when another category is selected
                let isAllOthersSelected = selectedCategory.wrappedValue == allOthersFilterKey
                let rowOpacity: Double = selectedCategory.wrappedValue == nil || isAllOthersSelected ? 1.0 : 0.2

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        // Toggle selection: tap again to deselect
                        if selectedCategory.wrappedValue == allOthersFilterKey {
                            selectedCategory.wrappedValue = nil
                        } else {
                            selectedCategory.wrappedValue = allOthersFilterKey
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        // Color indicator
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colors.count > 4 ? colors[4] : AppColors.linePrimary)
                            .frame(width: 4, height: 16)

                        // "All Others" text aligned to emoji position (no separate emoji space)
                        Text("All Others")
                            .font(AppFonts.overusedGroteskMedium(size: 16))
                            .foregroundStyle(AppColors.foregroundPrimary)

                        Spacer()

                        // Amount and percentage
                        HStack(spacing: 4) {
                            Text("+\(currencyPrefs.formatPrimaryAmount(allOthersAmount))")
                                .font(AppFonts.overusedGroteskMedium(size: 16))
                                .foregroundStyle(AppColors.foregroundSecondary)

                            Text("·")
                                .font(AppFonts.overusedGroteskMedium(size: 16))
                                .foregroundStyle(AppColors.foregroundSecondary)

                            Text("\(Int(percentage.rounded()))%")
                                .font(AppFonts.overusedGroteskMedium(size: 16))
                                .foregroundStyle(AppColors.foregroundSecondary)
                        }
                    }
                    .opacity(rowOpacity)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }


    func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }

    func amountText(_ value: Double) -> String { 
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0  // Hide .00
        formatter.maximumFractionDigits = 2  // Show up to .01
        formatter.groupingSeparator = ","
        formatter.numberStyle = .decimal
        
        let formattedAmount = formatter.string(from: NSNumber(value: abs(value))) ?? String(format: "%.0f", abs(value))
        return "\(value < 0 ? "-" : "+")\(formattedAmount)"
    }
    func dateSubtitle(_ date: Date) -> String {
        let df = DateFormatter(); df.dateFormat = "EEEE, MMM d, yyyy"; return df.string(from: date)
    }
}