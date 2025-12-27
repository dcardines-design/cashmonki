//
//  AddCategorySheet.swift
//  Cashooya Playground
//
//  Created by Claude on 9/11/25.
//

import SwiftUI

struct AddCategorySheet: View {
    @Binding var isPresented: Bool
    let currentTab: CategoryTab // Current tab context (Income/Expense)
    @State private var categoryName = ""
    @State private var selectedEmoji = "🚗"
    @State private var selectedParentCategory: String?
    @State private var showingEmojiPicker = false
    @State private var showingDuplicateError = false
    @ObservedObject private var categoriesManager = CategoriesManager.shared
    
    /// Check if the form is valid for saving
    private var isFormValid: Bool {
        return !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: {
                    isPresented = false
                }) {
                    Image("chevron-left")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 24, height: 24)
                        .foregroundColor(AppColors.foregroundSecondary)
                }
                
                Spacer()
                
                Text("Add Category")
                    .font(AppFonts.overusedGroteskSemiBold(size: 18))
                    .foregroundColor(AppColors.foregroundPrimary)
                
                Spacer()
                
                // Invisible spacer for balance
                Color.clear
                    .frame(width: 24, height: 24)
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
                        text: $categoryName,
                        placeholder: "Enter category name",
                        size: .md
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    .onChange(of: categoryName) { _, newValue in
                        print("🔤 Category name changed to: '\(newValue)'")
                    }
                    
                    // Parent Category Picker - using reusable AppInputField component
                    AppInputField.parentCategory(
                        selectedParent: Binding(
                            get: { selectedParentCategory ?? "" },
                            set: { selectedParentCategory = $0.isEmpty ? nil : $0 }
                        ),
                        availableCategories: getAvailableParentCategories(),
                        currentCategoryName: categoryName,
                        size: .md
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
                    action: { saveCategory() },
                    hierarchy: .primary,
                    size: .small,
                    isEnabled: isFormValid
                )
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 34)
            }
            .background(AppColors.backgroundWhite)
        }
        .background(AppColors.backgroundWhite)
        .sheet(isPresented: $showingEmojiPicker) {
            EmojiPickerSheet(selectedEmoji: $selectedEmoji, isPresented: $showingEmojiPicker)
        }
        .appInfoAlert(
            title: "Cannot Create Category",
            isPresented: $showingDuplicateError,
            message: "Unable to create the category. This could be due to a duplicate name, missing parent category, or other validation issue. Please check the console for details."
        )
    }
    
    private func getAvailableParentCategories() -> [CategoryData] {
        // Get categories that can be parents (all existing categories for new category creation)
        return categoriesManager.allCategoriesWithCustom
    }
    
    private func saveCategory() {
        print("💾 saveCategory called with categoryName: '\(categoryName)'")
        guard !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { 
            print("❌ Category name is empty after trimming")
            return 
        }
        
        let trimmedName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        print("✂️ Trimmed name: '\(trimmedName)'") 
        
        // If no parent is selected, pass nil (creates top-level category)
        let finalParentCategory: String? = selectedParentCategory
            
        print("🔥 ===== ADD CATEGORY WITH CONTAINER SYSTEM =====")
        print("🔥 User selected parent: \(selectedParentCategory ?? "None")")
        print("🔥 Selected tab: \(currentTab)")
        print("🔥 Final parent (with container): \(finalParentCategory ?? "None")")
        
        let targetType = finalParentCategory == nil ? (currentTab == .income ? CategoryType.income : CategoryType.expense) : nil
        print("🔥 About to call addCategory with:")
        print("🔥   - name: '\(trimmedName)'")
        print("🔥   - emoji: '\(selectedEmoji)'")  
        print("🔥   - parentCategory: '\(finalParentCategory ?? "nil")'")
        print("🔥   - targetType: \(targetType?.rawValue ?? "nil")")
        
        let success = categoriesManager.addCategory(
            name: trimmedName,
            emoji: selectedEmoji,
            parentCategory: finalParentCategory,
            targetType: targetType
        )
        
        print("🔥 addCategory returned: \(success)")
        
        if success {
            print("✅ Successfully created category: \(trimmedName) with emoji: \(selectedEmoji), parent: \(selectedParentCategory ?? "None")")

            // Track category creation in PostHog
            PostHogManager.shared.capture(.categoryCreated, properties: [
                "name": trimmedName,
                "emoji": selectedEmoji,
                "type": currentTab.rawValue,
                "has_parent": selectedParentCategory != nil,
                "parent_category": selectedParentCategory ?? ""
            ])
            
            // Verify the category was created with correct type
            if let createdCategory = categoriesManager.findCategory(by: trimmedName) {
                print("🔥 ✅ ADD VERIFICATION: Found created category:")
                print("🔥   - ID: \(createdCategory.id)")
                print("🔥   - Name: '\(createdCategory.name)'")
                print("🔥   - Emoji: '\(createdCategory.emoji)'")
                print("🔥   - Type: \(createdCategory.type)")
                print("🔥   - Should appear in: \(createdCategory.type == .income ? "INCOME" : "EXPENSE") tab")
                
                // Check if it appears in the correct category list
                let incomeCategories = categoriesManager.allIncomeCategoriesWithCustom
                let expenseCategories = categoriesManager.allExpenseCategoriesWithCustom
                let appearsInIncome = incomeCategories.contains { $0.id == createdCategory.id }
                let appearsInExpense = expenseCategories.contains { $0.id == createdCategory.id }
                
                print("🔥 ADD TAB VERIFICATION:")
                print("🔥   - Appears in Income list: \(appearsInIncome)")
                print("🔥   - Appears in Expense list: \(appearsInExpense)")
                print("🔥   - Expected tab: \(currentTab)")
            }
            
            isPresented = false
        } else {
            print("❌ Failed to create category: \(trimmedName)")
            
            // Enhanced error detection - check what exactly failed
            if let parent = finalParentCategory {
                let parentExists = categoriesManager.findCategory(by: parent) != nil
                print("🔍 DEBUGGING FAILURE:")
                print("🔍   - Parent category specified: '\(parent)'")
                print("🔍   - Parent exists in system: \(parentExists)")
                
                if !parentExists {
                    print("🔍   - Available categories:")
                    for category in categoriesManager.categories {
                        print("🔍     * '\(category.name)' (ID: \(category.id.uuidString.prefix(8)))")
                    }
                }
            }
            
            // Check if name already exists
            let nameExists = categoriesManager.findCategory(by: trimmedName) != nil
            print("🔍   - Category name '\(trimmedName)' already exists: \(nameExists)")
            
            showingDuplicateError = true
        }
    }
}

