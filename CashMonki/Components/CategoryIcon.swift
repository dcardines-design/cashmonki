import SwiftUI

struct TxnCategoryIcon: View {
    let category: String
    let size: CGFloat
    let backgroundColor: Color
    @ObservedObject private var categoriesManager = CategoriesManager.shared
    
    init(category: String, size: CGFloat = 36, backgroundColor: Color = AppColors.surfacePrimary) {
        self.category = category
        self.size = size
        self.backgroundColor = backgroundColor
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: size, height: size)
            
            Text(emojiForCategory(category))
                .font(.system(size: size * 0.5))
        }
    }
    
    /// Returns the appropriate emoji for a given category
    /// Now uses context-aware lookup to resolve emoji conflicts between income/expense categories
    private func emojiForCategory(_ category: String) -> String {
        // Always use fresh lookup from the unified category system (no caching for reactivity)
        let unifiedEmoji = categoriesManager.emojiFor(category: category, type: nil)
        
        // If unified system returns a valid emoji (not the default 📋), use it
        if unifiedEmoji != "📋" {
            return unifiedEmoji
        }
        
        // Fallback to hardcoded mapping for backward compatibility
        let normalizedCategory = category.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch normalizedCategory {
        // Common fallbacks for transaction categories not in the unified system
        case "netflix", "streaming":
            return "📺"
        case "spotify", "music":
            return "🎵"
        case "uber", "lyft", "grab", "taxi", "rideshare":
            return "🚕"
        case "amazon", "shopping":
            return "🛒"
        case "starbucks", "coffee":
            return "☕"
        case "mcdonalds", "kfc", "jollibee", "fastfood":
            return "🍟"
        case "gas", "fuel", "petrol":
            return "⛽"
        case "gym", "fitness":
            return "🏋️"
        case "pharmacy", "medicine":
            return "💊"
        case "bank", "banking":
            return "🏦"
        case "grocery", "groceries":
            return "🛒"
        case "hotel", "accommodation":
            return "🏨"
        case "flight", "airline":
            return "✈️"
        
        // Default for completely unknown categories
        default:
            return "📋"
        }
    }
}

// MARK: - Convenience Methods
extension TxnCategoryIcon {
    /// Returns emoji for category by UUID with optional name fallback
    /// Use this for budgets and any context where categoryId is available
    /// If UUID lookup fails (e.g., after category reset), falls back to name-based lookup
    static func emojiFor(categoryId: UUID, categoryName: String? = nil) -> String {
        // Try UUID lookup first (preferred)
        let result = CategoriesManager.shared.findCategoryOrSubcategoryById(categoryId)
        if let category = result?.category {
            return category.emoji
        } else if let subcategory = result?.subcategory {
            return subcategory.emoji
        }

        // Fallback to name-based lookup if UUID not found
        // This handles cases where categories were reinitialized with new UUIDs
        if let name = categoryName, !name.isEmpty {
            let nameEmoji = CategoriesManager.shared.emojiFor(category: name, type: nil)
            if nameEmoji != "📋" {
                return nameEmoji
            }
        }

        return "📋" // Default for deleted/orphaned categories
    }

    /// Returns just the emoji for a given category (by name - use only when UUID not available)
    static func emojiFor(category: String) -> String {
        return CategoriesManager.shared.emojiFor(category: category, type: nil)
    }

    /// Returns emoji for category with context-aware type information
    static func emojiFor(category: String, type: CategoryType?) -> String {
        return CategoriesManager.shared.emojiFor(category: category, type: type)
    }
    
    /// Returns background color based on category type
    static func backgroundColorFor(category: String) -> Color {
        // For consistency, always use the same surface color
        return AppColors.surfacePrimary
    }
}

// MARK: - Preview
struct TxnCategoryIcon_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Food categories
            HStack(spacing: 16) {
                TxnCategoryIcon(category: "Food & Drinks")
                TxnCategoryIcon(category: "Groceries")
                TxnCategoryIcon(category: "Restaurant")
                TxnCategoryIcon(category: "Cafe")
            }
            
            // Transportation categories
            HStack(spacing: 16) {
                TxnCategoryIcon(category: "Transportation")
                TxnCategoryIcon(category: "Taxi")
                TxnCategoryIcon(category: "Gas")
                TxnCategoryIcon(category: "Parking")
            }
            
            // Shopping categories
            HStack(spacing: 16) {
                TxnCategoryIcon(category: "Shopping")
                TxnCategoryIcon(category: "Clothing")
                TxnCategoryIcon(category: "Electronics")
                TxnCategoryIcon(category: "Home & Garden")
            }
            
            // Entertainment categories
            HStack(spacing: 16) {
                TxnCategoryIcon(category: "Entertainment")
                TxnCategoryIcon(category: "Movies")
                TxnCategoryIcon(category: "Gaming")
                TxnCategoryIcon(category: "Books")
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}