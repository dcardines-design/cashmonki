import Foundation

// MARK: - Category Data Structure

enum CategoryType: String, Codable, CaseIterable {
    case income = "income"
    case expense = "expense"
}

struct CategoryData: Codable, Identifiable {
    let id: UUID
    let name: String
    let emoji: String
    let subcategories: [SubcategoryData]
    let type: CategoryType
    let parent: String? // Parent category name (nil for top-level categories)
    let parentId: UUID? // Parent category ID (nil for top-level categories)
    
    init(id: UUID = UUID(), name: String, emoji: String, subcategories: [SubcategoryData] = [], type: CategoryType = .expense, parent: String? = nil, parentId: UUID? = nil) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.subcategories = subcategories
        self.type = type
        self.parent = parent
        self.parentId = parentId
    }
}

struct SubcategoryData: Codable, Identifiable {
    let id: UUID
    let name: String
    let emoji: String
    let type: CategoryType // Income or expense classification
    let parent: String? // Parent category name (usually set for subcategories)
    let parentId: UUID? // Parent category ID (usually set for subcategories)
    
    init(id: UUID = UUID(), name: String, emoji: String, type: CategoryType = .expense, parent: String? = nil, parentId: UUID? = nil) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.type = type
        self.parent = parent
        self.parentId = parentId
    }
}

// MARK: - Unified Category Data Structure
struct UnifiedCategoryData: Codable, Identifiable {
    let id: UUID
    var name: String
    var emoji: String
    var subcategories: [SubcategoryData]
    var type: CategoryType
    var parentCategoryId: UUID? // nil if it's a top-level category
    var isBuiltIn: Bool // true for original categories, false for user-created
    var isDeleted: Bool // soft delete flag
    var createdAt: Date
    var updatedAt: Date
    
    init(name: String, emoji: String, subcategories: [SubcategoryData] = [], type: CategoryType = .expense, parentCategoryId: UUID? = nil, isBuiltIn: Bool = false) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.subcategories = subcategories
        self.type = type
        self.parentCategoryId = parentCategoryId
        self.isBuiltIn = isBuiltIn
        self.isDeleted = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // Constructor that preserves existing UUID (for built-in categories)
    init(id: UUID, name: String, emoji: String, subcategories: [SubcategoryData] = [], type: CategoryType = .expense, parentCategoryId: UUID? = nil, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.subcategories = subcategories
        self.type = type
        self.parentCategoryId = parentCategoryId
        self.isBuiltIn = isBuiltIn
        self.isDeleted = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Category Group Structure for Optimized Display
struct CategoryGroup: Identifiable, Equatable {
    let id = UUID()
    let parent: DisplayCategoryData
    let children: [DisplayCategoryData]
    
    static func == (lhs: CategoryGroup, rhs: CategoryGroup) -> Bool {
        return lhs.parent.categoryData.name == rhs.parent.categoryData.name &&
               lhs.children.count == rhs.children.count
    }
}

// MARK: - Categories Manager

class CategoriesManager: ObservableObject {
    static let shared = CategoriesManager()
    
    @Published var categoryHierarchy: [String: [String]] = [:] // parentCategory: [childCategories]
    
    // MARK: - Performance Optimization: Category Group Caching
    @Published private var cachedGroupedCategories: [CategoryGroup] = []
    private var lastCacheUpdate: Date = Date.distantPast
    private var lastSearchCache: [String: [CategoryGroup]] = [:]
    private let cacheValidityDuration: TimeInterval = 60 // 1 minute
    
    private let hierarchyKey = "CategoryHierarchy"
    
    private func saveCategoryHierarchy() {
        if let encoded = try? JSONEncoder().encode(categoryHierarchy) {
            UserDefaults.standard.set(encoded, forKey: hierarchyKey)
        }
    }
    
    private func loadCategoryHierarchy() {
        if let data = UserDefaults.standard.data(forKey: hierarchyKey),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            categoryHierarchy = decoded
        }
    }
    
    private init() {
        loadCategoryHierarchy()
        loadCategories()
        migrateFromOldSystemIfNeeded()
        
        // Ensure "No Category" entries exist with proper UUIDs
        ensureNoCategoryEntriesExist()
        
        // Fix any existing orphaned transactions after a delay to ensure UserManager is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.fixOrphanedTransactions()
        }
        
        // Cache is already built in loadCategories()
    }
    
    // All income categories with their subcategories
    let allIncomeCategories: [CategoryData] = [
        CategoryData(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "No Category", 
            emoji: "❓", 
            subcategories: [],
            type: .income
        ),
        CategoryData(name: "Salary", emoji: "💼", subcategories: [
            SubcategoryData(name: "Base Salary", emoji: "💰", type: .income),
            SubcategoryData(name: "Overtime", emoji: "⏰", type: .income),
            SubcategoryData(name: "Bonus", emoji: "🎁", type: .income)
        ]),
        CategoryData(
            id: UUID(uuidString: "B1C1E001-1234-5678-9ABC-DEF012345678")!,
            name: "Business Income", 
            emoji: "🏢", 
            subcategories: [
                SubcategoryData(name: "Revenue", emoji: "📈", type: .income),
                SubcategoryData(name: "Business Consulting", emoji: "💼", type: .income),
                SubcategoryData(name: "Services", emoji: "🔧", type: .income)
            ],
            type: .income
        ),
        CategoryData(name: "Passive", emoji: "📊", subcategories: [
            SubcategoryData(name: "Dividends", emoji: "💎", type: .income),
            SubcategoryData(name: "Investment Interest", emoji: "🏦", type: .income),
            SubcategoryData(name: "Royalties", emoji: "👑", type: .income)
        ]),
        CategoryData(name: "Investment", emoji: "📈", subcategories: [
            SubcategoryData(name: "Stocks", emoji: "📊", type: .income),
            SubcategoryData(name: "Crypto", emoji: "₿", type: .income),
            SubcategoryData(name: "Real Estate", emoji: "🏠", type: .income)
        ]),
        CategoryData(name: "Government", emoji: "🏛️", subcategories: [
            SubcategoryData(name: "Tax Refund", emoji: "🔄", type: .income),
            SubcategoryData(name: "Benefits", emoji: "🛡️", type: .income),
            SubcategoryData(name: "Stimulus", emoji: "💰", type: .income)
        ]),
        CategoryData(name: "Miscellaneous", emoji: "🔄", subcategories: [
            SubcategoryData(name: "Other Income", emoji: "💵", type: .income),
            SubcategoryData(name: "Found Money", emoji: "🪙", type: .income),
            SubcategoryData(name: "Cash Back", emoji: "💳", type: .income)
        ]),
        CategoryData(name: "Refunds", emoji: "🔄", subcategories: [
            SubcategoryData(name: "Product Returns", emoji: "📦", type: .income),
            SubcategoryData(name: "Service Refunds", emoji: "🔧", type: .income),
            SubcategoryData(name: "Insurance Claims", emoji: "🛡️", type: .income)
        ]),
        CategoryData(name: "Prizes", emoji: "🏆", subcategories: [
            SubcategoryData(name: "Contests", emoji: "🎪", type: .income),
            SubcategoryData(name: "Lottery", emoji: "🎲", type: .income),
            SubcategoryData(name: "Awards", emoji: "🥇", type: .income)
        ]),
        CategoryData(name: "Donations", emoji: "💝", subcategories: [
            SubcategoryData(name: "Gifts Received", emoji: "🎁", type: .income),
            SubcategoryData(name: "Charity Returns", emoji: "❤️", type: .income),
            SubcategoryData(name: "Crowdfunding", emoji: "👥", type: .income)
        ])
    ]
    
