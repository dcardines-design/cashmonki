//
//  ComponentRegistry.swift  
//  CashMonki
//
//  Created by Claude on 9/7/25.
//

import SwiftUI

// MARK: - Component Registry
/// Comprehensive inventory of all available UI components
/// Used to enforce strict reusable UI principles
struct ComponentRegistry {
    
    // MARK: - Component Categories
    
    /// Available input components and their use cases
    enum InputComponents: String, CaseIterable {
        case text = "AppInputField.text"
        case amount = "AppInputField.amount" 
        case merchant = "AppInputField.merchant"
        case search = "AppInputField.search"
        case date = "AppInputField.date"
        
        var description: String {
            switch self {
            case .text: return "Basic text input fields"
            case .amount: return "Currency/amount inputs with formatting"
            case .merchant: return "Merchant name inputs (can hide icons)"
            case .search: return "Search inputs with magnifying glass icon"
            case .date: return "Date picker inputs with consistent styling"
            }
        }
        
        var useCases: [String] {
            switch self {
            case .text: return ["Names", "Notes", "Descriptions", "General text"]
            case .amount: return ["Transaction amounts", "Prices", "Currency values"]
            case .merchant: return ["Business names", "Vendor names", "Store names"]
            case .search: return ["Search fields", "Filter inputs", "Lookup fields"] 
            case .date: return ["Date selection", "Time selection", "DateTime pickers"]
            }
        }
        
        var adaptations: [String] {
            switch self {
            case .text: return ["Modify placeholder", "Toggle required state", "Add validation"]
            case .amount: return ["Change currency", "Modify formatting", "Add validation"]
            case .merchant: return ["Hide icons", "Change helper text", "Modify validation"]
            case .search: return ["Change placeholder", "Modify icon", "Add clear button"]
            case .date: return ["Change format", "Date/time/both components", "Min/max dates"]
            }
        }
    }
    
    /// Available button components and their hierarchy
    enum ButtonComponents: String, CaseIterable {
        case primary = "AppButton.primary"
        case secondary = "AppButton.secondary" 
        case tertiary = "AppButton.tertiary"
        case ghost = "AppButton.ghost"
        case text = "AppButton.text"
        
        var description: String {
            switch self {
            case .primary: return "Main actions - save, confirm, submit"
            case .secondary: return "Alternative actions - cancel, back"
            case .tertiary: return "Less important actions - additional options"
            case .ghost: return "Subtle interactions - minimal emphasis"
            case .text: return "Text-only buttons - inline actions"
            }
        }
        
        var useCases: [String] {
            switch self {
            case .primary: return ["Save", "Confirm", "Submit", "Create", "Login"]
            case .secondary: return ["Cancel", "Back", "Skip", "Alternative action"]
            case .tertiary: return ["Settings", "More options", "Secondary features"]
            case .ghost: return ["Close", "Dismiss", "Subtle toggles"]
            case .text: return ["Links", "Inline actions", "Navigation"]
            }
        }
        
        var adaptations: [String] {
            switch self {
            case .primary: return ["Add left/right icons", "Change text", "Modify colors"]
            case .secondary: return ["Add icons", "Change styling", "Modify emphasis"]
            case .tertiary: return ["Add icons", "Change colors", "Modify size"]
            case .ghost: return ["Add subtle icons", "Change opacity", "Modify interaction"]
            case .text: return ["Change font weight", "Add underline", "Modify color"]
            }
        }
    }
    
    /// Available display components for showing data
    enum DisplayComponents: String, CaseIterable {
        case transactionRow = "UnifiedTransactionDisplay.row"
        case transactionTile = "UnifiedTransactionDisplay.tile"
        case transactionCompact = "UnifiedTransactionDisplay.compact"
        case transactionDetailed = "UnifiedTransactionDisplay.detailed"
        case selectionRow = "SelectionRowItem"
        case categoryIcon = "TxnCategoryIcon"
        case receiptCard = "ReceiptUploadCard"
        
