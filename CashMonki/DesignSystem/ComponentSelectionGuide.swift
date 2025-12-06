//
//  ComponentSelectionGuide.swift
//  CashMonki
//
//  Created by Claude on 9/7/25.
//

import SwiftUI

// MARK: - Component Selection Decision Tree
/// Provides intelligent guidance for component selection based on use cases
/// Enforces the strict UI principle: use existing components before creating new ones
struct ComponentSelectionGuide {
    
    // MARK: - Decision Tree Node
    struct DecisionNode {
        let question: String
        let options: [String: DecisionResult]
        
        enum DecisionResult {
            case component(String, adaptations: [String] = [])
            case nextQuestion(DecisionNode)
            case requiresApproval(String, reason: String)
        }
    }
    
    // MARK: - Main Decision Tree
    static let mainDecisionTree = DecisionNode(
        question: "What type of UI element do you need?",
        options: [
            "User Input": .nextQuestion(inputDecisionTree),
            "Button/Action": .nextQuestion(buttonDecisionTree),
            "Display Data": .nextQuestion(displayDecisionTree),
            "Layout/Container": .nextQuestion(layoutDecisionTree),
            "Visual Element": .nextQuestion(visualDecisionTree)
        ]
    )
    
    // MARK: - Input Decision Tree
    static let inputDecisionTree = DecisionNode(
        question: "What kind of input do you need?",
        options: [
            "Text Input": .nextQuestion(DecisionNode(
                question: "What type of text input?",
                options: [
                    "Basic text (names, notes)": .component("AppInputField.text", adaptations: ["Modify placeholder", "Toggle required state", "Add validation"]),
                    "Currency/money amounts": .component("AppInputField.amount", adaptations: ["Change currency", "Modify formatting", "Add validation"]),
                    "Business/merchant names": .component("AppInputField.merchant", adaptations: ["Hide icons", "Change helper text", "Modify validation"]),
                    "Search functionality": .component("AppInputField.search", adaptations: ["Change placeholder", "Modify icon", "Add clear button"])
                ]
            )),
            "Date Selection": .component("AppInputField.date", adaptations: ["Change format", "Date/time/both components", "Min/max dates"]),
            "Option Selection": .nextQuestion(DecisionNode(
                question: "How many options?",
                options: [
                    "Toggle (on/off)": .component("CapsuleToggle", adaptations: ["Change colors", "Modify text", "Add icons"]),
                    "Multiple choice": .component("SelectionRowItem", adaptations: ["Change icons", "Modify selection state", "Add custom content"]),
                    "Complex selection": .requiresApproval("Custom picker component", reason: "Complex selection UI not covered by existing components")
                ]
            )),
            "Other input type": .requiresApproval("Custom input component", reason: "Input type not covered by existing components")
        ]
    )
    
    // MARK: - Button Decision Tree
    static let buttonDecisionTree = DecisionNode(
        question: "What's the button's importance level?",
        options: [
            "Primary action (save, confirm, submit)": .component("AppButton.primary", adaptations: ["Add left/right icons", "Change text", "Modify colors"]),
            "Secondary action (cancel, back)": .component("AppButton.secondary", adaptations: ["Add icons", "Change styling", "Modify emphasis"]),
            "Less important action": .component("AppButton.tertiary", adaptations: ["Add icons", "Change colors", "Modify size"]),
            "Subtle interaction": .component("AppButton.ghost", adaptations: ["Add subtle icons", "Change opacity", "Modify interaction"]),
            "Text-only action": .component("AppButton.text", adaptations: ["Change font weight", "Add underline", "Modify color"]),
            "Toggle button": .component("CapsuleToggle", adaptations: ["Change colors", "Modify text", "Add icons"])
        ]
    )
    