    // All expense categories with their subcategories
    let allCategories: [CategoryData] = [
        CategoryData(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "No Category", 
            emoji: "❓", 
            subcategories: [],
            type: .expense
        ),
        
        CategoryData(name: "Home", emoji: "🏠", subcategories: [
            SubcategoryData(name: "Rent/Mortgage", emoji: "🔑", type: .expense),
            SubcategoryData(name: "Property Tax", emoji: "📝", type: .expense),
            SubcategoryData(name: "Home Repairs", emoji: "🔨", type: .expense)
        ]),
        
        CategoryData(name: "Utilities & Bills", emoji: "💡", subcategories: [
            SubcategoryData(name: "Electricity", emoji: "⚡", type: .expense),
            SubcategoryData(name: "Water", emoji: "💧", type: .expense),
            SubcategoryData(name: "Internet", emoji: "📶", type: .expense)
        ]),
        
        CategoryData(name: "Food", emoji: "🍎", subcategories: [
            SubcategoryData(name: "Groceries", emoji: "🛒", type: .expense),
            SubcategoryData(name: "Snacks", emoji: "🥨", type: .expense),
            SubcategoryData(name: "Meal Prep", emoji: "🥡", type: .expense)
        ]),
        
        CategoryData(name: "Dining", emoji: "🍽️", subcategories: [
            SubcategoryData(name: "Restaurants", emoji: "🍛", type: .expense),
            SubcategoryData(name: "Cafes", emoji: "☕", type: .expense),
            SubcategoryData(name: "Takeout", emoji: "🥡", type: .expense)
        ]),
        
        CategoryData(name: "Transport", emoji: "🚗", subcategories: [
            SubcategoryData(name: "Fuel", emoji: "⛽", type: .expense),
            SubcategoryData(name: "Car Payments", emoji: "💵", type: .expense),
            SubcategoryData(name: "Rideshare", emoji: "🚕", type: .expense)
        ]),
        
        CategoryData(name: "Insurance", emoji: "🛡️", subcategories: [
            SubcategoryData(name: "Auto Insurance", emoji: "🚘", type: .expense),
            SubcategoryData(name: "Home Insurance", emoji: "🏡", type: .expense),
            SubcategoryData(name: "Life Insurance", emoji: "📃", type: .expense)
        ]),
        
        CategoryData(name: "Health", emoji: "🩺", subcategories: [
            SubcategoryData(name: "Doctor Visits", emoji: "👨‍⚕️", type: .expense),
            SubcategoryData(name: "Medications", emoji: "💊", type: .expense),
            SubcategoryData(name: "Therapy", emoji: "🧠", type: .expense)
        ]),
        
        CategoryData(name: "Debt", emoji: "💳", subcategories: [
            SubcategoryData(name: "Credit Cards", emoji: "💲", type: .expense),
            SubcategoryData(name: "Loans", emoji: "📊", type: .expense),
            SubcategoryData(name: "Loan Interest", emoji: "📈", type: .expense)
        ]),
        
        CategoryData(name: "Fun", emoji: "🎭", subcategories: [
            SubcategoryData(name: "Movies", emoji: "🎬", type: .expense),
            SubcategoryData(name: "Concerts", emoji: "🎵", type: .expense),
            SubcategoryData(name: "Games", emoji: "🎮", type: .expense)
        ]),
        
        CategoryData(name: "Clothes", emoji: "👕", subcategories: [
            SubcategoryData(name: "Work Attire", emoji: "👔", type: .expense),
            SubcategoryData(name: "Casual Wear", emoji: "👖", type: .expense),
            SubcategoryData(name: "Shoes", emoji: "👟", type: .expense)
        ]),
        
        CategoryData(name: "Personal", emoji: "💇", subcategories: [
            SubcategoryData(name: "Haircuts", emoji: "✂️", type: .expense),
            SubcategoryData(name: "Skincare", emoji: "🧴", type: .expense),
            SubcategoryData(name: "Hygiene", emoji: "🧼", type: .expense)
        ]),
        
        CategoryData(name: "Learning", emoji: "📚", subcategories: [
            SubcategoryData(name: "Tuition", emoji: "🎓", type: .expense),
            SubcategoryData(name: "Books", emoji: "📖", type: .expense),
            SubcategoryData(name: "Courses", emoji: "💻", type: .expense)
        ]),
        
        CategoryData(name: "Kids", emoji: "👶", subcategories: [
            SubcategoryData(name: "Childcare", emoji: "🧒", type: .expense),
            SubcategoryData(name: "Toys", emoji: "🧸", type: .expense),
            SubcategoryData(name: "Activities", emoji: "🎨", type: .expense)
        ]),
        
        CategoryData(name: "Pets", emoji: "🐾", subcategories: [
            SubcategoryData(name: "Vet Care", emoji: "🏥", type: .expense),
            SubcategoryData(name: "Pet Food", emoji: "🥫", type: .expense),
            SubcategoryData(name: "Grooming", emoji: "✂️", type: .expense)
        ]),
        
        CategoryData(name: "Gifts", emoji: "🎁", subcategories: [
            SubcategoryData(name: "Presents", emoji: "🎀", type: .expense),
            SubcategoryData(name: "Donations", emoji: "💝", type: .expense),
            SubcategoryData(name: "Cards", emoji: "💌", type: .expense)
        ]),
        
        CategoryData(name: "Travel", emoji: "✈️", subcategories: [
            SubcategoryData(name: "Flights", emoji: "🛫", type: .expense),
            SubcategoryData(name: "Hotels", emoji: "🏨", type: .expense),
            SubcategoryData(name: "Rental Cars", emoji: "🚙", type: .expense)
        ]),
        
        CategoryData(name: "Subscriptions", emoji: "🔄", subcategories: [
            SubcategoryData(name: "Streaming", emoji: "📺", type: .expense),
            SubcategoryData(name: "Software", emoji: "🖥️", type: .expense),
            SubcategoryData(name: "Memberships", emoji: "🔑", type: .expense)
        ]),
        
        CategoryData(name: "Household", emoji: "🧹", subcategories: [
            SubcategoryData(name: "Cleaning", emoji: "🧽", type: .expense),
            SubcategoryData(name: "Furniture", emoji: "🛋️", type: .expense),
            SubcategoryData(name: "Decor", emoji: "🏺", type: .expense)
        ]),
        
        CategoryData(name: "Services", emoji: "👔", subcategories: [
            SubcategoryData(name: "Legal", emoji: "⚖️", type: .expense),
            SubcategoryData(name: "Accounting", emoji: "🧮", type: .expense),
            SubcategoryData(name: "Professional Consulting", emoji: "💼", type: .expense)
        ]),
        
        CategoryData(name: "Supplies", emoji: "📎", subcategories: [
            SubcategoryData(name: "Office", emoji: "📌", type: .expense),
            SubcategoryData(name: "Crafts", emoji: "🖌️", type: .expense),
            SubcategoryData(name: "Packaging", emoji: "📦", type: .expense)
        ]),
        
        CategoryData(name: "Fitness", emoji: "🧘", subcategories: [
            SubcategoryData(name: "Gym", emoji: "🏋️", type: .expense),
            SubcategoryData(name: "Fitness Equipment", emoji: "🎯", type: .expense),
            SubcategoryData(name: "Classes", emoji: "🤸", type: .expense)
        ]),
        
        CategoryData(name: "Tech", emoji: "💻", subcategories: [
            SubcategoryData(name: "Devices", emoji: "📱", type: .expense),
            SubcategoryData(name: "Accessories", emoji: "🎧", type: .expense),
            SubcategoryData(name: "Tech Repairs", emoji: "🔧", type: .expense)
        ]),
        
        CategoryData(
            id: UUID(uuidString: "B1C1E002-1234-5678-9ABC-DEF012345678")!,
            name: "Business Expenses", 
            emoji: "💼", 
            subcategories: [
                SubcategoryData(name: "Marketing", emoji: "📣", type: .expense),
                SubcategoryData(name: "Inventory", emoji: "📦", type: .expense),
                SubcategoryData(name: "Workspace", emoji: "🏢", type: .expense)
            ],
            type: .expense
        ),
        
        CategoryData(name: "Taxes", emoji: "📑", subcategories: [
            SubcategoryData(name: "Income Tax", emoji: "💸", type: .expense),
            SubcategoryData(name: "Sales Tax", emoji: "🧾", type: .expense),
            SubcategoryData(name: "Filing Fees", emoji: "📋", type: .expense)
        ]),
        
        CategoryData(name: "Savings", emoji: "💰", subcategories: [
            SubcategoryData(name: "Emergency Fund", emoji: "🚨", type: .expense),
            SubcategoryData(name: "Retirement", emoji: "👵", type: .expense),
            SubcategoryData(name: "Investments", emoji: "📈", type: .expense)
        ]),
        
        CategoryData(name: "Auto", emoji: "🔩", subcategories: [
            SubcategoryData(name: "Maintenance", emoji: "🔧", type: .expense),
            SubcategoryData(name: "Registration", emoji: "📃", type: .expense),
            SubcategoryData(name: "Parking", emoji: "🅿️", type: .expense)
        ]),
        
        CategoryData(name: "Drinks", emoji: "🍷", subcategories: [
            SubcategoryData(name: "Coffee", emoji: "☕", type: .expense),
            SubcategoryData(name: "Alcohol", emoji: "🍺", type: .expense),
            SubcategoryData(name: "Beverages", emoji: "🥤", type: .expense)
        ]),
        
        CategoryData(name: "Hobbies", emoji: "🎨", subcategories: [
            SubcategoryData(name: "Supplies", emoji: "🧶", type: .expense),
            SubcategoryData(name: "Hobby Equipment", emoji: "🎣", type: .expense),
            SubcategoryData(name: "Events", emoji: "🎪", type: .expense)
        ]),
        
        CategoryData(name: "Events", emoji: "🎉", subcategories: [
            SubcategoryData(name: "Parties", emoji: "🎊", type: .expense),
            SubcategoryData(name: "Tickets", emoji: "🎫", type: .expense),
            SubcategoryData(name: "Ceremonies", emoji: "💍", type: .expense)
        ]),
        
        CategoryData(name: "Other", emoji: "🔄", subcategories: [
            SubcategoryData(name: "Fees", emoji: "💲", type: .expense),
            SubcategoryData(name: "Miscellaneous", emoji: "❓", type: .expense),
            SubcategoryData(name: "Uncategorized", emoji: "📋", type: .expense)
        ])
    ]
    
    // MARK: - Helper Methods
    
    /// Get all subcategory names (flattened)
    var subcategoryNames: [String] {
        return allCategoriesWithCustom.flatMap { category in
            category.subcategories.map { $0.name }
        }
    }
    
    // MARK: - ID-Based Lookup Methods (Performance Optimized)
    
    /// Fast O(1) lookup of category by ID
    func findCategoryById(_ id: UUID) -> UnifiedCategoryData? {
        return categories.first { $0.id == id }
    }
    
    /// Fast O(1) lookup of category or subcategory by ID  
    func findCategoryOrSubcategoryById(_ id: UUID) -> (category: UnifiedCategoryData?, subcategory: SubcategoryData?, parent: UnifiedCategoryData?)? {
        #if DEBUG
        print("🔍 findCategoryOrSubcategoryById: Looking for ID \(id.uuidString.prefix(8))")
        #endif
        
        // First check main categories using optimized lookup
        if let category = findCategory(by: id) {
            #if DEBUG
            print("🔍 findCategoryOrSubcategoryById: Found category '\(category.name)' with ID \(id.uuidString.prefix(8))")
            #endif
            return (category: category, subcategory: nil, parent: nil)
        }
        
        // Then check subcategories
        for category in categories {
            if let subcategory = category.subcategories.first(where: { $0.id == id }) {
                #if DEBUG
                print("🔍 findCategoryOrSubcategoryById: Found subcategory '\(subcategory.name)' under '\(category.name)' with ID \(id.uuidString.prefix(8))")
                #endif
                return (category: nil, subcategory: subcategory, parent: category)
            }
        }
        
        #if DEBUG
        print("🔍 findCategoryOrSubcategoryById: No category or subcategory found for ID \(id.uuidString.prefix(8))")
        #endif
        return nil
    }
    
    /// Get category ID from category name (for migration purposes)
    func getCategoryId(for categoryName: String) -> UUID? {
        print("🔍 getCategoryId: Looking for '\(categoryName)'")
        let result = findCategoryOrSubcategory(by: categoryName)
        print("🔍 getCategoryId result: isSubcategory=\(result.isSubcategory), category=\(result.category?.name ?? "nil"), subcategory=\(result.subcategory?.name ?? "nil"), parent=\(result.parent?.name ?? "nil")")
        
        if result.category != nil || result.subcategory != nil {
            let id = result.category?.id ?? result.subcategory?.id
            print("✅ getCategoryId: Found ID \(id?.uuidString.prefix(8) ?? "nil") for '\(categoryName)'")
            return id
        }
        
        // Log missing category for debugging
        print("⚠️ getCategoryId: Category '\(categoryName)' not found")
        print("📋 Available categories: \(categoryNames.joined(separator: ", "))")
        print("📋 Available subcategories: \(subcategoryNames.joined(separator: ", "))")
        return nil
    }
    
