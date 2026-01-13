//
//  HomePageComponents.swift
//  Cashooya Playground
//
//  Created by Dante Cardines III on 9/5/25.
//

import SwiftUI

// MARK: - HomePage UI Components

extension HomePage {
    
    internal var accountSelector: some View {
        AccountSelectorButton()
    }
    
    internal var totalSpentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sectionTitle)
                .font(AppFonts.overusedGroteskMedium(size: 18))
                .foregroundStyle(AppColors.foregroundSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                // Amount with decimal in tertiary color
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(currencyWholeNumber(cachedCurrentPeriodTotal))
                        .font(AppFonts.overusedGroteskSemiBold(size: 40))

                    Text(currencyDecimalPart(cachedCurrentPeriodTotal))
                        .font(AppFonts.overusedGroteskSemiBold(size: 40))
                        .foregroundColor(AppColors.foregroundTertiary)
                }
                
                HStack(spacing: 4) {
                    // Only show arrow icon if percentage change is not 0%
                    if percentageChange != 0.0 {
                        let assetName = percentageChange >= 0 ? "uui_arrow_up" : "uui_arrow_down"
                        let fallbackName = percentageChange >= 0 ? "arrow.up" : "arrow.down"
                        
                        AppIcon(assetName: assetName, fallbackSystemName: fallbackName)
                            .font(AppFonts.overusedGroteskMedium(size: 16))
                            .foregroundStyle(percentageChangeColor)
                    }
                    Text("\(formatPercentageWithCommas(abs(percentageChange)))%")
                        .font(AppFonts.overusedGroteskMedium(size: 16))
                        .foregroundStyle(percentageChangeColor)
                }
            }
        }
    }
    
    internal var timelineSelector: some View {
        VStack(spacing: 12) {
            // Chart type selector - completely separate container
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
            
            // Date range selector - completely separate container 
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
        .frame(maxWidth: .infinity)
    }
    
    internal var actionTiles: some View {
        HStack(alignment: .top, spacing: 10) {
            BigTile.icon(
                assetName: (isAnalyzingReceipt && originalTileClicked == .upload) ? "clock-refresh" : "upload-01",
                fallbackSystemName: (isAnalyzingReceipt && originalTileClicked == .upload) ? "clock.arrow.circlepath" : "square.and.arrow.up",
                title: (isAnalyzingReceipt && originalTileClicked == .upload) ? "..." : "Upload",
                isLoading: isAnalyzingReceipt && originalTileClicked == .upload,
                usageLimitText: RevenueCatManager.shared.isProUser ? nil : dailyUsageManager.getUsageDisplayText()
            ) {
                if !isAnalyzingReceipt {
                    // Check daily usage limit before proceeding
                    guard dailyUsageManager.canUseReceiptAnalysis() else {
                        print("📊 HomePage: Upload blocked - daily limit reached")
                        showingCustomPaywall = true
                        return
                    }
                    
                    originalTileClicked = .upload
                    currentPhotoSource = .upload
                    isDirectPhotoPickerPresented = true
                }
            }
            
            BigTile.icon(
                assetName: (isAnalyzingReceipt && originalTileClicked == .scan) ? "clock-refresh" : "scan",
                fallbackSystemName: (isAnalyzingReceipt && originalTileClicked == .scan) ? "clock.arrow.circlepath" : "camera",
                title: (isAnalyzingReceipt && originalTileClicked == .scan) ? "..." : "Scan",
                isLoading: isAnalyzingReceipt && originalTileClicked == .scan,
                usageLimitText: RevenueCatManager.shared.isProUser ? nil : dailyUsageManager.getUsageDisplayText()
            ) {
                if !isAnalyzingReceipt {
                    // Check daily usage limit before proceeding
                    guard dailyUsageManager.canUseReceiptAnalysis() else {
                        print("📊 HomePage: Scan blocked - daily limit reached")
                        showingCustomPaywall = true
                        return
                    }

                    // Check camera permission before opening camera
                    CameraManager.checkPermissionStatus { status in
                        switch status {
                        case .granted:
                            // 🕐 CAMERA LAG DEBUG - Start timing from button tap
                            let scanButtonTapped = Date()
                            print("🕐🕐🕐 CAMERA LAG DEBUG: ==== SCAN BUTTON TAPPED ====")
                            print("🕐 CAMERA LAG DEBUG: Button tap timestamp: \(scanButtonTapped)")
                            CameraLagDebug.shared.scanButtonTappedAt = scanButtonTapped

                            originalTileClicked = .scan
                            currentPhotoSource = .camera
                            isCameraPresented = true

                            print("🕐 CAMERA LAG DEBUG: isCameraPresented set to true, time: \(String(format: "%.3f", Date().timeIntervalSince(scanButtonTapped) * 1000))ms since tap")
                        case .denied:
                            // Show alert to open Settings
                            showingCameraPermissionAlert = true
                        case .notDetermined:
                            // Permission dialog shown, wait for result
                            break
                        }
                    }
                }
            }
            
            BigTile.icon(
                assetName: "plus",
                fallbackSystemName: "plus",
                title: "Add"
            ) {
                print("🔵 HomePage: Add button tapped!")
                isAddPresented = true
                print("🔵 HomePage: isAddPresented set to \(isAddPresented)")
            }
        }
        .padding(.bottom, 20)
    }
    
    internal var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recently added")
                .font(AppFonts.overusedGroteskMedium(size: 16))
                .foregroundColor(AppColors.foregroundSecondary)
            
            VStack(spacing: 0) {
                if recentTransactions.isEmpty {
                    Text("No transactions yet")
                        .font(AppFonts.overusedGroteskMedium(size: 14))
                        .foregroundStyle(AppColors.foregroundTertiary)
                        .padding(.vertical, 20)
                } else {
                    // Individual transaction list
                    ForEach(Array(recentTransactions.enumerated()), id: \.element.id) { index, txn in
                        UnifiedTransactionDisplay.row(
                            transaction: txn,
                            onTap: {
                                print("🔴 DEBUG: Transaction tapped - \(txn.merchantName ?? "Unknown")")
                                selectedTransactionForDetail = txn
                                print("🔴 DEBUG: selectedTransactionForDetail set to: \(selectedTransactionForDetail?.merchantName ?? "nil")")
                            },
                            onTransactionUpdate: { updatedTransaction in
                                userManager.updateTransaction(updatedTransaction)
                            }
                        )
                        if index < recentTransactions.count - 1 { 
                            Divider().padding(.leading, 64) 
                        }
                    }
                }
                
                // View All Transactions Button - Now inside the same container
                Divider()
                
                AppButton(
                    title: "View all transactions",
                    action: {
                        selectedTab = .transactions
                    },
                    hierarchy: .tertiary,
                    size: .doubleExtraSmall,
                    rightIcon: "chevron-right"
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .opacity(1.0) // Force UI refresh through refreshTrigger state change
    }

    // MARK: - Recurring / Subscriptions Section

    internal var recurringTransactionsSection: some View {
        let subscriptions = SubscriptionManager.shared.subscriptions.filter { $0.isActive }
        let totalMonthly = SubscriptionManager.shared.totalMonthlySpend

        return Group {
            VStack(alignment: .leading, spacing: 10) {
                // Header row
                HStack {
                    Text("Recurring / Subscriptions")
                        .font(AppFonts.overusedGroteskMedium(size: 16))
                        .foregroundColor(AppColors.foregroundSecondary)
                    Spacer()
                    Text("\(CurrencyPreferences.shared.formatPrimaryAmount(totalMonthly))/monthly")
                        .font(AppFonts.overusedGroteskMedium(size: 16))
                        .foregroundColor(AppColors.foregroundSecondary)
                }

                // 2-column grid for subscription cards
                if !subscriptions.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(Array(subscriptions.prefix(5))) { subscription in
                            SubscriptionCard(subscription: subscription) {
                                print("📋 Subscription tapped: \(subscription.name)")
                                selectedSubscriptionForDetail = subscription
                            }
                        }
                    }
                }

                // Add subscription card - full width, height hugs content
                AddSubscriptionCard {
                    // Check if user can add more subscriptions before opening form
                    if SubscriptionManager.shared.canAddMoreSubscriptions {
                        showingAddSubscription = true
                    } else {
                        // Show paywall for free users who have reached the limit
                        showingCustomPaywall = true
                    }
                }
            }
        }
    }

    internal var chartFilterTabs: some View {
        HStack(spacing: 8) {
            // Show Expense, Income, and Balance tabs
            ForEach([ChartFilter.expense, ChartFilter.income, ChartFilter.balance], id: \.id) { filter in
                TabChip.basic(
                    title: filter.rawValue,
                    isSelected: chartFilter == filter
                ) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        chartFilter = filter
                    }
                    print("Selected filter: \(filter.rawValue)")
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Helper Functions
    
    /// Format percentage with commas for large numbers
    internal func formatPercentageWithCommas(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }
}