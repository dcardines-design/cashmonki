//
//  AddTransactionSheet.swift
//  Cashooya Playground
//
//  Created by Dante Cardines III on 9/5/25.
//

import SwiftUI

struct AddTransactionSheet: View {
    @Binding var isPresented: Bool
    let primaryCurrency: Currency
    var onSave: (Txn) -> Void

    @State private var amountText: String = ""
    @State private var merchantName: String = ""
    @State private var note: String = ""
    @State private var selectedCategoryId: UUID?
    @State private var selectedCurrency: Currency
    @State private var date: Date = Date()
    @State private var showingCurrencyPicker = false
    @FocusState private var isAmountFocused: Bool
    @FocusState private var isMerchantFocused: Bool
    @FocusState private var isNoteFocused: Bool
    @ObservedObject private var categoriesManager = CategoriesManager.shared
    @ObservedObject private var rateManager = CurrencyRateManager.shared
    
    init(
        isPresented: Binding<Bool>,
        primaryCurrency: Currency,
        prefillAmount: String? = nil,
        prefillMerchant: String? = nil,
        prefillNote: String? = nil,
        prefillCategoryId: UUID? = nil,
        prefillDate: Date? = nil,
        prefillCurrency: Currency? = nil,
        onSave: @escaping (Txn) -> Void
    ) {
        self._isPresented = isPresented
        self.primaryCurrency = primaryCurrency
        self.onSave = onSave
        self._selectedCurrency = State(initialValue: prefillCurrency ?? primaryCurrency)
        self._amountText = State(initialValue: prefillAmount ?? "")
        self._merchantName = State(initialValue: prefillMerchant ?? "")
        self._note = State(initialValue: prefillNote ?? "")
        self._selectedCategoryId = State(initialValue: prefillCategoryId)
        self._date = State(initialValue: prefillDate ?? Date())
    }

    // Computed property to get category name for display
    private var selectedCategoryName: String {
        guard let categoryId = selectedCategoryId else { return "" }
        let result = categoriesManager.findCategoryOrSubcategoryById(categoryId)
        return result?.category?.name ?? result?.subcategory?.name ?? ""
    }
    
