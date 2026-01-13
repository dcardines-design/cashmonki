//
//  CategorySuggestionChips.swift
//  CashMonki
//
//  Horizontally scrollable category suggestion chips based on recent/frequent usage
//

import SwiftUI

struct CategorySuggestionChips: View {
    @Binding var selectedCategoryId: UUID?
    var selectedCategoryName: Binding<String>?

    @ObservedObject private var categoriesManager = CategoriesManager.shared

    init(selectedCategoryId: Binding<UUID?>, selectedCategoryName: Binding<String>? = nil) {
        self._selectedCategoryId = selectedCategoryId
        self.selectedCategoryName = selectedCategoryName
    }

    /// Get recent and frequent category IDs from user's transactions
    /// Priority: 3 most recent, then 5 most used (deduplicated)
    private var suggestedCategories: [(id: UUID, name: String, emoji: String)] {
        let transactions = UserManager.shared.currentUser.transactions

        // Get category IDs with their usage count and most recent date
        var categoryStats: [UUID: (count: Int, lastUsed: Date, name: String, emoji: String)] = [:]

        for txn in transactions {
            guard let catId = txn.categoryId else { continue }

            // Look up category info
            let result = categoriesManager.findCategoryOrSubcategoryById(catId)
            let name: String
            let emoji: String

            if let category = result?.category {
                name = category.name
                emoji = TxnCategoryIcon.emojiFor(category: category.name)
            } else if let subcategory = result?.subcategory {
                name = subcategory.name
                emoji = TxnCategoryIcon.emojiFor(category: subcategory.name)
            } else {
                continue
            }

            if var stats = categoryStats[catId] {
                stats.count += 1
                if txn.date > stats.lastUsed {
                    stats.lastUsed = txn.date
                }
                categoryStats[catId] = stats
            } else {
                categoryStats[catId] = (count: 1, lastUsed: txn.date, name: name, emoji: emoji)
            }
        }

        // Get top 3 most recent categories (sorted by lastUsed date, newest first)
        let mostRecent = categoryStats.sorted { $0.value.lastUsed > $1.value.lastUsed }
            .prefix(3)
            .map { (id: $0.key, name: $0.value.name, emoji: $0.value.emoji) }

        // Get IDs of recent categories to exclude from frequent list
        let recentIds = Set(mostRecent.map { $0.id })

        // Get top 5 most used categories (excluding those already in recent)
        let mostUsed = categoryStats
            .filter { !recentIds.contains($0.key) }
            .sorted { $0.value.count > $1.value.count }
            .prefix(5)
            .map { (id: $0.key, name: $0.value.name, emoji: $0.value.emoji) }

        // Combine: 3 recent + 5 frequent (max 8 total)
        return mostRecent + mostUsed
    }

    var body: some View {
        let suggestions = suggestedCategories

        if !suggestions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.id) { category in
                        categoryChip(
                            emoji: category.emoji,
                            name: category.name,
                            isSelected: selectedCategoryId == category.id
                        ) {
                            selectedCategoryId = category.id
                            selectedCategoryName?.wrappedValue = category.name
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4) // Give shadow room to render without clipping
            }
            .padding(.horizontal, -20) // Compensate for parent padding to allow edge-to-edge scroll
            .padding(.vertical, -4) // Compensate for inner padding to maintain original spacing
            .animation(.none, value: selectedCategoryId) // Prevent fade animation on selection
        }
    }

    private func categoryChip(emoji: String, name: String, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text(emoji)
                    .font(.system(size: 14))

                Text(name)
                    .font(AppFonts.overusedGroteskMedium(size: 14))
                    .foregroundColor(isSelected ? AppColors.primary : AppColors.foregroundPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color(hex: "EEEAFF") ?? .white : .white)
            .cornerRadius(10)
            .shadow(
                color: Color(red: 0.86, green: 0.89, blue: 0.96),
                radius: 0,
                x: 0,
                y: 3
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? AppColors.accentBackground : AppColors.line1stLine, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        Text("Category Suggestions")
            .font(.headline)

        CategorySuggestionChips(selectedCategoryId: .constant(nil))
    }
    .padding()
    .background(AppColors.surfacePrimary)
}
