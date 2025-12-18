//
//  ParentCategoryPickerSheet.swift
//  Cashooya Playground
//
//  Created by Claude on 9/12/25.
//

import SwiftUI

// MARK: - Parent Category Picker Sheet
struct ParentCategoryPickerSheet: View {
    @Binding var selectedParent: String?
    @Binding var isPresented: Bool
    let availableCategories: [CategoryData]
    let currentCategoryName: String
    let initialTab: CategoryTab?
    
    @State private var searchText = ""
    @State private var showingMoveError = false
    @State private var selectedTab: CategoryTab = .expense
    @ObservedObject private var categoriesManager = CategoriesManager.shared
    
    init(selectedParent: Binding<String?>, isPresented: Binding<Bool>, availableCategories: [CategoryData], currentCategoryName: String, initialTab: CategoryTab? = nil) {
        self._selectedParent = selectedParent
        self._isPresented = isPresented
        self.availableCategories = availableCategories
        self.currentCategoryName = currentCategoryName
        self.initialTab = initialTab
        // Set smart default based on initialTab
        self._selectedTab = State(initialValue: initialTab ?? .expense)
    }
    
    enum CategoryTab {
        case income
        case expense
    }
    
    /// Get categories based on selected tab (Income vs Expense)
    /// Now includes both types to enable cross-type parent assignment
    private var categoriesForSelectedTab: [CategoryData] {
        switch selectedTab {
        case .income:
            return categoriesManager.allIncomeCategoriesWithCustom
        case .expense:
            return categoriesManager.allExpenseCategoriesWithCustom
        }
    }
    
    private var filteredCategories: [CategoryData] {
        let tabCategories = categoriesForSelectedTab.filter { category in
            // Exclude the "No Parent" container categories from regular list
            !category.name.hasPrefix("No Parent")
        }
        
        if searchText.isEmpty {
            return tabCategories
        } else {
            #if DEBUG
            if !searchText.isEmpty {
                print("🔍 PARENTP STARTING SEARCH for '\(searchText)' across \(tabCategories.count) categories")
            }
            #endif
            
            let filteredResults = tabCategories.filter { category in
                // Debug: Show what we're searching
                #if DEBUG
                if !searchText.isEmpty && (searchText.lowercased().contains("haircuts") || searchText.lowercased().contains("hair")) {
                    print("🔍 PARENTP SEARCH DEBUG for '\(searchText)':")
                    print("🔍   - Checking category: '\(category.name)'")
                    print("🔍   - Category subcategories: \(category.subcategories.map { $0.name })")
                }
                #endif
                
                // Search in category name
                let categoryMatches = category.name.localizedCaseInsensitiveContains(searchText)
                
                // Search in subcategory names
                let subcategoryMatches = category.subcategories.contains { subcategory in
                    let matches = subcategory.name.localizedCaseInsensitiveContains(searchText)
                    #if DEBUG
                    if !searchText.isEmpty && (searchText.lowercased().contains("haircuts") || searchText.lowercased().contains("hair")) {
                        print("🔍   - Subcategory '\(subcategory.name)' matches '\(searchText)': \(matches)")
                    }
                    #endif
                    return matches
                }
                
                let result = categoryMatches || subcategoryMatches
                #if DEBUG
                if !searchText.isEmpty && (searchText.lowercased().contains("haircuts") || searchText.lowercased().contains("hair")) {
                    print("🔍   - Category '\(category.name)' result: \(result) (category: \(categoryMatches), subcategory: \(subcategoryMatches))")
                }
                #endif
                
                return result
            }
            
            #if DEBUG
            if !searchText.isEmpty {
                print("🔍 PARENTP SEARCH RESULTS for '\(searchText)': Found \(filteredResults.count) categories")
                for category in filteredResults {
                    let matchingSubcategories = category.subcategories.filter { subcategory in
                        subcategory.name.localizedCaseInsensitiveContains(searchText)
                    }
                    if !matchingSubcategories.isEmpty {
                        print("🔍   - '\(category.name)' has matching subcategories: \(matchingSubcategories.map { $0.name })")
                    }
                    if category.name.localizedCaseInsensitiveContains(searchText) {
                        print("🔍   - '\(category.name)' matches by category name")
                    }
                }
            }
            #endif
            
            return filteredResults
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            SheetHeader.basic(title: "Select Parent Category") {
                isPresented = false
            }
            
            // Search bar
            AppInputField.search(text: $searchText, placeholder: "Search for a category...", size: .md)
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 16)
                .background(AppColors.backgroundWhite)
                .fixedSize(horizontal: false, vertical: true)
            
            // Income/Expense tabs
            HStack(spacing: 8) {
                TabChip.basic(title: "Income", isSelected: selectedTab == .income) {
                    selectedTab = .income
                }
                
                TabChip.basic(title: "Expense", isSelected: selectedTab == .expense) {
                    selectedTab = .expense
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            
            // Category list
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    // Tab-specific "No Parent" option
                    SelectionRowItem.category(
                        selectedTab == .income ? "No Parent (Income)" : "No Parent (Expense)",
                        emoji: selectedTab == .income ? "📥" : "📤",
                        isSelected: selectedParent == (selectedTab == .income ? "No Parent (Income)" : "No Parent (Expense)"),
                        onTap: {
                            selectedParent = selectedTab == .income ? "No Parent (Income)" : "No Parent (Expense)"
                            searchText = ""
                            isPresented = false
                        }
                    )
                    
                    // Available parent categories
                    ForEach(filteredCategories, id: \.name) { category in
                        SelectionRowItem.category(
                            category.name,
                            emoji: category.emoji,
                            isSelected: selectedParent == category.name,
                            onTap: {
                                handleParentSelection(category.name)
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(AppColors.backgroundWhite)
        }
        .background(AppColors.backgroundWhite)
        .appInfoAlert(
            title: "Oops!",
            isPresented: $showingMoveError,
            message: "Remove the subcategories under this category first!"
        )
        .onAppear {
            // Smart tab selection based on current category context
            if initialTab == nil && !currentCategoryName.isEmpty {
                let result = categoriesManager.findCategoryOrSubcategory(by: currentCategoryName)
                if result.category != nil || result.subcategory != nil {
                    // Determine type from category or parent
                    let categoryType = result.parent?.type ?? result.category?.type
                    if let type = categoryType {
                        selectedTab = (type == .income) ? .income : .expense
                        #if DEBUG
                        print("🎯 ParentCategoryPickerSheet: Smart tab selection - '\(currentCategoryName)' is \(type) -> \(selectedTab)")
                        #endif
                    }
                }
            }
        }
    }
    
    private func handleParentSelection(_ parentName: String) {
        // Check if the current category has subcategories
        let currentChildren = categoriesManager.categoryHierarchy[currentCategoryName] ?? []
        if !currentChildren.isEmpty {
            // This category has subcategories, show error dialog
            showingMoveError = true
            return
        }
        
        // Safe to assign parent
        selectedParent = parentName
        searchText = ""
        isPresented = false
    }
}