    // MARK: - Display Decision Tree
    static let displayDecisionTree = DecisionNode(
        question: "What kind of data are you displaying?",
        options: [
            "Transaction Data": .nextQuestion(DecisionNode(
                question: "How should transactions be displayed?",
                options: [
                    "List rows": .component("UnifiedTransactionDisplay.row", adaptations: ["Modify callback", "Change update handler", "Add dividers"]),
                    "Card tiles": .component("UnifiedTransactionDisplay.tile", adaptations: ["Modify tap action", "Change card styling", "Add shadows"]),
                    "Compact/small spaces": .component("UnifiedTransactionDisplay.compact", adaptations: ["Modify size", "Change information density"]),
                    "Detailed view": .component("UnifiedTransactionDisplay.detailed", adaptations: ["Add/remove fields", "Modify layout", "Change spacing"])
                ]
            )),
            "Category Information": .component("TxnCategoryIcon", adaptations: ["Change size", "Modify background", "Add custom categories"]),
            "Selection List": .component("SelectionRowItem", adaptations: ["Change icons", "Modify selection state", "Add custom content"]),
            "Receipt Upload": .component("ReceiptUploadCard", adaptations: ["Change action", "Modify styling", "Add loading states"]),
            "Other data type": .requiresApproval("Custom display component", reason: "Data type not covered by existing display components")
        ]
    )
    
    // MARK: - Layout Decision Tree
    static let layoutDecisionTree = DecisionNode(
        question: "What kind of layout/container do you need?",
        options: [
            "Full-screen overlay": .component("FullScreenOverlayTemplate", adaptations: ["Change title/confirm text", "Modify actions", "Add validation"]),
            "Modal/sheet": .component("ModalOverlayTemplate", adaptations: ["Change size", "Modify corner radius", "Add custom content"]),
            "Settings page": .component("SettingsOverlayTemplate", adaptations: ["Change header", "Modify scrolling", "Add custom layout"]),
            "App icon display": .component("AppIcon", adaptations: ["Change fallback", "Modify size", "Add tinting"]),
            "Custom layout": .requiresApproval("Custom layout component", reason: "Layout pattern not covered by existing templates")
        ]
    )
    
    // MARK: - Visual Decision Tree
    static let visualDecisionTree = DecisionNode(
        question: "What visual element do you need?",
        options: [
            "Colors": .component("CashMonkiDS.Colors", adaptations: ["Use semantic color names from AppColors system"]),
            "Typography": .component("CashMonkiDS.Typography", adaptations: ["Choose from header1-3, body variants, labels, captions"]),
            "Spacing": .component("CashMonkiDS.Spacing", adaptations: ["Use xs, sm, md, lg, xl, xxl values"]),
            "Layout constants": .component("CashMonkiDS.Layout", adaptations: ["Corner radius, border width, standard sizes"]),
            "Animations": .component("CashMonkiDS.Animation", adaptations: ["Quick, standard, slow, spring animations"]),
            "Shadows": .component("CashMonkiDS.Shadow", adaptations: ["Small, medium, large shadow presets"]),
            "Custom visual element": .requiresApproval("Custom visual component", reason: "Visual element not covered by design system")
        ]
    )
}

// MARK: - Interactive Guide Methods
extension ComponentSelectionGuide {
    
    /// Find the best component match for a specific use case
    /// Returns component recommendation or approval requirement
    static func findComponent(for useCase: String) -> ComponentRecommendation {
        // First check direct matches in component registry
        let registryMatches = ComponentRegistry.findComponents(for: useCase)
        
        if !registryMatches.isEmpty {
            let primaryMatch = registryMatches.first!
            let componentInfo = ComponentRegistry.getComponentInfo(for: primaryMatch)
            
            return ComponentRecommendation(
                component: primaryMatch,
                confidence: .high,
                reason: "Direct match found in component registry",
                adaptations: extractAdaptations(from: componentInfo),
                alternatives: Array(registryMatches.dropFirst())
            )
        }
        
        // If no direct match, analyze use case keywords
        return analyzeUseCase(useCase)
    }
    
    /// Interactive decision tree walker
    static func walkDecisionTree(startingAt node: DecisionNode = mainDecisionTree) -> DecisionTreeResult {
        return DecisionTreeResult(
            currentNode: node,
            path: [],
            recommendation: nil
        )
    }
    
