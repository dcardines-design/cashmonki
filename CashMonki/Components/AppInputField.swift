//
//  AppInputField.swift
//  Cashooya Playground
//
//  Created by Claude on 9/7/25.
//

import SwiftUI

struct AppInputField: View {
    // MARK: - Size Options
    enum Size {
        case lg, md, sm
        
        var fontSize: CGFloat {
            switch self {
            case .lg: return 24
            case .md: return 20
            case .sm: return 16
            }
        }
        
        var iconSize: CGFloat {
            switch self {
            case .lg: return 24
            case .md: return 20
            case .sm: return 16
            }
        }
        
        var verticalPadding: CGFloat {
            switch self {
            case .lg: return 16
            case .md: return 14
            case .sm: return 8
            }
        }
        
        var titleSpacing: CGFloat {
            switch self {
            case .lg: return 8
            case .md: return 6
            case .sm: return 4
            }
        }
        
        
        var titleFont: Font {
            switch self {
            case .lg: return AppFonts.overusedGroteskMedium(size: 16)
            case .md: return AppFonts.overusedGroteskMedium(size: 14)
            case .sm: return AppFonts.overusedGroteskMedium(size: 12)
            }
        }
    }
    
    // MARK: - Properties
    let title: String
    @Binding var text: String
    let placeholder: String
    let isRequired: Bool
    let showRequiredLabel: Bool
    let leftIcon: String?
    let showLeftIcon: Bool
    let rightIcon: String?
    let showRightIcon: Bool
    let helperText: String?
    let showHelperText: Bool
    let keyboardType: UIKeyboardType
    let onRightIconTap: (() -> Void)?
    let size: Size
    
    // Date picker properties
    let isDatePicker: Bool
    @Binding var dateValue: Date
    let datePickerComponents: DatePickerComponents
    
    // Category picker properties
    let isCategoryPicker: Bool
    let transactionAmount: Double? // For determining income/expense context
    
    // Parent category picker properties
    let isParentCategoryPicker: Bool
    let availableParentCategories: [CategoryData]
    let currentCategoryName: String
    
    // Currency ticker properties
    let showCurrencyTicker: Bool
    @Binding var selectedCurrency: String
    let onCurrencyTap: (() -> Void)?
    
    // Amount input properties
    let isAmountField: Bool
    let textColor: Color?
    
    // Secure field properties
    let isSecureField: Bool
    @State private var isPasswordVisible: Bool = false
    
