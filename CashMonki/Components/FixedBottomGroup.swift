//
//  FixedBottomGroup.swift
//  Cashooya Playground
//
//  Created by Claude on 9/8/25.
//

import SwiftUI

struct FixedBottomGroup: View {
    /// One button in the group. Stacked top-to-bottom in the order given, so the safest action
    /// sits last (nearest the thumb).
    struct Action: Identifiable {
        let id = UUID()
        let title: String
        let hierarchy: ButtonHierarchy
        let isEnabled: Bool
        let action: () -> Void
    }

    let actions: [Action]

    init(
        buttonTitle: String,
        buttonAction: @escaping () -> Void,
        isButtonEnabled: Bool = true,
        buttonHierarchy: ButtonHierarchy = .primary
    ) {
        self.actions = [Action(title: buttonTitle,
                               hierarchy: buttonHierarchy,
                               isEnabled: isButtonEnabled,
                               action: buttonAction)]
    }

    init(actions: [Action]) {
        self.actions = actions
    }

    var body: some View {
        VStack(spacing: 0) {
            // Divider
            Divider()
                .background(AppColors.linePrimary)
            
            // Button container
            VStack(spacing: 16) {
                ForEach(actions) { item in
                    AppButton(
                        title: item.title,
                        action: item.action,
                        hierarchy: item.hierarchy,
                        size: .extraSmall,
                        isEnabled: item.isEnabled
                    )
                }
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

    /// Destructive action stacked above the safe one (turn off backup / keep backing up).
    /// The safe action sits at the bottom, nearest the thumb.
    static func destructiveThenPrimary(
        destructiveTitle: String,
        destructiveAction: @escaping () -> Void,
        primaryTitle: String,
        primaryAction: @escaping () -> Void
    ) -> FixedBottomGroup {
        FixedBottomGroup(actions: [
            Action(title: destructiveTitle, hierarchy: .destructive, isEnabled: true, action: destructiveAction),
            Action(title: primaryTitle, hierarchy: .primary, isEnabled: true, action: primaryAction)
        ])
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