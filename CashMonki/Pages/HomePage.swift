//
//  HomePage.swift
//  Cashooya Playground
//
//  Created by Dante Cardines III on 9/5/25.
//

import SwiftUI
import PhotosUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

struct HomePage: View {
    @Binding var selectedTab: Tab
    @Binding var primaryCurrency: Currency
    @ObservedObject internal var userManager = UserManager.shared
    @ObservedObject internal var accountManager = AccountManager.shared
    @ObservedObject internal var currencyPrefs = CurrencyPreferences.shared
    @ObservedObject internal var rateManager = CurrencyRateManager.shared
    @EnvironmentObject var toastManager: ToastManager

    @State internal var rangeSelection: RangeSelection = .day
    @State internal var rangeSelectionIndex: Int = 0  // Default to "24H"
    @State internal var chartFilter: ChartFilter = .expense
    @State internal var chartType: ChartType = .line
    @State internal var isAddPresented: Bool = false
    @State internal var isCustomPhotoPickerPresented: Bool = false
    @State internal var isDirectPhotoPickerPresented: Bool = false
    @State internal var selectedDirectPhoto: PhotosPickerItem?
    @State internal var isCameraPresented: Bool = false
    @State internal var capturedImage: UIImage?
    @State internal var isAnalyzingReceipt: Bool = false
    @State internal var analyzingSource: AnalyzingSource? = nil
    @State internal var originalTileClicked: AnalyzingSource? = nil
    @State internal var currentPhotoSource: PhotoSource = .upload
    @State internal var receiptAnalysisError: String?
    @State internal var photoCaptureStartTime: Date?
    
    enum AnalyzingSource {
        case upload
        case scan
    }
    @State internal var receiptSuccessMessage: String?
    @State internal var showingReceiptConfirmation: Bool = false
    @State internal var pendingReceiptImage: UIImage?
    @State internal var pendingReceiptAnalysis: ReceiptAnalysis?
    @State internal var showingReceiptDetail: Bool = false
    @State internal var selectedTransactionForDetail: Txn?
    
    // Performance optimization: Cache filtered transaction results
    @State internal var cachedCurrentPeriodTotal: Double = 0.0
    @State internal var cachedPreviousPeriodTotal: Double = 0.0
    @State internal var cachedAmountsCurrency: Currency = .php  // Track what currency the cached amounts are in
    @State internal var lastTransactionHash: Int = 0
    @State internal var lastRangeSelection: RangeSelection = .month
    @State internal var lastChartFilter: ChartFilter = .expense
    @State internal var recentTransactions: [Txn] = []
    @State internal var refreshTrigger: Bool = false
    @State internal var lastKnownTransactionCount: Int = 0
    
    // Chart interaction states
    @State internal var selectedDataPointIndex: Int? = nil
    
    // Enhanced smooth dragging state
    @State internal var selectedDragPosition: Double? = nil // Normalized X position (0-1)
    @State internal var selectedDragValue: Double? = nil    // Running total at drag position
    @State internal var selectedDragDate: Date? = nil       // Date at drag position
    @State internal var selectedDragHasCurrentData: Bool = false // Whether drag position has current period data
    @State internal var showingDataPointValue: Bool = false
    @State internal var dragLocation: CGPoint = .zero

    internal enum RangeSelection: String, CaseIterable, Identifiable { 
        case day = "24H", week = "7D", month = "1M", quarter = "3M"
        var id: String { rawValue } 
    }
    
    internal enum ChartFilter: String, CaseIterable, Identifiable {
        case balance = "Balance", expense = "Expense", income = "Income"
        var id: String { rawValue }
    }
    
    internal enum ChartType: String, CaseIterable, Identifiable {
        case line = "Line", bar = "Bar"
        var id: String { rawValue }
    }

