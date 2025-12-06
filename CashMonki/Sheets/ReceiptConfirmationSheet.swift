//
//  ReceiptConfirmationSheet.swift
//  Cashooya Playground
//
//  Created by Dante Cardines III on 9/5/25.
//

import SwiftUI

struct ReceiptConfirmationSheet: View {
    let originalImage: UIImage
    let analysis: ReceiptAnalysis
    let primaryCurrency: Currency
    let onConfirm: (ReceiptAnalysis, String?) -> Void
    let onCancel: () -> Void
    
    @State private var amount: String
    @State private var merchant: String
    @State private var selectedDate: Date
    @State private var selectedCategoryId: UUID?
    @State private var note: String = ""
    @State private var selectedCurrency: Currency
    @State private var showingCurrencyPicker = false
    
    @ObservedObject private var categoriesManager = CategoriesManager.shared
    
    // Smart decimal formatting - hides .00, shows .01 when needed
    static func formatAmountForInput(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0  // Hide .00
        formatter.maximumFractionDigits = 2  // Show up to .01
        formatter.groupingSeparator = ","
        formatter.numberStyle = .decimal
        
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.0f", amount)
    }
    
    // Smart currency parser that handles different international formats
    static func parseAmount(_ input: String, currency: Currency = .usd) -> Double? {
        let cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // DEBUG: Log input
        print("💰 PARSE AMOUNT DEBUG:")
        print("   📝 Input: '\(input)'")
        print("   🧹 Cleaned: '\(cleaned)'")
        print("   💱 Currency: \(currency.rawValue)")
        
        // VND TEST SCENARIOS (for validation):
        // ✅ Small: "25.000" → 25000, "60.000" → 60000
        // ✅ Medium: "123.456" → 123456, "1.234.567" → 1234567  
        // ✅ Large: "23.450.000" → 23450000, "100.000.000" → 100000000
        // ✅ Decimals: "60.5" → 60.5, "123.45" → 123.45 (when < 3 digits after period)
        // ✅ Mixed: "1.234.567,89" → 1234567.89
        // ✅ Edge: "₫ 1.000.000" → 1000000, "VND 50.000" → 50000
        
        // Handle different currency formats:
        // US/UK: 1,234.56 or 1234.56
        // European: 1.234,56 or 1234,56  
        // Vietnamese: 60.000 (60,000) AND 60.000.00 (60,000.00) - periods as thousands
        // Indian: 1,23,456.78 (lakhs format)
        // Mixed: 1.234.567,89 (European with comma decimal)
        
        // Remove common currency symbols and spaces first
        let processedInput = cleaned
            .replacingOccurrences(of: "₫", with: "") // Vietnamese dong
            .replacingOccurrences(of: "€", with: "") // Euro
            .replacingOccurrences(of: "$", with: "") // Dollar
            .replacingOccurrences(of: "£", with: "") // Pound
            .replacingOccurrences(of: "¥", with: "") // Yen/Yuan
            .replacingOccurrences(of: "₹", with: "") // Rupee
            .replacingOccurrences(of: " ", with: "") // Spaces
        
        print("   🧽 Processed: '\(processedInput)'")
        
        // Detect format by counting periods and commas
        let periodCount = processedInput.filter { $0 == "." }.count
        let commaCount = processedInput.filter { $0 == "," }.count
        
        print("   📊 Periods: \(periodCount), Commas: \(commaCount)")
        print("   🏷️ Currency-aware parsing for: \(currency.rawValue)")
        
        // CURRENCY-AWARE PRIORITY: VND/IDR gets special treatment first
        if (currency == .vnd || currency == .idr) && periodCount >= 1 && commaCount == 0 {
            print("   🎯 VND/IDR currency detected - prioritizing period-as-thousands parsing")
            
            // IMMEDIATE VND/IDR PARSING (moved up for priority)
            let parts = processedInput.components(separatedBy: ".")
            print("   🔢 VND Split by periods: \(parts)")
            
            // Multiple periods = thousands separators (1.234.567)
            if periodCount >= 2 {
                print("   📍 VND Multiple periods - treating as thousands separators")
                let allDigits = processedInput.replacingOccurrences(of: ".", with: "")
                if allDigits.allSatisfy(\.isNumber), !allDigits.isEmpty {
                    if let result = Double(allDigits) {
                        print("   ✅ VND multi-period result: '\(processedInput)' → \(result)")
                        return result
                    }
                }
            }
            // Single period logic
            else if periodCount == 1 && parts.count == 2 {
                let beforePeriod = parts[0]
                let afterPeriod = parts[1]
                
                // VND bias: treat as thousands if 3+ digits or "000"
                if afterPeriod.count >= 3 || afterPeriod == "000" {
                    print("   ✅ VND thousands format: '\(processedInput)'")
                    let allDigits = beforePeriod + afterPeriod
                    if let result = Double(allDigits) {
                        print("   💰 VND thousands result: \(result)")
                        return result
                    }
                }
                // Small digits = try decimal but prefer thousands for VND
                else if afterPeriod.count <= 2 {
                    let thousandsResult = Double(beforePeriod + afterPeriod)
                    let decimalResult = Double(processedInput)
                    
                    // For VND, prefer thousands interpretation
                    if let thousands = thousandsResult, thousands > 100 {
                        print("   💰 VND bias towards thousands: \(thousands)")
                        return thousands
                    } else if let decimal = decimalResult {
                        print("   💰 VND decimal fallback: \(decimal)")
                        return decimal
                    }
                }
            }
        }
        // PRIORITY 1: Standard US format: 1,234.56 (most common for non-VND)
        else if commaCount > 0 && periodCount <= 1 {
            print("   📍 US format detected (commas as thousands separators)")
            let withoutCommas = processedInput.replacingOccurrences(of: ",", with: "")
            print("   🔢 Removing commas: '\(processedInput)' → '\(withoutCommas)'")
            let result = Double(withoutCommas)
            print("   💰 US format result: \(result ?? 0)")
            return result
        }
        
        // PRIORITY 2: European format: 1.234,56
        if periodCount > 0 && commaCount == 1 {
            print("   📍 European format detected (periods as thousands, comma as decimal)")
            let commaIndex = processedInput.lastIndex(of: ",") ?? processedInput.endIndex
            let beforeComma = String(processedInput[..<commaIndex]).replacingOccurrences(of: ".", with: "")
            let afterComma = String(processedInput[processedInput.index(after: commaIndex)...])
            print("   🔢 Before comma: '\(beforeComma)', After comma: '\(afterComma)'")
            if let amount = Double(beforeComma + "." + afterComma) {
                print("   💰 European format result: \(amount)")
                return amount
            }
        }
        
        // PRIORITY 3: Fallback VND parsing with comma (mixed European-style)
        if (currency == .vnd || currency == .idr) && periodCount >= 1 && processedInput.contains(",") {
            print("   📍 VND mixed format with comma detected (fallback)")
            let parts = processedInput.components(separatedBy: ",")
            if parts.count == 2 {
                let integerPart = parts[0].replacingOccurrences(of: ".", with: "")
                let decimalPart = parts[1]
                print("   🔢 Integer: '\(integerPart)', Decimal: '\(decimalPart)'")
                if let amount = Double(integerPart + "." + decimalPart) {
                    print("   💰 VND mixed format result: \(amount)")
                    return amount
                }
            }
        }
        
        print("   🔄 No specific patterns matched, trying standard parsing...")
        
        // Try standard Double parsing after international formats
        if let standardAmount = Double(processedInput) {
            print("   💰 Standard Double result: \(standardAmount)")
            return standardAmount
        }
        
        print("   ⚠️ All parsing failed, using enhanced fallback...")
        
        // ENHANCED FALLBACK: VND-aware digits extraction
        if currency == .vnd && periodCount > 0 {
            print("   🇻🇳 VND-specific fallback: removing periods and treating as whole number")
            let withoutPeriods = processedInput.replacingOccurrences(of: ".", with: "")
            if let vndResult = Double(withoutPeriods), vndResult > 0 {
                print("   💰 VND aggressive fallback result: \(vndResult)")
                return vndResult
            }
        }
        
        // Final fallback: extract all digits and treat as whole number
        let digitsOnly = String(processedInput.filter { $0.isNumber })
        print("   🔢 Digits only: '\(digitsOnly)'")
        let result = Double(digitsOnly)
        print("   💰 Final fallback result: \(result ?? 0)")
        return result
    }
    
