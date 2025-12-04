//
//  ChoiceTile.swift
//  CashMonki
//
//  Created by Claude on 1/26/25.
//

import SwiftUI

// MARK: - Choice Tile Component

struct ChoiceTile: View {
    let emoji: String
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                // Emoji Icon
                VStack(alignment: .center, spacing: 10) {
                    Text(emoji)
                        .font(
                            Font.custom("Overused Grotesk", size: 14)
                                .weight(.medium)
                        )
                }
                .padding(8)
                .frame(width: 34, height: 34, alignment: .center)
                .background(isSelected ? Color(hex: "DED6FF") ?? AppColors.surfacePrimary : AppColors.surfacePrimary)
                .cornerRadius(200)
                
                // Title
                Text(title)
                    .font(
                        Font.custom("Overused Grotesk", size: 18)
                            .weight(.medium)
                    )
                    .foregroundColor(AppColors.foregroundPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // Selection Indicator
                if isSelected {
                    Image("check-circle")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(Color(hex: "542EFF") ?? .blue)
                        .frame(width: 20, height: 20)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(AppColors.linePrimary, lineWidth: 1.5)
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? Color(hex: "EEEAFF") ?? .white : 
                isPressed ? AppColors.surfacePrimary : Color(hex: "ffffff") ?? .white
            )
            .cornerRadius(12)
            .shadow(
                color: isSelected ? Color.clear : Color(red: 0.86, green: 0.89, blue: 0.96), 
                radius: 0, 
                x: 0, 
                y: isSelected ? 0 : 4
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .inset(by: 0.5)
                    .stroke(
                        isSelected ? AppColors.accentBackground : AppColors.line1stLine, 
                        lineWidth: 1
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .animation(.easeInOut(duration: 0.08), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        ChoiceTile(
            emoji: "📝",
            title: "Track daily spending",
            isSelected: false,
            onTap: {}
        )
        
        ChoiceTile(
            emoji: "📊",
            title: "Stick to a budget",
            isSelected: true,
            onTap: {}
        )
        
        ChoiceTile(
            emoji: "🐷",
            title: "Save more money",
            isSelected: false,
            onTap: {}
        )
    }
    .padding(20)
}