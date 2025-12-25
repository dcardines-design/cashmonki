import SwiftUI

struct SelectionRowItem: View {
    let icon: String // Emoji or symbol
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 14) {
                Text(icon)
                    .font(.system(size: 20))
                
                Text(title)
                    .font(AppFonts.overusedGroteskMedium(size: 16))
                    .foregroundColor(AppColors.foregroundPrimary)
                
                Spacer()
                
                if isSelected {
                    AppIcon(assetName: "check-circle", fallbackSystemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.primary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.backgroundWhite)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .inset(by: 0.5)
                    .stroke(AppColors.linePrimary, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Convenience Initializers

extension SelectionRowItem {
    // For currency selection
    static func currency(
        _ currency: Currency,
        isSelected: Bool,
        onTap: @escaping () -> Void
    ) -> SelectionRowItem {
        SelectionRowItem(
            icon: currency.flag,
            title: "\(currency.symbol) \(currency.rawValue) - \(currency.fullName)",
            isSelected: isSelected,
            onTap: onTap
        )
    }
    
    // For category selection  
    static func category(
        _ category: String,
        emoji: String,
        isSelected: Bool,
        onTap: @escaping () -> Void
    ) -> SelectionRowItem {
        SelectionRowItem(
            icon: emoji,
            title: category,
            isSelected: isSelected,
            onTap: onTap
        )
    }
    
    // For language selection
    static func language(
        _ language: Language,
        isSelected: Bool,
        onTap: @escaping () -> Void
    ) -> SelectionRowItem {
        SelectionRowItem(
            icon: language.flag,
            title: language.displayName,
            isSelected: isSelected,
            onTap: onTap
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        SelectionRowItem.currency(.usd, isSelected: false) {
            print("USD selected")
        }
        
        SelectionRowItem.currency(.php, isSelected: true) {
            print("PHP selected")
        }
        
        SelectionRowItem.category("Cafe", emoji: "☕", isSelected: false) {
            print("Cafe selected")
        }
        
        SelectionRowItem.category("Transportation", emoji: "🚗", isSelected: true) {
            print("Transportation selected")
        }
        
        SelectionRowItem.language(.english, isSelected: false) {
            print("English selected")
        }
        
        SelectionRowItem.language(.tagalog, isSelected: true) {
            print("Tagalog selected")
        }
    }
    .padding()
    .background(AppColors.surfacePrimary)
}