    /// Check if a string is a valid category
    func isValidCategory(_ name: String) -> Bool {
        return categoryNames.contains { $0.lowercased() == name.lowercased() }
    }
    
    /// Check if a string is a valid subcategory
    func isValidSubcategory(_ name: String) -> Bool {
        return subcategoryNames.contains { $0.lowercased() == name.lowercased() }
    }
    
    /// Get subcategories for a specific category
    func subcategoriesFor(category: String) -> [SubcategoryData] {
        return allCategoriesWithCustom.first { $0.name.lowercased() == category.lowercased() }?.subcategories ?? []
    }
    
    // MARK: - Hierarchy Management
    
    /// Get organized categories with hierarchy
    func getHierarchicalCategories() -> [DisplayCategoryData] {
        var result: [DisplayCategoryData] = []
        
        print("🔍 getHierarchicalCategories called (NEW UNIFIED SYSTEM)")
        
        // Get all parent categories (no parent assigned)
        let parents = parentCategories
        print("👨‍👩‍👧‍👦 Parent categories: \(parents.map { $0.name })")
        
        for parent in parents {
            // Convert to legacy CategoryData format
            let parentCategoryData = CategoryData(name: parent.name, emoji: parent.emoji, subcategories: parent.subcategories)
            
            // Get children for this parent
            let children = getChildCategories(for: parent.id)
            let hasChildren = !children.isEmpty
            
            // Add parent to result
            result.append(DisplayCategoryData(
                categoryData: parentCategoryData,
                isChild: false,
                parentName: nil,
                hasChildren: hasChildren
            ))
            
            // Add children to result
            for child in children {
                let childCategoryData = CategoryData(name: child.name, emoji: child.emoji, subcategories: child.subcategories)
                result.append(DisplayCategoryData(
                    categoryData: childCategoryData,
                    isChild: true,
                    parentName: parent.name,
                    hasChildren: false
                ))
                print("✅ Added child category: \(child.name) under \(parent.name)")
            }
        }
        
        print("📝 Final result: \(result.count) categories (\(parents.count) parents, \(result.count - parents.count) children)")
        return result
    }
    
    // MARK: - Optimized Category Group Management
    
    /// Get cached and optimized category groups for display
    /// This method provides significant performance improvements over repeated getHierarchicalCategories calls
    func getCachedGroupedCategories(searchText: String = "") -> [CategoryGroup] {
        let cacheKey = searchText.isEmpty ? "all" : searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if we have a valid cached result for this search
        if let cachedResult = lastSearchCache[cacheKey],
           !shouldRefreshCache() {
            #if DEBUG
            print("📊 Cache HIT for '\(cacheKey)' - returning \(cachedResult.count) groups")
            #endif
            return cachedResult
        }
        
        // Cache miss - need to calculate
        #if DEBUG
        print("📊 Cache MISS for '\(cacheKey)' - calculating groups")
        #endif
        
        // Refresh main cache if needed
        if shouldRefreshCache() {
            refreshCategoryGroupCache()
        }
        
        // Apply search filter if needed
        let filteredGroups = searchText.isEmpty ? cachedGroupedCategories : 
                            filterCachedCategories(searchText: searchText)
        
        // Cache the result
        lastSearchCache[cacheKey] = filteredGroups
        
        return filteredGroups
    }
    
    /// Check if cache needs refreshing
    private func shouldRefreshCache() -> Bool {
        return Date().timeIntervalSince(lastCacheUpdate) > cacheValidityDuration ||
               cachedGroupedCategories.isEmpty
    }
    
    /// Refresh the main category group cache
    private func refreshCategoryGroupCache() {
        #if DEBUG
        let startTime = CFAbsoluteTimeGetCurrent()
        #endif
        
        let hierarchicalCategories = getHierarchicalCategories()
        var groups: [CategoryGroup] = []
        
        // Group parent categories with their children
        let parentCategories = hierarchicalCategories.filter { !$0.isChild }
        
        for parent in parentCategories {
            let children = hierarchicalCategories.filter { 
                $0.isChild && $0.parentName == parent.categoryData.name 
            }
            
            groups.append(CategoryGroup(
                parent: parent,
                children: children
            ))
        }
        
        // Update cache
        cachedGroupedCategories = groups
        lastCacheUpdate = Date()
        
        // Clear search cache when main cache is refreshed
        lastSearchCache.removeAll()
        
        #if DEBUG
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        print("🔄 Cache refreshed with \(groups.count) groups in \(String(format: "%.3f", duration))s")
        #endif
    }
    
    /// Filter cached categories based on search text
    private func filterCachedCategories(searchText: String) -> [CategoryGroup] {
        let searchLower = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchLower.isEmpty else { return cachedGroupedCategories }
        
        return cachedGroupedCategories.compactMap { group in
            // Check if parent matches search (category name or subcategory names)
            let shouldIncludeParent = group.parent.categoryData.name.localizedCaseInsensitiveContains(searchLower) ||
                                    group.parent.categoryData.subcategories.contains { subcategory in
                                        subcategory.name.localizedCaseInsensitiveContains(searchLower)
                                    }
            
            // Filter children that match search
            let filteredChildren = group.children.filter { child in
                child.categoryData.name.localizedCaseInsensitiveContains(searchLower)
            }
            
            // Include group if parent matches or has matching children
            if shouldIncludeParent || !filteredChildren.isEmpty {
                return CategoryGroup(
                    parent: group.parent,
                    children: shouldIncludeParent ? group.children : filteredChildren
                )
            }
            return nil
        }
    }
    
    /// Clear category group caches (useful for memory pressure)
    func clearCategoryGroupCache() {
        cachedGroupedCategories.removeAll()
        lastSearchCache.removeAll()
        lastCacheUpdate = Date.distantPast
        
        print("🧹 Category group cache cleared")
    }
    
    // MARK: - Legacy Support Methods (for backward compatibility)
    
    /// Get children for a parent category (legacy method)
    func getChildrenFor(_ parentName: String) -> [CategoryData] {
        guard let parent = findCategory(by: parentName) else { return [] }
        let children = getChildCategories(for: parent.id)
        return children.map { CategoryData(name: $0.name, emoji: $0.emoji, subcategories: $0.subcategories) }
    }
    
    /// Check if a category is currently a parent (has children)
    func isParentCategory(_ categoryName: String) -> Bool {
        guard let parent = findCategory(by: categoryName) else { return false }
        return !getChildCategories(for: parent.id).isEmpty
    }
    
    /// Get emoji for category name with optional type context
    func emojiFor(category: String, type: CategoryType? = nil) -> String {
        // First try unified category system (top-level categories)
        if let unifiedCategory = findCategory(by: category) {
            return unifiedCategory.emoji
        }
        
        // Then try subcategory lookup
        if let subcategoryResult = findSubcategory(by: category) {
            return subcategoryResult.subcategory.emoji
        }
        
        print("⚠️ emojiFor: Category '\(category)' not found in unified system, falling back...")
        ensureLookupCacheValid()
        print("🔍 emojiFor: Available categories in cache: \(categoryLookupByName.keys.sorted())")
        
        // Try partial match for renamed categories (e.g., "Parking Cost" should match "Parking")
        let categoryLower = category.lowercased()
        for (cachedName, cachedCategory) in categoryLookupByName {
            if categoryLower.contains(cachedName) || cachedName.contains(categoryLower) {
                return cachedCategory.emoji
            }
        }
        
        // Try partial match in subcategories
        for cachedCategory in categories.filter({ !$0.isDeleted }) {
            for subcategory in cachedCategory.subcategories {
                let subLower = subcategory.name.lowercased()
                if categoryLower.contains(subLower) || subLower.contains(categoryLower) {
                    return subcategory.emoji
                }
            }
        }
        
        // If type is specified, search in that specific category type first
        if let type = type {
            let categories = type == .income ? allIncomeCategories : allCategories
            for categoryData in categories {
                if categoryData.name.lowercased() == category.lowercased() {
                    return categoryData.emoji
                }
                // Also search subcategories
                for subcategory in categoryData.subcategories {
                    if subcategory.name.lowercased() == category.lowercased() {
                        return subcategory.emoji
                    }
                }
            }
        }
        
        // Fall back to searching both (income first for compatibility)
        for categoryData in allIncomeCategories {
            if categoryData.name.lowercased() == category.lowercased() {
                return categoryData.emoji
            }
            for subcategory in categoryData.subcategories {
                if subcategory.name.lowercased() == category.lowercased() {
                    return subcategory.emoji
                }
            }
        }
        
        for categoryData in allCategories {
            if categoryData.name.lowercased() == category.lowercased() {
                return categoryData.emoji
            }
            for subcategory in categoryData.subcategories {
                if subcategory.name.lowercased() == category.lowercased() {
                    return subcategory.emoji
                }
            }
        }
        
        return "📋"
    }
    
    /// Legacy method for backward compatibility
    func emojiFor(category: String) -> String {
        return emojiFor(category: category, type: nil)
    }
    
    /// Get emoji for subcategory name (optimized O(1) lookup)
    func emojiFor(subcategory: String) -> String {
        ensureLookupCacheValid()
        if let parentCategories = subcategoryLookup[subcategory.lowercased()] {
            // Try income categories first (they're processed first, so they're earlier in the array)
            for parentCategory in parentCategories {
                if let subcategoryData = parentCategory.subcategories.first(where: { $0.name.lowercased() == subcategory.lowercased() }) {
                    return subcategoryData.emoji
                }
            }
        }
        return "📋"
    }
    
    /// Get all category names (cached for performance)
    var categoryNames: [String] {
        ensureLookupCacheValid()
        return cachedCategoryNames
    }
    
    /// Check if a category name exists (uses O(1) lookup)
    func categoryExists(_ name: String) -> Bool {
        return findCategory(by: name) != nil
    }
    
    /// Find category for a given subcategory (optimized O(1) lookup)
    func categoryFor(subcategory: String) -> CategoryData? {
        ensureLookupCacheValid()
        if let parentCategories = subcategoryLookup[subcategory.lowercased()] {
            // Try income categories first (they're processed first, so they're earlier in the array)
            for parentCategory in parentCategories {
                if parentCategory.subcategories.contains(where: { $0.name.lowercased() == subcategory.lowercased() }) {
                    return CategoryData(name: parentCategory.name, emoji: parentCategory.emoji, subcategories: parentCategory.subcategories)
                }
            }
        }
        return nil
    }
    
