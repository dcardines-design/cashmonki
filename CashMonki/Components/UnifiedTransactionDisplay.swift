//
//  UnifiedTransactionDisplay.swift
//  Cashooya Playground
//
//  Created by Claude on 9/7/25.
//

import SwiftUI

// MARK: - Unified Transaction Display Component
struct UnifiedTransactionDisplay: View {
    let transaction: Txn
    let displayStyle: DisplayStyle
    let onTap: (() -> Void)?
    let onTransactionUpdate: ((Txn) -> Void)?
    @ObservedObject private var categoriesManager = CategoriesManager.shared
    @ObservedObject private var userManager = UserManager.shared
    
    // MARK: - Display Styles
    enum DisplayStyle {
        case row        // List-style row (current TransactionRow)
        case tile       // Card-style tile (current TransactionTile)
        case compact    // Minimal display for small spaces
        case detailed   // Rich display with more information
    }
    
    init(
        transaction: Txn,
        displayStyle: DisplayStyle = .row,
        onTap: (() -> Void)? = nil,
        onTransactionUpdate: ((Txn) -> Void)? = nil
    ) {
        self.transaction = transaction
        self.displayStyle = displayStyle
        self.onTap = onTap
        self.onTransactionUpdate = onTransactionUpdate
    }
    
    /// Check if the transaction category is an income category
    private var isIncomeCategory: Bool {
        // Use transaction amount to determine income vs expense
        // This handles cases where expense categories are used for income (like utility refunds)
        // or income categories are used for expenses (like salary deductions)
        return transaction.amount > 0
    }
    
    /// Get the appropriate category type for emoji lookup
    private var categoryType: CategoryType {
        return isIncomeCategory ? .income : .expense
    }
    
    /// Get the appropriate color for the amount text
    private var amountTextColor: Color {
        // Use design system colors for consistency
        // Green for income (positive amounts), red for expenses (negative amounts)
        return transaction.amount > 0 ? AppColors.successForeground : Color.red
    }
    
    /// Check if we should show secondary amount (user entered or converted amount)
    private var shouldShowSecondaryAmount: Bool {
        // Don't show if primary and secondary amounts are the same
        if primaryAmountText == originalAmountText {
            return false
        }
        
        // Show if user has entered amount in different currency
        if transaction.userEnteredAmount != nil && transaction.userEnteredCurrency != nil {
            return true
        }
        // Or show if transaction was converted (legacy behavior)
        return transaction.wasConverted
    }
    
