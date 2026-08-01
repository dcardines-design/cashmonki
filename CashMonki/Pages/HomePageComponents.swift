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
    
    /// Dark promo card below the action tiles that opens the feedback board.
    internal var feedbackPromoCard: some View {
        Button {
            showingFeedbackBoard = true
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Got feedback?")
                    .font(AppFonts.overusedGroteskSemiBold(size: 16))
                    .foregroundColor(.white)
                Text("Let us know and we’ll try our best to fix it!")
                    .font(AppFonts.overusedGroteskMedium(size: 12))
                    .foregroundColor(Color(red: 0.66, green: 0.66, blue: 0.66))
            }
            .padding(.leading, 18)
            .padding(.trailing, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                ZStack(alignment: .trailing) {
                    Color(red: 0.15, green: 0.15, blue: 0.15)
                    Image("feedback-card-art")
                        .resizable()
                        .scaledToFit()
                }
            )
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// Promo carousel under the action tiles: pages the "Save data to cloud" nudge + the feedback
    /// card, ChatGPT/subscription-card style (paged, peek, dots). The sync nudge only appears when
    /// the user isn't signed in; when signed in the carousel collapses to just the feedback card.
    internal var promoCarousel: some View {
        // Order matches Figma: sync nudge first, feedback second. Drop the sync page once synced.
        let pages: [PromoPage] = authManager.isAuthenticated ? [.feedback] : [.sync, .feedback]
        return VStack(spacing: 8) {
            if pages.count <= 1 {
                promoView(for: pages[0])
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                            promoView(for: page)
                                .containerRelativeFrame(.horizontal, count: 1, span: 1, spacing: 12)
                                .id(index)
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, 20, for: .scrollContent)
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $currentPromoPage, anchor: .leading)
                .padding(.horizontal, -20) // bleed so the next card peeks to the screen edge

                HStack(spacing: 6) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill((currentPromoPage ?? 0) == index ? AppColors.foregroundPrimary : AppColors.foregroundTertiary.opacity(0.4))
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
                .animation(.easeInOut(duration: 0.2), value: currentPromoPage)
            }
        }
    }

    enum PromoPage { case sync, feedback }

    @ViewBuilder
    private func promoView(for page: PromoPage) -> some View {
        switch page {
        case .sync: syncPromoCard
        case .feedback: feedbackPromoCard
        }
    }

    /// "Save data to cloud" nudge (Figma 1710-7185 "sync data bar"). Tap → connect-account flow.
    /// Text block is laid out exactly like `feedbackPromoCard` — same sizes, spacing and padding —
    /// so the two carousel pages line up. The 400×67 art sits behind, scaled to fit against a
    /// matching #0a8cff base so it never crops; only the colours differ between the two cards.
    internal var syncPromoCard: some View {
        Button {
            showingConnectAccount = true
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Save data to cloud")
                    .font(AppFonts.overusedGroteskSemiBold(size: 16))
                    .foregroundColor(.white)
                Text("Log in to sync and secure your data!")
                    .font(AppFonts.overusedGroteskMedium(size: 12))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.leading, 18)
            .padding(.trailing, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                ZStack(alignment: .trailing) {
                    Color(red: 0.039, green: 0.549, blue: 1.0) // #0a8cff — same as the art's bar
                    Image("sync-data-bar")
                        .resizable()
                        .scaledToFit()
                }
            )
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
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

                // Horizontally paged carousel — each page is a 2×2 grid of up to 4 cards
                if !subscriptions.isEmpty {
                    let pages = subscriptions.chunked(into: 4)

                    ScrollView(.horizontal, showsIndicators: false) {
                        // Top-aligned so partial pages (1-3 tiles) hug the top-left
                        LazyHStack(alignment: .top, spacing: 12) {
                            ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                                subscriptionPageGrid(page)
                                    .containerRelativeFrame(.horizontal, count: 1, span: 1, spacing: 12)
                                    .id(index)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .contentMargins(.horizontal, 20, for: .scrollContent)
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: $currentSubscriptionPage, anchor: .leading)
                    .scrollDisabled(pages.count <= 1)
                    .padding(.horizontal, -20) // bleed out of parent's 20pt padding so pages peek to the screen edge
                    .onChange(of: pages.count) { _, newCount in
                        // Keep the current page (and dots) valid if the list shrinks.
                        if let page = currentSubscriptionPage, page >= newCount {
                            currentSubscriptionPage = max(0, newCount - 1)
                        }
                    }

                    // Page-indicator dots (only when there's more than one page)
                    if pages.count > 1 {
                        HStack(spacing: 6) {
                            ForEach(0..<pages.count, id: \.self) { index in
                                Circle()
                                    .fill((currentSubscriptionPage ?? 0) == index ? AppColors.foregroundPrimary : AppColors.foregroundTertiary.opacity(0.4))
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 2)
                        .animation(.easeInOut(duration: 0.2), value: currentSubscriptionPage)
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

    /// A single carousel page: a 2×2 grid of up to 4 subscription cards.
    @ViewBuilder
    internal func subscriptionPageGrid(_ subscriptions: [Subscription]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(subscriptions) { subscription in
                SubscriptionCard(subscription: subscription) {
                    print("📋 Subscription tapped: \(subscription.name)")
                    selectedSubscriptionForDetail = subscription
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