    // MARK: - Unified Category System
    @Published var categories: [UnifiedCategoryData] = []
    private let categoriesKey = "UnifiedCategories"
    
    // Performance optimization: O(1) lookup dictionaries
    private var categoryLookupByName: [String: UnifiedCategoryData] = [:]
    private var categoryLookupById: [UUID: UnifiedCategoryData] = [:]
    private var subcategoryLookup: [String: [UnifiedCategoryData]] = [:] // subcategory name -> array of parent categories (handles duplicates)
    private var cachedCategoryNames: [String] = []
    private var lookupCacheValid = false
    
    // MARK: - Core Data Management
    
    /// Rebuild lookup cache for O(1) category access
    private func rebuildLookupCache() {
        categoryLookupByName.removeAll()
        categoryLookupById.removeAll()
        subcategoryLookup.removeAll()
        cachedCategoryNames.removeAll()
        
        let sortedCategories = categories
            .filter { !$0.isDeleted }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        
        for category in sortedCategories {
            // Store by lowercase name for case-insensitive lookup
            categoryLookupByName[category.name.lowercased()] = category
            categoryLookupById[category.id] = category
            cachedCategoryNames.append(category.name)
            
            // Build subcategory lookup for O(1) subcategory -> parent category mapping (handles duplicates)
            for subcategory in category.subcategories {
                let key = subcategory.name.lowercased()
                if subcategoryLookup[key] == nil {
                    subcategoryLookup[key] = []
                }
                subcategoryLookup[key]?.append(category)
            }
        }
        
        lookupCacheValid = true
        print("✅ Rebuilt category lookup cache with \(categoryLookupByName.count) active categories and \(subcategoryLookup.count) subcategories")
    }
    
    /// Ensure lookup cache is valid before using it
    private func ensureLookupCacheValid() {
        if !lookupCacheValid {
            rebuildLookupCache()
        }
    }
    
