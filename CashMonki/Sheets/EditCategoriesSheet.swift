//
//  EditCategoriesSheet.swift
//  Cashooya Playground
//
//  Created by Claude on 9/11/25.
//

import SwiftUI

struct EditCategoriesSheet: View {
    @Binding var isPresented: Bool
    let initialTab: CategoryTab?
    @State private var searchText = ""
    @State private var showingAddCategory = false
    @State private var showingCustomPaywall = false
    @ObservedObject private var categoriesManager = CategoriesManager.shared
    @ObservedObject private var revenueCatManager = RevenueCatManager.shared
    @EnvironmentObject private var toastManager: ToastManager
    @State private var selectedCategoryForEdit: DisplayCategoryData?
    @State private var selectedTab: CategoryTab = .expense
    
    enum CategoryTab {
        case income
        case expense
    }
    
    init(isPresented: Binding<Bool>, initialTab: CategoryTab? = nil) {
        self._isPresented = isPresented
        self.initialTab = initialTab
        // Set smart default based on initialTab
        self._selectedTab = State(initialValue: initialTab ?? .expense)
    }
    
    // Performance optimization: Use debouncer for search
    @State private var searchDebouncer = Debouncer(delay: 0.3)
    
    // Performance optimization: Cache filtered groups
    @State private var cachedGroups: [CategoryGroup] = []
    @State private var isSearching = false
    
    // Scroll position preservation
    @State private var scrollPosition = ScrollPosition()
    
    /// Get optimized cached category groups
    private var filteredGroups: [CategoryGroup] {
        return cachedGroups
    }
    
    /// Get categories based on selected tab (Income vs Expense)
    private var categoriesForSelectedTab: [CategoryData] {
        let result: [CategoryData]
        switch selectedTab {
        case .income:
            result = categoriesManager.allIncomeCategoriesWithCustom.filter { !$0.name.hasPrefix("No Parent") }
            print("🔥 TAB FILTER: Income tab selected, found \(result.count) income categories (excluding No Parent containers)")
        case .expense:
            result = categoriesManager.allExpenseCategoriesWithCustom.filter { !$0.name.hasPrefix("No Parent") }
            print("🔥 TAB FILTER: Expense tab selected, found \(result.count) expense categories (excluding No Parent containers)")
        }
        
        // Debug: Show category names and types for verification
        print("🔥 TAB CATEGORIES (\(selectedTab)):")
        for category in result.prefix(10) { // Show first 10 to avoid spam
            print("🔥   - '\(category.name)' (Type: \(category.type), ID: \(category.id.uuidString.prefix(8))..., Subcategories: \(category.subcategories.map { $0.name }))")
        }
        if result.count > 10 {
            print("🔥   ... and \(result.count - 10) more categories")
        }
        
        // Debug: Look specifically for categories containing "haircuts" subcategories
        let categoriesWithHaircuts = result.filter { category in
            category.subcategories.contains { $0.name.lowercased().contains("haircuts") }
        }
        if !categoriesWithHaircuts.isEmpty {
            print("🔥 CATEGORIES WITH HAIRCUTS SUBCATEGORIES:")
            for category in categoriesWithHaircuts {
                print("🔥   - '\(category.name)': \(category.subcategories.map { $0.name })")
            }
        }
        
        // Debug: Show ALL categories and their subcategories (for debugging duplicate subcategories)
        print("🔥 ALL CATEGORIES AND SUBCATEGORIES:")
        for category in result {
            if !category.subcategories.isEmpty {
                print("🔥   - '\(category.name)': \(category.subcategories.map { $0.name })")
            }
        }
        
        return result
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
            print("🔍 STARTING SEARCH for '\(searchText)' across \(categories.count) categories")
        }
        #endif
        
