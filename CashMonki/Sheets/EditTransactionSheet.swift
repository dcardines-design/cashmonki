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
    // Recurring transaction state
    @State private var isRecurring: Bool
    @State private var recurringFrequency: RecurringFrequency
    @State private var showingFrequencyPicker: Bool = false
    // Recurring confirmation dialogs
    @State private var showingRecurringEditConfirmation = false
    @State private var showingRecurringDeleteConfirmation = false
    @State private var pendingUpdatedTransaction: Txn?
    @FocusState private var isAmountFocused: Bool
    @FocusState private var isMerchantFocused: Bool
    @FocusState private var isNoteFocused: Bool
    
    @ObservedObject private var categoriesManager = CategoriesManager.shared
    @ObservedObject private var rateManager = CurrencyRateManager.shared
    @ObservedObject private var recurringManager = RecurringTransactionManager.shared

    // MARK: - Recurring Transaction Type Detection

    /// Check if this transaction is a recurring template (parent)
    private var isRecurringTemplate: Bool {
        recurringManager.isTemplate(transaction)
    }

    /// Check if this transaction is a generated child of a recurring template
    private var isGeneratedChild: Bool {
        recurringManager.isGeneratedChild(transaction)
    }
    
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

        // Initialize recurring state from transaction
        // For generated children, check if they have a parent template (recurringTemplateId != nil)
        let recurringManager = RecurringTransactionManager.shared
        let isTemplate = recurringManager.isTemplate(transaction)
        let isChild = recurringManager.isGeneratedChild(transaction)

        // Toggle should show ON for both templates and generated children
        self._isRecurring = State(initialValue: isTemplate || isChild)

        // Get frequency from transaction or parent template
        var frequency: RecurringFrequency = .monthly
        if let txFrequency = transaction.recurringFrequency {
            frequency = txFrequency
        } else if isChild, let parentTemplate = recurringManager.getParentTemplate(for: transaction.id) {
            frequency = parentTemplate.recurringFrequency ?? .monthly
        }
        self._recurringFrequency = State(initialValue: frequency)

        print("🐛 EditTransactionSheet INIT - note field initialized with: '\(transaction.note ?? "")'")
        print("🐛 EditTransactionSheet INIT - isTemplate: \(isTemplate), isChild: \(isChild)")
        print("🐛 EditTransactionSheet INIT - isRecurring toggle: \(isTemplate || isChild), frequency: \(frequency.displayName)")
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

                    // Category Suggestions (recent/frequent)
                    CategorySuggestionChips(selectedCategoryId: $selectedCategoryId)
                        .padding(.top, -12)

                    // Date field with Time using AppInputField
                    AppInputField.date(title: "Date", dateValue: $selectedDate, components: [.date, .hourAndMinute], size: .md, maxDate: Date())

                    // Merchant field
                    AppInputField.text(
                        title: "Merchant (optional)",
                        text: $merchant,
                        placeholder: "Enter merchant name",
                        isRequired: false,
                        size: .md,
                        focusBinding: $isMerchantFocused
                    )

                    // Note field
                    AppInputField.text(
                        title: "Note (optional)",
                        text: $note,
                        placeholder: "Add context or description",
                        isRequired: false,
                        size: .md,
                        focusBinding: $isNoteFocused
                    )

                    // COMMENTED OUT FOR APP STORE SUBMISSION - TODO: Uncomment later
                    // Recurring Toggle Row
                    /*
                    HStack(spacing: 4) {
                        Text("This transaction repeats")
                            .font(AppFonts.overusedGroteskMedium(size: 16))
                            .foregroundColor(AppColors.foregroundPrimary)

                        Button(action: { showingFrequencyPicker = true }) {
                            Text(recurringFrequency.displayName)
                                .font(AppFonts.overusedGroteskMedium(size: 16))
                                .foregroundColor(AppColors.accentBackground)
                        }

                        Spacer()

                        Toggle("", isOn: $isRecurring)
                            .toggleStyle(SwitchToggleStyle(tint: AppColors.accentBackground))
                            .labelsHidden()
                    }
                    .padding(.vertical, 4)
                    */

                    Spacer()
                        .frame(height: 20)
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
            .presentationCornerRadius(20)
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showingFrequencyPicker) {
            RecurringFrequencyPickerSheet(
                isPresented: $showingFrequencyPicker,
                selectedFrequency: $recurringFrequency
            )
            .presentationDetents([.height(520)])
            .presentationCornerRadius(20)
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
        .confirmationDialog("Apply changes to", isPresented: $showingRecurringEditConfirmation, titleVisibility: .visible) {
            Button("This only") {
                handleRecurringEditOption(.thisOnly)
            }
            Button("Future ones") {
                handleRecurringEditOption(.allFuture)
            }
            Button("All of them") {
                handleRecurringEditOption(.allPastAndFuture)
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            isRecurringTemplate ? "Delete subscription?" : "Delete this transaction?",
            isPresented: $showingRecurringDeleteConfirmation,
            titleVisibility: .visible
        ) {
            if isRecurringTemplate {
                Button("Stop repeating") {
                    handleRecurringDeleteTemplateOption(.subscriptionOnly)
                }
                Button("Delete all", role: .destructive) {
                    handleRecurringDeleteTemplateOption(.allOccurrences)
                }
            } else {
                Button("Delete this only") {
                    handleRecurringDeleteChildOption(.thisOnly)
                }
                Button("Stop all future", role: .destructive) {
                    handleRecurringDeleteChildOption(.stopAllFuture)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
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
                userEnteredCurrency: transaction.userEnteredCurrency, // Keep existing user entry currency
                // Preserve recurring fields from original transaction
                isRecurring: transaction.isRecurring,
                recurringFrequency: transaction.recurringFrequency,
                recurringTemplateId: transaction.recurringTemplateId,
                lastGeneratedDate: transaction.lastGeneratedDate,
                isRecurringActive: transaction.isRecurringActive,
                subscriptionId: transaction.subscriptionId // Preserve subscription link
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
                userEnteredCurrency: selectedCurrency, // Keep for backward compatibility
                // Recurring fields
                // If toggle is OFF for a generated child, unlink from parent (make standalone)
                isRecurring: isRecurring && !isGeneratedChild, // Only templates can be recurring
                recurringFrequency: (isRecurring && !isGeneratedChild) ? recurringFrequency : nil,
                recurringTemplateId: isRecurring ? transaction.recurringTemplateId : nil, // Remove link if toggled OFF
                lastGeneratedDate: transaction.lastGeneratedDate, // Preserve existing
                isRecurringActive: isRecurring && !isGeneratedChild, // Only templates can be active
                subscriptionId: transaction.subscriptionId // Preserve subscription link
            )

        // Track transaction edit
        AnalyticsManager.shared.track(.transactionEdited, properties: [
            "amount": abs(updatedTransaction.amount),
            "currency": updatedTransaction.primaryCurrency.rawValue,
            "category": updatedTransaction.category,
            "is_income": updatedTransaction.amount > 0,
            "has_note": updatedTransaction.note != nil && !updatedTransaction.note!.isEmpty
        ])

        // If editing a recurring template, show confirmation dialog
        if isRecurringTemplate {
            print("🔄 SAVE TRANSACTION - This is a recurring template, showing confirmation")
            pendingUpdatedTransaction = updatedTransaction
            showingRecurringEditConfirmation = true
            return
        }

        // For non-recurring or generated children, proceed normally
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

    // MARK: - Recurring Edit Confirmation Handler

    private func handleRecurringEditOption(_ option: RecurringEditOption) {
        guard let updatedTransaction = pendingUpdatedTransaction else {
            print("⚠️ handleRecurringEditOption - No pending transaction")
            return
        }

        switch option {
        case .thisOnly:
            // Just update the template, no children affected
            print("✏️ Recurring Edit - This only: updating template")
            onTransactionUpdate?(updatedTransaction)

        case .allFuture:
            // Update template + future children
            print("✏️ Recurring Edit - All future: updating template and future children")
            onTransactionUpdate?(updatedTransaction)
            recurringManager.updateFutureChildren(templateId: transaction.id) { child in
                createUpdatedChild(child, from: updatedTransaction)
            }

        case .allPastAndFuture:
            // Update template + all children
            print("✏️ Recurring Edit - All past & future: updating template and all children")
            onTransactionUpdate?(updatedTransaction)
            recurringManager.updateAllChildren(templateId: transaction.id) { child in
                createUpdatedChild(child, from: updatedTransaction)
            }
        }

        toastManager.showChangesSaved()

        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    /// Create an updated child transaction by applying template changes
    private func createUpdatedChild(_ child: Txn, from template: Txn) -> Txn {
        // Apply template changes (amount, category, merchant, note) but keep child-specific fields (date, id)
        return Txn(
            txID: child.txID,
            accountID: child.accountID,
            walletID: child.walletID,
            category: template.category,
            categoryId: template.categoryId,
            amount: template.amount,
            date: child.date,  // Keep child's date
            createdAt: child.createdAt,
            receiptImage: nil,
            hasReceiptImage: child.hasReceiptImage,
            merchantName: template.merchantName,
            paymentMethod: child.paymentMethod,
            receiptNumber: child.receiptNumber,
            invoiceNumber: child.invoiceNumber,
            items: child.items,
            note: template.note,
            originalAmount: template.originalAmount,
            originalCurrency: template.originalCurrency,
            primaryCurrency: child.primaryCurrency,
            secondaryCurrency: child.secondaryCurrency,
            exchangeRate: template.exchangeRate,
            secondaryAmount: template.secondaryAmount,
            secondaryExchangeRate: template.secondaryExchangeRate,
            userEnteredAmount: template.userEnteredAmount,
            userEnteredCurrency: template.userEnteredCurrency,
            isRecurring: false,
            recurringFrequency: nil,
            recurringTemplateId: child.recurringTemplateId,
            lastGeneratedDate: nil,
            isRecurringActive: false,
            subscriptionId: child.subscriptionId // Preserve subscription link
        )
    }

    private func deleteTransaction() {
        // If this is a recurring transaction (template or child), show confirmation
        if isRecurringTemplate || isGeneratedChild {
            print("🔄 DELETE TRANSACTION - This is a recurring transaction, showing confirmation")
            showingRecurringDeleteConfirmation = true
            return
        }

        // For non-recurring transactions, proceed with normal delete
        performDelete()
    }

    /// Actually perform the delete operation
    private func performDelete() {
        // Track transaction deletion
        AnalyticsManager.shared.track(.transactionDeleted, properties: [
            "amount": abs(transaction.amount),
            "currency": transaction.primaryCurrency.rawValue,
            "category": transaction.category,
            "is_income": transaction.amount > 0
        ])

        // Call the delete callback - parent will handle closing sheets and showing toast
        onTransactionDelete?(transaction)

        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    // MARK: - Recurring Delete Confirmation Handler

    private func handleRecurringDeleteTemplateOption(_ option: RecurringDeleteTemplateOption) {
        switch option {
        case .subscriptionOnly:
            // Delete template only, convert children to standalone
            print("🗑️ Recurring Delete Template - Subscription only")
            recurringManager.deleteTemplate(templateId: transaction.id, deleteChildren: false)

        case .allOccurrences:
            // Delete template and all children
            print("🗑️ Recurring Delete Template - All occurrences")
            recurringManager.deleteTemplate(templateId: transaction.id, deleteChildren: true)
        }

        // Notify parent and dismiss (no need to call onTransactionDelete as manager handles it)
        toastManager.showDeleted("Transaction deleted")

        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    private func handleRecurringDeleteChildOption(_ option: RecurringDeleteChildOption) {
        switch option {
        case .thisOnly:
            // Delete just this child
            print("🗑️ Recurring Delete Child - This only")
            recurringManager.deleteGeneratedChild(childId: transaction.id, stopFuture: false)

        case .stopAllFuture:
            // Delete child and deactivate parent
            print("🗑️ Recurring Delete Child - Stop all future")
            recurringManager.deleteGeneratedChild(childId: transaction.id, stopFuture: true)
        }

        // Notify parent and dismiss
        toastManager.showDeleted("Transaction deleted")

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