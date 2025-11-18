//
//  StrictUIValidator.swift
//  CashMonki
//
//  Created by Claude on 9/7/25.
//

import SwiftUI

// MARK: - Strict UI Validator
/// Enforces the strict reusable UI principle across the application
/// Prevents creation of new UI components without proper validation
struct StrictUIValidator {
    
    // MARK: - Validation Levels
    enum ValidationLevel {
        case strict    // No new components allowed without approval
        case moderate  // New components allowed with strong justification
        case permissive // New components allowed with basic documentation
    }
    
    // Current validation level (can be configured per build or environment)
    static var currentLevel: ValidationLevel = .strict
    
    // MARK: - Validation Results
    enum ValidationStatus {
        case approved(String)
        case warning(String, suggestion: String?)
        case blocked(String, alternatives: [String])
        case requiresApproval(String, reason: String)
    }
    
    // MARK: - Component Validation
    
    /// Validates if a new component should be created or if existing components should be used
    /// Call this before creating any new SwiftUI View struct
    static func validateNewComponent(
        name: String,
        purpose: String,
        useCases: [String] = [],
        justification: String = ""
    ) -> ValidationStatus {
        
        // Check if component already exists
        if componentExists(name) {
            return .blocked(
                "Component '\(name)' already exists in the design system",
                alternatives: ["Use existing '\(name)' component", "Extend existing component with new functionality"]
            )
        }
        
        // Check if similar functionality exists
        let similarComponents = findSimilarComponents(for: purpose, useCases: useCases)
        
        if !similarComponents.isEmpty {
            let primaryAlternative = similarComponents.first!
            return .blocked(
                "Similar functionality exists in '\(primaryAlternative)'. New component '\(name)' is not needed.",
                alternatives: similarComponents + ["Adapt existing component with parameters"]
            )
        }
        
        // Check against current validation level
        switch currentLevel {
        case .strict:
            return .requiresApproval(
                "Strict mode: All new components require explicit approval",
                reason: "No existing component covers use case: \(purpose)"
            )
            
        case .moderate:
            if justification.count < 50 {
                return .requiresApproval(
                    "Moderate mode: New component requires detailed justification (min 50 chars)",
                    reason: "Provided justification: '\(justification)' is insufficient"
                )
            }
            return .approved("New component approved with justification")
            
        case .permissive:
            if purpose.isEmpty {
                return .warning(
                    "Purpose documentation required for new component",
                    suggestion: "Add clear purpose description for component '\(name)'"
                )
            }
            return .approved("New component approved in permissive mode")
        }
    }
    
    /// Validates component usage in views
    /// Call this to check if a component is being used appropriately
    static func validateComponentUsage(
        component: String,
        context: String,
        parameters: [String: Any] = [:]
    ) -> ValidationStatus {
        
        // Check if component exists
        guard componentExists(component) else {
            return .blocked(
                "Component '\(component)' not found in design system",
                alternatives: findAlternativeComponents(for: context)
            )
        }
        
        // Validate component matches context
        let recommendation = ComponentSelectionGuide.findComponent(for: context)
        
        if let recommendedComponent = recommendation.component {
            if recommendedComponent == component {
                return .approved("Perfect component match for context")
            } else if recommendation.alternatives.contains(component) {
                return .warning(
                    "Component works but '\(recommendedComponent)' would be more appropriate",
                    suggestion: "Consider using recommended component for better semantic fit"
                )
            } else {
                return .warning(
                    "Component may not be ideal for this context",
                    suggestion: "Recommended: '\(recommendedComponent)' instead of '\(component)'"
                )
            }
        }
        
        return .approved("Component usage validated")
    }
    
