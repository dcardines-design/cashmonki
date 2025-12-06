//
//  CashMonkiDesignSystem.swift
//  CashMonki
//
//  Created by Claude on 9/7/25.
//

import SwiftUI

// MARK: - Unified Design System
struct CashMonkiDS {
    
    // MARK: - Colors
    struct Colors {
        static let primary = AppColors.accentBackground
        static let foreground = AppColors.foregroundPrimary
        static let foregroundSecondary = AppColors.foregroundSecondary
        static let surface = AppColors.surfacePrimary
        static let background = AppColors.backgroundWhite
        static let line = AppColors.linePrimary
    }
    
    // MARK: - Typography
    struct Typography {
        // Headers
        static let header1 = AppFonts.overusedGroteskSemiBold(size: 32)
        static let header2 = AppFonts.overusedGroteskSemiBold(size: 24)
        static let header3 = AppFonts.overusedGroteskSemiBold(size: 20)
        
        // Body text
        static let body = AppFonts.overusedGroteskMedium(size: 16)
        static let bodyLarge = AppFonts.overusedGroteskMedium(size: 18)
        static let bodySmall = AppFonts.overusedGroteskMedium(size: 14)
        
        // Input text
        static let inputLarge = AppFonts.overusedGroteskMedium(size: 24)
        static let inputMedium = AppFonts.overusedGroteskMedium(size: 18)
        
        // Labels
        static let label = AppFonts.overusedGroteskMedium(size: 16)
        static let labelSmall = AppFonts.overusedGroteskMedium(size: 14)
        
        // Caption
        static let caption = AppFonts.overusedGroteskMedium(size: 12)
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Layout
    struct Layout {
        static let cornerRadius: CGFloat = 10
        static let cornerRadiusSmall: CGFloat = 8
        static let cornerRadiusLarge: CGFloat = 16
        
        static let borderWidth: CGFloat = 1
        static let focusBorderWidth: CGFloat = 2
        
        static let buttonHeight: CGFloat = 44
        static let inputHeight: CGFloat = 52
        static let iconSize: CGFloat = 20
        
        static let screenPadding: CGFloat = 20
        static let cardPadding: CGFloat = 16
    }
    
    // MARK: - Animation
    struct Animation {
        static let quick = SwiftUI.Animation.linear(duration: 0.2)
        static let standard = SwiftUI.Animation.linear(duration: 0.3)
        static let slow = SwiftUI.Animation.linear(duration: 0.5)
        static let spring = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.8)
    }
    
    // MARK: - Shadows
    struct Shadow {
        static let small = (color: Color.black.opacity(0.1), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
        static let medium = (color: Color.black.opacity(0.15), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))
        static let large = (color: Color.black.opacity(0.2), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(8))
    }
}

// MARK: - Unified Component Interface
extension CashMonkiDS {
    
    // MARK: - Input Components
    struct Input {
        static func text(
            title: String,
            text: Binding<String>,
            placeholder: String = "",
            isRequired: Bool = false,
            isSecure: Bool = false
        ) -> AnyView {
            if isSecure {
                return AnyView(
                    SecureInputWithToggle(
                        title: title,
                        text: text,
                        placeholder: placeholder
                    )
                )
            } else {
                return AnyView(
                    AppInputField.text(
                        title: title,
                        text: text,
                        placeholder: placeholder,
                        isRequired: isRequired,
                        size: .md
                    )
                )
            }
        }
        
        static func amount(
            text: Binding<String>,
            currency: String = "USD"
        ) -> AnyView {
            return AnyView(
                AppInputField.amount(text: text, selectedCurrency: .constant(currency))
            )
        }
        
        static func merchant(text: Binding<String>) -> AnyView {
            return AnyView(
                AppInputField.merchant(text: text)
            )
        }
        
        static func search(
            text: Binding<String>,
            placeholder: String = "Search..."
        ) -> AnyView {
            return AnyView(
                AppInputField.search(text: text, placeholder: placeholder)
            )
        }
        
        static func date(
            title: String = "Date",
            dateValue: Binding<Date>,
            components: DatePickerComponents = .date
        ) -> AnyView {
            return AnyView(
                AppInputField.date(
                    title: title,
                    dateValue: dateValue,
                    components: components
                )
            )
        }
    }
    
    // MARK: - Button Components
    struct Button {
        static func primary(
            _ title: String,
            leftIcon: String? = nil,
            rightIcon: String? = nil,
            size: ButtonSize = .medium,
            action: @escaping () -> Void
        ) -> AppButton {
            AppButton.primary(title, size: size, leftIcon: leftIcon, rightIcon: rightIcon, action: action)
        }
        
        static func secondary(
            _ title: String,
            leftIcon: String? = nil,
            rightIcon: String? = nil,
            size: ButtonSize = .medium,
            action: @escaping () -> Void
        ) -> AppButton {
            AppButton.secondary(title, size: size, leftIcon: leftIcon, rightIcon: rightIcon, action: action)
        }
        