        let filteredCategories = searchText.isEmpty ? categories :
            categories.filter { category in
                // Debug: Show what we're searching
                #if DEBUG
                if !searchText.isEmpty && (searchText.lowercased().contains("haircuts") || searchText.lowercased().contains("hair")) {
                    print("🔍 SEARCH DEBUG for '\(searchText)':")
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
            print("🔍 SEARCH RESULTS for '\(searchText)': Found \(filteredCategories.count) categories")
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
                print("🔍 DISPLAY: Category '\(category.name)' - showing \(subcategoriesToShow.count) of \(category.subcategories.count) subcategories")
                print("🔍   - All subcategories: \(category.subcategories.map { $0.name })")
                print("🔍   - Filtered subcategories: \(subcategoriesToShow.map { $0.name })")
            }
            #endif
            
            let builtInSubcategories = subcategoriesToShow.map { subcategory in
                DisplayCategoryData(
                    categoryData: CategoryData(name: subcategory.name, emoji: subcategory.emoji, subcategories: []),
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
        print("🔍 EditCategories search completed in \(String(format: "%.3f", duration))s for '\(searchText)' - showing \(filteredCategories.count) \(selectedTab == .income ? "income" : "expense") categories")
        #endif
        
        isSearching = false
    }
    
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            SheetHeader.withCustomAction(
                title: "Edit Categories",
                onBackTap: { isPresented = false },
                rightIcon: "plus",
                rightSystemIcon: "plus",
                onRightTap: {
                    if revenueCatManager.isProUser {
                    showingAddCategory = true
                } else {
                    showingCustomPaywall = true
                }
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
                        ForEach(filteredGroups, id: \.id) { group in
                            GroupedCategoryForEdit(
                                parentCategory: group.parent,
                                children: group.children,
                                onParentTap: {
                                    if revenueCatManager.isProUser {
                                        selectedCategoryForEdit = group.parent
                                        
                                        // Set smart tab default based on category type
                                        if group.parent.categoryData.type == .income {
                                            selectedTab = .income
                                        } else {
                                            selectedTab = .expense
                                        }
                                        
                                        searchText = ""
                                    } else {
                                        showingCustomPaywall = true
                                    }
                                },
                                onChildTap: { childCategory in
                                    if revenueCatManager.isProUser {
                                        selectedCategoryForEdit = childCategory
                                        
                                        // Set smart tab default based on category type
                                        if childCategory.categoryData.type == .income {
                                            selectedTab = .income
                                        } else {
                                            selectedTab = .expense
                                        }
                                        
                                        searchText = ""
                                    } else {
                                        showingCustomPaywall = true
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .scrollPosition($scrollPosition)
                .background(AppColors.backgroundWhite)
            }
        }
        .background(AppColors.backgroundWhite)
        .onAppear {
            // Initialize cache on first load
            updateCachedGroups(searchText: "")
        }
        .onChange(of: searchText) { _, newValue in
            // Update cache when search text changes (debounced)
            updateCachedGroups(searchText: newValue)
        }
        .onReceive(categoriesManager.objectWillChange) { _ in
            // Refresh cache when categories change (add/edit/delete) - IMMEDIATE
            print("🔔 EditCategoriesSheet: Received category change notification")
            
            // Store current scroll position before refresh
            let currentPosition = scrollPosition
            
            // Force clear the cache to ensure fresh data
            cachedGroups.removeAll()
            // Use immediate update (no debouncing) for category changes
            updateCachedGroupsImmediate(searchText: searchText)
            
            print("✅ EditCategoriesSheet: Cache refreshed with \(cachedGroups.count) groups")
            
            // Restore scroll position immediately
            scrollPosition = currentPosition
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategorySheet(
                isPresented: $showingAddCategory,
                currentTab: selectedTab == .income ? .income : .expense
            )
            .presentationDetents([.fraction(0.98)])
            .presentationDragIndicator(.hidden)
        }
        .fullScreenCover(isPresented: $showingCustomPaywall) {
            CustomPaywallSheet(isPresented: $showingCustomPaywall)
        }
        .sheet(
            isPresented: Binding(
                get: { selectedCategoryForEdit != nil },
                set: { if !$0 { selectedCategoryForEdit = nil } }
            )
        ) {
            if let categoryData = selectedCategoryForEdit {
                EditCategoryDetailSheet(
                    categoryData: categoryData,
                    currentTab: selectedTab == .income ? .income : .expense,
                    onDismiss: {
                        selectedCategoryForEdit = nil
                        print("🔔 EditCategoriesSheet: Manual refresh on dismiss")
                        
                        // Force immediate refresh when returning from edit (backup mechanism)
                        let currentPosition = scrollPosition
                        cachedGroups.removeAll()
                        updateCachedGroupsImmediate(searchText: searchText)
                        scrollPosition = currentPosition
                        
                        print("✅ EditCategoriesSheet: Manual refresh completed with \(cachedGroups.count) groups")
                    }
                )
                .presentationDetents([.fraction(0.98)])
                .presentationDragIndicator(.hidden)
            }
        }
    }
}

// MARK: - Grouped Category for Edit
struct GroupedCategoryForEdit: View {
    let parentCategory: DisplayCategoryData
    let children: [DisplayCategoryData]
    let onParentTap: () -> Void
    let onChildTap: (DisplayCategoryData) -> Void
    
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
                
                // Edit chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColors.foregroundSecondary)
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
                .stroke(AppColors.linePrimary, lineWidth: 1)
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
                            
                            // Edit chevron
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.foregroundSecondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.953, green: 0.961, blue: 0.973)) // #F3F5F8
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onChildTap(child)
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

// MARK: - Category Row Item for Edit
private struct CategoryRowItemForEdit: View {
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