    /// Validates view hierarchy for proper component usage
    /// Checks if custom views should use existing components instead
    static func validateViewHierarchy(_ viewName: String, contains elements: [String]) -> ValidationStatus {
        
        var violations: [String] = []
        var suggestions: [String] = []
        
        // Check for common patterns that should use existing components
        if elements.contains("TextField") || elements.contains("TextEditor") {
            if !elements.contains("AppInputField") {
                violations.append("Raw TextField/TextEditor usage detected")
                suggestions.append("Use AppInputField component family for consistent styling")
            }
        }
        
        if elements.contains("Button") {
            if !elements.contains("AppButton") {
                violations.append("Raw Button usage detected")
                suggestions.append("Use AppButton component family for consistent styling")
            }
        }
        
        if elements.contains("Image") && !elements.contains("AppIcon") {
            violations.append("Raw Image usage for icons detected")
            suggestions.append("Use AppIcon component for vector assets with fallbacks")
        }
        
        // Check for hardcoded values that should use design system
        if elements.contains("hardcoded-color") {
            violations.append("Hardcoded color values detected")
            suggestions.append("Use AppColors or CashMonkiDS.Colors for consistent theming")
        }
        
        if elements.contains("hardcoded-font") {
            violations.append("Hardcoded font usage detected")
            suggestions.append("Use CashMonkiDS.Typography for consistent font system")
        }
        
        if elements.contains("hardcoded-spacing") {
            violations.append("Hardcoded spacing values detected")
            suggestions.append("Use CashMonkiDS.Spacing for consistent spacing system")
        }
        
        // Return results
        if !violations.isEmpty {
            return .blocked(
                "View '\(viewName)' violates component usage rules: \(violations.joined(separator: ", "))",
                alternatives: suggestions
            )
        }
        
        return .approved("View hierarchy follows component usage rules")
    }
    
    // MARK: - Design System Validation
    
    /// Validates color usage against design system
    static func validateColorUsage(_ colorValue: String, context: String) -> ValidationStatus {
        
        let designSystemColors = [
            "AppColors.foregroundPrimary",
            "AppColors.foregroundSecondary", 
            "AppColors.surfacePrimary",
            "AppColors.backgroundWhite",
            "AppColors.accentBackground",
            "AppColors.linePrimary",
            "CashMonkiDS.Colors.primary",
            "CashMonkiDS.Colors.foreground",
            "CashMonkiDS.Colors.surface",
            "CashMonkiDS.Colors.background"
        ]
        
        // Check if using design system colors
        if designSystemColors.contains(colorValue) {
            return .approved("Using design system color")
        }
        
        // Check for hardcoded RGB/hex values
        if colorValue.contains("Color(red:") || colorValue.contains("#") || colorValue.contains("0x") {
            return .blocked(
                "Hardcoded color value detected: \(colorValue)",
                alternatives: ["Use AppColors semantic names", "Use CashMonkiDS.Colors", "Add color to design system if needed"]
            )
        }
        
        // Check for system colors that might be replaced
        if colorValue.contains("Color.") || colorValue.contains(".systemBackground") {
            return .warning(
                "System color usage: \(colorValue)",
                suggestion: "Consider using design system colors for consistency"
            )
        }
        
        return .approved("Color usage acceptable")
    }
    
    /// Validates font usage against design system
    static func validateFontUsage(_ fontValue: String) -> ValidationStatus {
        
        let designSystemFonts = [
            "CashMonkiDS.Typography.header1",
            "CashMonkiDS.Typography.header2", 
            "CashMonkiDS.Typography.header3",
            "CashMonkiDS.Typography.body",
            "CashMonkiDS.Typography.bodyLarge",
            "CashMonkiDS.Typography.bodySmall",
            "CashMonkiDS.Typography.inputLarge",
            "CashMonkiDS.Typography.inputMedium",
            "CashMonkiDS.Typography.label",
            "CashMonkiDS.Typography.labelSmall",
            "CashMonkiDS.Typography.caption"
        ]
        
        // Check if using design system fonts
        if designSystemFonts.contains(fontValue) {
            return .approved("Using design system typography")
        }
        
        // Check for OverusedGrotesk usage (acceptable)
        if fontValue.contains("OverusedGrotesk") {
            return .approved("Using brand font family")
        }
        
        // Check for system fonts
        if fontValue.contains("Font.system") || fontValue.contains(".font(") {
            return .warning(
                "System font usage: \(fontValue)",
                suggestion: "Consider using CashMonkiDS.Typography for consistency"
            )
        }
        
        return .approved("Font usage acceptable")
    }
    