    var canSave: Bool {
        !amountText.isEmpty && selectedCategoryId != nil && Double(amountText.replacingOccurrences(of: ",", with: "")) != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            SheetHeader.basic(
                title: "Add Transaction",
                onBackTap: { isPresented = false }
            )
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Amount Field
                    AppInputField.amount(text: $amountText, selectedCurrency: Binding(
                        get: { selectedCurrency.rawValue },
                        set: { _ in }
                    ), onCurrencyTap: {
                        showingCurrencyPicker = true
                    }, size: .md, focusBinding: $isAmountFocused)

                    // Category Field
                    AppInputField.categoryById(selectedCategoryId: $selectedCategoryId, size: .md)

                    // Category Suggestions (recent/frequent)
                    CategorySuggestionChips(selectedCategoryId: $selectedCategoryId)
                        .padding(.top, -12)

                    // Date Field with Time
                    AppInputField.date(title: "Date", dateValue: $date, components: [.date, .hourAndMinute], size: .md, maxDate: Date())

                    // Merchant Name Field
                    AppInputField.text(
                        title: "Merchant (optional)",
                        text: $merchantName,
                        placeholder: "Enter merchant name",
                        isRequired: false,
                        size: .md,
                        focusBinding: $isMerchantFocused
                    )

                    // Note Field
                    AppInputField.text(
                        title: "Note (optional)",
                        text: $note,
                        placeholder: "Add context or description",
                        isRequired: false,
                        size: .md,
                        focusBinding: $isNoteFocused
                    )

                    Spacer()
                        .frame(height: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            
            // Fixed bottom group
            FixedBottomGroup.primary(
                title: "Save",
                action: save,
                isEnabled: canSave
            )
        }
        .background(AppColors.backgroundWhite)
        .onAppear {
            // Auto-focus amount input when sheet appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isAmountFocused = true
            }
        }
        .sheet(isPresented: $showingCurrencyPicker) {
            CurrencyPickerSheet(
                primaryCurrency: $selectedCurrency,
                isPresented: $showingCurrencyPicker
            )
            .presentationDetents([.fraction(0.98)])
            .presentationCornerRadius(20)
            .presentationDragIndicator(.hidden)
        }
    }
    
    private func save() {
        print("🚀 AddTransactionSheet: SAVE STARTED")
        print("📊 AddTransactionSheet: Input values:")
        print("   - amountText: '\(amountText)'")
        print("   - merchantName: '\(merchantName)'")
        print("   - note: '\(note)'")
        print("   - selectedCategoryId: \(selectedCategoryId?.uuidString.prefix(8) ?? "nil")")
        print("   - date: \(date)")
        print("   - canSave: \(canSave)")
        
        // Remove commas before converting to Double
        let cleanAmount = amountText.replacingOccurrences(of: ",", with: "")
        print("💰 AddTransactionSheet: cleanAmount = '\(cleanAmount)'")
        
        guard let amount = Double(cleanAmount) else { 
            print("❌ AddTransactionSheet: FAILED - Cannot convert '\(cleanAmount)' to Double")
            return 
        }
        print("✅ AddTransactionSheet: Successfully parsed amount = \(amount)")
        
        // Robust note handling
        let finalNote: String? = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalMerchantName: String? = merchantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Determine category info and whether it's income or expense
        let categoryName: String
        let categoryId: UUID?
        let isIncome: Bool
        
        if let selectedId = selectedCategoryId {
            // Use selected category
            categoryId = selectedId
            
            // Use ID-based lookup to get category info
            if let categoryResult = categoriesManager.findCategoryOrSubcategoryById(selectedId) {
                print("🔍 AddTransactionSheet: ID-based lookup for categoryId '\(selectedId.uuidString.prefix(8))':")
                
                if let category = categoryResult.category {
                    // It's a top-level category
                    categoryName = category.name
                    isIncome = category.type == .income
                    print("   - Found category: '\(category.name)' (type: \(category.type))")
                } else if let subcategory = categoryResult.subcategory, let parent = categoryResult.parent {
                    // It's a subcategory - use subcategory's own type, not parent's
                    categoryName = subcategory.name
                    isIncome = subcategory.type == .income
                    print("   - Found subcategory: '\(subcategory.name)' under '\(parent.name)' (subcategory type: \(subcategory.type), parent type: \(parent.type))")
                } else {
                    print("⚠️ AddTransactionSheet: Invalid category result structure")
                    return
                }
            } else {
                print("⚠️ AddTransactionSheet: Category with ID '\(selectedId.uuidString.prefix(8))' not found")
                return
            }
        } else {
            // No category selected - use predefined "No Category" expense UUID
            print("🔍 AddTransactionSheet: No category selected, defaulting to expense")
            categoryId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")! // No Category (Expense)
            categoryName = "No Category"
            isIncome = false
        }
        
        // Use the date selected by the user in the date picker
        let currentTimestamp = date
        print("📅 ✅ TIMESTAMP: Using date from date picker - \(currentTimestamp)")
        print("📅 ✅ TIMESTAMP ISO: \(ISO8601DateFormatter().string(from: currentTimestamp))")
        
        // Get current account ID from AccountManager
        let currentAccountId = AccountManager.shared.selectedSubAccountId ?? UserManager.shared.currentUser.defaultSubAccount?.id
        print("🏦 AddTransactionSheet: Using account ID: \(currentAccountId?.uuidString.prefix(8) ?? "nil")")
        print("💱 AddTransactionSheet: Using selected currency: \(selectedCurrency.rawValue) (\(selectedCurrency.displayName))")
        
        // Create transaction with automatic currency conversion and correct sign
        let baseTransaction = rateManager.createTransaction(
            accountID: UserManager.shared.currentUser.id,
            walletID: currentAccountId,
            category: categoryName,
            categoryId: categoryId,
            originalAmount: amount,
            originalCurrency: selectedCurrency,
            date: currentTimestamp,
            merchantName: finalMerchantName,
            note: finalNote,
            isIncome: isIncome
        )

        // Create final transaction with recurring fields if enabled
        let transaction = Txn(
            txID: baseTransaction.txID,
            accountID: baseTransaction.accountID,
            walletID: baseTransaction.walletID,
            category: baseTransaction.category,
            categoryId: baseTransaction.categoryId,
            amount: baseTransaction.amount,
            date: baseTransaction.date,
            createdAt: baseTransaction.createdAt,
            receiptImage: nil,
            hasReceiptImage: baseTransaction.hasReceiptImage,
            merchantName: baseTransaction.merchantName,
            paymentMethod: baseTransaction.paymentMethod,
            receiptNumber: baseTransaction.receiptNumber,
            invoiceNumber: baseTransaction.invoiceNumber,
            items: baseTransaction.items,
            note: baseTransaction.note,
            originalAmount: baseTransaction.originalAmount,
            originalCurrency: baseTransaction.originalCurrency,
            primaryCurrency: baseTransaction.primaryCurrency,
            secondaryCurrency: baseTransaction.secondaryCurrency,
            exchangeRate: baseTransaction.exchangeRate,
            secondaryAmount: baseTransaction.secondaryAmount,
            secondaryExchangeRate: baseTransaction.secondaryExchangeRate,
            userEnteredAmount: baseTransaction.userEnteredAmount,
            userEnteredCurrency: baseTransaction.userEnteredCurrency,
            // Recurring fields - always false for manual transactions
            isRecurring: false,
            recurringFrequency: nil,
            recurringTemplateId: nil,
            lastGeneratedDate: nil,
            isRecurringActive: false
        )

        print("🏗️ AddTransactionSheet: Created transaction:")
        print("   - id: \(transaction.id.uuidString.prefix(8))")
        print("   - category: '\(transaction.category)'")
        print("   - categoryId: \(transaction.categoryId?.uuidString.prefix(8) ?? "nil")")
        print("   - amount: \(transaction.amount)")
        print("   - primaryCurrency: \(transaction.primaryCurrency.rawValue) (\(transaction.primaryCurrency.displayName))")
        print("   - date: \(transaction.date)")
        print("   - merchantName: '\(transaction.merchantName ?? "nil")'")
        print("   - note: '\(transaction.note ?? "nil")'")
        print("   - walletID: \(transaction.walletID?.uuidString.prefix(8) ?? "nil")")
        
        print("📤 AddTransactionSheet: Calling onSave callback...")
        onSave(transaction)
        print("✅ AddTransactionSheet: onSave callback completed")

        // Cancel today's reminder since user tracked
        NotificationManager.shared.onTransactionAdded()

        // Track transaction creation
        AnalyticsManager.shared.trackTransactionCreated(
            amount: abs(transaction.amount),
            currency: transaction.primaryCurrency.rawValue,
            category: categoryName,
            isIncome: isIncome
        )

        print("🔄 AddTransactionSheet: Dismissing sheet...")
        isPresented = false
        print("✅ AddTransactionSheet: SAVE COMPLETED SUCCESSFULLY")
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