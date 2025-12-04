import SwiftUI

struct TabChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(AppFonts.overusedGroteskMedium(size: 16))
                .foregroundColor(isSelected ? Color(red: 0.33, green: 0.18, blue: 1) : AppColors.foregroundSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .center)
                .background(
                    Group {
                        if isSelected {
                            Color(red: 0.91, green: 0.89, blue: 1) // Light purple background #E8E4FF
                        } else {
                            Color.white // White background for active/unselected state
                        }
                    }
                )
                .cornerRadius(12)
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Convenience Initializers

extension TabChip {
    // For basic tab/chip usage
    static func basic(
        title: String,
        isSelected: Bool,
        onTap: @escaping () -> Void
    ) -> TabChip {
        TabChip(
            title: title,
            isSelected: isSelected,
            onTap: onTap
        )
    }
    
    // For filter chip usage
    static func filter(
        title: String,
        isActive: Bool,
        onToggle: @escaping () -> Void
    ) -> TabChip {
        TabChip(
            title: title,
            isSelected: isActive,
            onTap: onToggle
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        // Tab usage example
        HStack(spacing: 12) {
            TabChip.basic(title: "Income", isSelected: true) {
                print("Income selected")
            }
            
            TabChip.basic(title: "Expenses", isSelected: false) {
                print("Expenses selected")
            }
            
            TabChip.basic(title: "All", isSelected: false) {
                print("All selected")
            }
        }
        
        // Filter chips example
        HStack(spacing: 12) {
            TabChip.filter(title: "Food", isActive: true) {
                print("Food filter toggled")
            }
            
            TabChip.filter(title: "Transport", isActive: false) {
                print("Transport filter toggled")
            }
            
            TabChip.filter(title: "Shopping", isActive: true) {
                print("Shopping filter toggled")
            }
        }
    }
    .padding()
    .background(AppColors.surfacePrimary)
}