// MARK: - Emoji Picker Sheet
struct EmojiPickerSheet: View {
    @Binding var selectedEmoji: String
    @Binding var isPresented: Bool
    
    // Common emojis for categories
    private let emojis = [
        "🏠", "💡", "🍎", "🍽️", "🚗", "🛡️", "🩺", "💳", "🎭", "👕",
        "💇", "📚", "👶", "🐾", "🎁", "✈️", "📱", "🧹", "👔", "📎",
        "🧘", "💻", "📊", "📑", "💰", "🔩", "🍷", "🎨", "🎉", "🔄",
        "☕", "🛒", "🥨", "🥡", "🍛", "🚕", "⛽", "🚘", "🏡", "📃",
        "👨‍⚕️", "💊", "🧠", "💲", "📈", "🎬", "🎵", "🎮", "👖", "👟",
        "✂️", "🧴", "🧼", "🎓", "📖", "🧒", "🧸", "🥫", "💝", "🛫",
        "🏨", "🚙", "📺", "🖥️", "🔑", "🧽", "🛋️", "🏺", "⚖️", "🧮",
        "💼", "📌", "🖌️", "📦", "🏋️", "🤸", "🎧", "🔧"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 16) {
                    ForEach(emojis, id: \.self) { emoji in
                        Button(action: {
                            selectedEmoji = emoji
                            isPresented = false
                        }) {
                            Text(emoji)
                                .font(.system(size: 32))
                                .frame(width: 40, height: 40)
                                .background(selectedEmoji == emoji ? AppColors.surfacePrimary : Color.clear)
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Emoji")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    isPresented = false
                }
            )
        }
        .presentationDetents([.fraction(0.9)])
    }
}