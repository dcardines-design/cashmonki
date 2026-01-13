//
//  RecurringDetailSheet.swift
//  CashMonki
//
//  Detail sheet for viewing and managing recurring transactions/subscriptions
//

import SwiftUI

struct RecurringDetailSheet: View {
    let subscription: Subscription
    var onDismiss: (() -> Void)?
    var onEdit: ((Subscription) -> Void)?
    var onDelete: ((Subscription) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var currencyPrefs = CurrencyPreferences.shared
    @ObservedObject private var categoriesManager = CategoriesManager.shared
    @State private var showingEditSheet = false
    @State private var showingSettingsMenu = false
    // @State private var isActivePulsing = false  // Hidden for future use (status row)
    @State private var selectedTransaction: Txn? = nil
    @State private var showingTransactionDetail = false
    @State private var showingDeleteConfirmation = false
    @State private var showingEditConfirmation = false
    @State private var pendingEditedSubscription: Subscription? = nil
    // @State private var showingPauseConfirmation = false  // Hidden for future use

    // MARK: - Computed Properties

    /// Converted amount in user's primary currency
    private var convertedAmount: Double {
        CurrencyRateManager.shared.convertAmount(
            abs(subscription.amount),
            from: subscription.currency,
            to: currencyPrefs.primaryCurrency
        )
    }

    /// Whether this is an income subscription (based on category type)
    private var isIncome: Bool {
        if let categoryId = subscription.categoryId {
            let result = categoriesManager.findCategoryOrSubcategoryById(categoryId)
            if let category = result?.category {
                return category.type == .income
            } else if let subcategory = result?.subcategory {
                return subcategory.type == .income
            }
        }
        // Fallback: check by category name
        let result = categoriesManager.findCategoryOrSubcategory(by: subscription.category)
        if let category = result.category {
            return category.type == .income
        } else if let subcategory = result.subcategory {
            return subcategory.type == .income
        }
        return false // Default to expense
    }

    /// Category emoji for display
    private var categoryEmoji: String {
        if let categoryId = subscription.categoryId {
            let result = categoriesManager.findCategoryOrSubcategoryById(categoryId)
            if let category = result?.category {
                return category.emoji
            } else if let subcategory = result?.subcategory {
                return subcategory.emoji
            }
        }
        return TxnCategoryIcon.emojiFor(category: subscription.category)
    }

    /// Get all transactions generated from this subscription (newest first)
    private var generatedTransactions: [Txn] {
        UserManager.shared.currentUser.transactions
            .filter { $0.subscriptionId == subscription.id }
            .sorted { $0.date > $1.date }
    }

    // Date formatter
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter
    }()

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header with settings button
            SheetHeader.withCustomAction(
                title: "Recurring Details",
                onBackTap: {
                    if let onDismiss = onDismiss {
                        onDismiss()
                    } else {
                        dismiss()
                    }
                },
                rightIcon: "settings-01",
                rightSystemIcon: "gearshape",
                onRightTap: {
                    showingSettingsMenu = true
                }
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Category and merchant section
                    categoryMerchantSection

                    // Large converted amount
                    largeAmountSection

                    // Detail rows (includes Billing History)
                    detailRowsSection
                }
                .padding(.bottom, 32)
            }
        }
        .background(AppColors.backgroundWhite)
        .confirmationDialog("Subscription Options", isPresented: $showingSettingsMenu) {
            Button("Edit Subscription") {
                showingEditSheet = true
            }
            // MARK: - Pause/Resume Options (Hidden for future use)
            // Uncomment when ready to enable pause/resume functionality
            /*
            if subscription.isActive {
                Button("Pause Subscription") {
                    // Check if there are existing transactions
                    if !generatedTransactions.isEmpty {
                        showingPauseConfirmation = true
                    } else {
                        // No transactions, just pause
                        pauseSubscriptionOnly()
                        if let onDismiss = onDismiss {
                            onDismiss()
                        } else {
                            dismiss()
                        }
                    }
                }
            } else {
                Button("Resume Subscription") {
                    resumeSubscription()
                    if let onDismiss = onDismiss {
                        onDismiss()
                    } else {
                        dismiss()
                    }
                }
            }
            */
            Button("Delete Subscription", role: .destructive) {
                showingDeleteConfirmation = true
            }
            Button("Cancel", role: .cancel) {}
        }
        // MARK: - Pause Confirmation Dialog (Hidden for future use)
        // Uncomment when ready to enable pause/resume functionality
        /*
        .confirmationDialog("Pause Subscription", isPresented: $showingPauseConfirmation, titleVisibility: .visible) {
            Button("Keep Transactions") {
                // Just pause, keep existing transactions
                pauseSubscriptionOnly()
                if let onDismiss = onDismiss {
                    onDismiss()
                } else {
                    dismiss()
                }
            }
            Button("Delete All Transactions", role: .destructive) {
                // Pause and delete all generated transactions
                pauseAndDeleteTransactions()
                if let onDismiss = onDismiss {
                    onDismiss()
                } else {
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Do you want to keep the \(generatedTransactions.count) existing transaction\(generatedTransactions.count == 1 ? "" : "s") or delete them?")
        }
        */
        .alert("Delete Subscription", isPresented: $showingDeleteConfirmation) {
            Button("Delete Future", role: .destructive) {
                // Delete subscription but keep existing transactions
                onDelete?(subscription)
                // Delay dismissal to allow alert to close first
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if let onDismiss = onDismiss {
                        onDismiss()
                    } else {
                        dismiss()
                    }
                }
            }
            Button("Delete All", role: .destructive) {
                // Delete subscription AND all generated transactions
                deleteSubscriptionWithTransactions()
                // Delay dismissal to allow alert to close first
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if let onDismiss = onDismiss {
                        onDismiss()
                    } else {
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You have \(generatedTransactions.count) past transaction\(generatedTransactions.count == 1 ? "" : "s") from this subscription. Keep them in your history or delete everything?")
        }
        .sheet(isPresented: $showingEditSheet) {
            EditSubscriptionSheet(
                subscription: subscription,
                isPresented: $showingEditSheet,
                onSave: { updatedSubscription in
                    // Check if there are existing transactions
                    if !generatedTransactions.isEmpty {
                        // Store the edited subscription and show confirmation
                        pendingEditedSubscription = updatedSubscription
                        showingEditConfirmation = true
                    } else {
                        // No existing transactions, just save the subscription
                        onEdit?(updatedSubscription)
                        if let onDismiss = onDismiss {
                            onDismiss()
                        } else {
                            dismiss()
                        }
                    }
                }
            )
            .presentationDetents([.fraction(0.98)])
            .presentationCornerRadius(20)
            .presentationDragIndicator(.hidden)
        }
        .alert("Apply Changes", isPresented: $showingEditConfirmation) {
            Button("Apply") {
                // Update subscription - changes apply to future only
                if let edited = pendingEditedSubscription {
                    onEdit?(edited)
                }
                pendingEditedSubscription = nil
                if let onDismiss = onDismiss {
                    onDismiss()
                } else {
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {
                pendingEditedSubscription = nil
            }
        } message: {
            Text("Your changes will apply to future charges only. Past records won't be affected.")
        }
        .sheet(isPresented: $showingTransactionDetail) {
            if let txn = selectedTransaction {
                ReceiptDetailSheet(
                    transaction: txn,
                    onTransactionUpdate: { updatedTxn in
                        // Update the transaction in UserManager
                        UserManager.shared.updateTransaction(updatedTxn)
                    },
                    onTransactionDelete: { deletedTxn in
                        // Delete the transaction from UserManager
                        UserManager.shared.removeTransaction(withId: deletedTxn.id)
                        showingTransactionDetail = false
                    },
                    onDismiss: {
                        showingTransactionDetail = false
                    }
                )
                .presentationDetents([.fraction(0.98)])
                .presentationCornerRadius(20)
                .presentationDragIndicator(.hidden)
            }
        }
    }

    // MARK: - Section Views

    private var categoryMerchantSection: some View {
        HStack(spacing: 12) {
            // Category icon
            TxnCategoryIcon(category: subscription.category, size: 52)

            // Category and merchant
            VStack(alignment: .leading, spacing: 2) {
                Text(subscription.category)
                    .font(AppFonts.overusedGroteskMedium(size: 18))
                    .foregroundColor(AppColors.foregroundPrimary)

                Text(subscription.name)
                    .font(AppFonts.overusedGroteskMedium(size: 18))
                    .foregroundColor(AppColors.foregroundSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var largeAmountSection: some View {
        HStack {
            Text("\(currencyPrefs.primarySymbol)\(formatCurrencyAmount(convertedAmount))")
                .font(AppFonts.overusedGroteskMedium(size: 70))
                .foregroundColor(isIncome ? AppColors.successForeground : Color(red: 0.9, green: 0.3, blue: 0.1))
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var detailRowsSection: some View {
        VStack(spacing: 18) {
            // Merchant row
            horizontalDetailRow(title: "Merchant", value: subscription.name)

            // MARK: - Status Row (Hidden for future use)
            // Status row with colored dot - uncomment when ready to enable pause/resume
            /*
            HStack {
                Text("Status")
                    .font(AppFonts.overusedGroteskMedium(size: 16))
                    .foregroundColor(AppColors.foregroundSecondary)

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(subscription.isActive ? Color.green : AppColors.foregroundTertiary)
                        .frame(width: 6, height: 6)
                        .opacity(subscription.isActive ? (isActivePulsing ? 0.4 : 1.0) : 1.0)
                        .animation(
                            subscription.isActive ?
                                Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true) :
                                .default,
                            value: isActivePulsing
                        )
                        .onAppear {
                            if subscription.isActive {
                                isActivePulsing = true
                            }
                        }

                    Text(subscription.isActive ? "Active" : "Paused")
                        .font(AppFonts.overusedGroteskMedium(size: 16))
                        .foregroundColor(AppColors.foregroundPrimary)
                }
            }
            */

            // Amount row (original currency)
            horizontalDetailRow(
                title: "Amount",
                value: "\(subscription.currency.symbol)\(formatCurrencyAmount(abs(subscription.amount)))"
            )

            // Category row with emoji
            HStack {
                Text("Category")
                    .font(AppFonts.overusedGroteskMedium(size: 16))
                    .foregroundColor(AppColors.foregroundSecondary)

                Spacer()

                HStack(spacing: 8) {
                    TxnCategoryIcon(category: subscription.category, size: 26)

                    Text(subscription.category)
                        .font(AppFonts.overusedGroteskMedium(size: 16))
                        .foregroundColor(AppColors.foregroundPrimary)
                }
            }

            // Start Date row
            horizontalDetailRow(
                title: "Start Date",
                value: dateFormatter.string(from: subscription.createdAt)
            )

            // Repeats row
            horizontalDetailRow(
                title: "Repeats",
                value: subscription.frequency.displayName
            )

            // MARK: - Auto-Add When Due row (Hidden for future use)
            /*
            horizontalDetailRow(
                title: "Auto-Add When Due",
                value: subscription.autoAddTransaction ? "Yes" : "No"
            )
            */

            // Reminder row
            if subscription.reminderEnabled {
                let reminderDays = ReminderDays(rawValue: subscription.reminderDaysBefore) ?? .one
                horizontalDetailRow(
                    title: "Reminder",
                    value: reminderDays.displayName
                )
            }

            // Note row (if exists)
            if let note = subscription.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                horizontalDetailRow(title: "Note", value: note)
            }

            // Billing History section
            billingHistorySection
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    private var billingHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            Text("Billing History")
                .font(AppFonts.overusedGroteskMedium(size: 16))
                .foregroundColor(AppColors.foregroundSecondary)

            // Timeline cards container
            VStack(spacing: 8) {
                // Next renewal (at top)
                timelineRow(
                    name: subscription.name,
                    subtitle: "Next on \(formatShortDateWithTime(subscription.nextDueDate))",
                    isPast: false
                )

                // Show real generated transactions (newest first, up to 5)
                if generatedTransactions.isEmpty {
                    // No transactions yet - show "First charge" row
                    timelineRow(
                        name: subscription.name,
                        subtitle: "First charge \(formatShortDate(subscription.createdAt))",
                        isPast: true
                    )
                } else {
                    // Show actual generated transactions (most recent 5, newest first)
                    ForEach(generatedTransactions.prefix(5), id: \.id) { txn in
                        Button {
                            selectedTransaction = txn
                            showingTransactionDetail = true
                        } label: {
                            timelineRow(
                                name: txn.merchantName ?? subscription.name,
                                subtitle: "Charged \(formatShortDateWithTime(txn.date))",
                                isPast: true,
                                transaction: txn
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(AppColors.surfacePrimary)
            .cornerRadius(18)
        }
    }

    // MARK: - Helper Views

    private func horizontalDetailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(AppFonts.overusedGroteskMedium(size: 16))
                .foregroundColor(AppColors.foregroundSecondary)

            Spacer()

            Text(value)
                .font(AppFonts.overusedGroteskMedium(size: 16))
                .foregroundColor(AppColors.foregroundPrimary)
        }
    }

    private func timelineRow(name: String, subtitle: String, isPast: Bool, transaction: Txn? = nil) -> some View {
        // Use transaction's actual data if available, otherwise use subscription data
        let displayAmount: Double
        let displayCurrency: Currency
        let displayIsIncome: Bool

        if let txn = transaction {
            // Use the actual transaction's amount and currency
            displayAmount = CurrencyRateManager.shared.convertAmount(
                abs(txn.amount),
                from: txn.primaryCurrency,
                to: currencyPrefs.primaryCurrency
            )
            displayCurrency = txn.primaryCurrency
            // Determine income/expense by looking up category type (more reliable than amount sign)
            if let catId = txn.categoryId {
                if let result = categoriesManager.findCategoryOrSubcategoryById(catId) {
                    if let cat = result.category {
                        displayIsIncome = cat.type == .income
                    } else if let subcat = result.subcategory {
                        displayIsIncome = subcat.type == .income
                    } else {
                        displayIsIncome = txn.amount > 0
                    }
                } else {
                    displayIsIncome = txn.amount > 0
                }
            } else {
                // Fallback to name lookup
                let result = categoriesManager.findCategoryOrSubcategory(by: txn.category)
                if let cat = result.category {
                    displayIsIncome = cat.type == .income
                } else if let subcat = result.subcategory {
                    displayIsIncome = subcat.type == .income
                } else {
                    displayIsIncome = txn.amount > 0
                }
            }
        } else {
            // Use subscription data for future/preview rows
            displayAmount = convertedAmount
            displayCurrency = subscription.currency
            displayIsIncome = isIncome
        }

        return HStack(alignment: .center, spacing: 4) {
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(AppFonts.overusedGroteskMedium(size: 14))
                    .foregroundColor(isPast ? AppColors.foregroundPrimary : AppColors.foregroundSecondary)

                Text(subtitle)
                    .font(AppFonts.overusedGroteskMedium(size: 14))
                    .foregroundColor(AppColors.foregroundSecondary)
            }

            Spacer()

            // Amount
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(currencyPrefs.primarySymbol)\(formatCurrencyAmount(displayAmount))")
                    .font(AppFonts.overusedGroteskMedium(size: 20))
                    .foregroundColor(isPast ? (displayIsIncome ? AppColors.successForeground : AppColors.destructiveForeground) : AppColors.foregroundSecondary)

                // Secondary amount if different currency
                if displayCurrency != currencyPrefs.primaryCurrency {
                    let originalAmount = transaction?.amount ?? subscription.amount
                    Text("\(displayCurrency.symbol)\(formatCurrencyAmount(abs(originalAmount)))")
                        .font(AppFonts.overusedGroteskMedium(size: 14))
                        .foregroundColor(AppColors.foregroundSecondary)
                }
            }

        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isPast ? AppColors.backgroundWhite : Color.clear)
        .cornerRadius(10)
        .contentShape(Rectangle())
    }

    // MARK: - Helper Functions

    private func formatCurrencyAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.0f", amount)
    }

    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private func formatShortDateWithTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }

    // MARK: - Pause/Resume Helpers (Hidden for future use)
    // Uncomment when ready to enable pause/resume functionality
    /*
    /// Pause subscription only, keep transactions
    private func pauseSubscriptionOnly() {
        var pausedSubscription = subscription
        pausedSubscription.isActive = false
        onEdit?(pausedSubscription)
        print("⏸️ RecurringDetailSheet: Paused subscription '\(subscription.name)'")
    }

    /// Pause subscription AND delete all generated transactions
    private func pauseAndDeleteTransactions() {
        // First delete all generated transactions
        let transactionsToDelete = generatedTransactions
        for txn in transactionsToDelete {
            UserManager.shared.removeTransaction(withId: txn.id)
        }
        print("🗑️ RecurringDetailSheet: Deleted \(transactionsToDelete.count) transactions while pausing")

        // Then pause the subscription
        var pausedSubscription = subscription
        pausedSubscription.isActive = false
        onEdit?(pausedSubscription)
        print("⏸️ RecurringDetailSheet: Paused subscription '\(subscription.name)'")
    }

    /// Resume a paused subscription
    private func resumeSubscription() {
        var resumedSubscription = subscription
        resumedSubscription.isActive = true
        // Reset next due date to future if it's in the past
        if resumedSubscription.nextDueDate <= Date() {
            resumedSubscription.nextDueDate = resumedSubscription.calculateNextDueDate(after: Date())
        }
        onEdit?(resumedSubscription)
        print("▶️ RecurringDetailSheet: Resumed subscription '\(subscription.name)'")
    }
    */

    // MARK: - Deletion Helpers

    /// Delete subscription AND all transactions generated from it
    private func deleteSubscriptionWithTransactions() {
        // First delete all generated transactions
        let transactionsToDelete = generatedTransactions
        for txn in transactionsToDelete {
            UserManager.shared.removeTransaction(withId: txn.id)
        }
        print("🗑️ RecurringDetailSheet: Deleted \(transactionsToDelete.count) generated transactions")

        // Then delete the subscription itself
        onDelete?(subscription)
    }
}

// MARK: - Preview

#Preview {
    RecurringDetailSheet(
        subscription: Subscription(
            name: "Netflix",
            amount: 10,
            currency: .usd,
            category: "Entertainment",
            frequency: .monthly,
            nextDueDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
            reminderEnabled: true,
            reminderDaysBefore: 3,
            autoAddTransaction: true,
            isActive: true,
            createdAt: Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        )
    )
}