    /// Validates spacing usage against design system
    static func validateSpacingUsage(_ spacingValue: String) -> ValidationStatus {
        
        let designSystemSpacing = [
            "CashMonkiDS.Spacing.xs",
            "CashMonkiDS.Spacing.sm",
            "CashMonkiDS.Spacing.md",
            "CashMonkiDS.Spacing.lg",
            "CashMonkiDS.Spacing.xl",
            "CashMonkiDS.Spacing.xxl"
        ]
        
        // Check if using design system spacing
        if designSystemSpacing.contains(spacingValue) {
            return .approved("Using design system spacing")
        }
        
        // Check for hardcoded numeric values
        if spacingValue.matches("^\\d+(\\.\\d+)?$") {
            return .warning(
                "Hardcoded spacing value: \(spacingValue)",
                suggestion: "Use CashMonkiDS.Spacing constants for consistency"
            )
        }
        
        return .approved("Spacing usage acceptable")
    }
    
    // MARK: - Helper Methods
    
    private static func componentExists(_ name: String) -> Bool {
        let allComponents = getAllComponents()
        return allComponents.contains(name) || 
               allComponents.contains { $0.hasSuffix(".\(name)") } ||
               name.hasPrefix("App") || // AppButton, AppInputField, etc.
               name.hasPrefix("Unified") || // UnifiedTransactionDisplay
               name.hasSuffix("Template") // Overlay templates
    }
    
    private static func findSimilarComponents(for purpose: String, useCases: [String]) -> [String] {
        // Use ComponentRegistry to find similar components
        var similarComponents: [String] = []
        
        // Check purpose against use cases
        similarComponents.append(contentsOf: ComponentRegistry.findComponents(for: purpose))
        
        // Check individual use cases
        for useCase in useCases {
            similarComponents.append(contentsOf: ComponentRegistry.findComponents(for: useCase))
        }
        
        // Remove duplicates and return
        return Array(Set(similarComponents))
    }
    
    private static func findAlternativeComponents(for context: String) -> [String] {
        let recommendation = ComponentSelectionGuide.findComponent(for: context)
        
        var alternatives: [String] = []
        if let component = recommendation.component {
            alternatives.append(component)
        }
        alternatives.append(contentsOf: recommendation.alternatives)
        
        return alternatives
    }
    
    private static func getAllComponents() -> [String] {
        var components: [String] = []
        components.append(contentsOf: ComponentRegistry.InputComponents.allCases.map(\.rawValue))
        components.append(contentsOf: ComponentRegistry.ButtonComponents.allCases.map(\.rawValue))
        components.append(contentsOf: ComponentRegistry.DisplayComponents.allCases.map(\.rawValue))
        components.append(contentsOf: ComponentRegistry.LayoutComponents.allCases.map(\.rawValue))
        components.append(contentsOf: ComponentRegistry.DesignSystemComponents.allCases.map(\.rawValue))
        return components
    }
}

// MARK: - Validation Helpers
extension String {
    func matches(_ regex: String) -> Bool {
        return range(of: regex, options: .regularExpression) != nil
    }
}

// MARK: - ViewBuilder Validation Extensions
extension StrictUIValidator {
    
    /// Validates SwiftUI view construction for compliance
    /// Use this in custom views to ensure proper component usage
    static func validateViewConstruction<V: View>(
        _ view: V,
        componentName: String,
        purpose: String
    ) -> ValidationStatus {
        
        // This would ideally use reflection to analyze the view hierarchy
        // For now, provide basic validation guidance
        
        let viewDescription = String(describing: type(of: view))
        
        // Check if this is a basic SwiftUI component being used directly
        if viewDescription.contains("Button") && !componentName.contains("AppButton") {
            return .blocked(
                "Direct Button usage detected in '\(componentName)'",
                alternatives: ["Use AppButton component family", "Wrap in appropriate AppButton variant"]
            )
        }
        
        if viewDescription.contains("TextField") && !componentName.contains("AppInputField") {
            return .blocked(
                "Direct TextField usage detected in '\(componentName)'",
                alternatives: ["Use AppInputField component family", "Wrap in appropriate input component"]
            )
        }
        
        return .approved("View construction follows component guidelines")
    }
}

// MARK: - Compile-Time Validation (Macros placeholder)
// Note: In a real implementation, these would be Swift macros for compile-time checking
extension StrictUIValidator {
    