        var description: String {
            switch self {
            case .transactionRow: return "List-style transaction display"
            case .transactionTile: return "Card-style transaction display"
            case .transactionCompact: return "Minimal transaction display for small spaces"
            case .transactionDetailed: return "Rich transaction display with full details"
            case .selectionRow: return "Selection list items with icons and checkmarks"
            case .categoryIcon: return "Transaction category icons with emojis"
            case .receiptCard: return "Specialized receipt upload card component"
            }
        }
        
        var useCases: [String] {
            switch self {
            case .transactionRow: return ["Transaction lists", "History views", "Tables"]
            case .transactionTile: return ["Dashboard cards", "Featured transactions", "Grid views"]
            case .transactionCompact: return ["Widgets", "Summary views", "Sidebar items"]
            case .transactionDetailed: return ["Detail views", "Full information display"]
            case .selectionRow: return ["Settings lists", "Picker options", "Menu items"]
            case .categoryIcon: return ["Transaction categories", "Category displays"]
            case .receiptCard: return ["Upload interfaces", "Receipt-specific actions"]
            }
        }
        
        var adaptations: [String] {
            switch self {
            case .transactionRow: return ["Modify callback", "Change update handler", "Add dividers"]
            case .transactionTile: return ["Modify tap action", "Change card styling", "Add shadows"]
            case .transactionCompact: return ["Modify size", "Change information density"]
            case .transactionDetailed: return ["Add/remove fields", "Modify layout", "Change spacing"]
            case .selectionRow: return ["Change icons", "Modify selection state", "Add custom content"]
            case .categoryIcon: return ["Change size", "Modify background", "Add custom categories"]
            case .receiptCard: return ["Change action", "Modify styling", "Add loading states"]
            }
        }
    }
    
    /// Available layout and container components
    enum LayoutComponents: String, CaseIterable {
        case fullScreenOverlay = "FullScreenOverlayTemplate"
        case modalOverlay = "ModalOverlayTemplate"  
        case settingsOverlay = "SettingsOverlayTemplate"
        case capsuleToggle = "CapsuleToggle"
        case appIcon = "AppIcon"
        
        var description: String {
            switch self {
            case .fullScreenOverlay: return "Full-screen modal with header and actions"
            case .modalOverlay: return "Sheet-style modal with rounded corners"
            case .settingsOverlay: return "Settings-style overlay without confirm button"
            case .capsuleToggle: return "Toggle button with capsule styling"
            case .appIcon: return "App icons with SF Symbol fallbacks"
            }
        }
        
        var useCases: [String] {
            switch self {
            case .fullScreenOverlay: return ["Edit forms", "Creation flows", "Primary actions"]
            case .modalOverlay: return ["Quick edits", "Selections", "Secondary actions"]
            case .settingsOverlay: return ["Settings screens", "Navigation lists", "Info pages"]
            case .capsuleToggle: return ["Option toggles", "Filter buttons", "State switches"]
            case .appIcon: return ["Navigation icons", "Action icons", "Status indicators"]
            }
        }
        
        var adaptations: [String] {
            switch self {
            case .fullScreenOverlay: return ["Change title/confirm text", "Modify actions", "Add validation"]
            case .modalOverlay: return ["Change size", "Modify corner radius", "Add custom content"]
            case .settingsOverlay: return ["Change header", "Modify scrolling", "Add custom layout"]
            case .capsuleToggle: return ["Change colors", "Modify text", "Add icons"]
            case .appIcon: return ["Change fallback", "Modify size", "Add tinting"]
            }
        }
    }
    
    /// Design system constants and utilities
    enum DesignSystemComponents: String, CaseIterable {
        case colors = "CashMonkiDS.Colors"
        case typography = "CashMonkiDS.Typography"
        case spacing = "CashMonkiDS.Spacing"
        case layout = "CashMonkiDS.Layout"
        case animation = "CashMonkiDS.Animation"
        case shadows = "CashMonkiDS.Shadow"
        
        var description: String {
            switch self {
            case .colors: return "App color palette with semantic naming"
            case .typography: return "Font system with consistent sizes and weights"
            case .spacing: return "Standardized spacing values (xs to xxl)"
            case .layout: return "Layout constants for consistent sizing"
            case .animation: return "Standard animation durations and curves"
            case .shadows: return "Predefined shadow styles"
            }
        }
        
