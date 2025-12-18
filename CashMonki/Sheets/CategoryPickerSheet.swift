//
//  CategoryPickerSheet.swift
//  Cashooya Playground
//
//  Created by Claude on 9/8/25.
//

import SwiftUI

struct CategoryPickerSheet: View {
    @Binding var selectedCategory: String
    @Binding var selectedCategoryId: UUID?
    @Binding var isPresented: Bool
    let initialTab: CategoryTab?
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var showingEditCategories = false
    @State private var selectedTab: CategoryTab = .expense
    @ObservedObject private var categoriesManager = CategoriesManager.shared
    
    // Track whether we're using ID-based or String-based selection
    private let useIdBasedSelection: Bool
    
    // Helper function to check if a category is selected
    private func isCategorySelected(_ categoryData: CategoryData) -> Bool {
        if useIdBasedSelection {
            return selectedCategoryId == categoryData.id
        } else {
            return selectedCategory == categoryData.name
        }
    }
    
    // Helper function to select a category
    private func selectCategory(_ categoryData: CategoryData) {
        print("🐛 CategoryPickerSheet: selectCategory called")
        print("🐛 CategoryPickerSheet: useIdBasedSelection = \(useIdBasedSelection)")
        print("🐛 CategoryPickerSheet: categoryData.name = '\(categoryData.name)'")
        print("🐛 CategoryPickerSheet: categoryData.id = \(categoryData.id.uuidString.prefix(8))")
        
        if useIdBasedSelection {
            print("🐛 CategoryPickerSheet: Setting selectedCategoryId to \(categoryData.id.uuidString.prefix(8))")
            selectedCategoryId = categoryData.id
        } else {
            print("🐛 CategoryPickerSheet: Setting selectedCategory to '\(categoryData.name)'")
            selectedCategory = categoryData.name
        }
    }
    
    // Helper function to select "No Category" option
    private func selectNoCategory() {
        if useIdBasedSelection {
            // Use the actual "No Category" UUIDs instead of nil
            if selectedTab == .income {
                selectedCategoryId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")! // No Category (Income)
            } else {
                selectedCategoryId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")! // No Category (Expense)
            }
        } else {
            selectedCategory = selectedTab == .income ? "No Category (Income)" : "No Category (Expense)"
        }
    }
    
    // Helper function to check if "No Category" is selected
    private var isNoCategorySelected: Bool {
        if useIdBasedSelection {
            // Check for actual "No Category" UUIDs
            let noCategoryIncomeUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
            let noCategoryExpenseUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
            
            if selectedTab == .income {
                return selectedCategoryId == noCategoryIncomeUUID
            } else {
                return selectedCategoryId == noCategoryExpenseUUID
            }
        } else {
            let noCategoryName = selectedTab == .income ? "No Category (Income)" : "No Category (Expense)"
            return selectedCategory == noCategoryName
        }
    }
    
    init(selectedCategory: Binding<String>, isPresented: Binding<Bool>, initialTab: CategoryTab? = nil) {
        self._selectedCategory = selectedCategory
        self._selectedCategoryId = .constant(nil)
        self._isPresented = isPresented
        self.initialTab = initialTab
        self.useIdBasedSelection = false
        // Set smart default based on initialTab
        self._selectedTab = State(initialValue: initialTab ?? .expense)
    }
    
    init(selectedCategoryId: Binding<UUID?>, isPresented: Binding<Bool>, initialTab: CategoryTab? = nil) {
        self._selectedCategory = .constant("")
        self._selectedCategoryId = selectedCategoryId
        self._isPresented = isPresented
        self.initialTab = initialTab
        self.useIdBasedSelection = true
        // Set smart default based on initialTab
        self._selectedTab = State(initialValue: initialTab ?? .expense)
    }
    
    enum CategoryTab {
        case income
        case expense
    }
    
    // Performance optimization: Use debouncer for search
    @State private var searchDebouncer = Debouncer(delay: 0.3)
    
    // Performance optimization: Cache filtered groups
    @State private var cachedGroups: [CategoryGroup] = []
    @State private var isSearching = false
    
    /// Get optimized cached category groups
    private var filteredGroups: [CategoryGroup] {
        return cachedGroups
    }
    
    /// Get categories based on selected tab (Income vs Expense)
    private var categoriesForSelectedTab: [CategoryData] {
        switch selectedTab {
        case .income:
            return categoriesManager.allIncomeCategoriesWithCustom.filter { !$0.name.hasPrefix("No Parent") }
        case .expense:
            return categoriesManager.allExpenseCategoriesWithCustom.filter { !$0.name.hasPrefix("No Parent") }
        }
    }
    
