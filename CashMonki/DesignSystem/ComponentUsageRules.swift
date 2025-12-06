//
//  ComponentUsageRules.swift
//  CashMonki
//
//  Created by Claude on 9/7/25.
//

import SwiftUI

// MARK: - Component Usage Rules
/// Defines and enforces strict rules for UI component usage
/// Ensures consistent application of the reusable UI principle
struct ComponentUsageRules {
    
    // MARK: - Rule Categories
    
    /// Core rules that must never be violated
    enum CoreRules: String, CaseIterable {
        case noRawSwiftUIComponents = "No raw SwiftUI components (Button, TextField, etc.) without design system wrapper"
        case useExistingComponentsFirst = "Always check existing components before creating new ones"
        case followDesignSystemColors = "Use AppColors/CashMonkiDS.Colors only, no hardcoded colors"
        case followDesignSystemFonts = "Use CashMonkiDS.Typography only, no hardcoded fonts"
        case followDesignSystemSpacing = "Use CashMonkiDS.Spacing constants, no magic numbers"
        case documentNewComponents = "All new components require documentation and approval"
        
        var description: String {
            switch self {
            case .noRawSwiftUIComponents:
                return "Wrap all basic SwiftUI components (Button, TextField, Image) in design system components"
            case .useExistingComponentsFirst:
                return "Before creating new components, verify no existing component can be adapted"
            case .followDesignSystemColors:
                return "Use semantic color names from AppColors, never Color(red:), #hexColors, or hardcoded values"
            case .followDesignSystemFonts:
                return "Use CashMonkiDS.Typography constants, never Font.system() or hardcoded font names"
            case .followDesignSystemSpacing:
                return "Use CashMonkiDS.Spacing (xs/sm/md/lg/xl/xxl), never hardcoded padding/spacing numbers"
            case .documentNewComponents:
                return "New components need: purpose, use cases, adaptation options, and team approval"
            }
        }
        
        var enforcement: EnforcementLevel {
            return .blocking // Core rules are always blocking
        }
    }
    
    /// Component-specific usage rules
    enum ComponentRules: String, CaseIterable {
        case inputFieldsUseAppInputField = "All text input fields must use AppInputField family"
        case buttonsUseAppButton = "All buttons must use AppButton hierarchy (primary/secondary/tertiary/ghost/text)"
        case iconsUseAppIcon = "All icons must use AppIcon with fallback system names"
        case transactionsUseUnified = "All transaction displays must use UnifiedTransactionDisplay"
        case overlaysUseTemplates = "All modal/overlay screens must use overlay templates"
        case categoriesUseTxnIcon = "Transaction categories must use TxnCategoryIcon component"
        case selectionsUseRowItem = "Selection lists must use SelectionRowItem component"
        
        var description: String {
            switch self {
            case .inputFieldsUseAppInputField:
                return "TextField/TextEditor → AppInputField.text/amount/merchant/search/date"
            case .buttonsUseAppButton:
                return "Button → AppButton.primary/secondary/tertiary/ghost/text based on hierarchy"
            case .iconsUseAppIcon:
                return "Image(systemName:) → AppIcon(assetName:, fallbackSystemName:)"
            case .transactionsUseUnified:
                return "Custom transaction views → UnifiedTransactionDisplay.row/tile/compact/detailed"
            case .overlaysUseTemplates:
                return "Custom overlays → FullScreenOverlayTemplate/ModalOverlayTemplate/SettingsOverlayTemplate"
            case .categoriesUseTxnIcon:
                return "Custom category icons → TxnCategoryIcon with standardized emoji system"
            case .selectionsUseRowItem:
                return "Custom selection rows → SelectionRowItem with icon/title/selection state"
            }
        }
        
        var allowedExceptions: [String] {
            switch self {
            case .inputFieldsUseAppInputField:
                return ["Search bars in navigation", "Inline editing in complex layouts"]
            case .buttonsUseAppButton:
                return ["Custom gesture recognizers", "Complex interactive elements"]
            case .iconsUseAppIcon:
                return ["Decorative graphics", "Complex illustrations"]
            case .transactionsUseUnified:
                return ["Dashboard summary cards", "Chart/graph elements"]
            case .overlaysUseTemplates:
                return ["System alerts", "Third-party integrations"]
            case .categoriesUseTxnIcon:
                return ["Custom category creation flow", "Admin interfaces"]
            case .selectionsUseRowItem:
                return ["Complex multi-selection interfaces", "Custom picker styles"]
            }
        }
        