        static func tertiary(
            _ title: String,
            leftIcon: String? = nil,
            rightIcon: String? = nil,
            size: ButtonSize = .medium,
            action: @escaping () -> Void
        ) -> AppButton {
            AppButton.tertiary(title, size: size, leftIcon: leftIcon, rightIcon: rightIcon, action: action)
        }
        
        static func ghost(
            _ title: String,
            leftIcon: String? = nil,
            rightIcon: String? = nil,
            action: @escaping () -> Void
        ) -> AppButton {
            AppButton.ghost(title, leftIcon: leftIcon, rightIcon: rightIcon, action: action)
        }
        
        static func text(
            _ title: String,
            leftIcon: String? = nil,
            rightIcon: String? = nil,
            action: @escaping () -> Void
        ) -> AppButton {
            AppButton.text(title, leftIcon: leftIcon, rightIcon: rightIcon, action: action)
        }
    }
    
    // MARK: - Overlay Components
    struct Overlay {
        static func fullScreenOverlay<Content: View>(
            title: String,
            confirmTitle: String = "Save",
            isConfirmEnabled: Bool = true,
            onBack: @escaping () -> Void,
            onConfirm: @escaping () -> Void,
            @ViewBuilder content: () -> Content
        ) -> FullScreenOverlayTemplate<Content> {
            FullScreenOverlayTemplate(
                title: title,
                confirmTitle: confirmTitle,
                isConfirmEnabled: isConfirmEnabled,
                onBack: onBack,
                onConfirm: onConfirm,
                content: content
            )
        }
        
        static func modalOverlay<Content: View>(
            title: String,
            confirmTitle: String = "Save",
            isConfirmEnabled: Bool = true,
            onBack: @escaping () -> Void,
            onConfirm: @escaping () -> Void,
            @ViewBuilder content: () -> Content
        ) -> ModalOverlayTemplate<Content> {
            ModalOverlayTemplate(
                title: title,
                confirmTitle: confirmTitle,
                isConfirmEnabled: isConfirmEnabled,
                onBack: onBack,
                onConfirm: onConfirm,
                content: content
            )
        }
        
        static func settingsOverlay<Content: View>(
            title: String,
            onBack: @escaping () -> Void,
            @ViewBuilder content: () -> Content
        ) -> SettingsOverlayTemplate<Content> {
            SettingsOverlayTemplate(
                title: title,
                onBack: onBack,
                content: content
            )
        }
    }
    
    // MARK: - Transaction Display Components
    // Note: Use UnifiedTransactionDisplay directly to avoid compilation order issues
    // Examples:
    // UnifiedTransactionDisplay.row(transaction: txn)
    // UnifiedTransactionDisplay.tile(transaction: txn) { }
    // UnifiedTransactionDisplay.compact(transaction: txn)
    // UnifiedTransactionDisplay.detailed(transaction: txn)
    
    // MARK: - Selection Components
    struct Selection {
        /// Selection row for lists (currency, category, etc.)
        static func row(
            icon: String,
            title: String,
            isSelected: Bool,
            onTap: @escaping () -> Void
        ) -> SelectionRowItem {
            SelectionRowItem(
                icon: icon,
                title: title,
                isSelected: isSelected,
                onTap: onTap
            )
        }
        
        /// Currency selection row
        static func currency(
            _ currency: Currency,
            isSelected: Bool,
            onTap: @escaping () -> Void
        ) -> SelectionRowItem {
            SelectionRowItem.currency(
                currency,
                isSelected: isSelected,
                onTap: onTap
            )
        }
        
        /// Category selection row
        static func category(
            _ category: String,
            emoji: String,
            isSelected: Bool,
            onTap: @escaping () -> Void
        ) -> SelectionRowItem {
            SelectionRowItem.category(
                category,
                emoji: emoji,
                isSelected: isSelected,
                onTap: onTap
            )
        }
        
        /// Tab/chip for filtering and tabbed navigation
        static func tabChip(
            title: String,
            isSelected: Bool,
            onTap: @escaping () -> Void
        ) -> TabChip {
            TabChip.basic(
                title: title,
                isSelected: isSelected,
                onTap: onTap
            )
        }
        
        /// Filter chip for content filtering
        static func filterChip(
            title: String,
            isActive: Bool,
            onToggle: @escaping () -> Void
        ) -> TabChip {
            TabChip.filter(
                title: title,
                isActive: isActive,
                onToggle: onToggle
            )
        }
    }
    
    // MARK: - Icon Components
    struct Icon {
        /// Category icon for transactions
        static func category(
            _ category: String,
            size: CGFloat = 36,
            backgroundColor: Color = Colors.surface
        ) -> TxnCategoryIcon {
            TxnCategoryIcon(
                category: category,
                size: size,
                backgroundColor: backgroundColor
            )
        }
        
