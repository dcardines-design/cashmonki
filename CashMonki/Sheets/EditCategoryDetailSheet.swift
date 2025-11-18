//
//  EditCategoryDetailSheet.swift
//  Cashooya Playground
//
//  Created by Claude on 9/12/25.
//

import SwiftUI
import Combine

// MARK: - Edit Category Detail Sheet
struct EditCategoryDetailSheet: View {
    let categoryData: DisplayCategoryData
    let onDismiss: () -> Void
    let currentTab: CategoryTab // Current tab context (Income/Expense)
    
    enum CategoryTab {
        case income
        case expense
        
        var rawValue: String {
            switch self {
            case .income: return "income"
            case .expense: return "expense"
            }
        }
    }
    
    @ObservedObject private var categoriesManager = CategoriesManager.shared
    
    // Computed property for the original category name and ID
    private var originalCategoryName: String {
        return categoryData.categoryData.name
    }
    
    private var originalCategoryId: UUID {
        return categoryData.categoryData.id
    }
    
    private var parentCategoryName: String? {
        return categoryData.categoryData.parent
    }
    
    private var parentCategoryId: UUID? {
        return categoryData.categoryData.parentId
    }
    @State private var editedName: String
    @State private var selectedEmoji: String
    @State private var selectedParentCategory: String?
    @State private var selectedParentCategoryId: UUID?
    
    // Store original values for comparison
    private let originalName: String
    private let originalEmoji: String
    private let originalParentCategory: String?
    
    // Computed property to get current category data dynamically
    private var currentCategoryData: (name: String, emoji: String, parentName: String?)? {
        // First try to find by the current edited name (if it exists)
        if let category = categoriesManager.findCategory(by: editedName) {
            let parentName = category.parentCategoryId != nil ? 
                categoriesManager.findCategory(by: category.parentCategoryId!)?.name : nil
            return (category.name, category.emoji, parentName)
        }
        
        // Fallback to original name lookup
        if let category = categoriesManager.findCategory(by: originalCategoryName) {
            let parentName = category.parentCategoryId != nil ? 
                categoriesManager.findCategory(by: category.parentCategoryId!)?.name : nil
            return (category.name, category.emoji, parentName)
        }
        
        return nil
    }
    @State private var showingEmojiPicker = false
    @State private var showingMoveError = false
    @State private var showingDuplicateError = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteError = false
    @State private var categoryChildrenNames: [String] = []
    
    private let objectWillChange = PassthroughSubject<Void, Never>()
    
    /// Check if any changes have been made
    private var hasChanges: Bool {
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameChanged = trimmedName != originalName
        let emojiChanged = selectedEmoji != originalEmoji
        
        // Check parent changes by comparing the actual parent names
        let parentChanged = selectedParentCategory != originalParentCategory
        
        #if DEBUG
        print("🔥 hasChanges DEBUG:")
        print("🔥   - Original name: '\(originalName)' vs Current: '\(trimmedName)' -> Changed: \(nameChanged)")
        print("🔥   - Original emoji: '\(originalEmoji)' vs Current: '\(selectedEmoji)' -> Changed: \(emojiChanged)")
        print("🔥   - Original parent: '\(originalParentCategory ?? "nil")'")
        print("🔥   - Current parent: '\(selectedParentCategory ?? "nil")'")
        print("🔥   - Parent changed: \(parentChanged)")
        print("🔥   - Has changes: \(nameChanged || emojiChanged || parentChanged)")
        #endif
        
        return nameChanged || emojiChanged || parentChanged
    }
    