    /// Save unified categories to UserDefaults
    private func saveCategories() {
        if let encoded = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(encoded, forKey: categoriesKey)
            lookupCacheValid = false // Invalidate cache when data changes
            print("✅ Saved \(categories.count) categories to storage")
        }
    }
    
    /// Load unified categories from UserDefaults
    private func loadCategories() {
        if let data = UserDefaults.standard.data(forKey: categoriesKey),
           let decoded = try? JSONDecoder().decode([UnifiedCategoryData].self, from: data) {
            categories = decoded
            print("✅ Loaded \(categories.count) categories from storage")
        } else {
            // First launch - initialize with built-in categories
            initializeWithBuiltInCategories()
        }
        // Build lookup cache immediately after loading
        rebuildLookupCache()
    }
    
    /// Initialize with built-in categories on first launch
    private func initializeWithBuiltInCategories() {
        print("🔄 First launch - initializing with built-in categories")
        
        // Initialize with expense categories (preserve original UUIDs)
        var initialCategories = allCategories.map { categoryData in
            UnifiedCategoryData(
                id: categoryData.id,
                name: categoryData.name,
                emoji: categoryData.emoji,
                subcategories: categoryData.subcategories,
                type: .expense,
                parentCategoryId: nil,
                isBuiltIn: true
            )
        }
        
        // Add income categories (preserve original UUIDs)
        let incomeCategories = allIncomeCategories.map { categoryData in
            UnifiedCategoryData(
                id: categoryData.id,
                name: categoryData.name,
                emoji: categoryData.emoji,
                subcategories: categoryData.subcategories,
                type: .income,
                parentCategoryId: nil,
                isBuiltIn: true
            )
        }
        
        initialCategories.append(contentsOf: incomeCategories)
        categories = initialCategories
        
        saveCategories()
        print("✅ Initialized with \(categories.count) built-in categories (\(allCategories.count) expense + \(allIncomeCategories.count) income)")
    }
    
    // MARK: - Public Access Methods
    
    /// Get all active (non-deleted) categories as legacy CategoryData for backward compatibility
    var allCategoriesWithCustom: [CategoryData] {
        let activeCategories = categories.filter { !$0.isDeleted }
        return activeCategories
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { unified in
                // Find parent category name if this category has a parent
                let parentName = unified.parentCategoryId != nil ? 
                    findCategory(by: unified.parentCategoryId!)?.name : nil
                
                // Create subcategories with parent information
                let enrichedSubcategories = unified.subcategories.map { subcategory in
                    SubcategoryData(
                        id: subcategory.id,
                        name: subcategory.name, 
                        emoji: subcategory.emoji,
                        parent: unified.name,
                        parentId: unified.id
                    )
                }
                
                return CategoryData(
                    id: unified.id,
                    name: unified.name, 
                    emoji: unified.emoji, 
                    subcategories: enrichedSubcategories,
                    type: unified.type,
                    parent: parentName,
                    parentId: unified.parentCategoryId
                )
            }
    }
    
    /// Get all active income categories from unified system (includes custom income categories)
    var allIncomeCategoriesWithCustom: [CategoryData] {
        let activeIncomeCategories = categories.filter { !$0.isDeleted && $0.type == .income }
        return activeIncomeCategories
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { unified in
                // Find parent category name if this category has a parent
                let parentName = unified.parentCategoryId != nil ? 
                    findCategory(by: unified.parentCategoryId!)?.name : nil
                
                // Create subcategories with parent information
                let enrichedSubcategories = unified.subcategories.map { subcategory in
                    SubcategoryData(
                        id: subcategory.id,
                        name: subcategory.name, 
                        emoji: subcategory.emoji,
                        parent: unified.name,
                        parentId: unified.id
                    )
                }
                
                return CategoryData(
                    id: unified.id,
                    name: unified.name, 
                    emoji: unified.emoji, 
                    subcategories: enrichedSubcategories,
                    type: .income,
                    parent: parentName,
                    parentId: unified.parentCategoryId
                )
            }
    }
    
    /// Get all active expense categories from unified system (includes custom expense categories)
    var allExpenseCategoriesWithCustom: [CategoryData] {
        let activeExpenseCategories = categories.filter { !$0.isDeleted && $0.type == .expense }
        return activeExpenseCategories
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { unified in
                // Find parent category name if this category has a parent
                let parentName = unified.parentCategoryId != nil ? 
                    findCategory(by: unified.parentCategoryId!)?.name : nil
                
                // Create subcategories with parent information
                let enrichedSubcategories = unified.subcategories.map { subcategory in
                    SubcategoryData(
                        id: subcategory.id,
                        name: subcategory.name, 
                        emoji: subcategory.emoji,
                        parent: unified.name,
                        parentId: unified.id
                    )
                }
                
                return CategoryData(
                    id: unified.id,
                    name: unified.name, 
                    emoji: unified.emoji, 
                    subcategories: enrichedSubcategories,
                    type: .expense,
                    parent: parentName,
                    parentId: unified.parentCategoryId
                )
            }
    }
    
    /// Get all active parent categories (no parent assigned)
    var parentCategories: [UnifiedCategoryData] {
        return categories
            .filter { !$0.isDeleted && $0.parentCategoryId == nil }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    /// Get child categories for a specific parent
    func getChildCategories(for parentId: UUID) -> [UnifiedCategoryData] {
        return categories
            .filter { !$0.isDeleted && $0.parentCategoryId == parentId }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    /// Find category by name (optimized O(1) lookup)
    func findCategory(by name: String) -> UnifiedCategoryData? {
        ensureLookupCacheValid()
        return categoryLookupByName[name.lowercased()]
    }
    
    /// Find category by ID (optimized O(1) lookup)
    func findCategory(by id: UUID) -> UnifiedCategoryData? {
        ensureLookupCacheValid()
        let result = categoryLookupById[id]
        #if DEBUG
        print("🔍 findCategory(by id): Looking for \(id.uuidString.prefix(8)), found: \(result?.name ?? "nil")")
        #endif
        return result
    }

    /// Get current category name for a transaction, using ID lookup with string fallback.
    /// This ensures renamed categories display their current name.
    func getCategoryDisplayName(for transaction: Txn) -> String {
        // Try ID lookup first (gets current/renamed name)
        if let categoryId = transaction.categoryId,
           let category = findCategory(by: categoryId) {
            return category.name
        }
        // Also check if it's a subcategory by ID
        if let categoryId = transaction.categoryId,
           let result = findSubcategoryById(categoryId) {
            return result.subcategory.name
        }
        // Fallback to stored string for older transactions without IDs
        return transaction.category
    }

    /// Find subcategory by ID
    func findSubcategoryById(_ id: UUID) -> (subcategory: SubcategoryData, parent: UnifiedCategoryData)? {
        for category in categories {
            if let subcategory = category.subcategories.first(where: { $0.id == id }) {
                return (subcategory: subcategory, parent: category)
            }
        }
        return nil
    }

    /// Find subcategory by name and return both the subcategory and its parent category
    /// For duplicates, returns the first match (income categories are processed first, so they take priority)
    func findSubcategory(by name: String) -> (subcategory: SubcategoryData, parent: UnifiedCategoryData)? {
        ensureLookupCacheValid()
        if let parentCategories = subcategoryLookup[name.lowercased()] {
            // Try income categories first (they're processed first, so they're earlier in the array)
            for parentCategory in parentCategories {
                if let subcategoryData = parentCategory.subcategories.first(where: { $0.name.lowercased() == name.lowercased() }) {
                    print("🔍 findSubcategory: Found '\(name)' under '\(parentCategory.name)' (type: \(parentCategory.type))")
                    return (subcategory: subcategoryData, parent: parentCategory)
                }
            }
        }
        return nil
    }
    
    /// Find either a top-level category or subcategory by name
    func findCategoryOrSubcategory(by name: String) -> (isSubcategory: Bool, category: UnifiedCategoryData?, subcategory: SubcategoryData?, parent: UnifiedCategoryData?) {
        // First try to find as top-level category
        if let category = findCategory(by: name) {
            return (false, category, nil, nil)
        }
        
        // Then try to find as subcategory
        if let result = findSubcategory(by: name) {
            return (true, nil, result.subcategory, result.parent)
        }
        
        return (false, nil, nil, nil)
    }
    
    // MARK: - CRUD Operations
    
    /// Add a new category
    func addCategory(name: String, emoji: String, parentCategory: String? = nil, targetType: CategoryType? = nil) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate name is not empty
        guard !trimmedName.isEmpty else { 
            print("❌ addCategory: Empty name")
            return false 
        }
        
        // HARDCODED RESTRICTION: Prevent adding subcategories to "No Category" entries
        if let parentCategory = parentCategory {
            if parentCategory == "No Category" {
                print("❌ addCategory: Cannot add subcategories to 'No Category' entries")
                return false
            }
            // Also check by UUID for extra safety
            if let parent = findCategory(by: parentCategory) {
                let noCategoryIncomeUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
                let noCategoryExpenseUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
                if parent.id == noCategoryIncomeUUID || parent.id == noCategoryExpenseUUID {
                    print("❌ addCategory: Cannot add subcategories to 'No Category' entries (UUID check)")
                    return false
                }
            }
        }
        
        // Allow duplicate names - no duplicate checking for new categories
        // This allows users to create categories with similar names freely
        
        // Find parent if specified and determine type
        var parentId: UUID? = nil
        var categoryType: CategoryType = .expense // Default fallback
        
        if let parentName = parentCategory, parentName != "None" {
            print("🔍 addCategory: Looking for parent category '\(parentName)'")
            guard let parent = findCategory(by: parentName) else {
                print("❌ addCategory: Parent category '\(parentName)' not found")
                print("❌ Available categories:")
                for category in categories {
                    print("❌   - '\(category.name)' (ID: \(category.id.uuidString.prefix(8)))")
                }
                return false
            }
            parentId = parent.id
            categoryType = parent.type // Inherit type from parent
            print("🔍 addCategory: Setting parent to '\(parentName)' (ID: \(parent.id.uuidString.prefix(8))), inheriting type \(categoryType)")
        } else if let targetType = targetType {
            // No parent specified, use targetType from tab selection
            categoryType = targetType
            print("🔍 addCategory: No parent specified, using targetType \(targetType) from tab selection")
        } else {
            // Fallback to expense if no parent or targetType specified
            categoryType = .expense
            print("🔍 addCategory: No parent or targetType specified, defaulting to expense")
        }
        
        // Create new category
        let newCategory = UnifiedCategoryData(
            name: trimmedName,
            emoji: emoji,
            subcategories: [],
            type: categoryType,
            parentCategoryId: parentId,
            isBuiltIn: false
        )
        
        categories.append(newCategory)
        saveCategories()
        
        // Invalidate category group cache after adding new category
        clearCategoryGroupCache()
        
        print("✅ addCategory: Successfully created '\(trimmedName)' under parent '\(parentCategory ?? "None")'")
        objectWillChange.send()
        return true
    }
    
    /// Update an existing category with proper parent hierarchy handling
    func updateCategory(originalName: String, newName: String, newEmoji: String, parentCategory: String? = nil, targetType: CategoryType? = nil) -> Bool {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate name is not empty
        guard !trimmedName.isEmpty else { 
            print("❌ updateCategory: Empty name")
            return false 
        }
        
        // HARDCODED RESTRICTION: Prevent editing "No Category" entries
        if originalName == "No Category" {
            print("❌ updateCategory: Cannot edit 'No Category' entries")
            return false
        }
        
        // HARDCODED RESTRICTION: Prevent adding subcategories to "No Category" entries  
        if let parentCategory = parentCategory {
            if parentCategory == "No Category" {
                print("❌ updateCategory: Cannot add subcategories to 'No Category' entries")
                return false
            }
            // Also check by UUID for extra safety
            if let parent = findCategory(by: parentCategory) {
                let noCategoryIncomeUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
                let noCategoryExpenseUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
                if parent.id == noCategoryIncomeUUID || parent.id == noCategoryExpenseUUID {
                    print("❌ updateCategory: Cannot add subcategories to 'No Category' entries (UUID check)")
                    return false
                }
            }
        }
        
        print("🔍 updateCategory: Starting update of '\(originalName)' to '\(trimmedName)' with parent '\(parentCategory ?? "None")'")
        
        // Get the current category being edited
        let currentResult = findCategoryOrSubcategory(by: originalName)
        
        // Check for duplicate names - log but allow the update (matching subcategory behavior)
        if let existingCategory = findCategory(by: trimmedName) {
            if let currentCategory = currentResult.category {
                if existingCategory.id != currentCategory.id {
                    // Different category with same name exists - allow anyway (user's choice to overlap)
                    print("🔍 updateCategory: Found existing category '\(trimmedName)' with ID \(existingCategory.id)")
                    print("🔍 updateCategory: Allowing rename to '\(trimmedName)' - user's choice to use existing name")
                } else {
                    print("✅ updateCategory: Same category being updated (just emoji/name change)")
                }
            }
        }
        
        // Check if this is currently a subcategory that needs to be converted to a full category
        
        if currentResult.isSubcategory {
            // This is currently a subcategory - we need to convert it to a full category
            return convertSubcategoryToCategory(originalName: originalName, newName: trimmedName, newEmoji: newEmoji, parentCategory: parentCategory, targetType: targetType)
        }
        
        // Find the category to update using the improved lookup system
        print("🔍 DEBUG: Looking for category '\(originalName)' in \(categories.count) total categories")
        
        // Use the optimized lookup system to find the category
        ensureLookupCacheValid()
        guard let categoryToUpdate = categoryLookupByName[originalName.lowercased()] else {
            print("❌ updateCategory: Category '\(originalName)' not found in lookup cache")
            return false
        }
        
        // Find the category index by ID (more reliable than name)
        guard let categoryIndex = categories.firstIndex(where: { $0.id == categoryToUpdate.id }) else {
            print("❌ updateCategory: Category with ID \(categoryToUpdate.id) not found in array")
            return false
        }
        
        // Check if this category has subcategories and user is trying to make it a subcategory
        let hasBuiltInSubcategories = !categories[categoryIndex].subcategories.isEmpty
        let hasChildCategories = categories.contains { $0.parentCategoryId == categories[categoryIndex].id }

        // Only block if trying to set a REAL parent (not "No Parent" containers which keep it as top-level)
        let isSettingRealParent = parentCategory != nil &&
            parentCategory != "None" &&
            !parentCategory!.isEmpty &&
            !parentCategory!.hasPrefix("No Parent")

        if isSettingRealParent && (hasBuiltInSubcategories || hasChildCategories) {
            let subcategoryNames = categories[categoryIndex].subcategories.map { $0.name }
            let childCategoryNames = categories.filter { $0.parentCategoryId == categories[categoryIndex].id }.map { $0.name }
            let allChildren = subcategoryNames + childCategoryNames

            print("❌ updateCategory: Cannot move category '\(originalName)' - it has \(allChildren.count) subcategories: \(allChildren.joined(separator: ", "))")
            return false
        }
        
        // Find parent if specified and determine if type change is needed
        var parentId: UUID? = nil
        var newType = categories[categoryIndex].type // Default to current type
        
        if let parentName = parentCategory, 
           parentName != "None" && 
           !parentName.isEmpty && 
           !parentName.hasPrefix("No Parent") { // Handle "No Parent (Income)" and "No Parent (Expense)" as null parent
            guard let parent = findCategory(by: parentName) else {
                print("❌ updateCategory: Parent category '\(parentName)' not found")
                return false
            }
            
            // Prevent setting self as parent
            if parent.id == categoryToUpdate.id {
                print("❌ updateCategory: Cannot set category as its own parent")
                return false
            }
            
            parentId = parent.id
            newType = parent.type // Inherit type from parent (enables cross-type moves)
            print("🔍 updateCategory: Setting parent to '\(parentName)' (ID: \(parent.id))")
            print("🔍 updateCategory: Category type will change from \(categories[categoryIndex].type) to \(newType)")
        } else if let parentName = parentCategory, parentName.hasPrefix("No Parent") {
            // Handle "No Parent (Income)" and "No Parent (Expense)" container selections
            if parentName.contains("Income") {
                newType = .income
            } else if parentName.contains("Expense") {
                newType = .expense
            }
            print("🔍 updateCategory: Converting to '\(parentName)' - setting type to \(newType)")
            if newType != categories[categoryIndex].type {
                print("🔍 updateCategory: Category type will change from \(categories[categoryIndex].type) to \(newType)")
            }
        } else if let targetType = targetType {
            // No parent specified, but targetType provided (from tab selection)
            newType = targetType
            print("🔍 updateCategory: No parent specified, using targetType \(targetType) from tab selection")
            if newType != categories[categoryIndex].type {
                print("🔍 updateCategory: Category type will change from \(categories[categoryIndex].type) to \(newType)")
            }
        }
        
        // Store old type for transaction refresh
        let oldType = categories[categoryIndex].type
        let categoryId = categories[categoryIndex].id
        
        // Update the category
        categories[categoryIndex].name = trimmedName
        categories[categoryIndex].emoji = newEmoji
        categories[categoryIndex].parentCategoryId = parentId
        categories[categoryIndex].type = newType // Update type to match parent (enables cross-type moves)
        categories[categoryIndex].updatedAt = Date()
        
        print("🔄 updateCategory: Updated category at index \(categoryIndex):")
        print("   - ID: \(categories[categoryIndex].id)")
        print("   - New Name: '\(categories[categoryIndex].name)'")
        print("   - New Emoji: '\(categories[categoryIndex].emoji)'")
        print("   - New Type: \(categories[categoryIndex].type)")
        print("   - Parent ID: \(categories[categoryIndex].parentCategoryId?.uuidString ?? "None")")
        
        // Refresh transactions if type changed
        refreshTransactionsForCategoryTypeChange(categoryId: categoryId, oldType: oldType, newType: newType)

        // Update budget categoryName if name changed
        if originalName != trimmedName {
            updateBudgetCategoryName(categoryId: categoryId, newName: trimmedName)
        }

        saveCategories()
        
        // Force immediate UI refresh for category changes
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        // Force rebuild lookup cache immediately since names changed
        rebuildLookupCache()
        
        print("🔍 updateCategory: Post-update lookup test for '\(trimmedName)':")
        if let testLookup = findCategory(by: trimmedName) {
            print("   ✅ Found: ID=\(testLookup.id), Name='\(testLookup.name)', Emoji='\(testLookup.emoji)', Parent=\(testLookup.parentCategoryId?.uuidString ?? "None")")
        } else {
            print("   ❌ NOT FOUND in lookup cache!")
        }
        
        // Invalidate category group cache after updating category
        clearCategoryGroupCache()
        
        // Force immediate UI update - synchronous to prevent race conditions
        self.objectWillChange.send()
        
        // Track category edit in PostHog
        PostHogManager.shared.capture(.categoryEdited, properties: [
            "original_name": originalName,
            "new_name": trimmedName,
            "new_emoji": newEmoji,
            "type": newType.rawValue,
            "has_parent": parentId != nil
        ])

        print("✅ updateCategory: Successfully updated '\(originalName)' to '\(trimmedName)' with parent '\(parentCategory ?? "None")'")
        return true
    }
    
    /// Convert a subcategory to a full category with optional parent assignment
    private func convertSubcategoryToCategory(originalName: String, newName: String, newEmoji: String, parentCategory: String?, targetType: CategoryType? = nil) -> Bool {
        print("🔄 convertSubcategoryToCategory: Converting '\(originalName)' to full category")
        
        // Find the subcategory and its current parent
        guard let result = findSubcategory(by: originalName) else {
            print("❌ convertSubcategoryToCategory: Subcategory '\(originalName)' not found")
            return false
        }
        
        let currentParent = result.parent
        let currentSubcategory = result.subcategory
        let oldType = currentSubcategory.type // Store the subcategory's current type
        
        // Find the current parent category index
        guard let currentParentIndex = categories.firstIndex(where: { $0.id == currentParent.id }) else {
            print("❌ convertSubcategoryToCategory: Current parent category not found")
            return false
        }
        
        // Remove the subcategory from its current parent
        categories[currentParentIndex].subcategories.removeAll { $0.name == originalName }
        categories[currentParentIndex].updatedAt = Date()
        
        // Find new parent if specified and determine target type
        var newParentId: UUID? = nil
        var finalType = currentParent.type // Default to current parent's type
        
        if let parentName = parentCategory, 
           parentName != "None" && 
           !parentName.isEmpty && 
           !parentName.hasPrefix("No Parent") { // Handle "No Parent (Income)" and "No Parent (Expense)" as null parent
            guard let newParent = findCategory(by: parentName) else {
                print("❌ convertSubcategoryToCategory: New parent category '\(parentName)' not found")
                return false
            }
            newParentId = newParent.id
            finalType = newParent.type // Inherit type from new parent (enables cross-type moves)
            print("🔍 convertSubcategoryToCategory: Setting new parent to '\(parentName)' (ID: \(newParent.id))")
            print("🔍 convertSubcategoryToCategory: Category type will change from \(currentParent.type) to \(finalType)")
        } else if let parentName = parentCategory, parentName.hasPrefix("No Parent") {
            // Handle "No Parent (Income)" and "No Parent (Expense)" container selections
            if parentName.contains("Income") {
                finalType = .income
            } else if parentName.contains("Expense") {
                finalType = .expense
            }
            print("🔍 convertSubcategoryToCategory: Converting to '\(parentName)' - setting type to \(finalType)")
            if finalType != currentParent.type {
                print("🔍 convertSubcategoryToCategory: Category type will change from \(currentParent.type) to \(finalType)")
            }
        } else if let targetType = targetType {
            // No parent specified, but targetType provided (from tab selection)
            finalType = targetType
            print("🔍 convertSubcategoryToCategory: No parent specified, using targetType \(targetType) from tab selection")
            if finalType != currentParent.type {
                print("🔍 convertSubcategoryToCategory: Category type will change from \(currentParent.type) to \(finalType)")
            }
        }
        
        // Check for duplicate names - only fail if there's a different category (not this subcategory) with the same name
        if let existingCategory = findCategory(by: newName) {
            // If there's an existing category with this name, we need to make sure it's not OK to have a duplicate
            // But since we're converting from a subcategory to a category, and subcategories can have the same name
            // as categories (they're in different namespaces), we should allow this conversion
            print("🔍 convertSubcategoryToCategory: Found existing category '\(newName)' with ID \(existingCategory.id)")
            print("🔍 convertSubcategoryToCategory: Converting subcategory '\(originalName)' to category - this is allowed even if names match")
        }
        
        // Create a new full category from the subcategory
        let newCategory = UnifiedCategoryData(
            name: newName,
            emoji: newEmoji,
            subcategories: [],
            type: finalType, // Use final type (enables cross-type conversion)
            parentCategoryId: newParentId,
            isBuiltIn: false
        )
        
        // Add the new category to the categories array
        categories.append(newCategory)
        
        // Refresh transactions for subcategory type change (using subcategory name for lookup)
        refreshTransactionsForSubcategoryTypeChange(subcategoryName: originalName, oldType: oldType, newType: finalType)
        
        print("✅ convertSubcategoryToCategory: Successfully converted '\(originalName)' to category '\(newName)' with parent '\(parentCategory ?? "None")'")
        
        saveCategories()
        
        // Force immediate UI refresh for subcategory conversion
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        rebuildLookupCache()
        clearCategoryGroupCache()
        self.objectWillChange.send()
        
        return true
    }
    
    /// Update a subcategory within its parent category
    func updateSubcategory(originalName: String, newName: String, newEmoji: String) -> Bool {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate name is not empty
        guard !trimmedName.isEmpty else {
            print("❌ updateSubcategory: Empty name")
            return false
        }
        
        // Find the subcategory and its parent
        guard let result = findSubcategory(by: originalName) else {
            print("❌ updateSubcategory: Subcategory '\(originalName)' not found")
            return false
        }
        
        let parentCategory = result.parent
        
        // HARDCODED RESTRICTION: Prevent editing subcategories under "No Category" entries
        if parentCategory.name == "No Category" {
            print("❌ updateSubcategory: Cannot edit subcategories under 'No Category' entries")
            return false
        }
        
        // Also check by UUID for extra safety
        let noCategoryIncomeUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let noCategoryExpenseUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        if parentCategory.id == noCategoryIncomeUUID || parentCategory.id == noCategoryExpenseUUID {
            print("❌ updateSubcategory: Cannot edit subcategories under 'No Category' entries (UUID check)")
            return false
        }
        
        // Find the parent category index in our categories array
        guard let parentIndex = categories.firstIndex(where: { $0.id == parentCategory.id }) else {
            print("❌ updateSubcategory: Parent category not found in categories array")
            return false
        }
        
        // Find the subcategory index within the parent's subcategories
        guard let subcategoryIndex = categories[parentIndex].subcategories.firstIndex(where: { $0.name == originalName }) else {
            print("❌ updateSubcategory: Subcategory not found in parent's subcategories")
            return false
        }
        
        // Get the current subcategory to preserve its type and ID
        let currentSubcategory = categories[parentIndex].subcategories[subcategoryIndex]
        let subcategoryId = currentSubcategory.id

        // Update the subcategory, preserving its type and ID
        categories[parentIndex].subcategories[subcategoryIndex] = SubcategoryData(
            id: subcategoryId,
            name: trimmedName,
            emoji: newEmoji,
            type: currentSubcategory.type // Preserve the existing type
        )
        categories[parentIndex].updatedAt = Date()

        // Update budget categoryName if name changed
        if originalName != trimmedName {
            updateBudgetCategoryName(categoryId: subcategoryId, newName: trimmedName)
        }

        saveCategories()
        clearCategoryGroupCache()

        print("✅ updateSubcategory: Successfully updated subcategory '\(originalName)' to '\(trimmedName)' under parent '\(parentCategory.name)'")
        self.objectWillChange.send()
        return true
    }
    
    /// Delete a category (soft delete)
    func deleteCategory(_ categoryName: String) -> Bool {
        print("🗑️ deleteCategory: Starting deletion of '\(categoryName)'")
        
        // HARDCODED RESTRICTION: Prevent deleting "No Category" entries
        if categoryName == "No Category" {
            print("❌ deleteCategory: Cannot delete 'No Category' entries")
            return false
        }
        
        // Also check by UUID for extra safety
        if let category = findCategory(by: categoryName) {
            let noCategoryIncomeUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
            let noCategoryExpenseUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
            if category.id == noCategoryIncomeUUID || category.id == noCategoryExpenseUUID {
                print("❌ deleteCategory: Cannot delete 'No Category' entries (UUID check)")
                return false
            }
        }
        
        // Find the category
        guard let categoryIndex = categories.firstIndex(where: { !$0.isDeleted && $0.name == categoryName }) else {
            print("❌ deleteCategory: Category '\(categoryName)' not found")
            return false
        }
        
        let categoryId = categories[categoryIndex].id
        
        // Check if category has children
        let childCategories = getChildCategories(for: categoryId)
        if !childCategories.isEmpty {
            print("❌ Cannot delete category '\(categoryName)' - has \(childCategories.count) subcategories")
            return false
        }
        
        // Get the category type before deletion to determine correct "No Category" type
        let categoryType = categories[categoryIndex].type
        let categoryEmoji = categories[categoryIndex].emoji

        // Soft delete the category
        categories[categoryIndex].isDeleted = true
        categories[categoryIndex].updatedAt = Date()

        // Track category deletion in PostHog
        PostHogManager.shared.capture(.categoryDeleted, properties: [
            "name": categoryName,
            "emoji": categoryEmoji,
            "type": categoryType.rawValue
        ])

        saveCategories()
        
        // Convert affected transactions to "No Category"
        print("🗑️ deleteCategory: About to call convertOrphanedTransactionsToNoCategory")
        print("🗑️ deleteCategory: categoryName='\(categoryName)', categoryId=\(categoryId.uuidString.prefix(8)), categoryType=\(categoryType)")
        convertOrphanedTransactionsToNoCategory(deletedCategoryName: categoryName, deletedCategoryId: categoryId, originalType: categoryType)

        // Convert affected budgets to "No Category"
        convertOrphanedBudgetsToNoCategory(deletedCategoryId: categoryId, originalType: categoryType)

        // Invalidate category group cache after deleting category
        clearCategoryGroupCache()
        
        print("✅ Successfully deleted category '\(categoryName)' and updated affected transactions")
        objectWillChange.send()
        return true
    }
    
    /// Convert transactions that reference deleted categories to "No Category"
    private func convertOrphanedTransactionsToNoCategory(deletedCategoryName: String, deletedCategoryId: UUID, originalType: CategoryType) {
        print("🔄 ===== ORPHANED TRANSACTION CONVERSION START =====")
        print("🔄 Deleted category name: '\(deletedCategoryName)'")
        print("🔄 Deleted category ID: \(deletedCategoryId.uuidString.prefix(8))")
        print("🔄 Original category type: \(originalType)")
        
        let userManager = UserManager.shared
        let allTransactions = userManager.getTransactions()
        
        print("🔄 Total transactions to check: \(allTransactions.count)")
        
        // Determine the appropriate "No Category" UUID and name based on original category type
        let noCategoryId: UUID
        let noCategoryName = "No Category"
        
        switch originalType {
        case .income:
            noCategoryId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")! // No Category (Income)
        case .expense:
            noCategoryId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")! // No Category (Expense)
        }
        
        print("🔄 Target 'No Category' ID: \(noCategoryId.uuidString.prefix(8))")
        
        var updatedCount = 0
        
        // Find transactions that reference the deleted category (by name or ID)
        for (index, transaction) in allTransactions.enumerated() {
            var shouldUpdate = false
            var updatedTransaction = transaction
            
            print("🔍 Checking transaction \(index + 1): '\(transaction.category)' - \(transaction.merchantName ?? "Unknown")")
            print("   - Transaction category: '\(transaction.category)'")
            print("   - Transaction categoryId: '\(transaction.categoryId?.uuidString.prefix(8) ?? "nil")'")
            
            // Check if transaction references deleted category by name (exact match)
            if transaction.category == deletedCategoryName {
                shouldUpdate = true
                print("   ✅ MATCH BY NAME: '\(transaction.category)' == '\(deletedCategoryName)'")
            }
            
            // Check if transaction references deleted category by ID
            if let categoryId = transaction.categoryId, categoryId == deletedCategoryId {
                shouldUpdate = true
                print("   ✅ MATCH BY ID: \(categoryId.uuidString.prefix(8)) == \(deletedCategoryId.uuidString.prefix(8))")
            }
            
            if !shouldUpdate {
                print("   ❌ NO MATCH - skipping")
            }
            
            if shouldUpdate {
                // Update transaction to use "No Category"
                updatedTransaction = Txn(
                    id: transaction.id,
                    userId: transaction.userId,
                    category: noCategoryName,
                    categoryId: noCategoryId,
                    amount: transaction.amount, // Keep original amount and sign
                    date: transaction.date,
                    createdAt: transaction.createdAt,
                    receiptImage: transaction.receiptImage,
                    hasReceiptImage: transaction.hasReceiptImage,
                    merchantName: transaction.merchantName,
                    paymentMethod: transaction.paymentMethod,
                    receiptNumber: transaction.receiptNumber,
                    invoiceNumber: transaction.invoiceNumber,
                    items: transaction.items,
                    note: transaction.note,
                    accountId: transaction.accountId,
                    originalAmount: transaction.originalAmount,
                    originalCurrency: transaction.originalCurrency,
                    primaryCurrency: transaction.primaryCurrency,
                    secondaryCurrency: transaction.secondaryCurrency,
                    exchangeRate: transaction.exchangeRate,
                    secondaryAmount: transaction.secondaryAmount,
                    secondaryExchangeRate: transaction.secondaryExchangeRate
                )
                
                // Update the transaction in UserManager
                userManager.updateTransaction(updatedTransaction)
                updatedCount += 1
                
                print("   ✅ Updated transaction: \(transaction.merchantName ?? "Unknown") - '\(deletedCategoryName)' → 'No Category'")
            }
        }
        
        print("🔄 ===== ORPHANED TRANSACTION CONVERSION COMPLETE =====")
        print("✅ Converted \(updatedCount) orphaned transactions to 'No Category' (\(originalType.rawValue))")
        print("🔄 Final summary:")
        print("   - Checked \(allTransactions.count) total transactions")
        print("   - Updated \(updatedCount) transactions")
        print("   - Target category: '\(noCategoryName)' with ID \(noCategoryId.uuidString.prefix(8))")
        
        // Trigger UI refresh
        DispatchQueue.main.async {
            userManager.objectWillChange.send()
            self.objectWillChange.send()
        }
    }

    /// Convert budgets that reference deleted categories to "No Category"
    private func convertOrphanedBudgetsToNoCategory(deletedCategoryId: UUID, originalType: CategoryType) {
        print("🔄 ===== ORPHANED BUDGET CONVERSION START =====")
        print("🔄 Deleted category ID: \(deletedCategoryId.uuidString.prefix(8))")
        print("🔄 Original category type: \(originalType)")

        let userManager = UserManager.shared
        let allBudgets = userManager.currentUser.budgets

        // Determine the appropriate "No Category" UUID based on original category type
        let noCategoryId: UUID
        let noCategoryName = "No Category"

        switch originalType {
        case .income:
            noCategoryId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")! // No Category (Income)
        case .expense:
            noCategoryId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")! // No Category (Expense)
        }

        var updatedCount = 0

        for budget in allBudgets {
            if budget.categoryId == deletedCategoryId {
                // Update budget to use "No Category"
                let updatedBudget = Budget(
                    id: budget.id,
                    walletId: budget.walletId,
                    categoryId: noCategoryId,
                    categoryName: noCategoryName,
                    amount: budget.amount,
                    currency: budget.currency,
                    period: budget.period,
                    applyToAllPeriods: budget.applyToAllPeriods,
                    isActive: budget.isActive
                )
                userManager.updateBudget(updatedBudget)
                updatedCount += 1
                print("   ✅ Updated budget to 'No Category'")
            }
        }

        print("🔄 ===== ORPHANED BUDGET CONVERSION COMPLETE =====")
        print("✅ Converted \(updatedCount) orphaned budgets to 'No Category'")
    }

    /// Update budget categoryName when a category is renamed
    private func updateBudgetCategoryName(categoryId: UUID, newName: String) {
        print("🔄 ===== BUDGET NAME UPDATE START =====")
        print("🔄 Category ID: \(categoryId.uuidString.prefix(8))")
        print("🔄 New name: '\(newName)'")

        let userManager = UserManager.shared
        let allBudgets = userManager.currentUser.budgets

        var updatedCount = 0

        for budget in allBudgets {
            if budget.categoryId == categoryId && budget.categoryName != newName {
                // Update budget with new category name
                let updatedBudget = Budget(
                    id: budget.id,
                    walletId: budget.walletId,
                    categoryId: budget.categoryId,
                    categoryName: newName,
                    amount: budget.amount,
                    currency: budget.currency,
                    period: budget.period,
                    applyToAllPeriods: budget.applyToAllPeriods,
                    isActive: budget.isActive
                )
                userManager.updateBudget(updatedBudget)
                updatedCount += 1
                print("   ✅ Updated budget name from '\(budget.categoryName)' to '\(newName)'")
            }
        }

        print("🔄 ===== BUDGET NAME UPDATE COMPLETE =====")
        print("✅ Updated \(updatedCount) budget(s) with new category name")
    }

    /// Delete a specific subcategory and convert affected transactions to "No Category"
    func deleteSubcategory(subcategoryName: String, parentCategoryName: String) -> Bool {
        print("🗑️ deleteSubcategory: Starting deletion of subcategory '\(subcategoryName)' under '\(parentCategoryName)'")
        
        // Find the parent category
        guard let parentIndex = categories.firstIndex(where: { !$0.isDeleted && $0.name == parentCategoryName }) else {
            print("❌ deleteSubcategory: Parent category '\(parentCategoryName)' not found")
            return false
        }
        
        // Find the subcategory within the parent
        guard let subcategoryIndex = categories[parentIndex].subcategories.firstIndex(where: { $0.name == subcategoryName }) else {
            print("❌ deleteSubcategory: Subcategory '\(subcategoryName)' not found under '\(parentCategoryName)'")
            return false
        }
        
        // Get subcategory info before deletion
        let subcategory = categories[parentIndex].subcategories[subcategoryIndex]
        let subcategoryId = subcategory.id
        let subcategoryType = subcategory.type
        
        // Remove the subcategory from the parent category
        categories[parentIndex].subcategories.remove(at: subcategoryIndex)
        categories[parentIndex].updatedAt = Date()
        
        saveCategories()
        
        // Convert affected transactions to "No Category"
        convertOrphanedTransactionsToNoCategory(deletedCategoryName: subcategoryName, deletedCategoryId: subcategoryId, originalType: subcategoryType)

        // Convert affected budgets to "No Category"
        convertOrphanedBudgetsToNoCategory(deletedCategoryId: subcategoryId, originalType: subcategoryType)

        // Invalidate category group cache after deleting subcategory
        clearCategoryGroupCache()

        print("✅ Successfully deleted subcategory '\(subcategoryName)' and updated affected transactions and budgets")
        objectWillChange.send()
        return true
    }
    
    /// Fix existing orphaned transactions that reference deleted categories
    func fixOrphanedTransactions() {
        print("🔧 ===== FIXING EXISTING ORPHANED TRANSACTIONS =====")
        
        let userManager = UserManager.shared
        let allTransactions = userManager.getTransactions()
        
        var fixedCount = 0
        
        for transaction in allTransactions {
            // Check if transaction has a categoryId that no longer exists
            if let categoryId = transaction.categoryId {
                let categoryResult = findCategoryOrSubcategoryById(categoryId)
                
                if categoryResult == nil {
                    // This transaction is orphaned - fix it
                    print("🔧 Found orphaned transaction: \(transaction.merchantName ?? "Unknown") - categoryId: \(categoryId.uuidString.prefix(8))")
                    
                    // Determine if it should be income or expense based on amount sign
                    let isIncome = transaction.amount > 0
                    let noCategoryId: UUID
                    
                    if isIncome {
                        noCategoryId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")! // No Category (Income)
                    } else {
                        noCategoryId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")! // No Category (Expense)
                    }
                    
                    // Update transaction to use "No Category"
                    let updatedTransaction = Txn(
                        id: transaction.id,
                        userId: transaction.userId,
                        category: "No Category",
                        categoryId: noCategoryId,
                        amount: transaction.amount,
                        date: transaction.date,
                        createdAt: transaction.createdAt,
                        receiptImage: transaction.receiptImage,
                        hasReceiptImage: transaction.hasReceiptImage,
                        merchantName: transaction.merchantName,
                        paymentMethod: transaction.paymentMethod,
                        receiptNumber: transaction.receiptNumber,
                        invoiceNumber: transaction.invoiceNumber,
                        items: transaction.items,
                        note: transaction.note,
                        accountId: transaction.accountId,
                        originalAmount: transaction.originalAmount,
                        originalCurrency: transaction.originalCurrency,
                        primaryCurrency: transaction.primaryCurrency,
                        secondaryCurrency: transaction.secondaryCurrency,
                        exchangeRate: transaction.exchangeRate,
                        secondaryAmount: transaction.secondaryAmount,
                        secondaryExchangeRate: transaction.secondaryExchangeRate
                    )
                    
                    userManager.updateTransaction(updatedTransaction)
                    fixedCount += 1
                    
                    print("   ✅ Fixed: \(transaction.merchantName ?? "Unknown") - now uses 'No Category' (\(isIncome ? "income" : "expense"))")
                }
            }
        }
        
        print("🔧 ===== ORPHANED TRANSACTION FIX COMPLETE =====")
        print("✅ Fixed \(fixedCount) orphaned transactions")
        
        // Trigger UI refresh
        DispatchQueue.main.async {
            userManager.objectWillChange.send()
            self.objectWillChange.send()
        }
    }
    
    // MARK: - Migration & Reset
    
    /// Migrate from old system to new unified system (called on init)
    private func migrateFromOldSystemIfNeeded() {
        // Check if old system data exists
        let hasOldCustomCategories = UserDefaults.standard.data(forKey: "CustomCategories") != nil
        let hasOldHierarchy = UserDefaults.standard.data(forKey: "CategoryHierarchy") != nil
        
        if hasOldCustomCategories || hasOldHierarchy {
            print("🔄 Migrating from old category system...")
            
            // Clear new system and reinitialize with built-in categories
            UserDefaults.standard.removeObject(forKey: categoriesKey)
            categories.removeAll()
            initializeWithBuiltInCategories()
            
            // Clear old system data
            UserDefaults.standard.removeObject(forKey: "CustomCategories")
            UserDefaults.standard.removeObject(forKey: "CategoryHierarchy")
            UserDefaults.standard.removeObject(forKey: "OverriddenBuiltInNames")
            UserDefaults.standard.removeObject(forKey: "CategoryReplacements")
            
            print("✅ Migration completed - old data cleared, using fresh built-in categories")
        }
    }
    
    /// Check if "No Category" entries exist with proper UUIDs and fix if missing
    func ensureNoCategoryEntriesExist() {
        let noCategoryIncomeUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let noCategoryExpenseUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        
        var needsReset = false
        
        // Check if No Category entries exist with correct UUIDs
        if findCategory(by: noCategoryIncomeUUID) == nil {
            print("⚠️ No Category (Income) missing or has wrong UUID")
            needsReset = true
        }
        
        if findCategory(by: noCategoryExpenseUUID) == nil {
            print("⚠️ No Category (Expense) missing or has wrong UUID")
            needsReset = true
        }
        
        if needsReset {
            print("🔧 Auto-fixing No Category entries by resetting categories...")
            resetAllCategories()
        } else {
            print("✅ No Category entries exist with proper UUIDs")
        }
    }
    
    /// Force regenerate categories (public method for debugging)
    func forceRegenerateCategories() {
        print("🔧 FORCE: Regenerating all categories with proper UUIDs...")
        resetAllCategories()
    }
    
    /// Reset all categories to built-in defaults
    func resetAllCategories() {
        print("🔄 Resetting all categories to defaults...")
        
        // Clear all data
        categories.removeAll()
        UserDefaults.standard.removeObject(forKey: categoriesKey)
        
        // Reinitialize with built-in categories
        initializeWithBuiltInCategories()
        
        // Invalidate category group cache after reset
        clearCategoryGroupCache()
        
        print("✅ All categories reset to defaults")
        objectWillChange.send()
    }
    
    /// Override allCategories to include custom ones
    var allCategoriesOverride: [CategoryData] {
        return allCategoriesWithCustom
    }
}