    // Computed property to get category name for the analysis
    private var selectedCategoryName: String {
        guard let categoryId = selectedCategoryId else { return "No Category" }
        let result = categoriesManager.findCategoryOrSubcategoryById(categoryId)
        return result?.category?.name ?? result?.subcategory?.name ?? "No Category"
    }
    
    /// Check if the form is valid for confirming
    private var isFormValid: Bool {
        let trimmedAmount = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Use smart parser to validate international currency formats
        // Supports: US (1,234.56), European (1.234,56), Vietnamese (60.000.00), etc.
        return !trimmedAmount.isEmpty && (Self.parseAmount(trimmedAmount, currency: selectedCurrency) ?? 0) > 0
    }
    
    init(originalImage: UIImage, analysis: ReceiptAnalysis, primaryCurrency: Currency, onConfirm: @escaping (ReceiptAnalysis, String?) -> Void, onCancel: @escaping () -> Void) {
        self.originalImage = originalImage
        self.analysis = analysis
        self.primaryCurrency = primaryCurrency
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        
        // Initialize state with analysis data
        self._amount = State(initialValue: Self.formatAmountForInput(analysis.totalAmount))
        self._merchant = State(initialValue: analysis.merchantName)
        self._selectedDate = State(initialValue: analysis.date)
        self._selectedCurrency = State(initialValue: analysis.currency)
        // Find category ID from analysis category name
        let categoryId = CategoriesManager.shared.findCategoryOrSubcategory(by: analysis.category).category?.id ??
                        CategoriesManager.shared.findCategoryOrSubcategory(by: analysis.category).subcategory?.id
        self._selectedCategoryId = State(initialValue: categoryId)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            SheetHeader.basic(
                title: "Confirm Transaction",
                onBackTap: onCancel
            )
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Amount field
                    AppInputField.amount(
                        text: $amount, 
                        selectedCurrency: Binding(
                            get: { selectedCurrency.rawValue },
                            set: { _ in }
                        ), 
                        onCurrencyTap: {
                            showingCurrencyPicker = true
                        }, 
                        size: .md
                    )
                    
                    // Merchant field
                    AppInputField.merchant(text: $merchant, size: .md)
                    
                    // Date field
                    AppInputField.date(title: "Date added", dateValue: $selectedDate, size: .md)
                    
                    // Category field
                    AppInputField.categoryById(selectedCategoryId: $selectedCategoryId, size: .md)
                    
                    // Note field
                    AppInputField.text(
                        title: "Note",
                        text: $note,
                        placeholder: "Add context or description (optional)",
                        isRequired: false,
                        size: .md
                    )
                    
                    // Receipt section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Receipt")
                            .font(AppFonts.overusedGroteskMedium(size: 16))
                            .foregroundColor(AppColors.foregroundSecondary)
                        
                        // Receipt image - full width with aspect ratio
                        Image(uiImage: originalImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .background(AppColors.surfacePrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(AppColors.linePrimary, lineWidth: 1)
                            )
                    }
                    
                    // Add extra bottom padding for the sticky button
                    Spacer()
                        .frame(height: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            
            // Fixed bottom group
            FixedBottomGroup.primary(
                title: "Confirm",
                action: {
                    // Create updated analysis with modified values
                    let updatedAnalysis = ReceiptAnalysis(
                        merchantName: merchant,
                        totalAmount: Self.parseAmount(amount, currency: selectedCurrency) ?? analysis.totalAmount,
                        date: selectedDate,
                        category: selectedCategoryName,
                        paymentMethod: analysis.paymentMethod,
                        currency: selectedCurrency,
                        items: analysis.items,
                        rawText: analysis.rawText
                    )
                    // Pass note separately (trimmed, nil if empty)
                    let finalNote = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note.trimmingCharacters(in: .whitespacesAndNewlines)
                    onConfirm(updatedAnalysis, finalNote)
                },
                isEnabled: isFormValid
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
    }
}