    init(categoryData: DisplayCategoryData, currentTab: CategoryTab, onDismiss: @escaping () -> Void) {
        self.categoryData = categoryData
        self.currentTab = currentTab
        self.onDismiss = onDismiss
        
        // Use the category data directly - no need for lookups!
        let currentName = categoryData.categoryData.name
        let currentEmoji = categoryData.categoryData.emoji
        
        print("🔍 EditCategoryDetailSheet INIT (Direct Data):")
        print("   - Category name: '\(currentName)'")
        print("   - Category emoji: '\(currentEmoji)'")
        print("   - Is child: \(categoryData.isChild)")
        if let parentName = categoryData.parentName {
            print("   - Parent: '\(parentName)'")
        }
        
        self.originalName = currentName
        self.originalEmoji = currentEmoji
        self._editedName = State(initialValue: currentName)
        self._selectedEmoji = State(initialValue: currentEmoji)
        
        // Set parent category directly from the display data
        let currentParent = categoryData.isChild ? categoryData.parentName : nil
        let currentParentId = categoryData.isChild ? categoryData.categoryData.parentId : nil
        
        self.originalParentCategory = currentParent
        self._selectedParentCategory = State(initialValue: currentParent)
        self._selectedParentCategoryId = State(initialValue: currentParentId)
        
        #if DEBUG
        print("🔥 EditCategoryDetailSheet INIT DEBUG:")
        print("🔥   - Category: '\(categoryData.categoryData.name)'")
        print("🔥   - Is Child: \(categoryData.isChild)")
        print("🔥   - Original parent: '\(currentParent ?? "nil")'")
        print("🔥   - Original parent ID: '\(currentParentId?.uuidString ?? "nil")'")
        print("🔥   - Current tab: \(currentTab)")
        #endif
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: {
                    onDismiss()
                }) {
                    Image("chevron-left")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 24, height: 24)
                        .foregroundColor(AppColors.foregroundSecondary)
                }
                
                Spacer()
                
                Text("Edit Category")
                    .font(AppFonts.overusedGroteskSemiBold(size: 18))
                    .foregroundColor(AppColors.foregroundPrimary)
                
                Spacer()
                
                // Delete button
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Image("trash-04")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 24, height: 24)
                        .foregroundColor(AppColors.foregroundSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Emoji selector
                    Button(action: {
                        showingEmojiPicker = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(AppColors.surfacePrimary)
                                .frame(width: 80, height: 80)
                            
                            Text(selectedEmoji)
                                .font(.system(size: 40))
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Category name input
                    AppInputField.text(
                        title: "Category Name",
                        text: $editedName,
                        placeholder: "Enter category name",
                        size: .md
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    
                    // Parent Category Picker - using reusable AppInputField component
                    AppInputField.parentCategory(
                        selectedParent: Binding(
                            get: { selectedParentCategory ?? "" },
                            set: { newValue in
                                selectedParentCategory = newValue.isEmpty ? nil : newValue
                                selectedParentCategoryId = getParentCategoryId(from: newValue.isEmpty ? nil : newValue)
                                print("🔄 Parent category changed to: '\(newValue)' (ID: \(selectedParentCategoryId?.uuidString ?? "None"))")
                                
                                // Auto-save category type changes for immediate transaction color updates
                                autoSaveCategoryTypeChange(newParent: newValue.isEmpty ? nil : newValue)
                            }
                        ),
                        availableCategories: getAvailableParentCategories(),
                        currentCategoryName: editedName,
                        size: AppInputField.Size.md
                    )
                    
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 100) // Space for fixed button
            }
            
            // Fixed bottom button
            VStack(spacing: 0) {
                Divider()
                    .background(AppColors.linePrimary)
                
                AppButton(
                    title: "Save", 
                    action: { saveChanges() },
                    hierarchy: .primary,
                    size: .small,
                    isEnabled: hasChanges
                )
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 34)
            }
            .background(AppColors.backgroundWhite)
        }
        .background(AppColors.backgroundWhite)
        .onReceive(categoriesManager.objectWillChange) { _ in
            // Refresh category data when CategoriesManager updates
            DispatchQueue.main.async {
                refreshCategoryData()
            }
        }
        .sheet(isPresented: $showingEmojiPicker) {
            EmojiPickerSheet(selectedEmoji: $selectedEmoji, isPresented: $showingEmojiPicker)
        }
        .appInfoAlert(
            title: "Cannot Move Category",
            isPresented: $showingMoveError,
            message: {
                if categoryChildrenNames.count == 1 {
                    return "'\(originalCategoryName)' contains the subcategory '\(categoryChildrenNames.first!)'. Please remove or move this subcategory first before changing the parent."
                } else if categoryChildrenNames.count > 1 {
                    return "'\(originalCategoryName)' contains \(categoryChildrenNames.count) subcategories: \(categoryChildrenNames.joined(separator: ", ")). Please remove or move these subcategories first before changing the parent."
                } else {
                    return "This category contains subcategories. Please remove or move them first before changing the parent."
                }
            }(),
            onDismiss: {
                // Reset the selected parent category since the move is not allowed
                selectedParentCategory = nil
                selectedParentCategoryId = nil
            }
        )
        .appInfoAlert(
            title: "Category Already Exists",
            isPresented: $showingDuplicateError,
            message: "A category with this name already exists. Please choose a different name."
        )
        .appAlert(
            title: "Delete Category",
            isPresented: $showingDeleteConfirmation,
            message: "Are you sure you want to delete this category? Any transactions using this category will be automatically converted to 'No Category'. This action cannot be undone.",
            primaryAction: .destructive("Delete") {
                deleteCategory()
            }
        )
        .appInfoAlert(
            title: "Cannot Delete Category",
            isPresented: $showingDeleteError,
            message: "This category has subcategories. Please delete or move the subcategories first."
        )
    }
    
    private func refreshCategoryData() {
        // Try to find current category by the edited name or original name
        let categoryToRefresh = editedName.isEmpty ? originalCategoryName : editedName
        
        // Refresh emoji from current category using the improved lookup
        selectedEmoji = categoriesManager.emojiFor(category: categoryToRefresh)
        
        // Refresh parent category using the unified system
        if let currentCategory = categoriesManager.findCategory(by: categoryToRefresh),
           let parentId = currentCategory.parentCategoryId,
           let parentCategory = categoriesManager.findCategory(by: parentId) {
            selectedParentCategory = parentCategory.name
        } else {
            selectedParentCategory = nil
        }
        
        // Update editedName with current category name if found
        if let currentCategory = categoriesManager.findCategory(by: originalCategoryName) {
            editedName = currentCategory.name
        }
    }
    
    private func getAvailableParentCategories() -> [CategoryData] {
        // Get ALL categories (both Income and Expense) that can be parents
        // This enables cross-type parent editing (Income category can have Expense parent and vice versa)
        let allCategories = categoriesManager.allCategoriesWithCustom
            
        return allCategories.filter { category in
            // Exclude current category (use both original and edited names)
            guard category.name != originalCategoryName && category.name != editedName else { return false }
            
            // Exclude current children of this category
            let currentChildren = categoriesManager.categoryHierarchy[originalCategoryName] ?? []
            guard !currentChildren.contains(category.name) else { return false }
            
            return true
        }
    }
    
    /// Get the type of the current category being edited
    private func getCurrentCategoryType() -> CategoryType {
        // Try to find the current category by name and get its type
        if let category = categoriesManager.findCategory(by: originalCategoryName) {
            return category.type
        }
        
        // If not found, check if it's a subcategory
        let result = categoriesManager.findCategoryOrSubcategory(by: originalCategoryName)
        if result.isSubcategory {
            // Get type from parent category
            if let parentCategory = result.parent {
                return parentCategory.type
            }
        }
        
        // Default to expense if we can't determine the type
        return .expense
    }
    
    /// Convert parent category ID to name for API calls
    private func getParentCategoryName(from id: UUID?) -> String? {
        guard let id = id else { return nil }
        return categoriesManager.findCategory(by: id)?.name
    }
    
    /// Convert parent category name to ID for UI state
    private func getParentCategoryId(from name: String?) -> UUID? {
        guard let name = name else { return nil }
        return categoriesManager.findCategory(by: name)?.id
    }
    
    /// Get all children (subcategories and child categories) of a category
    private func getCategoryChildren(_ categoryName: String) -> [String] {
        var children: [String] = []
        
        // Get traditional subcategories
        if let category = categoriesManager.findCategory(by: categoryName) {
            children.append(contentsOf: category.subcategories.map { $0.name })
        }
        
        // Get categories that have this category as parent (via parentCategoryId)
        let childCategories = categoriesManager.allCategoriesWithCustom.filter { category in
            if let parentId = category.parentId,
               let parentCategory = categoriesManager.findCategory(by: parentId) {
                return parentCategory.name == categoryName
            }
            return false
        }
        children.append(contentsOf: childCategories.map { $0.name })
        
        return children
    }
    
    /// Auto-save category type changes for immediate transaction color updates
    private func autoSaveCategoryTypeChange(newParent: String?) {
        // Determine the new category type based on parent selection
        let newType: CategoryType
        
        if let parentName = newParent {
            // Moving to a parent category - inherit parent's type
            if let parentCategory = categoriesManager.findCategory(by: parentName) {
                newType = parentCategory.type
            } else {
                // Fallback to current tab type
                newType = currentTab == .income ? .income : .expense
            }
        } else {
            // No parent selected - use current tab type (Income/Expense)
            newType = currentTab == .income ? .income : .expense
        }
        
        // Get current category type for comparison
        let currentType = getCurrentCategoryType()
        
        // Only auto-save if the type actually changes
        guard newType != currentType else {
            print("🔄 Auto-save: Category type unchanged (\(currentType)), skipping auto-save")
            return
        }
        
        print("🔄 Auto-save: Category type changing from \(currentType) to \(newType)")
        
        // Convert newParent to final parent name using container system
        let finalParentName: String?
        if let parentName = newParent {
            finalParentName = parentName
        } else {
            finalParentName = newType == .income ? "No Parent (Income)" : "No Parent (Expense)"
        }
        
        // Auto-save the category with its new type
        let success = categoriesManager.updateCategory(
            originalName: originalCategoryName,
            newName: editedName.trimmingCharacters(in: .whitespacesAndNewlines),
            newEmoji: selectedEmoji,
            parentCategory: finalParentName,
            targetType: nil // Container system handles type automatically
        )
        
        if success {
            print("✅ Auto-save: Successfully updated category type to \(newType)")
        } else {
            print("❌ Auto-save: Failed to update category type")
        }
    }
    
    private func saveChanges() {
        print("🔥 ====== SAVE CATEGORY DEBUG START ======")
        print("🔥 Original Category: '\(originalCategoryName)'")
        print("🔥 Original Emoji: '\(originalEmoji)'") 
        print("🔥 Original Parent: '\(originalParentCategory ?? "None")'")
        print("🔥 ------ CURRENT VALUES ------")
        print("🔥 Edited Name: '\(editedName)'")
        print("🔥 Selected Emoji: '\(selectedEmoji)'")
        print("🔥 Selected Parent Name: '\(selectedParentCategory ?? "None")'")
        print("🔥 Selected Parent ID: '\(selectedParentCategoryId?.uuidString ?? "None")'")
        
        guard !editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { 
            print("🔥 ❌ Category name cannot be empty")
            return 
        }
        
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        print("🔥 Trimmed Name: '\(trimmedName)'")
        
        // Convert selectedParentCategoryId to parent name for the updateCategory call
        let parentName = getParentCategoryName(from: selectedParentCategoryId)
        print("🔥 Resolved Parent Name from ID: '\(parentName ?? "None")'")
        
        // Check if trying to move a parent category that has subcategories
        if selectedParentCategoryId != nil {
            let currentChildren = getCategoryChildren(originalCategoryName)
            print("🔥 Current Children Count: \(currentChildren.count)")
            if !currentChildren.isEmpty {
                print("🔥 ❌ Cannot move category - has subcategories: \(currentChildren)")
                // Store children info for the error message
                categoryChildrenNames = currentChildren
                showingMoveError = true
                return
            }
        }
        
        // Check what changes are being made
        let nameChanged = trimmedName != originalName
        let emojiChanged = selectedEmoji != originalEmoji
        let parentChanged = selectedParentCategoryId != parentCategoryId
        print("🔥 ------ CHANGES DETECTED ------")
        print("🔥 Name Changed: \(nameChanged) ('\(originalName)' -> '\(trimmedName)')")
        print("🔥 Emoji Changed: \(emojiChanged) ('\(originalEmoji)' -> '\(selectedEmoji)')")
        print("🔥 Parent Changed: \(parentChanged)")
        
        // Use the unified updateCategory method for both subcategories and top-level categories
        print("🔥 ------ CALLING UPDATE CATEGORY ------")
        print("🔥 Calling updateCategory with:")
        print("🔥   - originalName: '\(originalCategoryName)'")
        print("🔥   - newName: '\(trimmedName)'") 
        print("🔥   - newEmoji: '\(selectedEmoji)'")
        print("🔥   - parentCategory: '\(parentName ?? "None")'")
        
        // Use simplified container-based approach
        let finalParentName: String? = parentName ?? (currentTab == .income ? "No Parent (Income)" : "No Parent (Expense)")
        
        print("🔥 ===== EDIT CATEGORY WITH CONTAINER SYSTEM =====")
        print("🔥 User selected parent: \(parentName ?? "None")")
        print("🔥 Selected tab: \(currentTab)")
        print("🔥 Final parent (with container): \(finalParentName ?? "None")")
        
        let success = categoriesManager.updateCategory(
            originalName: originalCategoryName,
            newName: trimmedName,
            newEmoji: selectedEmoji,
            parentCategory: finalParentName,
            targetType: nil // No longer needed with container system
        )
        
        print("🔥 ------ UPDATE RESULT ------")
        if success {
            print("🔥 ✅ SUCCESS: Category update completed successfully!")
            print("🔥 Final Values:")
            print("🔥   - Name: '\(originalCategoryName)' -> '\(trimmedName)'")
            print("🔥   - Emoji: '\(originalEmoji)' -> '\(selectedEmoji)'")
            print("🔥   - Parent: '\(originalParentCategory ?? "None")' -> '\(parentName ?? "None")'")
            
            // Verify the category was actually updated by looking it up
            if let updatedCategory = categoriesManager.findCategory(by: trimmedName) {
                print("🔥 ✅ VERIFICATION: Found updated category:")
                print("🔥   - ID: \(updatedCategory.id)")
                print("🔥   - Name: '\(updatedCategory.name)'")
                print("🔥   - Emoji: '\(updatedCategory.emoji)'")
                print("🔥   - Parent ID: '\(updatedCategory.parentCategoryId?.uuidString ?? "None")'")
                print("🔥   - Type: \(updatedCategory.type)")
                print("🔥   - Should appear in: \(updatedCategory.type == .income ? "INCOME" : "EXPENSE") tab")
                
                // Additional verification: Check if it appears in the correct category list
                let incomeCategories = categoriesManager.allIncomeCategoriesWithCustom
                let expenseCategories = categoriesManager.allExpenseCategoriesWithCustom
                let appearsInIncome = incomeCategories.contains { $0.id == updatedCategory.id }
                let appearsInExpense = expenseCategories.contains { $0.id == updatedCategory.id }
                
                print("🔥 TAB VERIFICATION:")
                print("🔥   - Appears in Income list: \(appearsInIncome)")
                print("🔥   - Appears in Expense list: \(appearsInExpense)")
                if appearsInIncome && appearsInExpense {
                    print("🔥   ⚠️ WARNING: Category appears in BOTH lists!")
                } else if !appearsInIncome && !appearsInExpense {
                    print("🔥   ❌ ERROR: Category appears in NEITHER list!")
                }
            } else {
                print("🔥 ⚠️ WARNING: Could not find updated category by name '\(trimmedName)'")
            }
            
            print("🔥 ====== SAVE CATEGORY DEBUG END ======")
            
            // Force immediate UI update and dismiss synchronously
            DispatchQueue.main.async {
                onDismiss()
            }
        } else {
            print("🔥 ❌ FAILURE: Category update failed!")
            print("🔥 Possible reasons:")
            print("🔥   - Category name might already exist")
            print("🔥   - Parent category not found")
            print("🔥   - Category lookup failed")
            print("🔥 ====== SAVE CATEGORY DEBUG END ======")
            showingDuplicateError = true
        }
    }
    
    private func deleteCategory() {
        print("🗑️ Attempting to delete category: \(originalCategoryName)")
        let success = categoriesManager.deleteCategory(originalCategoryName)
        if success {
            print("✅ Successfully deleted category: \(originalCategoryName)")
            onDismiss()
        } else {
            print("❌ Failed to delete category: \(originalCategoryName) - likely has subcategories")
            showingDeleteError = true
        }
    }
}