// MARK: - Display Category Data Structure

struct DisplayCategoryData: Identifiable {
    let id = UUID()
    let categoryData: CategoryData
    let isChild: Bool
    let parentName: String?
    let hasChildren: Bool
}

// MARK: - Transaction Refresh Extension
extension CategoriesManager {
    
    /// Refresh all transactions when a category/subcategory changes income/expense type
    /// This ensures existing transactions are updated to match the new category classification
    func refreshTransactionsForCategoryTypeChange(categoryId: UUID, oldType: CategoryType, newType: CategoryType) {
        guard oldType != newType else {
            print("🔄 refreshTransactions: No type change detected, skipping refresh")
            return
        }
        
        print("🔄 refreshTransactions: Refreshing transactions for category ID \(categoryId.uuidString.prefix(8))")
        print("🔄 refreshTransactions: Type change: \(oldType) → \(newType)")
        
        let userManager = UserManager.shared
        var updatedTransactions: [Txn] = []
        var transactionCount = 0
        
        // Find all transactions that use this category
        for transaction in userManager.currentUser.transactions {
            if transaction.categoryId == categoryId {
                transactionCount += 1
                
                // Calculate new amount with correct sign based on new type
                let absoluteAmount = abs(transaction.amount)
                let newAmount = newType == .income ? absoluteAmount : -absoluteAmount
                
                print("   - Transaction \(transaction.id.uuidString.prefix(8)): \(transaction.amount) → \(newAmount)")
                
                // Create updated transaction with new amount
                let updatedTransaction = Txn(
                    id: transaction.id,
                    userId: transaction.userId,
                    category: transaction.category,
                    categoryId: transaction.categoryId,
                    amount: newAmount,
                    date: transaction.date,
                    createdAt: transaction.createdAt,
                    receiptImage: transaction.receiptImage,
                    hasReceiptImage: transaction.hasReceiptImage,
                    merchantName: transaction.merchantName,
                    paymentMethod: transaction.paymentMethod,
                    receiptNumber: transaction.receiptNumber,
                    invoiceNumber: transaction.invoiceNumber,
                    items: transaction.items,
                    note: transaction.note,
                    accountId: transaction.accountId,
                    originalAmount: transaction.originalAmount,
                    originalCurrency: transaction.originalCurrency,
                    primaryCurrency: transaction.primaryCurrency,
                    secondaryCurrency: transaction.secondaryCurrency,
                    exchangeRate: transaction.exchangeRate,
                    secondaryAmount: transaction.secondaryAmount,
                    secondaryExchangeRate: transaction.secondaryExchangeRate
                )
                
                updatedTransactions.append(updatedTransaction)
            }
        }
        
        // Update all affected transactions
        for updatedTransaction in updatedTransactions {
            userManager.updateTransaction(updatedTransaction)
        }
        
        print("✅ refreshTransactions: Updated \(transactionCount) transactions for category type change")
        
        if transactionCount > 0 {
            // Force immediate UI refresh on main thread
            DispatchQueue.main.async {
                userManager.objectWillChange.send()
                // Also trigger a secondary refresh to ensure all UI components update
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    userManager.objectWillChange.send()
                }
            }
            print("🔄 refreshTransactions: Triggered UI refresh for \(transactionCount) updated transactions")
        }
    }
    
    /// Refresh transactions for subcategory type changes (when moving between parents)
    func refreshTransactionsForSubcategoryTypeChange(subcategoryName: String, oldType: CategoryType, newType: CategoryType) {
        guard oldType != newType else {
            print("🔄 refreshTransactions: No subcategory type change detected, skipping refresh")
            return
        }
        
        print("🔄 refreshTransactions: Refreshing transactions for subcategory '\(subcategoryName)'")
        print("🔄 refreshTransactions: Type change: \(oldType) → \(newType)")
        
        let userManager = UserManager.shared
        var updatedTransactions: [Txn] = []
        var transactionCount = 0
        
        // Find all transactions that use this subcategory by name
        for transaction in userManager.currentUser.transactions {
            if transaction.category == subcategoryName {
                transactionCount += 1
                
                // Calculate new amount with correct sign based on new type
                let absoluteAmount = abs(transaction.amount)
                let newAmount = newType == .income ? absoluteAmount : -absoluteAmount
                
                print("   - Transaction \(transaction.id.uuidString.prefix(8)): \(transaction.amount) → \(newAmount)")
                
                // Create updated transaction with new amount
                let updatedTransaction = Txn(
                    id: transaction.id,
                    userId: transaction.userId,
                    category: transaction.category,
                    categoryId: transaction.categoryId,
                    amount: newAmount,
                    date: transaction.date,
                    createdAt: transaction.createdAt,
                    receiptImage: transaction.receiptImage,
                    hasReceiptImage: transaction.hasReceiptImage,
                    merchantName: transaction.merchantName,
                    paymentMethod: transaction.paymentMethod,
                    receiptNumber: transaction.receiptNumber,
                    invoiceNumber: transaction.invoiceNumber,
                    items: transaction.items,
                    note: transaction.note,
                    accountId: transaction.accountId,
                    originalAmount: transaction.originalAmount,
                    originalCurrency: transaction.originalCurrency,
                    primaryCurrency: transaction.primaryCurrency,
                    secondaryCurrency: transaction.secondaryCurrency,
                    exchangeRate: transaction.exchangeRate,
                    secondaryAmount: transaction.secondaryAmount,
                    secondaryExchangeRate: transaction.secondaryExchangeRate
                )
                
                updatedTransactions.append(updatedTransaction)
            }
        }
        
        // Update all affected transactions
        for updatedTransaction in updatedTransactions {
            userManager.updateTransaction(updatedTransaction)
        }
        
        print("✅ refreshTransactions: Updated \(transactionCount) transactions for subcategory type change")
        
        if transactionCount > 0 {
            // Force immediate UI refresh on main thread
            DispatchQueue.main.async {
                userManager.objectWillChange.send()
                // Also trigger a secondary refresh to ensure all UI components update
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    userManager.objectWillChange.send()
                }
            }
            print("🔄 refreshTransactions: Triggered UI refresh for \(transactionCount) updated transactions")
        }
    }
    
    /// Force a complete UI refresh for all transaction-related views
    /// Call this when navigating back from category editing to ensure UI updates properly
    func forceCompleteUIRefresh() {
        print("🔄 forceCompleteUIRefresh: Triggering complete UI refresh")
        
        DispatchQueue.main.async {
            // Trigger UserManager refresh first
            UserManager.shared.objectWillChange.send()
            
            // Then trigger CategoriesManager refresh
            self.objectWillChange.send()
            
            // Clear any cached data that might prevent updates
            self.clearCategoryGroupCache()
            
            // Force a second refresh after a small delay to catch any delayed updates
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                UserManager.shared.objectWillChange.send()
                self.objectWillChange.send()
            }
        }
    }
}
