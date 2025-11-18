//
//  ActionTile.swift
//  CashMonki
//
//  Created by Claude on 1/26/25.
//

import SwiftUI

// MARK: - Action Tile Component

struct ActionTile: View {
    let icon: String
    let title: String
    let subtitle: String
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 18) {
                // Icon
                AppIcon(assetName: icon, fallbackSystemName: icon)
                    .font(
                        Font.custom("Overused Grotesk", size: 18)
                            .weight(.medium)
                    )
                    .foregroundColor(AppColors.accentBackground)
                
                // Title and Subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(
                            Font.custom("Overused Grotesk", size: 18)
                                .weight(.medium)
                        )
                        .foregroundColor(AppColors.foregroundPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(subtitle)
                        .font(
                            Font.custom("Overused Grotesk", size: 16)
                                .weight(.medium)
                        )
                        .foregroundColor(AppColors.foregroundSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isPressed ? AppColors.surfacePrimary : .white)
            .cornerRadius(12)
            .shadow(
                color: isPressed ? Color.clear : Color(red: 0.86, green: 0.89, blue: 0.96), 
                radius: 0, 
                x: 0, 
                y: isPressed ? 0 : 4
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .inset(by: 0.5)
                    .stroke(AppColors.line1stLine, lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .accessibilityAddTraits(.isButton)
        .accessibilityRemoveTraits(.isStaticText)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        ActionTile(
            icon: "upload-01",
            title: "Upload",
            subtitle: "Upload a receipt and we'll get the details",
            onTap: {}
        )
        
        ActionTile(
            icon: "scan",
            title: "Scan",
            subtitle: "Capture a receipt and we'll get the details",
            onTap: {}
        )
        
        ActionTile(
            icon: "plus",
            title: "Add",
            subtitle: "Add transaction details manually",
            onTap: {}
        )
    }
    .padding(20)
}