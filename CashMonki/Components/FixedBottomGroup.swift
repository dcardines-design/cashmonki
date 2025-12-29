//
//  FixedBottomGroup.swift
//  Cashooya Playground
//
//  Created by Claude on 9/8/25.
//

import SwiftUI

struct FixedBottomGroup: View {
    let buttonTitle: String
    let buttonAction: () -> Void
    let isButtonEnabled: Bool
    let buttonHierarchy: ButtonHierarchy
    
    init(
        buttonTitle: String,
        buttonAction: @escaping () -> Void,
        isButtonEnabled: Bool = true,
        buttonHierarchy: ButtonHierarchy = .primary
    ) {
        self.buttonTitle = buttonTitle
        self.buttonAction = buttonAction
        self.isButtonEnabled = isButtonEnabled
        self.buttonHierarchy = buttonHierarchy
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Divider
            Divider()
                .background(AppColors.linePrimary)
            
            // Button container
            VStack {
                AppButton(
                    title: buttonTitle,
                    action: buttonAction,
                    hierarchy: buttonHierarchy,
                    size: .extraSmall,
                    isEnabled: isButtonEnabled
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 34)
            .background(AppColors.backgroundWhite)
        }
    }
}

// MARK: - Convenience Initializers

extension FixedBottomGroup {
    /// Primary action bottom group (Save, Confirm, etc.)
    static func primary(
        title: String,
        action: @escaping () -> Void,
        isEnabled: Bool = true
    ) -> FixedBottomGroup {
        FixedBottomGroup(
            buttonTitle: title,
            buttonAction: action,
            isButtonEnabled: isEnabled,
            buttonHierarchy: .primary
        )
    }
    
    /// Secondary action bottom group
    static func secondary(
        title: String,
        action: @escaping () -> Void,
        isEnabled: Bool = true
    ) -> FixedBottomGroup {
        FixedBottomGroup(
            buttonTitle: title,
            buttonAction: action,
            isButtonEnabled: isEnabled,
            buttonHierarchy: .secondary
        )
    }
}

#Preview {
    VStack {
        Spacer()
        Text("Content above")
            .padding()
        Spacer()
        
        FixedBottomGroup.primary(
            title: "Save",
            action: { print("Save tapped") },
            isEnabled: true
        )
    }
    .background(Color.gray.opacity(0.1))
}