        /// App icon with fallback
        static func app(
            assetName: String,
            fallbackSystemName: String,
            size: CGFloat = 20
        ) -> some View {
            AppIcon(
                assetName: assetName,
                fallbackSystemName: fallbackSystemName
            )
            .font(.system(size: size))
        }
    }
}

// MARK: - View Modifiers for Consistent Styling
extension View {
    
    // Card styling
    func cardStyle() -> some View {
        self
            .background(CashMonkiDS.Colors.surface)
            .cornerRadius(CashMonkiDS.Layout.cornerRadius)
    }
    
    // Shadow variants
    func shadowSmall() -> some View {
        let shadow = CashMonkiDS.Shadow.small
        return self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
    
    func shadowMedium() -> some View {
        let shadow = CashMonkiDS.Shadow.medium
        return self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
    
    func shadowLarge() -> some View {
        let shadow = CashMonkiDS.Shadow.large
        return self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
    
    // Screen padding
    func screenPadding() -> some View {
        self.padding(.horizontal, CashMonkiDS.Layout.screenPadding)
    }
    
    // Card padding
    func cardPadding() -> some View {
        self.padding(CashMonkiDS.Layout.cardPadding)
    }
    
    // Standard spacing
    func standardSpacing() -> some View {
        self.padding(CashMonkiDS.Spacing.md)
    }
    
    // Focus border
    func focusBorder(_ isFocused: Bool) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: CashMonkiDS.Layout.cornerRadius)
                .stroke(
                    isFocused ? CashMonkiDS.Colors.primary : Color.clear,
                    lineWidth: CashMonkiDS.Layout.focusBorderWidth
                )
        )
    }
}

// MARK: - Text Styles
extension Text {
    func header1() -> some View {
        self
            .font(CashMonkiDS.Typography.header1)
            .foregroundColor(CashMonkiDS.Colors.foreground)
    }
    
    func header2() -> some View {
        self
            .font(CashMonkiDS.Typography.header2)
            .foregroundColor(CashMonkiDS.Colors.foreground)
    }
    
    func header3() -> some View {
        self
            .font(CashMonkiDS.Typography.header3)
            .foregroundColor(CashMonkiDS.Colors.foreground)
    }
    
    func bodyText() -> some View {
        self
            .font(CashMonkiDS.Typography.body)
            .foregroundColor(CashMonkiDS.Colors.foreground)
    }
    
    func bodySecondary() -> some View {
        self
            .font(CashMonkiDS.Typography.body)
            .foregroundColor(CashMonkiDS.Colors.foregroundSecondary)
    }
    
    func label() -> some View {
        self
            .font(CashMonkiDS.Typography.label)
            .foregroundColor(CashMonkiDS.Colors.foregroundSecondary)
    }
    
    func caption() -> some View {
        self
            .font(CashMonkiDS.Typography.caption)
            .foregroundColor(CashMonkiDS.Colors.foregroundSecondary)
    }
}

// MARK: - Secure Input with Toggle
struct SecureInputWithToggle: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    
    @State private var isPasswordVisible = false
    @FocusState private var isFocused: Bool
    
    init(title: String, text: Binding<String>, placeholder: String) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
    }
    
    // Display text for the overlay (only used when hidden)
    private var displayText: String {
        return String(repeating: "●", count: text.count)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(CashMonkiDS.Typography.labelSmall)
                    .foregroundColor(CashMonkiDS.Colors.foregroundSecondary)
            }
            
            HStack {
                ZStack(alignment: .leading) {
                    if isPasswordVisible {
                        // Show plain text when visible
                        TextField("", text: $text)
                            .font(AppFonts.overusedGroteskMedium(size: 20))
                            .foregroundColor(CashMonkiDS.Colors.foreground)
                            .accentColor(AppColors.accentBackground)
                            .frame(height: 24)
                            .focused($isFocused)
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    // Empty toolbar to hide default accessory view
                                }
                            }
                    } else {
                        // Use SecureField when hidden for proper bullet spacing
                        SecureField("", text: $text)
                            .font(AppFonts.overusedGroteskMedium(size: 20))
                            .foregroundColor(CashMonkiDS.Colors.foreground)
                            .accentColor(AppColors.accentBackground)
                            .frame(height: 24)
                            .focused($isFocused)
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    // Empty toolbar to hide default accessory view
                                }
                            }
                    }
                    
                    // Custom placeholder to match AppInputField styling
                    if text.isEmpty {
                        Text(placeholder)
                            .font(AppFonts.overusedGroteskMedium(size: 20))
                            .foregroundColor(AppColors.foregroundSecondary)
                            .allowsHitTesting(false)
                    }
                }
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPasswordVisible.toggle()
                    }
                }) {
                    Image(isPasswordVisible ? "eye-off" : "eye")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 16, height: 16)
                        .foregroundColor(CashMonkiDS.Colors.foregroundSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(CashMonkiDS.Colors.surface)
            .cornerRadius(CashMonkiDS.Layout.cornerRadius)
        }
    }
}
