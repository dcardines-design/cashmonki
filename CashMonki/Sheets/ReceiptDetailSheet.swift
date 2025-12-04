//
//  ReceiptDetailSheet.swift
//  Cashooya Playground
//w
//  Created by Dante Cardines III on 9/5/25.
//

import SwiftUI

class TransactionState: ObservableObject {
    @Published var transaction: Txn
    @Published var shouldShowNote: Bool
    
    init(transaction: Txn) {
        self.transaction = transaction
        self.shouldShowNote = Self.hasValidNote(transaction.note)
    }
    
    func updateTransaction(_ newTransaction: Txn) {
        print("🐛 TransactionState - Updating transaction:")
        print("   - Note: '\(transaction.note ?? "nil")' → '\(newTransaction.note ?? "nil")'")
        print("   - Category: '\(transaction.category)' → '\(newTransaction.category)'")
        print("   - CategoryId: '\(transaction.categoryId?.uuidString.prefix(8) ?? "nil")' → '\(newTransaction.categoryId?.uuidString.prefix(8) ?? "nil")'")
        print("   - Amount: \(transaction.amount) → \(newTransaction.amount)")
        
        self.transaction = newTransaction
        self.shouldShowNote = Self.hasValidNote(newTransaction.note)
        
        print("🐛 TransactionState - After update:")
        print("   - Final category: '\(transaction.category)'")
        print("   - Final categoryId: '\(transaction.categoryId?.uuidString.prefix(8) ?? "nil")'")
        print("   - shouldShowNote: \(shouldShowNote)")
    }
    