        var useCases: [String] {
            switch self {
            case .colors: return ["Text colors", "Background colors", "Accent colors"]
            case .typography: return ["Headers", "Body text", "Labels", "Captions"]
            case .spacing: return ["Padding", "Margins", "Gaps", "Offsets"]
            case .layout: return ["Corner radius", "Heights", "Icon sizes"]
            case .animation: return ["Transitions", "State changes", "Interactions"]
            case .shadows: return ["Cards", "Overlays", "Elevation"]
            }
        }
    }
}

// MARK: - Component Registry Methods
extension ComponentRegistry {
    
    /// Find all components that could handle a specific use case
    static func findComponents(for useCase: String) -> [String] {
        var matches: [String] = []
        
        // Search input components
        for component in InputComponents.allCases {
            if component.useCases.contains(where: { $0.localizedCaseInsensitiveContains(useCase) }) {
                matches.append(component.rawValue)
            }
        }
        
        // Search button components  
        for component in ButtonComponents.allCases {
            if component.useCases.contains(where: { $0.localizedCaseInsensitiveContains(useCase) }) {
                matches.append(component.rawValue)
            }
        }
        
        // Search display components
        for component in DisplayComponents.allCases {
            if component.useCases.contains(where: { $0.localizedCaseInsensitiveContains(useCase) }) {
                matches.append(component.rawValue)
            }
        }
        
        // Search layout components
        for component in LayoutComponents.allCases {
            if component.useCases.contains(where: { $0.localizedCaseInsensitiveContains(useCase) }) {
                matches.append(component.rawValue)
            }
        }
        
        return matches
    }
    
    /// Get component information by name
    static func getComponentInfo(for componentName: String) -> String? {
        // Check input components
        if let input = InputComponents(rawValue: componentName) {
            return "\(input.description)\nUse cases: \(input.useCases.joined(separator: ", "))\nAdaptations: \(input.adaptations.joined(separator: ", "))"
        }
        
        // Check button components
        if let button = ButtonComponents(rawValue: componentName) {
            return "\(button.description)\nUse cases: \(button.useCases.joined(separator: ", "))\nAdaptations: \(button.adaptations.joined(separator: ", "))"
        }
        
        // Check display components
        if let display = DisplayComponents(rawValue: componentName) {
            return "\(display.description)\nUse cases: \(display.useCases.joined(separator: ", "))\nAdaptations: \(display.adaptations.joined(separator: ", "))"
        }
        
        // Check layout components
        if let layout = LayoutComponents(rawValue: componentName) {
            return "\(layout.description)\nUse cases: \(layout.useCases.joined(separator: ", "))\nAdaptations: \(layout.adaptations.joined(separator: ", "))"
        }
        
        return nil
    }
    
    /// List all available components in a category
    static func listAllComponents() -> String {
        var output = "# Available Components\n\n"
        
        output += "## Input Components\n"
        for component in InputComponents.allCases {
            output += "- **\(component.rawValue)**: \(component.description)\n"
        }
        
        output += "\n## Button Components\n" 
        for component in ButtonComponents.allCases {
            output += "- **\(component.rawValue)**: \(component.description)\n"
        }
        
        output += "\n## Display Components\n"
        for component in DisplayComponents.allCases {
            output += "- **\(component.rawValue)**: \(component.description)\n"
        }
        
        output += "\n## Layout Components\n"
        for component in LayoutComponents.allCases {
            output += "- **\(component.rawValue)**: \(component.description)\n"
        }
        
        output += "\n## Design System\n"
        for component in DesignSystemComponents.allCases {
            output += "- **\(component.rawValue)**: \(component.description)\n"
        }
        
        return output
    }
}

// MARK: - Debug Helper
#if DEBUG
extension ComponentRegistry {
    /// Print component registry for debugging
    static func printRegistry() {
        print(listAllComponents())
    }
    
    /// Search for components by keyword
    static func search(_ keyword: String) {
        let matches = findComponents(for: keyword)
        print("Components for '\(keyword)':")
        for match in matches {
            print("- \(match)")
        }
    }
}
#endif