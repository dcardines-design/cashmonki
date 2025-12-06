//
//  DesignSystemRules.swift
//  CashMonki
//
//  Created by Claude on 9/7/25.
//

import SwiftUI

// MARK: - Design System Rules & Guidelines

struct DesignSystemRules {
    
    // MARK: - Component Rules
    enum ComponentRules {
        
        // Input Field Rules
        enum InputField {
            static let rules = [
                "Always use CashMonkiDS.Input components instead of raw TextField",
                "Input titles should use secondary foreground color",
                "Input values should use primary foreground color when filled",
                "Placeholder text should use secondary foreground color",
                "All inputs should be full width by default",
                "Focus states should show primary color border",
                "Helper text should be hidden by default unless specifically needed"
            ]
        }
        
        // Button Rules
        enum Button {
            static let rules = [
                "Use button hierarchy: Primary > Secondary > Tertiary > Ghost > Text",
                "Primary buttons for main actions (Save, Confirm, Submit)",
                "Secondary buttons for alternative actions (Cancel, Back)",
                "Tertiary buttons for less important actions",
                "Ghost buttons for subtle interactions",
                "Text buttons for minimal actions",
                "Icons should be 20px unless specifically sized",
                "Button text should be medium weight font"
            ]
        }
        
        // Layout Rules
        enum Layout {
            static let rules = [
                "Use FullScreenOverlayTemplate for primary editing screens",
                "Use ModalOverlayTemplate for quick actions and selections",
                "Use SettingsOverlayTemplate for list-based navigation",
                "Screen padding should be 20px on sides",
                "Card padding should be 16px",
                "Standard spacing between sections should be 24px",
                "Spacing between related items should be 16px",
                "Small spacing within components should be 8px"
            ]
        }
        
        // Transaction Display Rules
        enum TransactionDisplay {
            static let rules = [
                "Always use UnifiedTransactionDisplay instead of TransactionRow/TransactionTile",
                "Use .row style for list views and tables",
                "Use .tile style for card-based layouts",
                "Use .compact style for widgets and small spaces",
                "Use .detailed style for rich information displays",
                "Always use TxnCategoryIcon for category icons - single source of truth",
                "Transaction amounts should use formatCurrency helper for consistency",
                "Converted amounts should show original currency when available"
            ]
        }
        
        // Icon Rules
        enum Icon {
            static let rules = [
                "Use TxnCategoryIcon for all transaction category displays",
                "Use AppIcon for app-specific icons with SF Symbol fallbacks",
                "Category icons should be consistent across all transaction displays",
                "Never duplicate emoji mapping logic - use TxnCategoryIcon.emojiFor()",
                "Icon sizes: 24px (compact), 34px (standard), 40px+ (detailed)",
                "Always provide fallback system icons"
            ]
        }
    }
    
    // MARK: - Typography Rules
    enum TypographyRules {
        static let rules = [
            "Use Header1 (32px) for screen titles",
            "Use Header2 (24px) for section headings",
            "Use Header3 (20px) for card titles",
            "Use Body (16px) for regular text content",
            "Use Input Large (24px) for main input field values",
            "Use Label (16px) for field labels",
            "Use Caption (12px) for helper text and metadata",
            "Always use OverusedGrotesk font family",
            "Use SemiBold for headers and important text",
            "Use Medium for body text and inputs",
            "Use Regular only for captions and helper text"
        ]
    }
    
    // MARK: - Color Rules
    enum ColorRules {
        static let rules = [
            "Use primary foreground for main content text",
            "Use secondary foreground for labels, placeholders, and helper text",
            "Use primary accent color for interactive elements and focus states",
            "Use surface primary for input backgrounds and cards",
            "Use background white for screen backgrounds",
            "Use line primary for dividers and borders",
            "Text showing 'n/a' should always use secondary foreground color",
            "Empty or placeholder text should use secondary foreground color",
            "Filled input values should use primary foreground color"
        ]
    }
    
    // MARK: - Spacing Rules
    enum SpacingRules {
        static let rules = [
            "XS (4px): Tight spacing within small components",
            "SM (8px): Small spacing between related elements",
            "MD (16px): Standard spacing between components",
            "LG (24px): Section spacing and form field gaps",
            "XL (32px): Major section breaks",
            "XXL (48px): Screen-level spacing",
            "Always use design system spacing values",
            "Avoid arbitrary spacing values"
        ]
    }
    