    private static func hasValidNote(_ note: String?) -> Bool {
        guard let note = note else { return false }
        return !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct ReceiptDetailSheet: View {
    @StateObject private var transactionState: TransactionState
    var onTransactionUpdate: ((Txn) -> Void)?
    var onTransactionDelete: ((Txn) -> Void)?
    var onDismiss: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false
    @State private var loadedReceiptImage: UIImage? = nil
    @State private var isLoadingReceiptImage = false
    
    init(transaction: Txn, onTransactionUpdate: ((Txn) -> Void)? = nil, onTransactionDelete: ((Txn) -> Void)? = nil, onDismiss: (() -> Void)? = nil) {
        print("🐛 ReceiptDetailSheet INIT - transaction.note: '\(transaction.note ?? "nil")'")
        print("🐛 ReceiptDetailSheet INIT - receipt image: \(transaction.receiptImage != nil ? "✅ EXISTS" : "❌ MISSING")")
        print("🐛 ReceiptDetailSheet INIT - hasReceiptImage flag: \(transaction.hasReceiptImage)")
        if let image = transaction.receiptImage {
            print("🐛 ReceiptDetailSheet INIT - image size: \(image.size.width) x \(image.size.height)")
        }
        self._transactionState = StateObject(wrappedValue: TransactionState(transaction: transaction))
        self.onTransactionUpdate = onTransactionUpdate
        self.onTransactionDelete = onTransactionDelete
        self.onDismiss = onDismiss
    }
    
    // Date formatter for consistent date formatting
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d, yyyy, 'at' h:mm a"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            SheetHeader.withEdit(
                title: "Transaction Details",
                onBackTap: { 
                    if let onDismiss = onDismiss {
                        onDismiss()
                    } else {
                        dismiss() 
                    }
                },
                onEditTap: { 
                    print("🐛 EDIT BUTTON - Opening edit sheet for transaction with note: '\(transactionState.transaction.note ?? "nil")'")
                    showingEditSheet = true 
                }
            )
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Category and merchant section
                    HStack(spacing: 12) {
                        // Category icon - 26px emoji size (52px container)
                        TxnCategoryIcon(category: transactionState.transaction.category, size: 52)
                        
                        // Category and merchant
                        VStack(alignment: .leading, spacing: 2) {
                            Text(transactionState.transaction.category)
                                .font(AppFonts.overusedGroteskMedium(size: 18))
                                .foregroundColor(.primary)
                            
                            Text(transactionState.transaction.merchantName ?? "-")
                                .font(AppFonts.overusedGroteskMedium(size: 18))
                                .foregroundColor(AppColors.foregroundSecondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    // Large currency amount
                    HStack {
                        if transactionState.transaction.amount < 0 {
                            Text("\(transactionState.transaction.primaryCurrency.symbol)\(formatCurrencyAmount(abs(transactionState.transaction.amount)))")
                                .font(AppFonts.overusedGroteskMedium(size: 70))
                                .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.1)) // Orange/red color for expenses
                        } else {
                            Text("\(transactionState.transaction.primaryCurrency.symbol)\(formatCurrencyAmount(transactionState.transaction.amount))")
                                .font(AppFonts.overusedGroteskMedium(size: 70))
                                .foregroundColor(AppColors.successForeground)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // Transaction details - New horizontal layout
                    VStack(spacing: 18) {
                        // Merchant row
                        horizontalDetailRow(title: "Merchant", value: transactionState.transaction.merchantName ?? "-")
                        
                        // Amount row - Always show user's original input (never changes with currency conversion)
                        horizontalDetailRow(
                            title: "Amount", 
                            value: {
                                // First try originalAmount/originalCurrency (most reliable for preserving user input)
                                if let originalAmount = transactionState.transaction.originalAmount,
                                   let originalCurrency = transactionState.transaction.originalCurrency {
                                    return "\(originalCurrency.symbol)\(formatCurrencyAmount(abs(originalAmount)))"
                                }
                                // Fallback to userEnteredAmount/userEnteredCurrency
                                else if let userEnteredAmount = transactionState.transaction.userEnteredAmount,
                                        let userEnteredCurrency = transactionState.transaction.userEnteredCurrency {
                                    return "\(userEnteredCurrency.symbol)\(formatCurrencyAmount(abs(userEnteredAmount)))"
                                }
                                // Last resort: show current amount in primary currency
                                else {
                                    return "\(transactionState.transaction.primaryCurrency.symbol)\(formatCurrencyAmount(abs(transactionState.transaction.amount)))"
                                }
                            }()
                        )
                        
                        // REMOVED: Primary Currency Amount field per user request
                        // Only work with the big red/green numbers and the amount field
                        
                        // COMMENTED OUT: Secondary Amount field - no longer displayed
                        /*
                        // Secondary Currency Amount row
                        if let secondaryAmount = transactionState.transaction.secondaryAmount,
                           let secondaryCurrency = transactionState.transaction.secondaryCurrency {
                            horizontalDetailRow(
                                title: "Secondary Amount", 
                                value: "\(secondaryCurrency.symbol)\(formatCurrencyAmount(secondaryAmount))"
                            )
                        }
                        */
                        
                        // Exchange Rate row (if applicable)
                        // COMMENTED OUT: Exchange rate display per user request
                        /*
                        if let exchangeRate = transactionState.transaction.exchangeRate, exchangeRate != 1.0 {
                            horizontalDetailRow(
                                title: "Exchange Rate", 
                                value: "\(transactionState.transaction.originalCurrency?.symbol ?? "$")1 : \(transactionState.transaction.primaryCurrency.symbol)\(String(format: "%.2f", exchangeRate))"
                            )
                        }
                        */
                        
                        // Category row with emoji
                        HStack {
                            Text("Category")
                                .font(AppFonts.overusedGroteskMedium(size: 16))
                                .foregroundColor(AppColors.foregroundSecondary)
                            
                            Spacer()
                            
                            HStack(spacing: 8) {
                                TxnCategoryIcon(category: transactionState.transaction.category, size: 26)
                                
                                Text(transactionState.transaction.category)
                                    .font(AppFonts.overusedGroteskMedium(size: 16))
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        // Date row
                        horizontalDetailRow(title: "Transaction Date", value: dateFormatter.string(from: transactionState.transaction.date))
                        
                        // Note row - only show if note exists and is not empty
                        if transactionState.shouldShowNote {
                            horizontalDetailRow(title: "Note", value: displayNote(transactionState.transaction.note))
                        }
                        
                        // Receipt section - Only show if we have an actual image to display
                        if hasReceiptImageToDisplay() {
                            HStack {
                                Text("Receipt")
                                    .font(AppFonts.overusedGroteskMedium(size: 16))
                                    .foregroundColor(AppColors.foregroundSecondary)
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    
                    // Receipt image - Only show if we have an actual image or are loading
                    if let receiptImage = transactionState.transaction.receiptImage ?? loadedReceiptImage {
                        VStack(alignment: .leading, spacing: 16) {
                            // Full-width receipt image with 20px margins
                            Image(uiImage: receiptImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(AppColors.linePrimary, lineWidth: 1)
                                )
                                .padding(.horizontal, 20)
                            
                            // COMMENTED OUT: Receipt and Invoice Number container
                            /*
                            VStack(spacing: 16) {
                                // Receipt Number row
                                HStack(spacing: 16) {
                                    Text("Receipt Number")
                                        .font(AppFonts.overusedGroteskMedium(size: 16))
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text(transactionState.transaction.receiptNumber ?? "-")
                                        .font(AppFonts.overusedGroteskMedium(size: 16))
                                        .foregroundColor(transactionState.transaction.receiptNumber != nil ? .primary : .secondary)
                                }
                                
                                // Invoice Number row
                                HStack(spacing: 16) {
                                    Text("Invoice Number")
                                        .font(AppFonts.overusedGroteskMedium(size: 16))
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text(transactionState.transaction.invoiceNumber ?? "-")
                                        .font(AppFonts.overusedGroteskMedium(size: 16))
                                        .foregroundColor(transactionState.transaction.invoiceNumber != nil ? .primary : .secondary)
                                }
                            }
                            .padding(16)
                            .background(AppColors.surfacePrimary)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(AppColors.linePrimary, lineWidth: 1)
                            )
                            .padding(.horizontal, 20)
                            */
                        }
                        .padding(.top, 0)
                        .padding(.bottom, 32)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .background(AppColors.backgroundWhite)
        .ignoresSafeArea(.container, edges: .bottom)
        .onAppear {
            print("🔄 ReceiptDetailSheet: onAppear called")
            // Refresh transaction data when view appears to ensure it's up to date
            refreshTransactionFromUserManager()
            // Load receipt image if available
            loadReceiptImageIfNeeded()
        }
        .onChange(of: showingEditSheet) { _, isShowing in
            if !isShowing {
                print("🔄 ReceiptDetailSheet: Edit sheet dismissed, refreshing transaction")
                refreshTransactionFromUserManager()
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditTransactionSheet(
                transaction: transactionState.transaction,
                onTransactionUpdate: { updatedTransaction in
                    print("🔥 CALLBACK - ReceiptDetailSheet received updated transaction")
                    print("🔥 CALLBACK - Transaction ID: \(updatedTransaction.id)")
                    print("🔥 CALLBACK - Category: '\(transactionState.transaction.category)' → '\(updatedTransaction.category)'")
                    print("🔥 CALLBACK - CategoryId: '\(transactionState.transaction.categoryId?.uuidString.prefix(8) ?? "nil")' → '\(updatedTransaction.categoryId?.uuidString.prefix(8) ?? "nil")'")
                    print("🔥 CALLBACK - Amount: \(transactionState.transaction.amount) → \(updatedTransaction.amount)")
                    print("🔥 CALLBACK - Note: '\(transactionState.transaction.note ?? "nil")' → '\(updatedTransaction.note ?? "nil")'")
                    
                    // Close edit sheet first
                    showingEditSheet = false
                    
                    // Update using the ObservableObject with explicit UI refresh
                    DispatchQueue.main.async {
                        print("🔥 CALLBACK - About to update TransactionState...")
                        transactionState.updateTransaction(updatedTransaction)
                        
                        // CRITICAL FIX: Update in UserManager to trigger HomePage refresh
                        print("🔥 CALLBACK - Updating transaction in UserManager...")
                        UserManager.shared.updateTransaction(updatedTransaction)
                        
                        // Force UI refresh by toggling a state variable
                        print("🔥 CALLBACK - Transaction state updated, forcing UI refresh...")
                        
                        // Then notify parent
                        onTransactionUpdate?(updatedTransaction)
                        
                        print("🔥 CALLBACK - Parent notification sent")
                    }
                },
                onTransactionDelete: { deletedTransaction in
                    // Close the edit sheet first
                    showingEditSheet = false
                    
                    // Small delay to allow sheet animation to complete, then close detail sheet and show toast
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        // Call parent delete callback
                        onTransactionDelete?(deletedTransaction)
                        
                        // Close this detail sheet
                        if let onDismiss = onDismiss {
                            onDismiss()
                        } else {
                            dismiss()
                        }
                        
                        // Show toast notification
                        showToast(message: "Transaction deleted")
                    }
                },
                onDismiss: {
                    showingEditSheet = false
                }
            )
            .id("edit-\(transactionState.transaction.id)-\(transactionState.transaction.note ?? "empty")")
            .presentationDetents([.fraction(0.98)])
            .presentationDragIndicator(.hidden)
        }
    }
    
    // Toast notification function
    private func showToast(message: String) {
        // Use UIKit's built-in notification banner
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(alert, animated: true)
            
            // Auto-dismiss after 1.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                alert.dismiss(animated: true)
            }
        }
    }
    
    /// Check if we have an actual receipt image to display
    private func hasReceiptImageToDisplay() -> Bool {
        return transactionState.transaction.receiptImage != nil || loadedReceiptImage != nil
    }
    
    /// Load receipt image from cache if transaction has one but no embedded image
    private func loadReceiptImageIfNeeded() {
        // Only load if transaction has receipt image flag but no embedded image
        guard transactionState.transaction.hasReceiptImage,
              transactionState.transaction.receiptImage == nil,
              loadedReceiptImage == nil,
              !isLoadingReceiptImage else {
            return
        }
        
        print("📸 ReceiptDetailSheet: Loading receipt image from cache for transaction: \(transactionState.transaction.id.uuidString.prefix(8))")
        isLoadingReceiptImage = true
        
        transactionState.transaction.loadReceiptImage { image in
            DispatchQueue.main.async {
                isLoadingReceiptImage = false
                if let image = image {
                    print("📸 ReceiptDetailSheet: ✅ Receipt image loaded from cache")
                    loadedReceiptImage = image
                } else {
                    print("📸 ReceiptDetailSheet: ❌ Receipt image not found in cache")
                }
            }
        }
    }
    
    /// Refresh transaction data from UserManager to ensure it's current
    private func refreshTransactionFromUserManager() {
        print("🔄 ReceiptDetailSheet: Refreshing transaction from UserManager")
        print("🔄 Current transaction ID: \(transactionState.transaction.id.uuidString.prefix(8))")
        print("🔄 Current category: '\(transactionState.transaction.category)'")
        
        let userManager = UserManager.shared
        let allTransactions = userManager.getTransactions()
        
        // Find the current transaction by ID
        if let freshTransaction = allTransactions.first(where: { $0.id == transactionState.transaction.id }) {
            print("🔄 Found fresh transaction:")
            print("   - Category: '\(transactionState.transaction.category)' → '\(freshTransaction.category)'")
            print("   - CategoryId: '\(transactionState.transaction.categoryId?.uuidString.prefix(8) ?? "nil")' → '\(freshTransaction.categoryId?.uuidString.prefix(8) ?? "nil")'")
            
            if freshTransaction.category != transactionState.transaction.category || 
               freshTransaction.categoryId != transactionState.transaction.categoryId {
                print("🔄 Transaction data changed, updating...")
                transactionState.updateTransaction(freshTransaction)
            } else {
                print("🔄 Transaction data is current, no update needed")
            }
        } else {
            print("⚠️ Could not find transaction with ID \(transactionState.transaction.id.uuidString.prefix(8)) in UserManager")
        }
    }
    
    /// Fix this specific transaction if it's orphaned or has invalid category reference
    private func fixThisTransactionIfOrphaned() {
        print("🔧 Checking if current transaction needs fixing...")
        
        let transaction = transactionState.transaction
        print("🔧 Transaction: \(transaction.merchantName ?? "Unknown") - '\(transaction.category)'")
        print("🔧 CategoryId: '\(transaction.categoryId?.uuidString.prefix(8) ?? "nil")'")
        
        let categoriesManager = CategoriesManager.shared
        
        // Check if the category still exists
        var categoryExists = false
        
        if let categoryId = transaction.categoryId {
            let result = categoriesManager.findCategoryOrSubcategoryById(categoryId)
            categoryExists = result != nil
            print("🔧 Category lookup result: \(result != nil ? "EXISTS" : "NOT FOUND")")
        }
        
        // Also check if the category name exists
        let categoryNameResult = categoriesManager.findCategoryOrSubcategory(by: transaction.category)
        let categoryNameExists = categoryNameResult.category != nil || categoryNameResult.subcategory != nil
        print("🔧 Category name '\(transaction.category)' exists: \(categoryNameExists)")
        
        if !categoryExists || !categoryNameExists {
            print("🔧 ⚠️ FOUND ORPHANED TRANSACTION - fixing...")
            
            // Determine if it should be income or expense based on amount sign
            let isIncome = transaction.amount > 0
            let noCategoryId: UUID
            
            if isIncome {
                noCategoryId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")! // No Category (Income)
            } else {
                noCategoryId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")! // No Category (Expense)
            }
            
            print("🔧 Converting to 'No Category' (\(isIncome ? "income" : "expense"))")
            
            // Create fixed transaction
            let fixedTransaction = Txn(
                txID: transaction.txID,
                accountID: transaction.accountID,
                walletID: transaction.walletID,
                category: "No Category",
                categoryId: noCategoryId,
                amount: transaction.amount,
                date: transaction.date,
                createdAt: transaction.createdAt,
                receiptImage: transaction.receiptImage,
                hasReceiptImage: transaction.hasReceiptImage,
                merchantName: transaction.merchantName,
                paymentMethod: transaction.paymentMethod,
                receiptNumber: transaction.receiptNumber,
                invoiceNumber: transaction.invoiceNumber,
                items: transaction.items,
                note: transaction.note,
                originalAmount: transaction.originalAmount,
                originalCurrency: transaction.originalCurrency,
                primaryCurrency: transaction.primaryCurrency,
                secondaryCurrency: transaction.secondaryCurrency,
                exchangeRate: transaction.exchangeRate,
                secondaryAmount: transaction.secondaryAmount,
                secondaryExchangeRate: transaction.secondaryExchangeRate
            )
            
            // Update in UserManager
            let userManager = UserManager.shared
            userManager.updateTransaction(fixedTransaction)
            
            // Update local state
            transactionState.updateTransaction(fixedTransaction)
            
            print("🔧 ✅ Transaction fixed and updated")
        } else {
            print("🔧 ✅ Transaction is valid, no fix needed")
        }
    }
    
    // Helper function for horizontal detail rows - New 16px layout
    private func horizontalDetailRow(title: String, value: String, secondaryValue: String? = nil) -> some View {
        HStack {
            // Title/Label on the left
            Text(title)
                .font(AppFonts.overusedGroteskMedium(size: 16))
                .foregroundColor(AppColors.foregroundSecondary)
            
            Spacer()
            
            // Value on the right
            HStack(spacing: 8) {
                Text(value)
                    .font(AppFonts.overusedGroteskMedium(size: 16))
                    .foregroundColor(.primary)
                
                if let secondaryValue = secondaryValue {
                    Text(secondaryValue)
                        .font(AppFonts.overusedGroteskMedium(size: 16))
                        .foregroundColor(AppColors.foregroundSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // Helper function to format currency with commas and smart decimal places
    private func formatCurrencyAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.0f", amount)
    }
    
    // Helper functions for robust note handling
    private func isEmptyNote(_ note: String?) -> Bool {
        guard let note = note else { return true }
        return note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func displayNote(_ note: String?) -> String {
        guard let note = note else { 
            print("🔍 displayNote: note is nil, returning '-'")
            return "-" 
        }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = trimmed.isEmpty ? "-" : trimmed
        print("🔍 displayNote: note='\(note)', trimmed='\(trimmed)', result='\(result)'")
        return result
    }
}
