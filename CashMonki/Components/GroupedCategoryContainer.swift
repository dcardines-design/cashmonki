//
//  GroupedCategoryContainer.swift
//  Cashooya Playground
//
//  Created by Claude on 9/12/25.
//

import SwiftUI

// MARK: - Grouped Category Container
struct GroupedCategoryContainer: View {
    let parentCategory: DisplayCategoryData
    let children: [DisplayCategoryData]
    let isExpanded: Bool
    let onParentTap: () -> Void
    let onChildTap: (String) -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Parent category row
            CategoryRowItem(
                emoji: parentCategory.categoryData.emoji,
                name: parentCategory.categoryData.name,
                onTap: onParentTap
            )
            
            // Child categories as separate rows
            ForEach(children, id: \.categoryData.name) { child in
                CategoryRowItem(
                    emoji: child.categoryData.emoji,
                    name: child.categoryData.name,
                    onTap: {
                        onChildTap(child.categoryData.name)
                    }
                )
            }
        }
    }
}

// MARK: - Category Row Item
private struct CategoryRowItem: View {
    let emoji: String
    let name: String
    let onTap: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(emoji)
                .font(.system(size: 20))
            
            Text(name)
                .font(AppFonts.overusedGroteskMedium(size: 16))
                .foregroundColor(AppColors.foregroundPrimary)
            
            Spacer()
            
            // Edit chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppColors.foregroundSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .inset(by: 0.5)
                .stroke(AppColors.linePrimary, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Legacy Components (Deprecated)
struct HierarchicalCategoryRow: View {
    let displayCategory: DisplayCategoryData
    let draggedCategory: String?
    let onTap: () -> Void
    let onDragStart: (String) -> Void
    let onDragEnd: () -> Void
    let onDrop: (String) -> Void
    let onToggleExpand: (String) -> Void
    
    @State private var isDropTarget = false
    
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(displayCategory.categoryData.emoji)
                .font(.system(size: displayCategory.isChild ? 18 : 20))
            
            Text(displayCategory.categoryData.name)
                .font(AppFonts.overusedGroteskMedium(size: displayCategory.isChild ? 14 : 16))
                .foregroundColor(AppColors.foregroundPrimary)
            
            Spacer()
            
            // Drag handle with dots-grid icon
            AppIcon(assetName: "dots-grid", fallbackSystemName: "line.3.horizontal")
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.627, green: 0.651, blue: 0.722))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isDropTarget ? 
                (displayCategory.isChild ? Color(red: 0.953, green: 0.961, blue: 0.973).opacity(0.7) : Color.white.opacity(0.7)) :
                (displayCategory.isChild ? Color(red: 0.953, green: 0.961, blue: 0.973) : Color.white)
        )
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .inset(by: 0.5)
                .stroke(
                    isDropTarget ? AppColors.accentBackground : AppColors.linePrimary, 
                    lineWidth: isDropTarget ? 2 : 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onDrag {
            onDragStart(displayCategory.categoryData.name)
            return NSItemProvider(object: displayCategory.categoryData.name as NSString)
        }
        .onDrop(of: [.text], isTargeted: $isDropTarget) { providers in
            // Only allow drops on parent categories (not child categories)
            guard !displayCategory.isChild else { return false }
            
            onDrop(displayCategory.categoryData.name)
            return true
        }
        .scaleEffect(draggedCategory == displayCategory.categoryData.name ? 1.05 : 1.0)
        .opacity(draggedCategory == displayCategory.categoryData.name ? 0.8 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: draggedCategory)
        .animation(.easeInOut(duration: 0.2), value: isDropTarget)
    }
}

struct DraggableCategoryRow: View {
    let category: CategoryData
    let onTap: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(category.emoji)
                .font(.system(size: 20))
            
            Text(category.name)
                .font(AppFonts.overusedGroteskMedium(size: 16))
                .foregroundColor(AppColors.foregroundPrimary)
            
            Spacer()
            
            // Drag handle with dots-grid icon
            AppIcon(assetName: "dots-grid", fallbackSystemName: "line.3.horizontal")
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.627, green: 0.651, blue: 0.722)) // #A0A6B8
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.953, green: 0.961, blue: 0.973)) // #F3F5F8
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .inset(by: 0.5)
                .stroke(AppColors.linePrimary, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}