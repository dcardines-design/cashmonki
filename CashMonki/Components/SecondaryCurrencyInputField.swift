//
//  SecondaryCurrencyInputField.swift
//  CashMonki
//
//  Created by Claude on 1/29/25.
//

import SwiftUI

struct SecondaryCurrencyInputField: View {
    @Binding var selectedCurrency: Currency?
    let primaryCurrency: Currency
    let title: String
    let size: AppInputField.Size = .md
    
    @State private var showingPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: size.titleSpacing) {
            // Title
            Text(title)
                .font(size.titleFont)
                .foregroundColor(AppColors.foregroundSecondary)
            
            // Currency Display Button
            Button(action: {
                showingPicker = true
            }) {
                HStack(alignment: .center, spacing: 12) {
                    // Currency Flag and Symbol - Code format (matching primary)
                    HStack(spacing: 8) {
                        if let currency = selectedCurrency {
                            Text(currency.flag)
                                .font(.system(size: 20))
                        } else {
                            Text("🏳️")
                                .font(.system(size: 20))
                        }
                        
                        Text(displayText)
                            .font(AppFonts.overusedGroteskMedium(size: size.fontSize))
                            .foregroundColor(AppColors.foregroundPrimary)
                    }
                    
                    Spacer()
                    
                    // Chevron (matching primary)
                    AppIcon(
                        assetName: "chevron-right",
                        fallbackSystemName: "chevron.right"
                    )
                    .foregroundColor(AppColors.foregroundSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, size.verticalPadding)
                .background(AppColors.surfacePrimary)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .inset(by: 0.5)
                        .stroke(Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .sheet(isPresented: $showingPicker) {
            SecondaryCurrencyPickerSheet(
                secondaryCurrency: $selectedCurrency,
                isPresented: $showingPicker
            )
            .presentationDetents([.fraction(0.98)])
            .presentationDragIndicator(.hidden)
        }
    }
    
    private var displayText: String {
        if let currency = selectedCurrency {
            return "\(currency.symbol) - \(currency.rawValue)"
        } else {
            return "None"
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        SecondaryCurrencyInputField(
            selectedCurrency: .constant(.usd),
            primaryCurrency: .php,
            title: "Secondary Currency (Optional)"
        )
        
        SecondaryCurrencyInputField(
            selectedCurrency: .constant(nil),
            primaryCurrency: .php,
            title: "Secondary Currency (Optional)"
        )
    }
    .padding()
    .background(AppColors.backgroundWhite)
}