        var enforcement: EnforcementLevel {
            return .warning // Component rules can be warnings with justification
        }
    }
    
    /// Design system consistency rules
    enum DesignSystemRules: String, CaseIterable {
        case maintainVisualHierarchy = "Follow button hierarchy: primary > secondary > tertiary > ghost > text"
        case consistentSpacing = "Use consistent spacing scale throughout interface"
        case semanticColorUsage = "Use semantic color names (foregroundPrimary, not specific RGB values)"
        case typographyScale = "Follow typography hierarchy: header1-3 > body variants > labels > caption"
        case cornerRadiusConsistency = "Use consistent corner radius from Layout constants"
        case shadowConsistency = "Use predefined shadow styles (small/medium/large)"
        
        var description: String {
            switch self {
            case .maintainVisualHierarchy:
                return "Most important actions use primary buttons, less important use secondary, etc."
            case .consistentSpacing:
                return "Stick to xs(4), sm(8), md(16), lg(24), xl(32), xxl(48) spacing values"
            case .semanticColorUsage:
                return "foregroundPrimary for main text, foregroundSecondary for labels, etc."
            case .typographyScale:
                return "header1 for main titles, body for content, label for field labels, caption for small text"
            case .cornerRadiusConsistency:
                return "Use Layout.cornerRadius(10) or cornerRadiusSmall(8)/Large(16)"
            case .shadowConsistency:
                return "Use Shadow.small/medium/large instead of custom shadow values"
            }
        }
        
        var enforcement: EnforcementLevel {
            return .advisory // Design rules are advisory but should be followed
        }
    }
    
    // MARK: - Enforcement Levels
    enum EnforcementLevel {
        case blocking    // Prevents compilation/runtime in strict mode
        case warning     // Shows warning but allows execution
        case advisory    // Best practice guidance only
        
        var description: String {
            switch self {
            case .blocking: return "BLOCKED - Must be fixed"
            case .warning: return "WARNING - Should be addressed"
            case .advisory: return "ADVISORY - Best practice"
            }
        }
        
        var emoji: String {
            switch self {
            case .blocking: return "🛑"
            case .warning: return "⚠️"
            case .advisory: return "💡"
            }
        }
    }
    
    // MARK: - Rule Enforcement
    
    /// Check all rules against a component usage
    static func enforceRules(
        for component: String,
        in context: String
    ) -> [RuleViolation] {
        
        var violations: [RuleViolation] = []
        
        // Check core rules
        violations.append(contentsOf: checkCoreRules(component: component, context: context))
        
        // Check component-specific rules
        violations.append(contentsOf: checkComponentRules(component: component, context: context))
        
        // Check design system rules
        violations.append(contentsOf: checkDesignSystemRules(component: component, context: context))
        
        return violations
    }
    
    /// Specific rule checks for new component creation
    static func enforceNewComponentRules(
        name: String,
        purpose: String,
        justification: String,
        hasDocumentation: Bool
    ) -> [RuleViolation] {
        
        var violations: [RuleViolation] = []
        
        // Check if existing components could be used
        let existingComponents = ComponentRegistry.findComponents(for: purpose)
        if !existingComponents.isEmpty {
            violations.append(RuleViolation(
                rule: CoreRules.useExistingComponentsFirst.rawValue,
                severity: .blocking,
                message: "Existing components found: \(existingComponents.joined(separator: ", "))",
                suggestion: "Adapt existing components instead of creating '\(name)'",
                context: "New component: \(name)"
            ))
        }
        
        // Check documentation requirement
        if !hasDocumentation {
            violations.append(RuleViolation(
                rule: CoreRules.documentNewComponents.rawValue,
                severity: .blocking,
                message: "New component '\(name)' lacks required documentation",
                suggestion: "Add purpose, use cases, adaptations, and team approval documentation",
                context: "New component creation"
            ))
        }
        
        // Check justification quality
        if justification.count < 100 {
            violations.append(RuleViolation(
                rule: CoreRules.documentNewComponents.rawValue,
                severity: .warning,
                message: "Insufficient justification for new component '\(name)'",
                suggestion: "Provide detailed justification (min 100 characters) explaining why existing components cannot be adapted",
                context: "Component justification: \(justification.count) chars"
            ))
        }
        
        return violations
    }
    