    var body: some View {
        scrollContent
            .background(AppColors.surfacePrimary)
            .modifier(modifiersWrapper)
            .onChange(of: accountManager.selectedSubAccountId) { [self] oldValue, newValue in
                print("🏦 HomePage: Account selection changed - updating data")
                print("🏦 HomePage: Old account: \(oldValue?.uuidString.prefix(8) ?? "nil")")
                print("🏦 HomePage: New account: \(newValue?.uuidString.prefix(8) ?? "nil")")
                print("🔄 HomePage: Forcing complete chart refresh...")
                
                // Force complete cache invalidation
                self.lastTransactionHash = 0 // Force cache refresh
                self.lastRangeSelection = .day // Force different value to trigger recalculation
                self.lastRangeSelection = rangeSelection // Reset to actual value
                self.lastChartFilter = .income // Force different value
                self.lastChartFilter = chartFilter // Reset to actual value
                self.cachedAmountsCurrency = .usd // Force currency conversion check
                DispatchQueue.main.async {
                    self.refreshTrigger.toggle() // Force view refresh
                }
                
                // Wait for AccountManager to update filtered transactions, then refresh
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
                    print("🔄 HomePage: Delayed refresh after wallet switch")
                    
                    // CRITICAL: Update transaction count for new wallet
                    let newFilteredCount = accountManager.filteredTransactions.count
                    print("📊 HomePage: Transaction count for new wallet: \(newFilteredCount)")
                    self.lastKnownTransactionCount = newFilteredCount
                    
                    updateCachedTotalsIfNeeded()
                    updateRecentTransactions()
                    DispatchQueue.main.async {
                        self.refreshTrigger.toggle() // Second refresh to ensure UI updates
                    }
                }
            }
            .onChange(of: accountManager.showingAllAccounts) { [self] oldValue, newValue in
                print("🏦 HomePage: All accounts toggle changed - updating data")
                print("🏦 HomePage: Show all accounts: \(oldValue) → \(newValue)")
                print("🔄 HomePage: Forcing complete chart refresh...")
                
                // Force complete cache invalidation
                self.lastTransactionHash = 0 // Force cache refresh
                self.lastRangeSelection = .day // Force different value to trigger recalculation
                self.lastRangeSelection = rangeSelection // Reset to actual value
                self.lastChartFilter = .income // Force different value
                self.lastChartFilter = chartFilter // Reset to actual value
                self.cachedAmountsCurrency = .usd // Force currency conversion check
                DispatchQueue.main.async {
                    self.refreshTrigger.toggle() // Force view refresh
                }
                
                // Wait for AccountManager to update filtered transactions, then refresh
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
                    print("🔄 HomePage: Delayed refresh after accounts toggle")
                    
                    // CRITICAL: Update transaction count for new filtering mode
                    let newFilteredCount = accountManager.filteredTransactions.count
                    print("📊 HomePage: Transaction count after toggle: \(newFilteredCount)")
                    self.lastKnownTransactionCount = newFilteredCount
                    
                    updateCachedTotalsIfNeeded()
                    updateRecentTransactions()
                    DispatchQueue.main.async {
                        self.refreshTrigger.toggle() // Second refresh to ensure UI updates
                    }
                }
            }
            .sheet(isPresented: $isAddPresented) {
                AddTransactionSheet(isPresented: $isAddPresented, primaryCurrency: primaryCurrency) { newTxn in
                    print("🎬 HomePage: AddTransactionSheet is being presented")
                    print("🏠 HomePage: Received transaction from AddTransactionSheet:")
                    print("   - Merchant: \(newTxn.merchantName ?? "Unknown")")
                    print("   - Amount: \(newTxn.amount)")
                    print("   - Category: \(newTxn.category)")
                    
                    // Add transaction to UserManager
                    userManager.addTransaction(newTxn)
                    
                    // Show success toast
                    toastManager.showSuccess("Transaction added!")
                    
                    // Force complete UI refresh
                    DispatchQueue.main.async { [self] in
                        print("🔄 HomePage: Forcing complete UI refresh after transaction add")
                        self.lastTransactionHash = 0 // Force cache refresh
                        DispatchQueue.main.async {
                            self.refreshTrigger.toggle() // Force view refresh
                        }
                        updateCachedTotalsIfNeeded()
                        updateRecentTransactions()
                        
                        print("✅ HomePage: UI refresh completed")
                        self.receiptSuccessMessage = "Transaction added successfully!"
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [self] in
                            self.receiptSuccessMessage = nil
                        }
                    }
                }
                .presentationDetents([.fraction(0.98)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(.thinMaterial)
                .presentationCornerRadius(20)
                .interactiveDismissDisabled(false)
            }
            .photosPicker(isPresented: $isDirectPhotoPickerPresented, selection: $selectedDirectPhoto, matching: .images, photoLibrary: .shared())
            .onChange(of: selectedDirectPhoto) { _, newItem in
                if let newItem = newItem {
                    loadDirectPhoto(newItem)
                }
            }
            .fullScreenCover(isPresented: $isCameraPresented) {
                CameraView(
                    isPresented: $isCameraPresented,
                    onPhotoTaken: { image in
                        photoCaptureStartTime = Date()
                        capturedImage = image
                    },
                    onCancel: {
                        isCameraPresented = false
                    }
                )
            }
            .onChange(of: capturedImage) { _, newImage in
                if let newImage = newImage {
                    let transitionStart = Date()
                    print("🕐 HomePage: Camera to analysis transition started")
                    
                    // Enhanced timing for analysis transition
                    if let captureTime = photoCaptureStartTime {
                        let transitionDuration = transitionStart.timeIntervalSince(captureTime)
                        print("🕐 DEBUG: TRANSITION TIME: \(String(format: "%.3f", transitionDuration * 1000))ms")
                        print("🚀 DEBUG: Transition from capture to sheet: \(String(format: "%.2f", transitionDuration))s")
                    }
                    
                    print("✅ HomePage: Camera captured image, starting analysis...")
                    analyzeReceiptImage(newImage, source: .scan)
                    
                    // Reset capture time
                    photoCaptureStartTime = nil
                    
                    print("🕐 HomePage: Analysis started")
                }
            }
            .sheet(isPresented: $showingReceiptConfirmation) {
                if let pendingImage = pendingReceiptImage, let pendingAnalysis = pendingReceiptAnalysis {
                    ReceiptConfirmationSheet(
                        originalImage: pendingImage,
                        analysis: pendingAnalysis,
                        primaryCurrency: primaryCurrency,
                        onConfirm: { confirmedAnalysis, note in
                            print("✅ HomePage: Receipt confirmed, creating transaction")
                            
                            // Create transaction from confirmed analysis with currency conversion
                            let categoryResult = CategoriesManager.shared.findCategoryOrSubcategory(by: confirmedAnalysis.category)
                            let categoryId = categoryResult.category?.id ?? categoryResult.subcategory?.id
                            
                            // Determine if this is income based on category type
                            let isIncome = categoryResult.category?.type == .income || categoryResult.subcategory?.type == .income
                            
                            let confirmedTransaction = rateManager.createTransaction(
                                accountID: userManager.currentUser.id,
                                walletID: accountManager.selectedSubAccountId,
                                category: confirmedAnalysis.category,
                                categoryId: categoryId,
                                originalAmount: confirmedAnalysis.totalAmount,
                                originalCurrency: confirmedAnalysis.currency,
                                date: confirmedAnalysis.date,
                                merchantName: confirmedAnalysis.merchantName,
                                note: note,
                                items: confirmedAnalysis.items,
                                isIncome: isIncome
                            )
                            
                            print("💫 HomePage: Created confirmed transaction with currency conversion:")
                            print("   - Original: \(confirmedAnalysis.currency.symbol)\(confirmedAnalysis.totalAmount)")
                            print("   - Converted: \(confirmedTransaction.primaryCurrency.symbol)\(abs(confirmedTransaction.amount))")
                            
                            // Handle successful receipt confirmation
                            userManager.addTransaction(confirmedTransaction)
                            
                            // Show success toast
                            toastManager.showSuccess("Transaction added!")
                            
                            // Force UI refresh
                            updateCachedTotalsIfNeeded()
                            updateRecentTransactions()
                            
                            // Clear pending data (async to avoid SwiftUI warnings)
                            DispatchQueue.main.async {
                                pendingReceiptImage = nil
                                pendingReceiptAnalysis = nil
                                showingReceiptConfirmation = false
                            }
                            
                            // Show success message with merchant name and amount
                            receiptSuccessMessage = "Receipt saved! \(confirmedAnalysis.merchantName) - \(currencyPrefs.formatPrimaryAmount(confirmedTransaction.amount))"
                            
                            // Clear success message after 3 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                receiptSuccessMessage = nil
                            }
                        },
                        onCancel: {
                            DispatchQueue.main.async {
                                pendingReceiptImage = nil
                                pendingReceiptAnalysis = nil
                                showingReceiptConfirmation = false
                            }
                        }
                    )
                    .presentationDetents([.fraction(0.98)])
                    .presentationDragIndicator(.hidden)
                }
            }
            .sheet(item: $selectedTransactionForDetail) { transaction in
                ReceiptDetailSheet(
                    transaction: transaction,
                    onTransactionUpdate: { updatedTransaction in
                        userManager.updateTransaction(updatedTransaction)
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
                .presentationDragIndicator(.hidden)
            }
            // TODO: Add toast functionality back when toast extension is available
            // .toast(message: receiptSuccessMessage, isShowing: .constant(receiptSuccessMessage != nil), duration: 3)
            // .toast(message: receiptAnalysisError, isShowing: .constant(receiptAnalysisError != nil), duration: 5)
    }
    
    // Break down complex expressions into sub-expressions
    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            mainContentStack
        }
    }
    
    private var mainContentStack: some View {
        VStack(alignment: .leading, spacing: 24) {
            accountSelector
            totalSpentSection
            styledChartFilterTabs
            styledLineChart
            combinedTabSelectors
            actionTiles
            recentTransactionsSection
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
    
    private var styledChartFilterTabs: some View {
        chartFilterTabs
            .padding(6)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private var comparisonChartWithDebugOverlay: some View {
        Group {
            comparisonChart
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 300, maxHeight: 300, alignment: .bottom)
                .background(.white)
                .cornerRadius(12)
        }
    }
    
    private var styledTimelineSelector: some View {
        timelineSelector
            .padding(6)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private var styledLineChart: some View {
        Group {
            if chartType == .line {
                lineChart
                    .frame(maxWidth: .infinity, minHeight: 280, maxHeight: 280, alignment: .top)
            } else {
                comparisonChart
                    .frame(maxWidth: .infinity, minHeight: 280, maxHeight: 280, alignment: .bottom)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.white)
        .cornerRadius(12)
    }
    
    private var modifiersWrapper: HomePageModifiersWrapper {
        HomePageModifiersWrapper(
            userManager: userManager,
            accountManager: accountManager,
            currencyPrefs: currencyPrefs,
            rangeSelection: rangeSelection,
            chartFilter: chartFilter,
            lastKnownTransactionCount: $lastKnownTransactionCount,
            lastTransactionHash: $lastTransactionHash,
            lastRangeSelection: $lastRangeSelection,
            lastChartFilter: $lastChartFilter,
            cachedAmountsCurrency: $cachedAmountsCurrency,
            refreshTrigger: $refreshTrigger,
            updateCachedTotalsIfNeeded: updateCachedTotalsIfNeeded,
            updateRecentTransactions: updateRecentTransactions,
            convertCachedAmountsIfNeeded: convertCachedAmountsIfNeeded
        )
    }
    
    // MARK: - Core Data Processing
    
    // Performance optimization: Only recalculate when transactions or range selection changes
    // MARK: - Currency Conversion for Bar Charts
    
    internal func convertCachedAmountsIfNeeded() {
        print("🔍 CURRENCY DEBUG: ========== CONVERSION CHECK ==========")
        print("🔍 CURRENCY DEBUG: Current cached currency: \(cachedAmountsCurrency.rawValue)")
        print("🔍 CURRENCY DEBUG: Target primary currency: \(currencyPrefs.primaryCurrency.rawValue)")
        print("🔍 CURRENCY DEBUG: Current cached total: \(cachedCurrentPeriodTotal)")
        print("🔍 CURRENCY DEBUG: Previous cached total: \(cachedPreviousPeriodTotal)")
        print("🔍 CURRENCY DEBUG: Chart filter: \(chartFilter)")
        
        // Only convert if the cached amounts are in a different currency than current primary
        guard cachedAmountsCurrency != currencyPrefs.primaryCurrency else {
            print("🔍 CURRENCY DEBUG: ❌ NO CONVERSION NEEDED - amounts already in \(currencyPrefs.primaryCurrency.rawValue)")
            return
        }
        
        print("🔍 CURRENCY DEBUG: ✅ CONVERSION NEEDED - converting from \(cachedAmountsCurrency.rawValue) to \(currencyPrefs.primaryCurrency.rawValue)")
        
        // Check if rate manager has rates available
        print("🔍 CURRENCY DEBUG: Rate manager available rates:")
        print("🔍 CURRENCY DEBUG: - Last update: \(rateManager.lastUpdateDate ?? Date(timeIntervalSince1970: 0))")
        
        // Convert current period total
        let convertedCurrentTotal = rateManager.convertAmount(
            cachedCurrentPeriodTotal,
            from: cachedAmountsCurrency,
            to: currencyPrefs.primaryCurrency
        )
        
        // Convert previous period total
        let convertedPreviousTotal = rateManager.convertAmount(
            cachedPreviousPeriodTotal,
            from: cachedAmountsCurrency,
            to: currencyPrefs.primaryCurrency
        )
        
        print("🔍 CURRENCY DEBUG: Conversion results:")
        print("🔍 CURRENCY DEBUG: - Current: \(cachedCurrentPeriodTotal) \(cachedAmountsCurrency.rawValue) → \(convertedCurrentTotal) \(currencyPrefs.primaryCurrency.rawValue)")
        print("🔍 CURRENCY DEBUG: - Previous: \(cachedPreviousPeriodTotal) \(cachedAmountsCurrency.rawValue) → \(convertedPreviousTotal) \(currencyPrefs.primaryCurrency.rawValue)")
        
        // Update cached totals with converted amounts
        cachedCurrentPeriodTotal = convertedCurrentTotal
        cachedPreviousPeriodTotal = convertedPreviousTotal
        cachedAmountsCurrency = currencyPrefs.primaryCurrency
        
        print("🔍 CURRENCY DEBUG: ✅ CACHED AMOUNTS UPDATED TO \(currencyPrefs.primaryCurrency.rawValue)")
        print("🔍 CURRENCY DEBUG: ========================================")
    }
    
    func updateCachedTotalsIfNeeded() {
        let transactions = accountManager.filteredTransactions
        let transactionHash = transactions.map { $0.id.hashValue }.reduce(0, ^)
        
        // CRITICAL FIX: Include selected account ID in hash to ensure cache invalidation when switching wallets
        let accountAwareHash = transactionHash ^ (accountManager.selectedSubAccountId?.hashValue ?? 0)
        
        // Check if we need to recalculate
        if accountAwareHash != lastTransactionHash || rangeSelection != lastRangeSelection || chartFilter != lastChartFilter {
            print("📊 HomePage: Recalculating totals - hash change: \(lastTransactionHash) → \(accountAwareHash)")
            print("📊 HomePage: Account ID included in hash: \(accountManager.selectedSubAccountId?.uuidString.prefix(8) ?? "nil")")
            print("🏦 HomePage: Currently selected account: \(accountManager.selectedSubAccountId?.uuidString.prefix(8) ?? "all accounts")")
            
            // Calculate net balance changes to match line chart data
            let currentNetChange = getNetBalanceChange(for: .current)
            let previousNetChange = getNetBalanceChange(for: .previous)
            
            // Use the net balance changes directly (no abs() since we want to show +/- changes)
            let currentTotal = currentNetChange
            let previousTotal = previousNetChange
            
            print("📊 HomePage: Raw totals (before currency conversion):")
            print("   - Current period: \(currentTotal)")
            print("   - Previous period: \(previousTotal)")
            print("   - Chart filter: \(chartFilter)")
            print("   - Primary currency: \(currencyPrefs.primaryCurrency.rawValue)")
            
            // Store the totals in primary currency directly (since transactions are already in primary currency)
            cachedCurrentPeriodTotal = currentTotal
            cachedPreviousPeriodTotal = previousTotal
            cachedAmountsCurrency = currencyPrefs.primaryCurrency
            
            // Update tracking variables
            lastTransactionHash = accountAwareHash
            lastRangeSelection = rangeSelection
            lastChartFilter = chartFilter
        }
    }
    
    internal func getFilteredTransactions(for period: Period) -> [Txn] {
        let transactions = accountManager.filteredTransactions
        let cal = Calendar.current
        let now = Date()
        
        switch period {
        case .current:
            return transactions.filter { txn in
                switch rangeSelection {
                case .day: return cal.isDateInToday(txn.date)
                case .week: return cal.isDate(txn.date, equalTo: now, toGranularity: .weekOfYear)
                case .month: return cal.isDate(txn.date, equalTo: now, toGranularity: .month)
                case .quarter:
                    let quarterStart = cal.date(byAdding: .month, value: -3, to: now) ?? now
                    return txn.date >= quarterStart
                }
            }
        case .previous:
            let previousDate: Date
            switch rangeSelection {
            case .day: previousDate = cal.date(byAdding: .day, value: -1, to: now) ?? now
            case .week: previousDate = cal.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
            case .month: previousDate = cal.date(byAdding: .month, value: -1, to: now) ?? now
            case .quarter: previousDate = cal.date(byAdding: .month, value: -6, to: now) ?? now
            }
            
            let previousFiltered = transactions.filter { txn in
                switch rangeSelection {
                case .day: return cal.isDateInYesterday(txn.date)
                case .week: return cal.isDate(txn.date, equalTo: previousDate, toGranularity: .weekOfYear)
                case .month: return cal.isDate(txn.date, equalTo: previousDate, toGranularity: .month)
                case .quarter:
                    let quarterEnd = cal.date(byAdding: .month, value: -3, to: now) ?? now
                    let quarterStart = cal.date(byAdding: .month, value: -6, to: now) ?? now
                    let isAfterStart = txn.date >= quarterStart
                    let isBeforeEnd = txn.date < quarterEnd
                    return isAfterStart && isBeforeEnd
                }
            }
            
            return previousFiltered
        }
    }
    
    internal enum Period {
        case current, previous
    }
    
    // Apply chart filter (Balance, Income, Expense)
    internal func applyChartFilter(transactions: [Txn]) -> [Double] {
        switch chartFilter {
        case .balance:
            return transactions.map { $0.amount }
        case .income:
            return transactions.filter { $0.amount > 0 }.map { $0.amount }
        case .expense:
            return transactions.filter { $0.amount < 0 }.map { $0.amount }
        }
    }
    
    // NEW: Calculate period-specific transaction total (matches line chart endpoint)
    internal func getNetBalanceChange(for period: Period) -> Double {
        let transactions = accountManager.filteredTransactions
        
        // Get period boundaries using the EXACT same logic as line chart
        let cal = Calendar.current
        let now = Date()
        
        let (periodStartDate, periodEndDate): (Date, Date) = {
            if period == .current {
                // Current period: use exact same logic as line chart
                let (startDate, _) = getExactTimePoints()
                return (startDate, now) // End at current time
            } else {
                // Previous period: calculate the same way as line chart would for previous period
                switch rangeSelection {
                case .day:
                    let currentStart = cal.startOfDay(for: now)
                    let previousStart = cal.date(byAdding: .day, value: -1, to: currentStart) ?? currentStart
                    return (previousStart, currentStart)
                case .week:
                    let currentStart = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
                    let previousStart = cal.date(byAdding: .weekOfYear, value: -1, to: currentStart) ?? currentStart
                    return (previousStart, currentStart)
                case .month:
                    let currentStart = cal.dateInterval(of: .month, for: now)?.start ?? now
                    let previousStart = cal.date(byAdding: .month, value: -1, to: currentStart) ?? currentStart
                    return (previousStart, currentStart)
                case .quarter:
                    let currentMonth = cal.component(.month, from: now)
                    let quarterStartMonth = ((currentMonth - 1) / 3) * 3 + 1
                    let currentStart = cal.date(from: DateComponents(year: cal.component(.year, from: now), month: quarterStartMonth, day: 1)) ?? now
                    let previousStart = cal.date(byAdding: .month, value: -3, to: currentStart) ?? currentStart
                    return (previousStart, currentStart)
                }
            }
        }()
        
        // Get only transactions within this period
        let periodTransactions = transactions.filter { txn in
            return txn.date >= periodStartDate && txn.date < periodEndDate
        }
        
        // Calculate total for transactions in this period only
        let periodTotal = periodTransactions.reduce(0) { total, txn in
            return total + getTransactionImpact(txn)
        }
        
        // Apply chart filter to the period total
        switch chartFilter {
        case .balance:
            return periodTotal // Show full period total
        case .income:
            // Only sum positive transactions (income)
            let incomeTotal = periodTransactions
                .filter { $0.amount > 0 }
                .reduce(0) { total, txn in total + txn.amount }
            return incomeTotal
        case .expense:
            // Only sum negative transactions (expenses) as positive
            let expenseTotal = periodTransactions
                .filter { $0.amount < 0 }
                .reduce(0) { total, txn in total + abs(txn.amount) }
            return expenseTotal
        }
    }
    
    // Helper function to get transaction impact (same as line chart)
    private func getTransactionImpact(_ transaction: Txn) -> Double {
        return transaction.amount // Transaction amounts already have correct sign
    }

    // MARK: - Computed Properties
    
    internal var sectionTitle: String {
        let filterType: String
        if chartFilter == .balance {
            filterType = "Total activity"
        } else if chartFilter == .income {
            filterType = "Income"
        } else {
            filterType = "Expenses"
        }
        return "\(filterType) this \(periodDisplayName)"
    }
    
    internal var periodDisplayName: String {
        switch rangeSelection {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        case .quarter: return "quarter"
        }
    }
    
    internal var currentPeriodLabel: String {
        switch rangeSelection {
        case .day: return "Today"
        case .week: return "This week"
        case .month: return "This month"
        case .quarter: return "This quarter"
        }
    }
    
    internal var previousPeriodLabel: String {
        switch rangeSelection {
        case .day: return "Yesterday"
        case .week: return "Last week"  
        case .month: return "Last month"
        case .quarter: return "Last quarter"
        }
    }
    
    internal var percentageChange: Double {
        guard cachedPreviousPeriodTotal != 0 else { return 0.0 }
        return ((cachedCurrentPeriodTotal - cachedPreviousPeriodTotal) / cachedPreviousPeriodTotal) * 100
    }
    
    internal var percentageChangeColor: Color {
        if percentageChange > 0 {
            return chartFilter == .expense ? AppColors.destructiveForeground : AppColors.chartIncome2
        } else if percentageChange < 0 {
            return chartFilter == .expense ? AppColors.chartIncome2 : AppColors.destructiveForeground
        } else {
            return .secondary
        }
    }
    
    func updateRecentTransactions() {
        #if DEBUG
        print("🔄 HomePage: updateRecentTransactions called")
        #endif
        
        // Sort by date (newest first) and take the 5 most recent
        let sortedTransactions = Array(accountManager.filteredTransactions
            .sorted { $0.date > $1.date }  // Newest first (descending order)
            .prefix(5))
        recentTransactions = sortedTransactions
        
        #if DEBUG
        print("✅ HomePage: Recent transactions updated - showing \(recentTransactions.count) transactions")
        for (index, txn) in recentTransactions.enumerated() {
            print("   \(index + 1). \(txn.merchantName ?? "Unknown") - \(txn.date.formatted(.dateTime.month().day()))")
        }
        #endif
    }
    
    // MARK: - Receipt Processing Functions (now pulled from ReceiptAnalysis)
    
    internal func handleReceiptAnalysisSuccess(_ analysis: ReceiptAnalysis) {
        print("✅ HomePage: Receipt analysis successful!")
        print("   - Merchant: \(analysis.merchantName)")
        print("   - Amount: \(analysis.currency.symbol)\(analysis.totalAmount)")
        print("   - Currency: \(analysis.currency.rawValue)")
        print("   - Date: \(analysis.date)")
        print("   - Category: \(analysis.category)")
        
        // Find category ID from analysis category name
        let categoryResult = CategoriesManager.shared.findCategoryOrSubcategory(by: analysis.category)
        let categoryId = categoryResult.category?.id ?? categoryResult.subcategory?.id
        
        // Determine if this is income based on category type
        let isIncome = categoryResult.category?.type == .income || categoryResult.subcategory?.type == .income
        
        // Use enhanced currency conversion transaction creation
        let transaction = rateManager.createTransaction(
            accountID: userManager.currentUser.id,
            walletID: accountManager.selectedSubAccountId,
            category: analysis.category,
            categoryId: categoryId,
            originalAmount: analysis.totalAmount,
            originalCurrency: analysis.currency,
            date: analysis.date,
            merchantName: analysis.merchantName,
            note: nil,
            items: analysis.items,
            isIncome: isIncome
        )
        
        print("💫 HomePage: Created transaction with currency conversion:")
        print("   - Original: \(analysis.currency.symbol)\(analysis.totalAmount) \(analysis.currency.rawValue)")
        print("   - Converted: \(transaction.primaryCurrency.symbol)\(abs(transaction.amount)) \(transaction.primaryCurrency.rawValue)")
        if let exchangeRate = transaction.exchangeRate {
            print("   - Exchange rate: \(String(format: "%.4f", exchangeRate))")
        }
        
        userManager.addTransaction(transaction)
        updateCachedTotalsIfNeeded()
        updateRecentTransactions()
        
        receiptSuccessMessage = "Receipt saved! \(analysis.merchantName) - \(analysis.currency.symbol)\(analysis.totalAmount)"
    }
    
    // MARK: - View Modifier for Complex Modifiers
    
    internal struct HomePageModifiersWrapper: ViewModifier {
        let userManager: UserManager
        let accountManager: AccountManager
        let currencyPrefs: CurrencyPreferences
        let rangeSelection: RangeSelection
        let chartFilter: ChartFilter
        let lastKnownTransactionCount: Binding<Int>
        let lastTransactionHash: Binding<Int>
        let lastRangeSelection: Binding<RangeSelection>
        let lastChartFilter: Binding<ChartFilter>
        let cachedAmountsCurrency: Binding<Currency>
        let refreshTrigger: Binding<Bool>
        let updateCachedTotalsIfNeeded: () -> Void
        let updateRecentTransactions: () -> Void
        let convertCachedAmountsIfNeeded: () -> Void
        
        func body(content: Content) -> some View {
            content
                .onChange(of: userManager.currentUser.transactions) { [self] _, newTransactions in
                    print("🔄 HomePage: transactions onChange triggered")
                    let filteredCount = accountManager.filteredTransactions.count
                    print("📊 HomePage: New filtered transaction count: \(filteredCount)")
                    
                    // Force UI refresh when transaction count changes
                    if filteredCount != self.lastKnownTransactionCount.wrappedValue {
                        print("📊 HomePage: Filtered transaction count changed from \(self.lastKnownTransactionCount.wrappedValue) to \(filteredCount)")
                        self.lastKnownTransactionCount.wrappedValue = filteredCount
                        updateCachedTotalsIfNeeded()
                        updateRecentTransactions()
                    } else {
                        updateCachedTotalsIfNeeded()
                    }
                }
                .onChange(of: rangeSelection) { _, _ in
                    updateCachedTotalsIfNeeded()
                }
                .onChange(of: chartFilter) { _, _ in
                    updateCachedTotalsIfNeeded()
                }
                .onChange(of: currencyPrefs.primaryCurrency) { [self] oldValue, newValue in
                    print("🔍 CURRENCY DEBUG: 🚨 PRIMARY CURRENCY CHANGED!")
                    print("🔍 CURRENCY DEBUG: From: \(oldValue.rawValue) → To: \(newValue.rawValue)")
                    
                    // Force complete cache invalidation instead of conversion
                    print("🔍 CURRENCY DEBUG: Invalidating cache for complete recalculation...")
                    self.lastTransactionHash.wrappedValue = 0 // Force cache refresh
                    self.lastRangeSelection.wrappedValue = .day // Force different value
                    self.lastRangeSelection.wrappedValue = rangeSelection // Reset to actual value
                    self.lastChartFilter.wrappedValue = .income // Force different value  
                    self.lastChartFilter.wrappedValue = chartFilter // Reset to actual value
                    self.cachedAmountsCurrency.wrappedValue = newValue // Set to new currency directly
                    
                    // CRITICAL: Also force cumulative chart refresh with new currency
                    print("💱 CHART: Forcing chart refresh for currency change")
                    DispatchQueue.main.async {
                        self.refreshTrigger.wrappedValue.toggle()
                    }
                }
                .onAppear {
                    lastKnownTransactionCount.wrappedValue = accountManager.filteredTransactions.count
                    updateCachedTotalsIfNeeded()
                    updateRecentTransactions()
                }
                .onReceive(userManager.objectWillChange.debounce(for: .milliseconds(100), scheduler: RunLoop.main)) { [self] _ in
                    print("🔔 HomePage: objectWillChange received from UserManager (debounced)")
                    // Force cache invalidation to ensure we see new transactions
                    self.lastTransactionHash.wrappedValue = 0
                    updateCachedTotalsIfNeeded()
                    updateRecentTransactions()
                }
                .onReceive(accountManager.objectWillChange.debounce(for: .milliseconds(100), scheduler: RunLoop.main)) { [self] _ in
                    print("🏦 HomePage: objectWillChange received from AccountManager (debounced)")
                    self.lastTransactionHash.wrappedValue = 0 // Force cache refresh
                    updateCachedTotalsIfNeeded()
                    updateRecentTransactions()
                }
        }
    }
    
    private var chartTypeSelector: some View {
        HStack {
            HStack(alignment: .top, spacing: 10) {
                // Line chart tab
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        chartType = .line
                    }
                }) {
                    AppIcon(assetName: "line-chart-up-01", fallbackSystemName: "chart.xyaxis.line")
                        .frame(width: 20, height: 20)
                        .foregroundColor(chartType == .line ? Color(red: 0.33, green: 0.18, blue: 1) : AppColors.foregroundSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(chartType == .line ? Color(red: 0.33, green: 0.18, blue: 1).opacity(0.1) : Color.clear)
                .background(.white)
                .cornerRadius(12)
                .animation(.easeInOut(duration: 0.15), value: chartType == .line)
                .buttonStyle(PlainButtonStyle())
                
                // Bar chart tab
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        chartType = .bar
                    }
                }) {
                    AppIcon(assetName: "bar-chart-01", fallbackSystemName: "chart.bar.fill")
                        .frame(width: 20, height: 20)
                        .foregroundColor(chartType == .bar ? Color(red: 0.33, green: 0.18, blue: 1) : AppColors.foregroundSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(chartType == .bar ? Color(red: 0.33, green: 0.18, blue: 1).opacity(0.1) : Color.clear)
                .background(.white)
                .cornerRadius(12)
                .animation(.easeInOut(duration: 0.15), value: chartType == .bar)
                .buttonStyle(PlainButtonStyle())
            }
            .padding(6)
            .background(.white)
            .cornerRadius(16)
            
            Spacer()
        }
    }
    
    private var dateRangeSelector: some View {
        HStack(spacing: 4) {
            ForEach(RangeSelection.allCases, id: \.id) { range in
                TabChip.basic(
                    title: range.rawValue,
                    isSelected: rangeSelection == range
                ) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        rangeSelection = range
                    }
                    print("Selected range: \(range.rawValue)")
                }
            }
        }
        .padding(6)
        .background(.white)
        .cornerRadius(16)
    }
    
    private var combinedTabSelectors: some View {
        HStack(spacing: 16) {
            // Chart type selector - left side
            HStack(alignment: .top, spacing: 10) {
                // Line chart tab
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        chartType = .line
                    }
                }) {
                    AppIcon(assetName: "line-chart-up-01", fallbackSystemName: "chart.xyaxis.line")
                        .frame(width: 20, height: 20)
                        .foregroundColor(chartType == .line ? Color(red: 0.33, green: 0.18, blue: 1) : AppColors.foregroundSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(chartType == .line ? Color(red: 0.33, green: 0.18, blue: 1).opacity(0.1) : Color.clear)
                .background(.white)
                .cornerRadius(12)
                .animation(.easeInOut(duration: 0.15), value: chartType == .line)
                .buttonStyle(PlainButtonStyle())
                
                // Bar chart tab
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        chartType = .bar
                    }
                }) {
                    AppIcon(assetName: "bar-chart-01", fallbackSystemName: "chart.bar.fill")
                        .frame(width: 20, height: 20)
                        .foregroundColor(chartType == .bar ? Color(red: 0.33, green: 0.18, blue: 1) : AppColors.foregroundSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(chartType == .bar ? Color(red: 0.33, green: 0.18, blue: 1).opacity(0.1) : Color.clear)
                .background(.white)
                .cornerRadius(12)
                .animation(.easeInOut(duration: 0.15), value: chartType == .bar)
                .buttonStyle(PlainButtonStyle())
            }
            .padding(6)
            .background(.white)
            .cornerRadius(16)
            
            // Date range selector - right side
            HStack(spacing: 4) {
                ForEach(RangeSelection.allCases, id: \.id) { range in
                    TabChip.basic(
                        title: range.rawValue,
                        isSelected: rangeSelection == range
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            rangeSelection = range
                        }
                        print("Selected range: \(range.rawValue)")
                    }
                }
            }
            .padding(6)
            .background(.white)
            .cornerRadius(16)
        }
    }
}