    // MARK: - Animation Rules
    enum AnimationRules {
        static let rules = [
            "Use quick (0.2s) for immediate feedback like button presses",
            "Use standard (0.3s) for most UI transitions",
            "Use slow (0.5s) for major state changes",
            "Use spring animation for interactive elements",
            "All overlay presentations should be animated",
            "Focus state changes should be quick",
            "Loading states should use standard timing"
        ]
    }
    
    // MARK: - Accessibility Rules
    enum AccessibilityRules {
        static let rules = [
            "All interactive elements should have minimum 44pt touch target",
            "Text should maintain sufficient contrast ratios",
            "Use semantic font sizes that respect system font size settings",
            "Provide meaningful accessibility labels for icons",
            "Ensure keyboard navigation works for all interactive elements",
            "Use system colors when appropriate for better accessibility",
            "Support dark mode if implementing custom colors"
        ]
    }
}

// MARK: - Rule Validation
struct DesignSystemValidator {
    
    // Validate component usage
    static func validateButton(_ button: AppButton) -> [String] {
        let warnings: [String] = []
        
        // Add validation logic here
        // Example: Check if button has appropriate hierarchy
        
        return warnings
    }
    
    static func validateSpacing(_ spacing: CGFloat) -> [String] {
        var warnings: [String] = []
        
        let allowedSpacing: [CGFloat] = [
            CashMonkiDS.Spacing.xs,
            CashMonkiDS.Spacing.sm,
            CashMonkiDS.Spacing.md,
            CashMonkiDS.Spacing.lg,
            CashMonkiDS.Spacing.xl,
            CashMonkiDS.Spacing.xxl
        ]
        
        if !allowedSpacing.contains(spacing) {
            warnings.append("Using non-standard spacing value: \(spacing). Consider using CashMonkiDS.Spacing values.")
        }
        
        return warnings
    }
    
    static func validateColor(_ color: Color) -> [String] {
        let warnings: [String] = []
        
        // Add color validation logic
        // This is tricky with SwiftUI Color, but you could compare against known values
        
        return warnings
    }
}

// MARK: - Documentation Generator
struct DesignSystemDocumentation {
    
    static func generateComponentGuide() -> String {
        return """
        # CashMonki Design System Guide
        
        ## Components
        
        ### Input Fields
        ```swift
        // ✅ Correct usage
        CashMonkiDS.Input.text(title: "Name", text: $name)
        CashMonkiDS.Input.amount(text: $amount)
        CashMonkiDS.Input.date(title: "Date", dateValue: $date)
        
        // ❌ Avoid
        TextField("Name", text: $name) // Use design system components instead
        ```
        
        ### Buttons
        ```swift
        // ✅ Correct usage
        CashMonkiDS.Button.primary("Save") { save() }
        CashMonkiDS.Button.secondary("Cancel") { cancel() }
        
        // ❌ Avoid
        Button("Save") { save() } // Use design system components instead
        ```
        
        ### Layout
        ```swift
        // ✅ Correct usage
        VStack(spacing: CashMonkiDS.Spacing.lg) {
            content
        }
        .screenPadding()
        
        // ❌ Avoid
        VStack(spacing: 25) { // Use standard spacing values
            content
        }
        .padding(.horizontal, 18) // Use standard padding
        ```
        
        ### Typography
        ```swift
        // ✅ Correct usage
        Text("Title").header2()
        Text("Description").bodyText()
        Text("Label").label()
        
        // ❌ Avoid
        Text("Title").font(.custom("SomeFont", size: 22)) // Use design system typography
        ```
        """
    }
    
    static func generateColorGuide() -> String {
        return """
        # Color Usage Guide
        
        - **Primary Foreground**: Main text content, filled input values
        - **Secondary Foreground**: Labels, placeholders, helper text, "n/a" values
        - **Primary Accent**: Interactive elements, focus states, primary buttons
        - **Surface Primary**: Input backgrounds, card backgrounds
        - **Background White**: Screen backgrounds
        - **Line Primary**: Borders, dividers
        """
    }
}

// MARK: - Development Helpers
#if DEBUG
extension View {
    func debugDesignSystem() -> some View {
        self.onAppear {
            print("Design System Debug Info")
            print("- Using CashMonkiDS for consistent styling")
            print("- Check DesignSystemRules for guidelines")
        }
    }
}
#endif