    // MARK: - Rule Checking Implementation
    
    private static func checkCoreRules(component: String, context: String) -> [RuleViolation] {
        var violations: [RuleViolation] = []
        
        // Check for raw SwiftUI component usage
        let rawComponents = ["Button", "TextField", "TextEditor", "Image", "Picker", "Toggle"]
        for rawComponent in rawComponents {
            if component.contains(rawComponent) && !component.contains("App") && !component.contains("Unified") {
                violations.append(RuleViolation(
                    rule: CoreRules.noRawSwiftUIComponents.rawValue,
                    severity: .blocking,
                    message: "Raw \(rawComponent) usage detected",
                    suggestion: "Use design system wrapper: App\(rawComponent) or appropriate component family",
                    context: context
                ))
            }
        }
        
        // Check for hardcoded colors
        if context.contains("Color(red:") || context.contains("#") || context.contains("0x") {
            violations.append(RuleViolation(
                rule: CoreRules.followDesignSystemColors.rawValue,
                severity: .blocking,
                message: "Hardcoded color values detected",
                suggestion: "Use AppColors or CashMonkiDS.Colors semantic names",
                context: context
            ))
        }
        
        // Check for hardcoded fonts
        if context.contains("Font.system") || context.contains(".font(.") {
            violations.append(RuleViolation(
                rule: CoreRules.followDesignSystemFonts.rawValue,
                severity: .warning,
                message: "System font usage detected",
                suggestion: "Use CashMonkiDS.Typography constants",
                context: context
            ))
        }
        
        return violations
    }
    
    private static func checkComponentRules(component: String, context: String) -> [RuleViolation] {
        var violations: [RuleViolation] = []
        
        // Check input field rules
        if (context.contains("input") || context.contains("field") || context.contains("text")) {
            if !component.contains("AppInputField") {
                violations.append(RuleViolation(
                    rule: ComponentRules.inputFieldsUseAppInputField.rawValue,
                    severity: .warning,
                    message: "Text input should use AppInputField family",
                    suggestion: "Use AppInputField.text/amount/merchant/search/date",
                    context: context,
                    alternatives: ["AppInputField.text", "AppInputField.amount", "AppInputField.merchant"]
                ))
            }
        }
        
        // Check button rules
        if (context.contains("button") || context.contains("action") || context.contains("tap")) {
            if !component.contains("AppButton") && !component.contains("CapsuleToggle") {
                violations.append(RuleViolation(
                    rule: ComponentRules.buttonsUseAppButton.rawValue,
                    severity: .warning,
                    message: "Button should use AppButton hierarchy",
                    suggestion: "Use AppButton.primary/secondary/tertiary/ghost/text based on importance",
                    context: context,
                    alternatives: ["AppButton.primary", "AppButton.secondary", "CapsuleToggle"]
                ))
            }
        }
        
        // Check transaction display rules
        if (context.contains("transaction") || context.contains("txn")) {
            if !component.contains("UnifiedTransactionDisplay") {
                violations.append(RuleViolation(
                    rule: ComponentRules.transactionsUseUnified.rawValue,
                    severity: .warning,
                    message: "Transaction display should use UnifiedTransactionDisplay",
                    suggestion: "Use UnifiedTransactionDisplay.row/tile/compact/detailed",
                    context: context,
                    alternatives: ["UnifiedTransactionDisplay.row", "UnifiedTransactionDisplay.tile"]
                ))
            }
        }
        
        return violations
    }
    
