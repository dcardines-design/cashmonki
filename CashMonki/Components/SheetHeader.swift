//
//  SheetHeader.swift
//  Cashooya Playground
//
//  Created by Claude on 9/8/25.
//

import SwiftUI

struct SheetHeader: View {
    let title: String
    let onBackTap: () -> Void
    let rightAction: RightAction?
    
    enum RightAction {
        case edit(action: () -> Void)
        case check(action: () -> Void)
        case custom(icon: String, systemIcon: String, action: () -> Void)
        
        var iconName: String {
            switch self {
            case .edit: return "settings-01"
            case .check: return "check"
            case .custom(let icon, _, _): return icon
            }
        }
        
        var systemIconName: String {
            switch self {
            case .edit: return "gearshape"
            case .check: return "checkmark"
            case .custom(_, let systemIcon, _): return systemIcon
            }
        }
        
        var action: () -> Void {
            switch self {
            case .edit(let action), .check(let action), .custom(_, _, let action):
                return action
            }
        }
    }
    
    init(title: String, onBackTap: @escaping () -> Void, rightAction: RightAction? = nil) {
        self.title = title
        self.onBackTap = onBackTap
        self.rightAction = rightAction
    }
    
    var body: some View {
        HStack {
            // Back button
            Button(action: onBackTap) {
                Image("chevron-left")
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 24, height: 24)
                    .foregroundColor(AppColors.foregroundSecondary)
            }
            
            Spacer()
            
            // Title
            Text(title)
                .font(AppFonts.overusedGroteskSemiBold(size: 18))
                .foregroundColor(AppColors.foregroundPrimary)
            
            Spacer()
            
            // Right action button or spacer
            if let rightAction = rightAction {
                Button(action: rightAction.action) {
                    Image(rightAction.iconName)
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 24, height: 24)
                        .foregroundColor(AppColors.foregroundSecondary)
                }
            } else {
                // Invisible spacer for balance (same size as back button)
                Color.clear
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(AppColors.backgroundWhite)
    }
}

// MARK: - Convenience Initializers

extension SheetHeader {
    /// Header with just a back button
    static func basic(title: String, onBackTap: @escaping () -> Void) -> SheetHeader {
        SheetHeader(title: title, onBackTap: onBackTap)
    }
    
    /// Header with back button and edit action
    static func withEdit(title: String, onBackTap: @escaping () -> Void, onEditTap: @escaping () -> Void) -> SheetHeader {
        SheetHeader(title: title, onBackTap: onBackTap, rightAction: .edit(action: onEditTap))
    }
    
    /// Header with back button and check action
    static func withCheck(title: String, onBackTap: @escaping () -> Void, onCheckTap: @escaping () -> Void) -> SheetHeader {
        SheetHeader(title: title, onBackTap: onBackTap, rightAction: .check(action: onCheckTap))
    }
    
    /// Header with back button and custom right action
    static func withCustomAction(
        title: String, 
        onBackTap: @escaping () -> Void, 
        rightIcon: String, 
        rightSystemIcon: String, 
        onRightTap: @escaping () -> Void
    ) -> SheetHeader {
        SheetHeader(
            title: title, 
            onBackTap: onBackTap, 
            rightAction: .custom(icon: rightIcon, systemIcon: rightSystemIcon, action: onRightTap)
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        SheetHeader.basic(title: "Add Transaction") { }
        
        SheetHeader.withEdit(title: "Transaction Details", onBackTap: { }, onEditTap: { })
        
        SheetHeader.withCheck(title: "Confirm Transaction", onBackTap: { }, onCheckTap: { })
    }
    .background(Color.gray.opacity(0.1))
}