    var body: some View {
        Button(action: handleTap) {
            switch displayStyle {
            case .row:
                rowContent
            case .tile:
                tileContent
            case .compact:
                compactContent
            case .detailed:
                detailedContent
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Content Variants
    
    private var rowContent: some View {
        HStack(alignment: .center, spacing: 12) {
            // Category Icon with context-aware emoji lookup
            ZStack {
                Circle()
                    .fill(AppColors.surfacePrimary)
                    .frame(width: 34, height: 34)
                
                Text(categoriesManager.emojiFor(category: transaction.category, type: categoryType))
                    .font(.system(size: 17))
            }
            
            // Transaction Details
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.category)
                    .font(AppFonts.overusedGroteskMedium(size: 15))
                    .foregroundColor(AppColors.foregroundPrimary)
                
                subtitleText
            }
            
            Spacer()
            
            // Amount Display
            VStack(alignment: .trailing, spacing: 2) {
                Text(primaryAmountText)
                    .font(AppFonts.overusedGroteskSemiBold(size: 17))
                    .foregroundColor(amountTextColor)
                
                if shouldShowSecondaryAmount {
                    Text(originalAmountText)
                        .font(AppFonts.overusedGroteskMedium(size: 12))
                        .foregroundColor(AppColors.foregroundSecondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.0001))
    }
    
    private var tileContent: some View {
        HStack(spacing: 12) {
            // Category Icon with context-aware emoji lookup
            ZStack {
                Circle()
                    .fill(AppColors.surfacePrimary)
                    .frame(width: 34, height: 34)
                
                Text(categoriesManager.emojiFor(category: transaction.category, type: categoryType))
                    .font(.system(size: 17))
            }
            
            // Transaction Details
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchantName ?? transaction.category)
                    .font(AppFonts.overusedGroteskSemiBold(size: 16))
                    .foregroundColor(AppColors.foregroundSecondary)
                    .lineLimit(1)
                
                Text(transaction.category)
                    .font(AppFonts.overusedGroteskMedium(size: 14))
                    .foregroundColor(AppColors.foregroundSecondary)
                    .lineLimit(1)
                
                Text(transaction.date, style: .date)
                    .font(AppFonts.overusedGroteskMedium(size: 12))
                    .foregroundColor(AppColors.foregroundSecondary)
            }
            
            Spacer()
            
            // Amount Display with dual currency support
            VStack(alignment: .trailing, spacing: 2) {
                Text(primaryAmountText)
                    .font(AppFonts.overusedGroteskSemiBold(size: 16))
                    .foregroundColor(amountTextColor)
                
                if shouldShowSecondaryAmount {
                    Text(originalAmountText)
                        .font(AppFonts.overusedGroteskMedium(size: 12))
                        .foregroundColor(AppColors.foregroundSecondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surfacePrimary)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 0.863, green: 0.886, blue: 0.957), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var compactContent: some View {
        HStack(spacing: 8) {
            // Small Category Icon with context-aware emoji lookup
            ZStack {
                Circle()
                    .fill(AppColors.surfacePrimary)
                    .frame(width: 24, height: 24)
                
                Text(categoriesManager.emojiFor(category: transaction.category, type: categoryType))
                    .font(.system(size: 12))
            }
            
            // Minimal Details
            VStack(alignment: .leading, spacing: 1) {
                Text(transaction.merchantName ?? transaction.category)
                    .font(AppFonts.overusedGroteskMedium(size: 13))
                    .foregroundColor(AppColors.foregroundSecondary)
                    .lineLimit(1)
                
                Text(primaryAmountText)
                    .font(AppFonts.overusedGroteskSemiBold(size: 12))
                    .foregroundColor(amountTextColor)
                
                if shouldShowSecondaryAmount {
                    Text(originalAmountText)
                        .font(AppFonts.overusedGroteskMedium(size: 10))
                        .foregroundColor(AppColors.foregroundSecondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private var detailedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Category Icon with context-aware emoji lookup
                ZStack {
                    Circle()
                        .fill(AppColors.surfacePrimary)
                        .frame(width: 40, height: 40)
                    
                    Text(categoriesManager.emojiFor(category: transaction.category, type: categoryType))
                        .font(.system(size: 20))
                }
                
                // Transaction Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.merchantName ?? transaction.category)
                        .font(AppFonts.overusedGroteskSemiBold(size: 18))
                        .foregroundColor(AppColors.foregroundSecondary)
                    
                    Text(transaction.category)
                        .font(AppFonts.overusedGroteskMedium(size: 14))
                        .foregroundColor(AppColors.foregroundSecondary)
                }
                
                Spacer()
                
                // Amount
                VStack(alignment: .trailing, spacing: 2) {
                    Text(primaryAmountText)
                        .font(AppFonts.overusedGroteskSemiBold(size: 20))
                        .foregroundColor(amountTextColor)
                    
                    if shouldShowSecondaryAmount {
                        Text(originalAmountText)
                            .font(AppFonts.overusedGroteskMedium(size: 14))
                            .foregroundColor(AppColors.foregroundSecondary)
                    }
                }
            }
            
            // Additional Details
            HStack {
                Text(formatDate(transaction.date))
                    .font(AppFonts.overusedGroteskMedium(size: 14))
                    .foregroundColor(AppColors.foregroundSecondary)
                
                Spacer()
                
                if let paymentMethod = transaction.paymentMethod {
                    Text(paymentMethod)
                        .font(AppFonts.overusedGroteskMedium(size: 14))
                        .foregroundColor(AppColors.foregroundSecondary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(AppColors.surfacePrimary)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Helper Functions
    
    private func handleTap() {
        onTap?()
    }
    
    @ViewBuilder
    private var subtitleText: some View {
        let dateText = formatDate(transaction.date)
        
        HStack(spacing: 4) {
            if let merchantName = transaction.merchantName, !merchantName.isEmpty {
                let trimmedMerchantName = merchantName.count > 12 ? 
                    String(merchantName.prefix(12)) + "..." : 
                    merchantName
                
                Text(trimmedMerchantName)
                    .font(AppFonts.overusedGroteskMedium(size: 12))
                    .foregroundColor(AppColors.foregroundSecondary)
                
                Text("·")
                    .font(AppFonts.overusedGroteskMedium(size: 12))
                    .foregroundColor(AppColors.foregroundSecondary)
            }
            
            Text(dateText)
                .font(AppFonts.overusedGroteskMedium(size: 12))
                .foregroundColor(AppColors.foregroundSecondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var primaryAmountText: String {
        let amount = abs(transaction.amount)
        return formatCurrency(amount, currency: transaction.primaryCurrency)
    }
    
    private var originalAmountText: String {
        // Show user entered amount if available, otherwise show original converted amount
        if let userEnteredAmount = transaction.userEnteredAmount,
           let userEnteredCurrency = transaction.userEnteredCurrency {
            return formatCurrency(abs(userEnteredAmount), currency: userEnteredCurrency)
        } else if let originalAmount = transaction.originalAmount,
                  let originalCurrency = transaction.originalCurrency {
            return formatCurrency(originalAmount, currency: originalCurrency)
        }
        return ""
    }
    
    private func formatCurrency(_ amount: Double, currency: Currency) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        let formattedAmount = formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.0f", amount)
        return "\(currency.symbol)\(formattedAmount)"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Convenience Initializers
extension UnifiedTransactionDisplay {
    
    /// Creates a row-style transaction display (replaces TransactionRow)
    static func row(
        transaction: Txn,
        onTap: @escaping () -> Void,
        onTransactionUpdate: ((Txn) -> Void)? = nil
    ) -> UnifiedTransactionDisplay {
        UnifiedTransactionDisplay(
            transaction: transaction,
            displayStyle: .row,
            onTap: onTap,
            onTransactionUpdate: onTransactionUpdate
        )
    }
    
    /// Creates a tile-style transaction display (replaces TransactionTile)
    static func tile(
        transaction: Txn,
        onTap: @escaping () -> Void
    ) -> UnifiedTransactionDisplay {
        UnifiedTransactionDisplay(
            transaction: transaction,
            displayStyle: .tile,
            onTap: onTap
        )
    }
    
    /// Creates a compact transaction display for small spaces
    static func compact(
        transaction: Txn,
        onTap: (() -> Void)? = nil
    ) -> UnifiedTransactionDisplay {
        UnifiedTransactionDisplay(
            transaction: transaction,
            displayStyle: .compact,
            onTap: onTap
        )
    }
    
    /// Creates a detailed transaction display with rich information
    static func detailed(
        transaction: Txn,
        onTransactionUpdate: ((Txn) -> Void)? = nil
    ) -> UnifiedTransactionDisplay {
        UnifiedTransactionDisplay(
            transaction: transaction,
            displayStyle: .detailed,
            onTransactionUpdate: onTransactionUpdate
        )
    }
}

// MARK: - Supporting Components

struct TransactionGroup: View {
    let title: String
    let transactions: [Txn]
    let displayStyle: UnifiedTransactionDisplay.DisplayStyle
    let onTransactionTap: (Txn) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(AppFonts.overusedGroteskSemiBold(size: 18))
                .foregroundColor(AppColors.foregroundPrimary)
                .padding(.horizontal, 16)
            
            LazyVStack(spacing: displayStyle == .tile ? 8 : 0) {
                ForEach(transactions) { transaction in
                    UnifiedTransactionDisplay(
                        transaction: transaction,
                        displayStyle: displayStyle
                    ) {
                        onTransactionTap(transaction)
                    }
                    .padding(.horizontal, displayStyle == .tile ? 16 : 0)
                    
                    // Add dividers for row style
                    if displayStyle == .row && transaction != transactions.last {
                        Divider()
                            .padding(.leading, 60) // Align with text, not icon
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    let sampleTransaction = Txn(
        txID: UUID(),
        accountID: UUID(),
        walletID: UUID(),
        category: "Transportation",
        categoryId: nil,
        amount: -175.0, // Converted to PHP (primary currency)
        date: Date(),
        createdAt: Date(),
        receiptImage: nil,
        hasReceiptImage: false,
        merchantName: "Uber",
        paymentMethod: "Credit Card",
        receiptNumber: nil,
        invoiceNumber: nil,
        items: [],
        note: nil,
        originalAmount: 10.09, // Original USD amount
        originalCurrency: .usd,
        primaryCurrency: .php,
        secondaryCurrency: nil,
        exchangeRate: 58.693,
        secondaryAmount: nil,
        secondaryExchangeRate: nil
    )
    
    ScrollView(showsIndicators: false) {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Row Style")
                    .font(.headline)
                UnifiedTransactionDisplay.row(
                    transaction: sampleTransaction,
                    onTap: { print("Row tapped") }
                )
                    .background(Color.white)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Tile Style")
                    .font(.headline)
                UnifiedTransactionDisplay.tile(transaction: sampleTransaction, onTap: {
                    print("Tapped tile")
                })
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Compact Style")
                    .font(.headline)
                UnifiedTransactionDisplay.compact(transaction: sampleTransaction)
                    .background(Color.gray.opacity(0.1))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Detailed Style")
                    .font(.headline)
                UnifiedTransactionDisplay.detailed(transaction: sampleTransaction)
            }
        }
        .padding()
    }
    .background(AppColors.backgroundWhite)
}