    /// Placeholder for compile-time component validation
    /// In future Swift versions, this could be a macro that validates at compile time
    static func requireComponentValidation(
        _ component: String,
        purpose: String,
        file: String = #file,
        line: Int = #line
    ) {
        #if DEBUG
        let status = validateNewComponent(name: component, purpose: purpose)
        
        switch status {
        case .blocked(let message, let alternatives):
            print("⛔ COMPONENT VALIDATION ERROR at \(file):\(line)")
            print("   \(message)")
            print("   Alternatives: \(alternatives.joined(separator: ", "))")
            
        case .requiresApproval(let message, let reason):
            print("🛑 COMPONENT APPROVAL REQUIRED at \(file):\(line)")
            print("   \(message)")
            print("   Reason: \(reason)")
            
        case .warning(let message, let suggestion):
            print("⚠️ COMPONENT WARNING at \(file):\(line)")
            print("   \(message)")
            if let suggestion = suggestion {
                print("   Suggestion: \(suggestion)")
            }
            
        case .approved(let message):
            print("✅ COMPONENT APPROVED at \(file):\(line): \(message)")
        }
        #endif
    }
}

// MARK: - Runtime Validation for Development
#if DEBUG
extension StrictUIValidator {
    
    /// Development-time component audit
    /// Call this to audit your entire view hierarchy for compliance
    static func auditAppCompliance() {
        print("=== STRICT UI COMPLIANCE AUDIT ===")
        
        // This would ideally traverse all registered views
        // For now, provide guidance on manual checks
        
        print("Manual audit checklist:")
        print("□ All text inputs use AppInputField")
        print("□ All buttons use AppButton")
        print("□ All icons use AppIcon")
        print("□ All colors use AppColors/CashMonkiDS.Colors")
        print("□ All fonts use CashMonkiDS.Typography")
        print("□ All spacing uses CashMonkiDS.Spacing")
        print("□ All overlays use Template components")
        print("□ All transaction displays use UnifiedTransactionDisplay")
        
        print("\nUse StrictUIValidator.validateComponentUsage() for specific components")
        print("Use ComponentSelectionGuide.quickFind() for component recommendations")
    }
    
    /// Test validation functions
    static func testValidation() {
        print("\n=== TESTING STRICT UI VALIDATOR ===")
        
        // Test new component validation
        let testComponents = [
            ("CustomButton", "button for special action", []),
            ("TransactionCard", "display transaction", ["transaction", "display"]),
            ("SpecialInput", "unique input field", ["input", "special"])
        ]
        
        for (name, purpose, useCases) in testComponents {
            print("\n--- Testing component: \(name) ---")
            let result = validateNewComponent(name: name, purpose: purpose, useCases: useCases)
            print(formatValidationStatus(result))
        }
        
        // Test component usage validation
        let usageTests = [
            ("AppButton.primary", "save button"),
            ("CustomComponent", "unknown usage"),
            ("AppInputField.text", "name input")
        ]
        
        for (component, context) in usageTests {
            print("\n--- Testing usage: \(component) for \(context) ---")
            let result = validateComponentUsage(component: component, context: context)
            print(formatValidationStatus(result))
        }
    }
    
    private static func formatValidationStatus(_ status: ValidationStatus) -> String {
        switch status {
        case .approved(let message):
            return "✅ APPROVED: \(message)"
            
        case .warning(let message, let suggestion):
            var result = "⚠️ WARNING: \(message)"
            if let suggestion = suggestion {
                result += "\n   💡 Suggestion: \(suggestion)"
            }
            return result
            
        case .blocked(let message, let alternatives):
            var result = "⛔ BLOCKED: \(message)"
            if !alternatives.isEmpty {
                result += "\n   🔄 Alternatives: \(alternatives.joined(separator: ", "))"
            }
            return result
            
        case .requiresApproval(let message, let reason):
            return "🛑 REQUIRES APPROVAL: \(message)\n   📝 Reason: \(reason)"
        }
    }
}
#endif

// MARK: - Integration with SwiftUI Previews
#if DEBUG
extension View {
    /// Development helper to validate component usage in previews
    func validateStrictUI(
        componentName: String,
        purpose: String
    ) -> some View {
        let _ = StrictUIValidator.requireComponentValidation(componentName, purpose: purpose)
        return self
    }
}
#endif