    /// Update cached groups with debounced search
    private func updateCachedGroups(searchText: String) {
        isSearching = !searchText.isEmpty
        
        searchDebouncer.debounce { [searchText] in
            updateCachedGroupsImmediate(searchText: searchText)
        }
    }
    
    /// Update cached groups immediately (no debouncing) - for category change events
    private func updateCachedGroupsImmediate(searchText: String) {
        #if DEBUG
        let startTime = CFAbsoluteTimeGetCurrent()
        #endif
        
        let categories = categoriesForSelectedTab
        
        #if DEBUG
        if !searchText.isEmpty {
            print("🔍 CATEGORYP STARTING SEARCH for '\(searchText)' across \(categories.count) categories")
        }
        #endif
        
        let filteredCategories = searchText.isEmpty ? categories :
            categories.filter { category in
                // Debug: Show what we're searching
                #if DEBUG
                if !searchText.isEmpty && (searchText.lowercased().contains("haircuts") || searchText.lowercased().contains("hair")) {
                    print("🔍 CATEGORYP SEARCH DEBUG for '\(searchText)':")
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
            print("🔍 CATEGORYP SEARCH RESULTS for '\(searchText)': Found \(filteredCategories.count) categories")
            for category in filteredCategories {
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
        
        // Helper function to check if a category has child categories (not just subcategories)
        func hasChildCategories(_ category: CategoryData) -> Bool {
            return filteredCategories.contains { $0.parentId == category.id }
        }
        
        // Convert to CategoryGroup format for display
        cachedGroups = filteredCategories.compactMap { category in
            // Skip categories that have a real parent (not "No Parent" containers)
            // Categories with "No Parent" containers should be treated as top-level
            if let parentId = category.parentId,
               let parent = categoriesManager.findCategory(by: parentId),
               !parent.name.hasPrefix("No Parent") {
                return nil // Skip - this has a real parent
            }
            
            let displayCategory = DisplayCategoryData(
                categoryData: category,
                isChild: false,
                parentName: nil,
                hasChildren: !category.subcategories.isEmpty || hasChildCategories(category)
            )
            
            // Collect both built-in subcategories and categories with this category as parent
            var allChildren: [DisplayCategoryData] = []
            
            // Add built-in subcategories (filter during search)
            let subcategoriesToShow = searchText.isEmpty ? category.subcategories : 
                category.subcategories.filter { subcategory in
                    subcategory.name.localizedCaseInsensitiveContains(searchText)
                }
            
            #if DEBUG
            if !searchText.isEmpty && (searchText.lowercased().contains("haircuts") || searchText.lowercased().contains("hair")) {
                print("🔍 CATEGORYP DISPLAY: Category '\(category.name)' - showing \(subcategoriesToShow.count) of \(category.subcategories.count) subcategories")
                print("🔍   - All subcategories: \(category.subcategories.map { $0.name })")
                print("🔍   - Filtered subcategories: \(subcategoriesToShow.map { $0.name })")
            }
            #endif
            
            let builtInSubcategories = subcategoriesToShow.map { subcategory in
                DisplayCategoryData(
                    categoryData: CategoryData(
                        id: subcategory.id, // Preserve the subcategory's original ID
                        name: subcategory.name, 
                        emoji: subcategory.emoji, 
                        subcategories: [],
                        type: category.type, // Inherit parent's type
                        parent: category.name,
                        parentId: category.id
                    ),
                    isChild: true,
                    parentName: category.name,
                    hasChildren: false
                )
            }
            allChildren.append(contentsOf: builtInSubcategories)
            
            // Add categories that have this category as their parent (excluding "No Parent" containers)
            let childCategories = filteredCategories.filter { childCategory in
                // Include if parent is this category, but exclude if this category is a "No Parent" container
                let hasThisParent = childCategory.parentId == category.id && !category.name.hasPrefix("No Parent")
                
                // During search, also filter by search term
                if !searchText.isEmpty {
                    return hasThisParent && childCategory.name.localizedCaseInsensitiveContains(searchText)
                }
                return hasThisParent
            }
            let childCategoryGroups = childCategories.map { childCategory in
                DisplayCategoryData(
                    categoryData: childCategory,
                    isChild: true,
                    parentName: category.name,
                    hasChildren: !childCategory.subcategories.isEmpty
                )
            }
            allChildren.append(contentsOf: childCategoryGroups)
            
            return CategoryGroup(parent: displayCategory, children: allChildren)
        }
        
        #if DEBUG
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        print("🔍 CategoryPicker search completed in \(String(format: "%.3f", duration))s for '\(searchText)' - showing \(filteredCategories.count) \(selectedTab == .income ? "income" : "expense") categories")
        #endif
        
        isSearching = false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            SheetHeader.withCustomAction(
                title: "Select Category",
                onBackTap: { isPresented = false },
                rightIcon: "settings-01",
                rightSystemIcon: "gearshape",
                onRightTap: {
                    showingEditCategories = true
                }
            )
        
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
                    updateCachedGroups(searchText: searchText)
                }
                
                TabChip.basic(title: "Expense", isSelected: selectedTab == .expense) {
                    selectedTab = .expense
                    updateCachedGroups(searchText: searchText)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            
            // Category list with loading state
            if isSearching && !searchText.isEmpty {
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Searching categories...")
                            .font(AppFonts.overusedGroteskMedium(size: 16))
                            .foregroundColor(AppColors.foregroundSecondary)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.backgroundWhite)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        // No Category option for transactions (only show when not searching)
                        if searchText.isEmpty {
                            NoCategoryOption(
                                tabType: selectedTab,
                                isSelected: isNoCategorySelected,
                                onTap: {
                                    selectNoCategory()
                                    searchText = ""
                                    isPresented = false
                                }
                            )
                        }
                        
                        ForEach(filteredGroups, id: \.id) { group in
                            GroupedCategoryForSelection(
                                parentCategory: group.parent,
                                children: group.children,
                                isParentSelected: isCategorySelected(group.parent.categoryData),
                                childSelectionCheck: isCategorySelected,
                                onParentTap: {
                                    selectCategory(group.parent.categoryData)
                                    searchText = ""
                                    isPresented = false
                                },
                                onChildTap: { childCategory in
                                    selectCategory(childCategory)
                                    searchText = ""
                                    isPresented = false
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .background(AppColors.backgroundWhite)
            }
        }
        .background(AppColors.backgroundWhite)
        .onAppear {
            // Smart tab selection based on current category
            if initialTab == nil && !selectedCategory.isEmpty {
                let result = categoriesManager.findCategoryOrSubcategory(by: selectedCategory)
                if result.category != nil || result.subcategory != nil {
                    // Determine type from category or parent
                    let categoryType = result.parent?.type ?? result.category?.type
                    if let type = categoryType {
                        selectedTab = (type == .income) ? .income : .expense
                        #if DEBUG
                        print("🎯 CategoryPickerSheet: Smart tab selection - '\(selectedCategory)' is \(type) -> \(selectedTab)")
                        #endif
                    }
                }
            }
            
            // Initialize cache on first load
            updateCachedGroups(searchText: "")
        }
        .onChange(of: searchText) { _, newValue in
            // Update cache when search text changes (debounced)
            updateCachedGroups(searchText: newValue)
        }
        .onReceive(categoriesManager.objectWillChange) { _ in
            // Refresh cache when categories change (add/edit/delete) - IMMEDIATE
            print("🔔 CategoryPickerSheet: Received category change notification")
            
            // Force clear cache and immediate update
            cachedGroups.removeAll()
            updateCachedGroupsImmediate(searchText: searchText)
            
            print("✅ CategoryPickerSheet: Cache refreshed with \(cachedGroups.count) groups")
        }
        .background(AppColors.backgroundWhite)
        .onAppear {
            // Smart tab selection based on current category
            if initialTab == nil && !selectedCategory.isEmpty {
                let result = categoriesManager.findCategoryOrSubcategory(by: selectedCategory)
                if result.category != nil || result.subcategory != nil {
                    selectedTab = (result.category?.type == .income || result.subcategory?.type == .income) ? .income : .expense
                }
            }
            
            // Initialize cache on first load
            updateCachedGroups(searchText: "")
        }
        .onChange(of: searchText) { _, newValue in
            // Update cache when search text changes (debounced)
            updateCachedGroups(searchText: newValue)
        }
        .onReceive(categoriesManager.objectWillChange) { _ in
            // Refresh cache when categories change (add/edit/delete) - IMMEDIATE
            print("🔔 CategoryPickerSheet: Received category change notification")
            
            // Force clear cache and immediate update
            cachedGroups.removeAll()
            updateCachedGroupsImmediate(searchText: searchText)
            
            print("✅ CategoryPickerSheet: Cache refreshed with \(cachedGroups.count) groups")
        }
        .sheet(isPresented: $showingEditCategories) {
            EditCategoriesSheet(
                isPresented: $showingEditCategories, 
                initialTab: selectedTab == .income ? .income : .expense
            )
            .presentationDetents([.fraction(0.98)])
            .presentationDragIndicator(.hidden)
        }
    }
}

// Grouped category container for selection
struct GroupedCategoryForSelection: View {
    let parentCategory: DisplayCategoryData
    let children: [DisplayCategoryData]
    let isParentSelected: Bool
    let childSelectionCheck: (CategoryData) -> Bool
    let onParentTap: () -> Void
    let onChildTap: (CategoryData) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Parent category row
            HStack(alignment: .center, spacing: 14) {
                Text(parentCategory.categoryData.emoji)
                    .font(.system(size: 20))
                
                Text(parentCategory.categoryData.name)
                    .font(AppFonts.overusedGroteskMedium(size: 16))
                    .foregroundColor(AppColors.foregroundPrimary)
                
                Spacer()
                
                // Selection indicator
                if isParentSelected {
                    AppIcon(assetName: "check-circle", fallbackSystemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.accentBackground)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 10,
                    bottomLeadingRadius: children.isEmpty ? 10 : 0,
                    bottomTrailingRadius: children.isEmpty ? 10 : 0,
                    topTrailingRadius: 10
                )
            )
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 10,
                    bottomLeadingRadius: children.isEmpty ? 10 : 0,
                    bottomTrailingRadius: children.isEmpty ? 10 : 0,
                    topTrailingRadius: 10
                )
                .inset(by: 0.5)
                .stroke(
                    isParentSelected ?
                        AppColors.accentBackground : AppColors.linePrimary,
                    lineWidth: isParentSelected ? 2 : 1
                )
            )
            .contentShape(Rectangle())
            .onTapGesture {
                onParentTap()
            }
            
            // Child categories
            if !children.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                        HStack(alignment: .center, spacing: 14) {
                            Text(child.categoryData.emoji)
                                .font(.system(size: 18))
                            
                            Text(child.categoryData.name)
                                .font(AppFonts.overusedGroteskMedium(size: 16))
                                .foregroundColor(AppColors.foregroundPrimary)
                            
                            Spacer()
                            
                            // Selection indicator
                            if childSelectionCheck(child.categoryData) {
                                AppIcon(assetName: "check-circle", fallbackSystemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(AppColors.accentBackground)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.953, green: 0.961, blue: 0.973)) // #F3F5F8
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onChildTap(child.categoryData)
                        }
                        
                        // Separator line between children (except last)
                        if index < children.count - 1 {
                            Divider()
                                .background(AppColors.linePrimary)
                                .padding(.horizontal, 20)
                        }
                    }
                }
                .background(Color(red: 0.953, green: 0.961, blue: 0.973))
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 10,
                        bottomTrailingRadius: 10,
                        topTrailingRadius: 0
                    )
                )
                .overlay(
                    GeometryReader { geometry in
                        Path { path in
                            let width = geometry.size.width
                            let height = geometry.size.height
                            
                            // Left border
                            path.move(to: CGPoint(x: 0.5, y: 0))
                            path.addLine(to: CGPoint(x: 0.5, y: height - 10))
                            
                            // Bottom left corner
                            path.addArc(center: CGPoint(x: 10.5, y: height - 10), 
                                       radius: 10, 
                                       startAngle: .degrees(180), 
                                       endAngle: .degrees(90), 
                                       clockwise: true)
                            
                            // Bottom border
                            path.addLine(to: CGPoint(x: width - 10, y: height - 0.5))
                            
                            // Bottom right corner
                            path.addArc(center: CGPoint(x: width - 10, y: height - 10), 
                                       radius: 10, 
                                       startAngle: .degrees(90), 
                                       endAngle: .degrees(0), 
                                       clockwise: true)
                            
                            // Right border
                            path.addLine(to: CGPoint(x: width - 0.5, y: 0))
                        }
                        .stroke(AppColors.linePrimary, lineWidth: 1)
                    }
                )
            }
        }
    }
}

// MARK: - No Category Option Component
struct NoCategoryOption: View {
    let tabType: CategoryPickerSheet.CategoryTab
    let isSelected: Bool
    let onTap: () -> Void
    
    private var noCategoryName: String {
        switch tabType {
        case .income:
            return "No Category (Income)"
        case .expense:
            return "No Category (Expense)"
        }
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text("📋")
                .font(.system(size: 20))
            
            Text(noCategoryName)
                .font(AppFonts.overusedGroteskMedium(size: 16))
                .foregroundColor(AppColors.foregroundSecondary)
            
            Spacer()
            
            // Selection indicator
            if isSelected {
                AppIcon(assetName: "check-circle", fallbackSystemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.accentBackground)
            }
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