    /// Validate if a component choice is appropriate for a use case
    static func validateComponentChoice(_ component: String, for useCase: String) -> ComponentValidationResult {
        // Check if component exists in registry
        let allComponents = getAllRegistryComponents()
        
        guard allComponents.contains(component) else {
            return ComponentValidationResult(
                isValid: false,
                severity: .error,
                message: "Component '\(component)' not found in registry",
                suggestion: "Use ComponentSelectionGuide.findComponent(for:) to find appropriate component"
            )
        }
        
        // Check if component matches use case
        let matches = ComponentRegistry.findComponents(for: useCase)
        if matches.contains(component) {
            return ComponentValidationResult(
                isValid: true,
                severity: .info,
                message: "Perfect match for use case",
                suggestion: nil
            )
        }
        
        // Check for similar components
        if let betterMatch = matches.first {
            return ComponentValidationResult(
                isValid: false,
                severity: .warning,
                message: "Component works but '\(betterMatch)' would be more appropriate",
                suggestion: "Consider using '\(betterMatch)' instead for better semantic fit"
            )
        }
        
        return ComponentValidationResult(
            isValid: true,
            severity: .warning,
            message: "Component can be used but may require adaptation",
            suggestion: "Ensure component behavior matches your use case requirements"
        )
    }
    
    // MARK: - Helper Methods
    
    private static func analyzeUseCase(_ useCase: String) -> ComponentRecommendation {
        let lowercaseUseCase = useCase.lowercased()
        
        // Keyword-based analysis
        if containsKeywords(lowercaseUseCase, ["input", "field", "text", "form"]) {
            return ComponentRecommendation(
                component: "AppInputField.text",
                confidence: .medium,
                reason: "Keywords suggest text input requirement",
                adaptations: ["Modify placeholder", "Toggle required state", "Add validation"],
                alternatives: ["AppInputField.amount", "AppInputField.merchant", "AppInputField.search"]
            )
        }
        
        if containsKeywords(lowercaseUseCase, ["button", "action", "tap", "click"]) {
            return ComponentRecommendation(
                component: "AppButton.primary",
                confidence: .medium,
                reason: "Keywords suggest button/action requirement",
                adaptations: ["Add left/right icons", "Change text", "Modify colors"],
                alternatives: ["AppButton.secondary", "AppButton.tertiary", "AppButton.ghost", "AppButton.text"]
            )
        }
        
        if containsKeywords(lowercaseUseCase, ["transaction", "display", "show", "list"]) {
            return ComponentRecommendation(
                component: "UnifiedTransactionDisplay.row",
                confidence: .medium,
                reason: "Keywords suggest transaction display requirement",
                adaptations: ["Modify callback", "Change update handler", "Add dividers"],
                alternatives: ["UnifiedTransactionDisplay.tile", "UnifiedTransactionDisplay.compact", "UnifiedTransactionDisplay.detailed"]
            )
        }
        
        // No clear match found
        return ComponentRecommendation(
            component: nil,
            confidence: .low,
            reason: "No clear component match found for this use case",
            adaptations: [],
            alternatives: [],
            requiresApproval: true,
            approvalReason: "Use case '\(useCase)' doesn't match existing component patterns"
        )
    }
    
    private static func containsKeywords(_ text: String, _ keywords: [String]) -> Bool {
        return keywords.contains { text.contains($0) }
    }
    
    private static func extractAdaptations(from componentInfo: String?) -> [String] {
        guard let info = componentInfo,
              let adaptationsStart = info.range(of: "Adaptations: ") else {
            return []
        }
        
        let adaptationsText = String(info[adaptationsStart.upperBound...])
        return adaptationsText.components(separatedBy: ", ")
    }
    
    private static func getAllRegistryComponents() -> [String] {
        var components: [String] = []
        components.append(contentsOf: ComponentRegistry.InputComponents.allCases.map(\.rawValue))
        components.append(contentsOf: ComponentRegistry.ButtonComponents.allCases.map(\.rawValue))
        components.append(contentsOf: ComponentRegistry.DisplayComponents.allCases.map(\.rawValue))
        components.append(contentsOf: ComponentRegistry.LayoutComponents.allCases.map(\.rawValue))
        components.append(contentsOf: ComponentRegistry.DesignSystemComponents.allCases.map(\.rawValue))
        return components
    }
}

// MARK: - Supporting Types

struct ComponentRecommendation {
    let component: String?
    let confidence: Confidence
    let reason: String
    let adaptations: [String]
    let alternatives: [String]
    var requiresApproval: Bool = false
    var approvalReason: String?
    
    enum Confidence {
        case high, medium, low
        
        var description: String {
            switch self {
            case .high: return "High confidence match"
            case .medium: return "Moderate confidence match"
            case .low: return "Low confidence match"
            }
        }
    }
    