    // Picker states
    @State private var showingDatePicker = false
    @State private var showingCategoryPicker = false
    @State private var showingParentCategoryPicker = false
    @State private var displayText: String = ""
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        switch datePickerComponents {
        case .date:
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
        case .hourAndMinute:
            formatter.dateStyle = .none
            formatter.timeStyle = .short
        case [.date, .hourAndMinute]:
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
        default:
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
        }
        return formatter
    }
    
    private var textForegroundColor: Color {
        let textToCheck = isDatePicker ? displayText : text
        
        // Always use black color for filled content, secondary for empty/placeholder
        if textToCheck.isEmpty || textToCheck == placeholder || textToCheck.lowercased() == "n/a" || textToCheck == "-" {
            return AppColors.foregroundSecondary
        } else {
            return Color.black // Force black color instead of AppColors.foregroundPrimary
        }
    }
    
    private var isInputFocused: Bool {
        if let externalBinding = externalFocusBinding {
            return externalBinding.wrappedValue
        } else {
            return isFocused
        }
    }
    
    // MARK: - Helper Functions
    
    private func filterAmountInput(_ value: String) -> String {
        guard isAmountField else { return value }
        
        // Remove commas first
        let cleanValue = value.replacingOccurrences(of: ",", with: "")
        
        // Allow numbers and one decimal point
        let filtered = cleanValue.filter { character in
            character.isNumber || character == "."
        }
        
        // Ensure only one decimal point
        let components = filtered.components(separatedBy: ".")
        if components.count > 2 {
            // More than one decimal point, keep only the first one
            let firstComponent = components.first ?? ""
            let remainingComponents = components.dropFirst().joined()
            return firstComponent + "." + remainingComponents
        }
        
        // Limit to 2 decimal places
        if components.count == 2, components.count > 1, components[1].count > 2 {
            let firstComponent = components.first ?? ""
            let secondComponent = components.count > 1 ? String(components[1].prefix(2)) : ""
            return firstComponent + "." + secondComponent
        }
        
        return filtered
    }
    
    private func formatAmountWithCommas(_ value: String) -> String {
        let components = value.components(separatedBy: ".")
        let integerPart = components.first ?? ""
        let decimalPart = components.count > 1 ? components[1] : ""
        
        // Handle empty integer part (e.g., user types ".50")
        if integerPart.isEmpty {
            if !decimalPart.isEmpty {
                return ".\(decimalPart)"
            } else {
                return "."
            }
        }
        
        // Format integer part with commas
        if let number = Int(integerPart) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            let formattedInteger = formatter.string(from: NSNumber(value: number)) ?? integerPart
            
            // Combine with decimal part if it exists
            if !decimalPart.isEmpty {
                return "\(formattedInteger).\(decimalPart)"
            } else if components.count > 1 {
                // User typed "123." so preserve the decimal point
                return "\(formattedInteger)."
            } else {
                return formattedInteger
            }
        }
        
        return value
    }
    
    private func formatAmountForDisplay(_ value: String) -> String {
        guard isAmountField && !value.isEmpty else { return value }
        
        // Remove commas first
        let cleanValue = value.replacingOccurrences(of: ",", with: "")
        
        // Try to convert to Double for smart formatting
        guard let amount = Double(cleanValue) else { return value }
        
        // Use smart decimal formatting (hide .00, show .01 etc.)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        
        return formatter.string(from: NSNumber(value: amount)) ?? value
    }
    
    // MARK: - State
    @FocusState private var isFocused: Bool
    
    // External focus binding for controlled focus
    let externalFocusBinding: FocusState<Bool>.Binding?
    
    // MARK: - Initializer
    init(
        title: String,
        text: Binding<String>,
        placeholder: String = "",
        isRequired: Bool = false,
        showRequiredLabel: Bool = false,
        leftIcon: String? = nil,
        showLeftIcon: Bool = false,
        rightIcon: String? = nil,
        showRightIcon: Bool = false,
        helperText: String? = nil,
        showHelperText: Bool = false,
        keyboardType: UIKeyboardType = .default,
        onRightIconTap: (() -> Void)? = nil,
        size: Size = .md,
        isDatePicker: Bool = false,
        dateValue: Binding<Date> = .constant(Date()),
        datePickerComponents: DatePickerComponents = .date,
        isCategoryPicker: Bool = false,
        transactionAmount: Double? = nil,
        isParentCategoryPicker: Bool = false,
        availableParentCategories: [CategoryData] = [],
        currentCategoryName: String = "",
        showCurrencyTicker: Bool = false,
        selectedCurrency: Binding<String> = .constant("USD"),
        onCurrencyTap: (() -> Void)? = nil,
        isAmountField: Bool = false,
        textColor: Color? = nil,
        isSecureField: Bool = false,
        externalFocusBinding: FocusState<Bool>.Binding? = nil
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.isRequired = isRequired
        self.showRequiredLabel = showRequiredLabel
        self.leftIcon = leftIcon
        self.showLeftIcon = showLeftIcon
        self.rightIcon = rightIcon
        self.showRightIcon = showRightIcon
        self.helperText = helperText
        self.showHelperText = showHelperText
        self.keyboardType = keyboardType
        self.onRightIconTap = onRightIconTap
        self.size = size
        self.isDatePicker = isDatePicker
        self._dateValue = dateValue
        self.datePickerComponents = datePickerComponents
        self.isCategoryPicker = isCategoryPicker
        self.transactionAmount = transactionAmount
        self.isParentCategoryPicker = isParentCategoryPicker
        self.availableParentCategories = availableParentCategories
        self.currentCategoryName = currentCategoryName
        self.showCurrencyTicker = showCurrencyTicker
        self._selectedCurrency = selectedCurrency
        self.onCurrencyTap = onCurrencyTap
        self.isAmountField = isAmountField
        self.textColor = textColor
        self.isSecureField = isSecureField
        self.externalFocusBinding = externalFocusBinding
    }
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            titleSection
            inputFieldSection
        }
        .onTapGesture {
            if isCategoryPicker {
                showingCategoryPicker = true
            } else if isParentCategoryPicker {
                showingParentCategoryPicker = true
            } else {
                // Unfocus when tapping outside input area (for regular text fields)
                if let externalBinding = externalFocusBinding {
                    externalBinding.wrappedValue = false
                } else {
                    isFocused = false
                }
            }
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var titleSection: some View {
        if !self.title.isEmpty {
            HStack {
                Text(self.title)
                    .font(AppFonts.overusedGroteskMedium(size: 16))
                    .foregroundColor(AppColors.foregroundSecondary)
                
                Spacer()
                
                if isRequired && showRequiredLabel {
                    Text("(Required)")
                        .font(AppFonts.overusedGroteskMedium(size: 16))
                        .foregroundColor(AppColors.foregroundSecondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private var inputFieldSection: some View {
        HStack(alignment: .center, spacing: showCurrencyTicker ? 0 : 10) {
            leftIconView
            mainInputContent
            rightIconView
            currencyTickerView
        }
        .padding(.horizontal, 16)
        .padding(.vertical, size.verticalPadding)
        .background(AppColors.surfacePrimary)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .inset(by: 0.5)
                .stroke(Color.clear, lineWidth: 1)
        )
        .sheet(isPresented: $showingDatePicker) {
            datePickerSheet
        }
        .sheet(isPresented: $showingCategoryPicker) {
            CategoryPickerSheet(
                selectedCategory: $text,
                isPresented: $showingCategoryPicker,
                initialTab: determineInitialTab()
            )
            .presentationDetents([.fraction(0.98)])
            .presentationDragIndicator(.hidden)
            .presentationBackground(.thinMaterial)
            .presentationCornerRadius(20)
            .interactiveDismissDisabled(false)
        }
        .sheet(isPresented: $showingParentCategoryPicker) {
            ParentCategoryPickerSheet(
                selectedParent: Binding(
                    get: { text.isEmpty ? nil : text },
                    set: { text = $0 ?? "" }
                ),
                isPresented: $showingParentCategoryPicker,
                availableCategories: availableParentCategories,
                currentCategoryName: currentCategoryName,
                initialTab: determineInitialTabForParent()
            )
            .presentationDetents([.fraction(0.98)])
            .presentationDragIndicator(.hidden)
            .presentationBackground(.thinMaterial)
            .presentationCornerRadius(20)
            .interactiveDismissDisabled(false)
        }
    }
    
    @ViewBuilder
    private var leftIconView: some View {
        if let leftIcon = leftIcon, showLeftIcon {
            AppIcon(assetName: leftIcon, fallbackSystemName: "magnifyingglass")
                .font(.system(size: size.iconSize))
                .foregroundColor(AppColors.foregroundSecondary)
                .frame(width: size.iconSize, height: size.iconSize)
        }
    }
    
    @ViewBuilder
    private var mainInputContent: some View {
        if isDatePicker {
            datePickerButton
        } else if isCategoryPicker {
            categoryPickerButton
        } else if isParentCategoryPicker {
            parentCategoryPickerButton
        } else {
            textFieldView
        }
    }
    
    @ViewBuilder 
    private var datePickerButton: some View {
        Button(action: {
            showingDatePicker = true
        }) {
            HStack {
                Text(displayText.isEmpty ? placeholder : displayText)
                    .font(AppFonts.overusedGroteskMedium(size: size.fontSize))
                    .foregroundStyle(textForegroundColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            let formattedText = dateFormatter.string(from: dateValue)
            displayText = formattedText
            text = formattedText
        }
        .onChange(of: dateValue) { _, newDate in
            let formattedText = dateFormatter.string(from: newDate)
            displayText = formattedText
            text = formattedText
        }
    }
    
    @ViewBuilder
    private var categoryPickerButton: some View {
        Button(action: {
            showingCategoryPicker = true
        }) {
            HStack(spacing: 12) {
                TxnCategoryIcon(category: text.isEmpty ? "No Category" : text, size: 24)
                Text(text.isEmpty ? "Select Category" : text)
                    .font(AppFonts.overusedGroteskMedium(size: size.fontSize))
                    .foregroundStyle(text.isEmpty ? AppColors.foregroundSecondary : AppColors.foregroundPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private var parentCategoryPickerButton: some View {
        Button(action: {
            showingParentCategoryPicker = true
        }) {
            HStack(spacing: 12) {
                TxnCategoryIcon(category: text.isEmpty ? "No Parent" : text, size: 24)
                Text(text.isEmpty ? "Select Parent Category (Optional)" : text)
                    .font(AppFonts.overusedGroteskMedium(size: size.fontSize))
                    .foregroundStyle(text.isEmpty ? AppColors.foregroundSecondary : AppColors.foregroundPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private var textFieldView: some View {
        TextField("", text: $text)
            .font(AppFonts.overusedGroteskMedium(size: size.fontSize))
            .foregroundStyle(textColor ?? Color.black)
            .accentColor(AppColors.accentBackground)
            .keyboardType(keyboardType)
            .focused(externalFocusBinding ?? $isFocused)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    // Empty toolbar to hide default accessory view
                }
            }
            .onChange(of: text) { _, newValue in
                if isAmountField {
                    // Filter input as user types (prevent multiple periods, non-numeric characters)
                    let filtered = filterAmountInput(newValue)
                    if filtered != newValue {
                        text = filtered
                    }
                }
            }
            .onChange(of: isInputFocused) { _, focused in
                if isAmountField {
                    if focused {
                        // When gaining focus, convert from display format back to raw format for editing
                        text = text.replacingOccurrences(of: ",", with: "")
                    } else {
                        // When losing focus, apply smart formatting
                        text = formatAmountForDisplay(text)
                    }
                }
            }
            .onSubmit {
                if isAmountField {
                    // Apply smart formatting when user presses return
                    text = formatAmountForDisplay(text)
                }
                
                // Ensure clean focus dismissal for all keyboard types
                DispatchQueue.main.async {
                    if let externalBinding = externalFocusBinding {
                        externalBinding.wrappedValue = false
                    } else {
                        isFocused = false
                    }
                    // Additional keyboard dismissal for alphabet keyboards
                    if keyboardType == .default || keyboardType == .alphabet {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .overlay(
                // Custom placeholder
                HStack {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(AppFonts.overusedGroteskMedium(size: size.fontSize))
                            .foregroundColor(AppColors.foregroundSecondary)
                        Spacer()
                    }
                }
                .allowsHitTesting(false)
            )
    }
    
    @ViewBuilder
    private var rightIconView: some View {
        if let rightIcon = rightIcon, showRightIcon {
            Button(action: {
                onRightIconTap?()
            }) {
                Image(systemName: rightIcon)
                    .font(.system(size: size.iconSize))
                    .foregroundColor(AppColors.foregroundSecondary)
                    .frame(width: size.iconSize, height: size.iconSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    @ViewBuilder
    private var currencyTickerView: some View {
        if showCurrencyTicker {
            Button(action: {
                onCurrencyTap?()
            }) {
                HStack(spacing: 4) {
                    Text(selectedCurrency)
                        .font(AppFonts.overusedGroteskMedium(size: size.fontSize))
                        .foregroundColor(AppColors.foregroundPrimary)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.foregroundSecondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    @ViewBuilder
    private var datePickerSheet: some View {
        DatePicker("", selection: $dateValue, displayedComponents: datePickerComponents)
            .datePickerStyle(.graphical)
            .labelsHidden()
            .presentationDetents([.fraction(0.5)])
    }
    
    /// Determine initial tab based on current selected category type (not transaction amount)
    private func determineInitialTab() -> CategoryPickerSheet.CategoryTab? {
        #if DEBUG
        print("🔥 CategoryPicker determineInitialTab:")
        print("🔥   - text (current category): '\(text)'")
        print("🔥   - text.isEmpty: \(text.isEmpty)")
        #endif
        
        // PRIORITY 1: Use selected category type to determine tab
        if !text.isEmpty {
            #if DEBUG
            print("🔥   - Searching for category: '\(text)'")
            #endif
            
            // Handle special "No Parent" container categories
            if text.hasPrefix("No Parent") {
                let tab: CategoryPickerSheet.CategoryTab = text.contains("Income") ? .income : .expense
                #if DEBUG
                print("🔥   - ✅ Found No Parent category '\(text)': opening \(tab) tab")
                #endif
                return tab
            }
            
            let categoryResult = CategoriesManager.shared.findCategoryOrSubcategory(by: text)
            if let category = categoryResult.category {
                let tab: CategoryPickerSheet.CategoryTab = category.type == .income ? .income : .expense
                #if DEBUG
                print("🔥   - ✅ Found category '\(category.name)' with type \(category.type): opening \(tab) tab")
                #endif
                return tab
            } else if let subcategory = categoryResult.subcategory, let parent = categoryResult.parent {
                let tab: CategoryPickerSheet.CategoryTab = subcategory.type == .income ? .income : .expense
                #if DEBUG
                print("🔥   - ✅ Found subcategory '\(text)' under parent '\(parent.name)' with subcategory type \(subcategory.type): opening \(tab) tab")
                #endif
                return tab
            } else {
                #if DEBUG
                print("🔥   - ❌ Category '\(text)' NOT FOUND in CategoriesManager")
                // Let's see what categories are available
                let allCategories = CategoriesManager.shared.allCategoriesWithCustom
                print("🔥   - Available categories: \(allCategories.prefix(5).map { $0.name })")
                #endif
            }
        }
        
        #if DEBUG
        print("🔥   - No valid category found, will default to .expense tab")
        #endif
        return nil // Default will be .expense
    }
    
    /// Determine initial tab for parent category picker based on current category being edited
    private func determineInitialTabForParent() -> ParentCategoryPickerSheet.CategoryTab? {
        // Try to find the current category being edited and use its type
        let categoryResult = CategoriesManager.shared.findCategoryOrSubcategory(by: currentCategoryName)
        if let category = categoryResult.category {
            return category.type == .income ? .income : .expense
        } else if let subcategory = categoryResult.subcategory {
            return subcategory.type == .income ? .income : .expense
        }
        
        return nil // Default will be .expense
    }
}

// MARK: - Convenience Methods

extension AppInputField {
    /// Creates a text input field
    static func text(title: String, text: Binding<String>, placeholder: String = "", isRequired: Bool = false, size: Size = .md, focusBinding: FocusState<Bool>.Binding? = nil) -> AppInputField {
        AppInputField(
            title: title,
            text: text,
            placeholder: placeholder,
            isRequired: isRequired,
            size: size,
            externalFocusBinding: focusBinding
        )
    }
    
    /// Creates a search input field with magnifying glass icon
    static func search(text: Binding<String>, placeholder: String = "Search...", size: Size = .md) -> AppInputField {
        AppInputField(
            title: "",
            text: text,
            placeholder: placeholder,
            leftIcon: "search-md",
            showLeftIcon: true,
            size: size
        )
    }
    
    /// Creates a merchant input field
    static func merchant(text: Binding<String>, size: Size = .md, focusBinding: FocusState<Bool>.Binding? = nil) -> AppInputField {
        AppInputField(
            title: "Merchant",
            text: text,
            placeholder: "Enter merchant name",
            isRequired: true,
            size: size,
            externalFocusBinding: focusBinding
        )
    }
    
    /// Creates an amount input field with currency support
    static func amount(text: Binding<String>, selectedCurrency: Binding<String>, onCurrencyTap: @escaping () -> Void = {}, size: Size = .md, textColor: Color? = nil, focusBinding: FocusState<Bool>.Binding? = nil) -> AppInputField {
        AppInputField(
            title: "Amount",
            text: text,
            placeholder: "0.00",
            isRequired: true,
            keyboardType: .decimalPad,
            size: size,
            showCurrencyTicker: true,
            selectedCurrency: selectedCurrency,
            onCurrencyTap: onCurrencyTap,
            isAmountField: true,
            textColor: textColor,
            externalFocusBinding: focusBinding
        )
    }
    
    /// Creates a date input field with date picker
    static func date(title: String, dateValue: Binding<Date>, components: DatePickerComponents = .date, size: Size = .md) -> AppInputField {
        AppInputField(
            title: title,
            text: .constant(""),
            isRequired: true,
            size: size,
            isDatePicker: true,
            dateValue: dateValue,
            datePickerComponents: components
        )
    }
    
    /// Creates a category selection field
    static func category(selectedCategory: Binding<String>, size: Size = .md, transactionAmount: Double? = nil) -> AppInputField {
        AppInputField(
            title: "Category",
            text: selectedCategory,
            placeholder: "Select Category",
            isRequired: true,
            size: size,
            isCategoryPicker: true,
            transactionAmount: transactionAmount
        )
    }
    
    static func categoryById(selectedCategoryId: Binding<UUID?>, size: Size = .md, transactionAmount: Double? = nil) -> some View {
        CategoryByIdInputField(selectedCategoryId: selectedCategoryId, size: size, transactionAmount: transactionAmount)
    }
    
    static func currency(selectedCurrency: Binding<Currency>, size: Size = .md, title: String = "Currency") -> some View {
        CurrencyInputField(selectedCurrency: selectedCurrency, size: size, title: title)
    }
    
    /// Creates a parent category selection field
    static func parentCategory(selectedParent: Binding<String>, availableCategories: [CategoryData], currentCategoryName: String, size: Size = .md) -> AppInputField {
        AppInputField(
            title: "Parent Category",
            text: selectedParent,
            placeholder: "Select Parent Category (Optional)",
            isRequired: false,
            size: size,
            isParentCategoryPicker: true,
            availableParentCategories: availableCategories,
            currentCategoryName: currentCategoryName
        )
    }
}

struct CategoryByIdInputField: View {
    @Binding var selectedCategoryId: UUID?
    let size: AppInputField.Size
    let transactionAmount: Double?
    
    @State private var showingCategoryPicker = false
    @ObservedObject private var categoriesManager = CategoriesManager.shared
    
    // Computed property to get category name for display
    private var selectedCategoryName: String {
        guard let categoryId = selectedCategoryId else { 
            print("🐛 CategoryByIdInputField: selectedCategoryId is nil")
            return "" 
        }
        
        print("🐛 CategoryByIdInputField: Looking up categoryId: \(categoryId.uuidString.prefix(8))")
        
        // Check for hardcoded "No Category" UUIDs first
        if categoryId.uuidString.lowercased() == "00000000-0000-0000-0000-000000000001" || 
           categoryId.uuidString.lowercased() == "00000000-0000-0000-0000-000000000002" {
            print("🐛 CategoryByIdInputField: Found hardcoded No Category UUID")
            return "No Category"
        }
        
        let result = categoriesManager.findCategoryOrSubcategoryById(categoryId)
        
        if let category = result?.category {
            print("🐛 CategoryByIdInputField: Found category: '\(category.name)'")
            return category.name
        } else if let subcategory = result?.subcategory {
            print("🐛 CategoryByIdInputField: Found subcategory: '\(subcategory.name)'")
            return subcategory.name
        } else {
            print("🐛 CategoryByIdInputField: No category found for ID: \(categoryId.uuidString.prefix(8))")
            return ""
        }
    }
    
    // Computed property to get category emoji for display
    private var selectedCategoryEmoji: String {
        guard let categoryId = selectedCategoryId else { return "" }
        
        // Check for hardcoded "No Category" UUIDs first
        if categoryId.uuidString.lowercased() == "00000000-0000-0000-0000-000000000001" || 
           categoryId.uuidString.lowercased() == "00000000-0000-0000-0000-000000000002" {
            return "📝" // Use a generic emoji for "No Category"
        }
        
        let result = categoriesManager.findCategoryOrSubcategoryById(categoryId)
        
        if let category = result?.category {
            return category.emoji
        } else if let subcategory = result?.subcategory {
            return subcategory.emoji
        } else {
            return ""
        }
    }
    
    // Computed property for display text (adds income/expense indication for No Category)
    private var displayText: String {
        if selectedCategoryName == "No Category" {
            // For No Category entries, determine type based on UUID or amount
            guard let categoryId = selectedCategoryId else { return selectedCategoryName }
            
            if categoryId.uuidString.lowercased() == "00000000-0000-0000-0000-000000000001" {
                return "No Category (Income)"
            } else if categoryId.uuidString.lowercased() == "00000000-0000-0000-0000-000000000002" {
                return "No Category (Expense)"
            } else if let amount = transactionAmount {
                // Fallback to amount-based determination
                return amount > 0 ? "No Category (Income)" : "No Category (Expense)"
            }
        }
        return selectedCategoryName
    }
    
    // Computed property for text color (consistent color for all categories)
    private var textColor: Color {
        return AppColors.foregroundPrimary
    }
    
    // Computed property to determine initial tab based on current category context
    private var initialTab: CategoryPickerSheet.CategoryTab {
        // If we have a selected category, determine its type
        if let categoryId = selectedCategoryId {
            // Check for hardcoded "No Category" UUIDs first
            if categoryId.uuidString.lowercased() == "00000000-0000-0000-0000-000000000001" {
                return .income // No Category (Income)
            } else if categoryId.uuidString.lowercased() == "00000000-0000-0000-0000-000000000002" {
                return .expense // No Category (Expense)
            }
            
            // Look up the category type from the categories manager
            if let result = categoriesManager.findCategoryOrSubcategoryById(categoryId) {
                if let category = result.category {
                    return category.type == .income ? .income : .expense
                } else if let subcategory = result.subcategory {
                    return subcategory.type == .income ? .income : .expense
                }
            }
        }
        
        // If no category is selected, try to determine from transaction amount
        if let amount = transactionAmount {
            return amount > 0 ? .income : .expense
        }
        
        // Default to expense if no context available
        return .expense
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Category")
                .font(.custom("OverusedGrotesk-Medium", size: 16))
                .foregroundStyle(AppColors.foregroundSecondary)
            
            Button(action: {
                showingCategoryPicker = true
            }) {
                HStack(spacing: 8) {
                    // Show emoji if category is selected
                    if !selectedCategoryName.isEmpty && !selectedCategoryEmoji.isEmpty {
                        Text(selectedCategoryEmoji)
                            .font(.system(size: 18))
                    }
                    
                    Text(selectedCategoryName.isEmpty ? "Select Category" : displayText)
                        .font(AppFonts.overusedGroteskMedium(size: size.fontSize))
                        .foregroundStyle(selectedCategoryName.isEmpty ? AppColors.foregroundSecondary : textColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    AppIcon(
                        assetName: "chevron-right",
                        fallbackSystemName: "chevron.right"
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, size.verticalPadding)
                .background(AppColors.surfacePrimary)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .inset(by: 0.5)
                        .stroke(Color.clear, lineWidth: 1)
                )
            }
        }
        .sheet(isPresented: $showingCategoryPicker) {
            CategoryPickerSheet(
                selectedCategoryId: $selectedCategoryId,
                isPresented: $showingCategoryPicker,
                initialTab: initialTab
            )
            .presentationDetents([.fraction(0.98)])
            .presentationDragIndicator(.hidden)
            .presentationBackground(.thinMaterial)
            .presentationCornerRadius(20)
            .interactiveDismissDisabled(false)
        }
    }
}

struct CurrencyInputField: View {
    @Binding var selectedCurrency: Currency
    let size: AppInputField.Size
    let title: String
    
    @State private var showingCurrencyPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: size.titleSpacing) {
            if !self.title.isEmpty {
                Text(self.title)
                    .font(size.titleFont)
                    .foregroundColor(AppColors.foregroundSecondary)
            }
            
            Button(action: {
                showingCurrencyPicker = true
            }) {
                HStack(alignment: .center, spacing: 12) {
                    // Currency Flag and Symbol - Code format
                    HStack(spacing: 8) {
                        Text(selectedCurrency.flag)
                            .font(.system(size: 20))
                        
                        Text("\(selectedCurrency.symbol) - \(selectedCurrency.rawValue)")
                            .font(AppFonts.overusedGroteskMedium(size: size.fontSize))
                            .foregroundColor(AppColors.foregroundPrimary)
                    }
                    
                    Spacer()
                    
                    // Chevron
                    AppIcon(
                        assetName: "chevron-right",
                        fallbackSystemName: "chevron.right"
                    )
                    .foregroundColor(AppColors.foregroundSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, size.verticalPadding)
                .background(AppColors.surfacePrimary)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .inset(by: 0.5)
                        .stroke(Color.clear, lineWidth: 1)
                )
            }
        }
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
