//
//  EditTransactionSheet.swift
//  Cashooya Playground
//
//  Created by Claude on 9/7/25.
//

import SwiftUI

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct EditTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var toastManager: ToastManager
    @State private var transaction: Txn
    let onTransactionUpdate: ((Txn) -> Void)?
    let onTransactionDelete: ((Txn) -> Void)?
    let onDismiss: (() -> Void)?
    
    // Form fields
    @State private var amount: String
    @State private var merchant: String
    @State private var selectedDate: Date
    @State private var selectedCategoryId: UUID?
    @State private var selectedCurrency: Currency
    @State private var note: String
    @State private var showingCurrencyPicker = false
    @State private var showingDeleteAlert = false
    @FocusState private var isAmountFocused: Bool
    @FocusState private var isMerchantFocused: Bool
    @FocusState private var isNoteFocused: Bool
    
    @ObservedObject private var categoriesManager = CategoriesManager.shared
    @ObservedObject private var rateManager = CurrencyRateManager.shared
    
    // Smart decimal formatting - hides .00, shows .01 when needed
    static func formatAmountForInput(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0  // Hide .00
        formatter.maximumFractionDigits = 2  // Show up to .01
        formatter.groupingSeparator = ","
        formatter.numberStyle = .decimal
        
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.0f", amount)
    }
    
    init(transaction: Txn, onTransactionUpdate: ((Txn) -> Void)? = nil, onTransactionDelete: ((Txn) -> Void)? = nil, onDismiss: (() -> Void)? = nil) {
        print("🐛 EditTransactionSheet INIT - transaction.id: \(transaction.id)")
        print("🐛 EditTransactionSheet INIT - transaction.note: '\(transaction.note ?? "nil")'")
        print("🐛 EditTransactionSheet INIT - initializing note field with: '\(transaction.note ?? "")'")
        
        self.transaction = transaction
        self.onTransactionUpdate = onTransactionUpdate
        self.onTransactionDelete = onTransactionDelete
        self.onDismiss = onDismiss
        // ACTUAL AMOUNT ARCHITECTURE: Always edit the original amount (source of truth)
        let displayAmount: Double
        let displayCurrency: Currency
        
        if let originalAmount = transaction.originalAmount, let originalCurrency = transaction.originalCurrency {
            // ✅ ACTUAL AMOUNT: Use original values (source of truth)
            displayAmount = abs(originalAmount)
            displayCurrency = originalCurrency
            print("✅ EditTransactionSheet INIT - Editing ACTUAL amount: \(displayAmount) \(originalCurrency.rawValue)")
        } else {
            // Fallback: No original amount stored, use transaction amount as actual
            // This handles legacy transactions that may not have originalAmount
            displayAmount = abs(transaction.amount)
            displayCurrency = transaction.primaryCurrency
            print("⚠️ EditTransactionSheet INIT - No ACTUAL amount found, using transaction amount: \(displayAmount) \(transaction.primaryCurrency.rawValue)")
        }
        
        self._amount = State(initialValue: Self.formatAmountForInput(displayAmount))
        self._merchant = State(initialValue: transaction.merchantName ?? "")
        self._selectedDate = State(initialValue: transaction.date)
        self._selectedCategoryId = State(initialValue: transaction.categoryId)
        self._selectedCurrency = State(initialValue: displayCurrency)
        self._note = State(initialValue: transaction.note ?? "")
        
        print("🐛 EditTransactionSheet INIT - note field initialized with: '\(transaction.note ?? "")'")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            SheetHeader.withCustomAction(
                title: "Edit Transaction",
                onBackTap: { 
                    saveCategoryOnly()
                },
                rightIcon: "trash-04",
                rightSystemIcon: "trash",
                onRightTap: {
                    showingDeleteAlert = true
                }
            )
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Amount field using AppInputField
                    AppInputField.amount(text: $amount, selectedCurrency: Binding(
                        get: { selectedCurrency.rawValue },
                        set: { _ in }
                    ), onCurrencyTap: {
                        showingCurrencyPicker = true
                    }, size: .md, focusBinding: $isAmountFocused)

                    // Category field using AppInputField
                    AppInputField.categoryById(
                        selectedCategoryId: $selectedCategoryId,
                        size: .md,
                        transactionAmount: Double(amount.replacingOccurrences(of: ",", with: "")) ?? 0
                    )

                    // Date field with Time using AppInputField
                    AppInputField.date(title: "Date", dateValue: $selectedDate, components: [.date, .hourAndMinute], size: .md)

                    // Merchant field
                    AppInputField.merchant(text: $merchant, size: .md, focusBinding: $isMerchantFocused)
                    
                    // Note field
                    AppInputField.text(title: "Note", text: $note, placeholder: "Add note...", size: .md, focusBinding: $isNoteFocused)
                    
                    Spacer()
                        .frame(height: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            
            // Fixed bottom group
            FixedBottomGroup.primary(
                title: "Save",
                action: saveTransaction,
                isEnabled: true
            )
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
        .appAlert(
            title: "Delete Transaction",
            isPresented: $showingDeleteAlert,
            message: "Are you sure you want to delete this transaction? This action cannot be undone.",
            primaryAction: .destructive("Delete") {
                deleteTransaction()
            }
        )
    }
    
    // COMMENTED OUT: Unused secondary amount field (convertedAmount computed property)
    /*
    // Computed property for converted amount
    private var convertedAmount: String {
        guard let amountValue = Double(amount) else { return "0" }
        let converted = amountValue * exchangeRate
        return String(format: "%.0f", converted)
    }
    
    // Mock exchange rate - replace with actual conversion
    private var exchangeRate: Double {
        switch selectedCurrency {
        case .usd: return 56.0 // 1 USD = 56 PHP
        case .php: return 1.0
        default: return 56.0
        }
    }
    */
    
    
    private func saveCategoryOnly() {
        print("🔥 SAVE CATEGORY ONLY - Function called")
        print("🔥 SAVE CATEGORY ONLY - selectedCategoryId: '\(selectedCategoryId?.uuidString.prefix(8) ?? "nil")'")
        
        // Save only the category change, keeping all other fields unchanged
        let updatedTransaction: Txn
        
        // Get category info from the selected category ID
        if let selectedId = selectedCategoryId {
            let categoryName: String
            let finalAmount: Double
            
            // Use ID-based lookup to get category info
            if let categoryResult = categoriesManager.findCategoryOrSubcategoryById(selectedId) {
                print("🔍 EditTransactionSheet (saveCategoryOnly): ID-based lookup for categoryId '\(selectedId.uuidString.prefix(8))':")
                
                if let category = categoryResult.category {
                    // It's a top-level category
                    categoryName = category.name
                    finalAmount = category.type == .income ? abs(transaction.amount) : -abs(transaction.amount)
                    print("   - Found category: '\(category.name)' (type: \(category.type))")
                } else if let subcategory = categoryResult.subcategory, let parent = categoryResult.parent {
                    // It's a subcategory - use subcategory's own type, not parent's
                    categoryName = subcategory.name
                    finalAmount = subcategory.type == .income ? abs(transaction.amount) : -abs(transaction.amount)
                    print("   - Found subcategory: '\(subcategory.name)' under '\(parent.name)' (subcategory type: \(subcategory.type), parent type: \(parent.type))")
                } else {
                    print("⚠️ EditTransactionSheet: Invalid category result structure")
                    if let onDismiss = onDismiss {
                        onDismiss()
                    } else {
                        dismiss()
                    }
                    return
                }
                print("   - Final amount: \(finalAmount)")
            } else {
                print("⚠️ EditTransactionSheet: Category with ID '\(selectedId.uuidString.prefix(8))' not found")
                if let onDismiss = onDismiss {
                    onDismiss()
                } else {
                    dismiss()
                }
                return
            }
            
            // Create updated transaction with only category changed
            updatedTransaction = Txn(
                txID: transaction.txID,
                accountID: transaction.accountID,
                walletID: transaction.walletID,
                category: categoryName,
                categoryId: selectedId,
                amount: finalAmount,
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
                secondaryExchangeRate: transaction.secondaryExchangeRate,
                userEnteredAmount: transaction.userEnteredAmount, // Keep existing user entry
                userEnteredCurrency: transaction.userEnteredCurrency // Keep existing user entry currency
            )
            
            print("🔍 EditTransactionSheet (saveCategoryOnly): Saving category change - '\(categoryName)' with amount \(finalAmount)")
            print("🔥 SAVE CATEGORY ONLY - About to call onTransactionUpdate callback")
            onTransactionUpdate?(updatedTransaction)
            print("🔥 SAVE CATEGORY ONLY - Callback called, about to dismiss")
        } else {
            print("🔥 SAVE CATEGORY ONLY - No selectedCategoryId, dismissing without save")
        }
        
        // Dismiss the sheet
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }
    
    private func saveTransaction() {
        print("🔥 SAVE TRANSACTION - Function called")
        print("🔥 SAVE TRANSACTION - selectedCategoryId: '\(selectedCategoryId?.uuidString.prefix(8) ?? "nil")'")
        print("🔥 SAVE TRANSACTION - Original date: \(transaction.date)")
        print("🔥 SAVE TRANSACTION - Selected date: \(selectedDate)")
        
        // ENHANCED AMOUNT DEBUGGING - Track amount changes
        print("💰 SAVE TRANSACTION - AMOUNT DEBUGGING:")
        print("💰   - Original transaction amount: \(transaction.amount)")
        print("💰   - Amount field text: '\(amount)'")
        
        // Update transaction with new values - remove commas before converting to Double
        let cleanAmount = amount.replacingOccurrences(of: ",", with: "")
        print("💰   - Clean amount (no commas): '\(cleanAmount)'")
        
        guard let amountValue = Double(cleanAmount) else { 
            print("❌ SAVE TRANSACTION - Invalid amount '\(cleanAmount)', cannot convert to Double, returning")
            return 
        }
        
        print("💰   - Parsed amount value: \(amountValue)")
        
        // Debug: Print note value before saving
        print("🐛 SAVE - EditTransactionSheet note field value: '\(note)'")
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        print("🐛 SAVE - Trimmed note: '\(trimmedNote)', isEmpty: \(trimmedNote.isEmpty)")
        
        // More robust empty check - handle empty strings, whitespace, and nil
        let finalNote: String? = trimmedNote.isEmpty ? nil : trimmedNote
        let finalMerchantName: String? = merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        print("🐛 SAVE - Final note value: '\(finalNote ?? "nil")'")
        print("🐛 SAVE - Final merchant value: '\(finalMerchantName ?? "nil")'")
        
        let updatedTransaction: Txn
        
        // Calculate secondary currency conversions (only if secondary currency is set)
        let secondaryCurrency = CurrencyPreferences.shared.secondaryCurrency
        let secondaryAmount: Double?
        let secondaryExchangeRate: Double?
        
        if let secondary = secondaryCurrency {
            secondaryAmount = rateManager.convertAmount(abs(amountValue), from: selectedCurrency, to: secondary)
            secondaryExchangeRate = rateManager.convertAmount(1.0, from: transaction.primaryCurrency, to: secondary)
        } else {
            secondaryAmount = nil
            secondaryExchangeRate = nil
        }
        
        // ACTUAL vs CONVERTED AMOUNT ARCHITECTURE:
        // ACTUAL AMOUNT = what user enters (amountValue in selectedCurrency)  
        // CONVERTED AMOUNT = ACTUAL converted to primary currency (stored in amount field)
        
        // Calculate CONVERTED AMOUNT from ACTUAL AMOUNT
        let convertedAmount: Double
        let exchangeRateUsed: Double
        
        if selectedCurrency == transaction.primaryCurrency {
            // Same currency - no conversion needed but still calculate for consistency
            convertedAmount = amountValue
            exchangeRateUsed = 1.0
            print("💰 SAVE TRANSACTION - Same currency: ACTUAL \(amountValue) \(selectedCurrency.rawValue) = CONVERTED \(convertedAmount) \(transaction.primaryCurrency.rawValue)")
        } else {
            // Different currency - convert ACTUAL to CONVERTED
            exchangeRateUsed = rateManager.convertAmount(1.0, from: selectedCurrency, to: transaction.primaryCurrency)
            convertedAmount = amountValue * exchangeRateUsed
            print("💰 SAVE TRANSACTION - Currency conversion: ACTUAL \(amountValue) \(selectedCurrency.rawValue) → CONVERTED \(convertedAmount) \(transaction.primaryCurrency.rawValue) (rate: \(exchangeRateUsed))")
        }
        
        // Determine final converted amount sign based on selected category type
        let finalConvertedAmount: Double
        let categoryName: String
        let categoryId: UUID?
            
            if let selectedId = selectedCategoryId {
                // Use ID-based lookup to get category info
                if let categoryResult = categoriesManager.findCategoryOrSubcategoryById(selectedId) {
                    print("🔍 EditTransactionSheet: ID-based lookup for categoryId '\(selectedId.uuidString.prefix(8))':")
                    
                    // Use selected category
                    categoryId = selectedId
                    
                    if let category = categoryResult.category {
                        // It's a top-level category
                        categoryName = category.name
                        finalConvertedAmount = category.type == .income ? abs(convertedAmount) : -abs(convertedAmount)
                        print("   - Found category: '\(category.name)' (type: \(category.type))")
                    } else if let subcategory = categoryResult.subcategory, let parent = categoryResult.parent {
                        // It's a subcategory - use subcategory's own type, not parent's
                        categoryName = subcategory.name
                        finalConvertedAmount = subcategory.type == .income ? abs(convertedAmount) : -abs(convertedAmount)
                        print("   - Found subcategory: '\(subcategory.name)' under '\(parent.name)' (subcategory type: \(subcategory.type), parent type: \(parent.type))")
                    } else {
                        print("⚠️ EditTransactionSheet: Invalid category result structure")
                        return
                    }
                    print("   - Final converted amount: \(finalConvertedAmount)")
                } else {
                    print("⚠️ EditTransactionSheet: Category with ID '\(selectedId.uuidString.prefix(8))' not found")
                    print("🔧 FALLBACK: Converting to 'No Category' due to invalid category ID")
                    
                    // Fallback to "No Category" with appropriate type based on original transaction
                    let isIncome = transaction.amount > 0
                    categoryId = isIncome ? 
                        UUID(uuidString: "00000000-0000-0000-0000-000000000001")! : // No Category (Income)
                        UUID(uuidString: "00000000-0000-0000-0000-000000000002")!   // No Category (Expense)
                    categoryName = "No Category"
                    finalConvertedAmount = isIncome ? abs(convertedAmount) : -abs(convertedAmount)
                    print("🔧 FALLBACK: Using 'No Category' (\(isIncome ? "income" : "expense")) with converted amount \(finalConvertedAmount)")
                }
            } else {
                // No category selected - use predefined "No Category" UUIDs based on original transaction type
                print("🔍 EditTransactionSheet: No category selected, determining from original amount")
                
                if transaction.amount >= 0 {
                    // Original was income, keep as income
                    categoryId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")! // No Category (Income)
                    categoryName = "No Category"
                    finalConvertedAmount = abs(convertedAmount)
                    print("   - No category selected, assigning as income: \(finalConvertedAmount)")
                } else {
                    // Original was expense, keep as expense  
                    categoryId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")! // No Category (Expense)
                    categoryName = "No Category"
                    finalConvertedAmount = -abs(convertedAmount)
                    print("   - No category selected, assigning as expense: \(finalConvertedAmount)")
                }
            }
            
            // ENHANCED DEBUGGING - Track final amounts before creating transaction
            print("💰 SAVE TRANSACTION - FINAL AMOUNT CALCULATIONS:")
            print("💰   - ACTUAL amount: \(amountValue) \(selectedCurrency.rawValue)")
            print("💰   - CONVERTED amount (with sign): \(finalConvertedAmount) \(transaction.primaryCurrency.rawValue)")
            print("💰   - Amount change: \(transaction.amount) → \(finalConvertedAmount)")
            
            updatedTransaction = Txn(
                txID: transaction.txID,
                accountID: transaction.accountID,
                walletID: transaction.walletID,
                category: categoryName,
                categoryId: categoryId,
                amount: finalConvertedAmount, // ✅ CONVERTED AMOUNT: In primary currency
                date: selectedDate,
                createdAt: transaction.createdAt,
                receiptImage: transaction.receiptImage,
                hasReceiptImage: transaction.hasReceiptImage,
                merchantName: finalMerchantName,
                paymentMethod: transaction.paymentMethod,
                receiptNumber: transaction.receiptNumber,
                invoiceNumber: transaction.invoiceNumber,
                items: transaction.items,
                note: finalNote,
                originalAmount: abs(amountValue), // ✅ ACTUAL AMOUNT: What user edited (source of truth)
                originalCurrency: selectedCurrency, // ✅ ACTUAL CURRENCY: Currency user was working in
                primaryCurrency: transaction.primaryCurrency, // Keep user's primary currency
                secondaryCurrency: secondaryCurrency,
                exchangeRate: exchangeRateUsed, // Rate used for ACTUAL → CONVERTED conversion
                secondaryAmount: secondaryAmount,
                secondaryExchangeRate: secondaryExchangeRate,
                userEnteredAmount: abs(amountValue), // Keep for backward compatibility
                userEnteredCurrency: selectedCurrency // Keep for backward compatibility
            )
        
        // Call the update callback
        print("🔥 SAVE TRANSACTION - About to call onTransactionUpdate callback")
        print("🔥 SAVE TRANSACTION - Final category: '\(updatedTransaction.category)'")
        print("🔥 SAVE TRANSACTION - Final categoryId: '\(updatedTransaction.categoryId?.uuidString.prefix(8) ?? "nil")'")
        print("🔥 SAVE TRANSACTION - Final amount: \(updatedTransaction.amount)")
        print("🔥 SAVE TRANSACTION - Final date: \(updatedTransaction.date)")
        print("🔥 SAVE TRANSACTION - Final note: '\(updatedTransaction.note ?? "nil")'")
        print("🔥 SAVE TRANSACTION - Transaction ID: \(updatedTransaction.id)")
        onTransactionUpdate?(updatedTransaction)
        print("🔥 SAVE TRANSACTION - Callback called, about to dismiss")

        // Show changes saved toast
        toastManager.showChangesSaved()

        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }
    
    private func deleteTransaction() {
        // Call the delete callback - parent will handle closing sheets and showing toast
        onTransactionDelete?(transaction)
        
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }
    
    private func getExchangeRate(from: Currency, to: Currency) -> Double {
        // Mock exchange rates - in a real app, this would fetch from an API
        switch (from, to) {
        case (.usd, .php): return 56.0  // 1 USD = 56 PHP
        case (.php, .usd): return 1.0/56.0  // 1 PHP = 0.0179 USD
        case (.eur, .php): return 61.0  // 1 EUR = 61 PHP
        case (.php, .eur): return 1.0/61.0  // 1 PHP = 0.0164 EUR
        case (.usd, .eur): return 0.92  // 1 USD = 0.92 EUR
        case (.eur, .usd): return 1.09  // 1 EUR = 1.09 USD
        default: return 1.0  // Same currency or unsupported conversion
        }
    }
    
}

// MARK: - Preview

struct EditTransactionSheet_Previews: PreviewProvider {
    static var previews: some View {
        EditTransactionSheet(
            transaction: DummyDataGenerator.generateRandom().first!,
            onTransactionUpdate: { _ in
                // Preview update callback
            },
            onTransactionDelete: { _ in
                // Preview delete callback
            }
        )
    }
}