    var formattedRecommendation: String {
        guard let component = component else {
            return "❌ No suitable component found. \(approvalReason ?? reason)\n\n🛑 REQUIRES APPROVAL: Contact team lead before creating new component."
        }
        
        var result = "✅ Recommended: \(component)\n"
        result += "🎯 Confidence: \(confidence.description)\n"
        result += "📝 Reason: \(reason)\n"
        
        if !adaptations.isEmpty {
            result += "🔧 Available adaptations:\n"
            for adaptation in adaptations {
                result += "   • \(adaptation)\n"
            }
        }
        
        if !alternatives.isEmpty {
            result += "🔄 Alternatives to consider:\n"
            for alternative in alternatives {
                result += "   • \(alternative)\n"
            }
        }
        
        if requiresApproval {
            result += "\n🛑 REQUIRES APPROVAL: \(approvalReason ?? "Component may need modification")"
        }
        
        return result
    }
}

struct ComponentValidationResult {
    let isValid: Bool
    let severity: Severity
    let message: String
    let suggestion: String?
    
    enum Severity {
        case info, warning, error
        
        var emoji: String {
            switch self {
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            }
        }
    }
    
    var formattedResult: String {
        var result = "\(severity.emoji) \(message)"
        if let suggestion = suggestion {
            result += "\n💡 Suggestion: \(suggestion)"
        }
        return result
    }
}

struct DecisionTreeResult {
    let currentNode: ComponentSelectionGuide.DecisionNode
    var path: [String]
    var recommendation: ComponentRecommendation?
    
    var currentQuestion: String {
        currentNode.question
    }
    
    var availableOptions: [String] {
        Array(currentNode.options.keys)
    }
    
    mutating func selectOption(_ option: String) -> DecisionTreeResult? {
        guard let result = currentNode.options[option] else { return nil }
        
        var newPath = path
        newPath.append(option)
        
        switch result {
        case .component(let componentName, let adaptations):
            return DecisionTreeResult(
                currentNode: currentNode,
                path: newPath,
                recommendation: ComponentRecommendation(
                    component: componentName,
                    confidence: .high,
                    reason: "Selected through decision tree",
                    adaptations: adaptations,
                    alternatives: []
                )
            )
        case .nextQuestion(let nextNode):
            return DecisionTreeResult(
                currentNode: nextNode,
                path: newPath,
                recommendation: nil
            )
        case .requiresApproval(let componentType, let reason):
            return DecisionTreeResult(
                currentNode: currentNode,
                path: newPath,
                recommendation: ComponentRecommendation(
                    component: nil,
                    confidence: .low,
                    reason: reason,
                    adaptations: [],
                    alternatives: [],
                    requiresApproval: true,
                    approvalReason: "New \(componentType) required - not covered by existing components"
                )
            )
        }
    }
}

// MARK: - Quick Access Methods
extension ComponentSelectionGuide {
    
    /// Quick component lookup with formatted output
    static func quickFind(_ useCase: String) -> String {
        let recommendation = findComponent(for: useCase)
        return recommendation.formattedRecommendation
    }
    
    /// Quick validation with formatted output
    static func quickValidate(component: String, for useCase: String) -> String {
        let validation = validateComponentChoice(component, for: useCase)
        return validation.formattedResult
    }
    
    /// Print all available components (for debugging)
    static func printAllComponents() {
        print(ComponentRegistry.listAllComponents())
    }
}

// MARK: - Debug Helper
#if DEBUG
extension ComponentSelectionGuide {
    /// Test the decision tree with sample use cases
    static func testDecisionTree() {
        let testCases = [
            "text input for user names",
            "button to save changes", 
            "display transaction in a list",
            "toggle for dark mode",
            "upload receipt image"
        ]
        
        for testCase in testCases {
            print("\n=== Testing: \(testCase) ===")
            print(quickFind(testCase))
        }
    }
    
    /// Test component validation
    static func testValidation() {
        let tests = [
            ("AppInputField.text", "name input"),
            ("AppButton.primary", "save button"),
            ("CustomButton", "save button") // Invalid component
        ]
        
        for (component, useCase) in tests {
            print("\n=== Validating: \(component) for '\(useCase)' ===")
            print(quickValidate(component: component, for: useCase))
        }
    }
}
#endif