    private static func checkDesignSystemRules(component: String, context: String) -> [RuleViolation] {
        var violations: [RuleViolation] = []
        
        // Check spacing consistency
        if context.contains("padding") || context.contains("spacing") {
            // Look for hardcoded numbers
            let spacingPattern = "\\d+(\\.\\d+)?"
            if context.matches(spacingPattern) && !context.contains("CashMonkiDS.Spacing") {
                violations.append(RuleViolation(
                    rule: DesignSystemRules.consistentSpacing.rawValue,
                    severity: .advisory,
                    message: "Consider using design system spacing",
                    suggestion: "Use CashMonkiDS.Spacing constants (xs/sm/md/lg/xl/xxl)",
                    context: context
                ))
            }
        }
        
        // Check typography hierarchy
        if context.contains("font") || context.contains("Font.") {
            if !context.contains("CashMonkiDS.Typography") && !context.contains("OverusedGrotesk") {
                violations.append(RuleViolation(
                    rule: DesignSystemRules.typographyScale.rawValue,
                    severity: .advisory,
                    message: "Consider using design system typography",
                    suggestion: "Use CashMonkiDS.Typography hierarchy",
                    context: context
                ))
            }
        }
        
        return violations
    }
    
    // MARK: - Rule Violation Structure
    struct RuleViolation {
        let rule: String
        let severity: EnforcementLevel
        let message: String
        let suggestion: String
        let context: String
        var alternatives: [String] = []
        
        var formattedMessage: String {
            var result = "\(severity.emoji) \(severity.description): \(message)"
            result += "\n📝 Rule: \(rule)"
            result += "\n🎯 Context: \(context)"
            result += "\n💡 Suggestion: \(suggestion)"
            
            if !alternatives.isEmpty {
                result += "\n🔄 Alternatives: \(alternatives.joined(separator: ", "))"
            }
            
            return result
        }
    }
    
    // MARK: - Rule Exemption System
    
    /// Request exemption from a specific rule
    static func requestExemption(
        from rule: String,
        reason: String,
        component: String,
        approver: String? = nil
    ) -> ExemptionRequest {
        return ExemptionRequest(
            rule: rule,
            reason: reason,
            component: component,
            approver: approver,
            requestDate: Date(),
            status: .pending
        )
    }
    
    struct ExemptionRequest {
        let rule: String
        let reason: String
        let component: String
        let approver: String?
        let requestDate: Date
        var status: ExemptionStatus
        var approvalDate: Date?
        
        enum ExemptionStatus {
            case pending, approved, denied, expired
        }
        
        var isValid: Bool {
            switch status {
            case .approved:
                // Exemptions expire after 90 days
                if let approvalDate = approvalDate {
                    return Date().timeIntervalSince(approvalDate) < 90 * 24 * 60 * 60
                }
                return false
            case .pending, .denied, .expired:
                return false
            }
        }
    }
    
    // MARK: - Bulk Rule Validation
    
    /// Validate an entire view file against all rules
    static func validateViewFile(
        content: String,
        fileName: String
    ) -> ComponentUsageAudit {
        
        var violations: [RuleViolation] = []
        
        // Parse content for rule violations (simplified implementation)
        let lines = content.components(separatedBy: .newlines)
        
        for (lineNumber, line) in lines.enumerated() {
            let lineContext = "File: \(fileName), Line: \(lineNumber + 1)"
            
            // Check for raw SwiftUI components
            let rawComponents = ["Button(", "TextField(", "Image(systemName:", "Picker("]
            for rawComponent in rawComponents {
                if line.contains(rawComponent) {
                    violations.append(RuleViolation(
                        rule: CoreRules.noRawSwiftUIComponents.rawValue,
                        severity: .blocking,
                        message: "Raw SwiftUI component usage: \(rawComponent)",
                        suggestion: "Use design system equivalent",
                        context: lineContext
                    ))
                }
            }
            
            // Check for hardcoded colors
            if line.contains("Color(red:") || line.contains("#") {
                violations.append(RuleViolation(
                    rule: CoreRules.followDesignSystemColors.rawValue,
                    severity: .blocking,
                    message: "Hardcoded color detected",
                    suggestion: "Use AppColors or CashMonkiDS.Colors",
                    context: lineContext
                ))
            }
            
            // Check for hardcoded spacing
            if line.contains(".padding(") && line.matches("padding\\(\\d+") {
                violations.append(RuleViolation(
                    rule: CoreRules.followDesignSystemSpacing.rawValue,
                    severity: .warning,
                    message: "Hardcoded padding detected",
                    suggestion: "Use CashMonkiDS.Spacing constants",
                    context: lineContext
                ))
            }
        }
        
        return ComponentUsageAudit(
            fileName: fileName,
            totalLines: lines.count,
            violations: violations,
            auditDate: Date()
        )
    }
    
