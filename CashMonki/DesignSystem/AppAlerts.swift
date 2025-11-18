//
//  AppAlerts.swift
//  CashMonki
//
//  Created by Claude on 1/26/25.
//

import SwiftUI

// MARK: - Standardized Alert System

/// Extension to provide consistent alert styling across the app
extension View {
    
    /// Standard confirmation alert with consistent styling
    /// - Parameters:
    ///   - title: Alert title
    ///   - isPresented: Binding to control presentation
    ///   - message: Alert message text
    ///   - primaryAction: Primary action button configuration
    ///   - secondaryAction: Optional secondary action (defaults to Cancel)
    func appAlert(
        title: String,
        isPresented: Binding<Bool>,
        message: String,
        primaryAction: AlertAction,
        secondaryAction: AlertAction? = nil
    ) -> some View {
        self.alert(title, isPresented: isPresented) {
            // Secondary action (Cancel) - always appears first
            if let secondary = secondaryAction {
                Button(secondary.title, role: secondary.role) {
                    secondary.action()
                }
            } else {
                Button("Cancel", role: .cancel) { }
            }
            
            // Primary action
            Button(primaryAction.title, role: primaryAction.role) {
                primaryAction.action()
            }
        } message: {
            AppAlertText(message)
        }
        .tint(AppColors.accentBackground)
    }
    
    /// Simple informational alert with OK button
    /// - Parameters:
    ///   - title: Alert title
    ///   - isPresented: Binding to control presentation
    ///   - message: Alert message text
    ///   - onDismiss: Optional action when dismissed
    func appInfoAlert(
        title: String,
        isPresented: Binding<Bool>,
        message: String,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        self.alert(title, isPresented: isPresented) {
            Button("OK", role: .cancel) {
                onDismiss?()
            }
        } message: {
            AppAlertText(message)
        }
        .tint(AppColors.accentBackground)
    }
    
    /// Text input alert with consistent styling
    /// - Parameters:
    ///   - title: Alert title
    ///   - isPresented: Binding to control presentation
    ///   - text: Binding to input text
    ///   - placeholder: Placeholder text for input
    ///   - message: Optional message text
    ///   - primaryAction: Primary action button configuration
    func appTextInputAlert(
        title: String,
        isPresented: Binding<Bool>,
        text: Binding<String>,
        placeholder: String = "",
        message: String? = nil,
        primaryAction: AlertAction
    ) -> some View {
        self.alert(title, isPresented: isPresented) {
            TextField(placeholder, text: text)
            Button("Cancel", role: .cancel) {
                text.wrappedValue = ""
            }
            Button(primaryAction.title, role: primaryAction.role) {
                primaryAction.action()
            }
        } message: {
            if let message = message {
                AppAlertText(message)
            }
        }
        .tint(AppColors.accentBackground)
    }
}

// MARK: - Alert Action Configuration

/// Configuration for alert action buttons
struct AlertAction {
    let title: String
    let role: ButtonRole?
    let action: () -> Void
    
    init(title: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.title = title
        self.role = role
        self.action = action
    }
    
    // Convenience constructors for common actions
    static func destructive(_ title: String, action: @escaping () -> Void) -> AlertAction {
        AlertAction(title: title, role: .destructive, action: action)
    }
    
    static func primary(_ title: String, action: @escaping () -> Void) -> AlertAction {
        AlertAction(title: title, role: nil, action: action)
    }
    
    static func cancel(_ title: String = "Cancel", action: @escaping () -> Void = {}) -> AlertAction {
        AlertAction(title: title, role: .cancel, action: action)
    }
}

// MARK: - Styled Alert Text Component

/// Standardized text component for alert messages with consistent styling
struct AppAlertText: View {
    private let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        Text(text)
            .font(AppFonts.overusedGroteskMedium(size: 14))
            .foregroundColor(AppColors.foregroundSecondary)
            .multilineTextAlignment(.leading)
    }
}

// MARK: - Preview Examples

#if DEBUG
struct AppAlerts_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Preview buttons to test different alert types
            Button("Show Confirmation Alert") { }
            Button("Show Info Alert") { }
            Button("Show Input Alert") { }
        }
        .padding()
        // Example usage:
        .appAlert(
            title: "Delete Transaction",
            isPresented: .constant(false),
            message: "Are you sure you want to delete this transaction? This action cannot be undone.",
            primaryAction: .destructive("Delete") { },
            secondaryAction: .cancel()
        )
    }
}
#endif