    struct ComponentUsageAudit {
        let fileName: String
        let totalLines: Int
        let violations: [RuleViolation]
        let auditDate: Date
        
        var complianceScore: Double {
            let blockingViolations = violations.filter { $0.severity == .blocking }.count
            let warningViolations = violations.filter { $0.severity == .warning }.count
            let advisoryViolations = violations.filter { $0.severity == .advisory }.count
            
            // Scoring: blocking = -10, warning = -3, advisory = -1
            let penaltyPoints = (blockingViolations * 10) + (warningViolations * 3) + advisoryViolations
            let maxScore = 100.0
            
            return max(0, maxScore - Double(penaltyPoints))
        }
        
        var formattedReport: String {
            var report = "=== COMPONENT USAGE AUDIT: \(fileName) ===\n"
            report += "📊 Compliance Score: \(String(format: "%.1f", complianceScore))%\n"
            report += "📄 Total Lines: \(totalLines)\n"
            report += "🚨 Total Violations: \(violations.count)\n\n"
            
            let groupedViolations = Dictionary(grouping: violations) { $0.severity }
            
            for severity in [EnforcementLevel.blocking, .warning, .advisory] {
                if let violationsForSeverity = groupedViolations[severity] {
                    report += "\(severity.emoji) \(severity.description) (\(violationsForSeverity.count)):\n"
                    for violation in violationsForSeverity {
                        report += "   • \(violation.message) - \(violation.context)\n"
                    }
                    report += "\n"
                }
            }
            
            return report
        }
    }
}

// MARK: - Quick Access Functions
extension ComponentUsageRules {
    
    /// Quick rule check for development
    static func quickCheck(component: String, context: String) -> String {
        let violations = enforceRules(for: component, in: context)
        
        if violations.isEmpty {
            return "✅ Component usage follows all rules"
        }
        
        var result = "Found \(violations.count) rule violation(s):\n\n"
        for violation in violations {
            result += violation.formattedMessage + "\n\n"
        }
        
        return result
    }
    
    /// Get all rules as documentation
    static func getAllRules() -> String {
        var documentation = "# Component Usage Rules\n\n"
        
        documentation += "## Core Rules (Must Follow)\n"
        for rule in CoreRules.allCases {
            documentation += "- **\(rule.rawValue)**: \(rule.description)\n"
        }
        
        documentation += "\n## Component Rules (Should Follow)\n"
        for rule in ComponentRules.allCases {
            documentation += "- **\(rule.rawValue)**: \(rule.description)\n"
            if !rule.allowedExceptions.isEmpty {
                documentation += "  - Exceptions: \(rule.allowedExceptions.joined(separator: ", "))\n"
            }
        }
        
        documentation += "\n## Design System Rules (Best Practices)\n"
        for rule in DesignSystemRules.allCases {
            documentation += "- **\(rule.rawValue)**: \(rule.description)\n"
        }
        
        return documentation
    }
}

// MARK: - Development Helper
#if DEBUG
extension ComponentUsageRules {
    /// Test rule enforcement
    static func testRuleEnforcement() {
        print("=== TESTING COMPONENT USAGE RULES ===")
        
        let testCases = [
            ("Button", "save action", []),
            ("AppButton.primary", "save action", []),
            ("TextField", "name input", []),
            ("CustomComponent", "special use case", ["AppInputField.text"])
        ]
        
        for (component, context, _) in testCases {
            print("\n--- Testing: \(component) for \(context) ---")
            print(quickCheck(component: component, context: context))
        }
    }
}
#endif