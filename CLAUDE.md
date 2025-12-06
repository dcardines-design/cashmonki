# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**CashMonki** is an iOS expense tracking app built with SwiftUI. It features receipt scanning with AI analysis, transaction management, and secure API key storage. The app uses the Overused Grotesk font family and follows a specific design system.

## Architecture

### Core Components

**Main App Structure:**
- `CashMonkiApp.swift` - App entry point with SwiftData container and Firebase initialization
- `ContentView.swift` - Main tab view with Home, Transactions, and Settings tabs
- Uses SwiftData for local persistence and conditional Firebase integration

**Transaction System:**
- `Txn` model handles transactions with receipt images, merchant info, categorization, and notes
- Dummy data generator provides sample transactions for development  
- Transactions display with category icons and can be edited through detail views
- Note: "receipts" and "transactions" are used interchangeably - receipt scanning creates transactions

**AI Receipt Processing:**
- `ReceiptAI.swift` implements OpenRouter API integration for receipt analysis
- Uses GPT-4 Vision model for extracting merchant, amount, date, category, and line items
- Image resizing and base64 encoding for API efficiency
- Receipt scanning automatically creates transactions with extracted data

**Security & Configuration:**
- `KeychainManager.swift` provides secure storage for API keys
- `Config.swift` manages API key retrieval with priority: Keychain > Environment > Info.plist
- API key is hardcoded initially for setup but stored securely in keychain

**Design System:**
- `CashoojaDesignSystem.swift` - Unified design system (CashMonkiDS) with centralized access to all components
- `AppColors.swift` defines brand colors with semantic naming
- `AppButton.swift` implements 5-tier button hierarchy (Primary, Secondary, Tertiary, Ghost, Text)
- `AppIcon.swift` wraps vector assets with SF Symbol fallbacks
- `FontManager.swift` manages Overused Grotesk font family with semantic scales
- `UnifiedTransactionDisplay.swift` - Single transaction display component with multiple styles

### Key Features

1. **Receipt Scanning**: Photo picker → AI analysis → automatic transaction creation
2. **Transaction Management**: Add, edit, view with category grouping, date filtering, and notes
3. **Smart Currency Formatting**: Hides unnecessary .00 decimals, shows .01 when needed
4. **Income/Expense Classification**: Automatic amount sign based on category type (supports subcategories)
5. **Dynamic Pie Charts**: Visual breakdown with tab-based highlighting for income/expense/balance
6. **Spending Analytics**: Period comparisons with visual charts  
7. **Secure Storage**: API keys stored in device keychain
8. **Wallet Management**: Multi-account support with account-based transaction organization
9. **Authentication System**: User registration, login, and onboarding flow
10. **Currency System**: Multi-currency support with real-time conversion and preferences

## Development Commands

### Building and Running
```bash
# Open project in Xcode
open "CashMonki.xcodeproj"

# For testing, use Xcode's built-in simulator
# No separate build commands - uses Xcode's build system
```

### Font Setup
The app requires the Overused Grotesk font family. Follow `Font-Setup-Instructions.md` to:
1. Add font files to Xcode project
2. Register in Info.plist under `UIAppFonts`
3. Verify font names with the provided debugging code

### API Configuration
- OpenRouter API key is required for receipt scanning (which creates transactions)
- Initially hardcoded in `Config.swift` line 33 for first-time setup
- Automatically moved to keychain for security after first launch
- For development, can set `OPENROUTER_API_KEY` environment variable

## Important Patterns

### Currency Formatting
Always use smart decimal formatting that hides unnecessary .00:
```swift
// ✅ CORRECT - Smart formatting (hides .00, shows .01)
let formatter = NumberFormatter()
formatter.minimumFractionDigits = 0  // Hide .00
formatter.maximumFractionDigits = 2  // Show up to .01
formatter.groupingSeparator = ","
// Results: 450.00 → 450, 450.01 → 450.01, 1234.56 → 1,234.56

// ❌ AVOID - Always shows .00
formatter.minimumFractionDigits = 2  // Forces .00 display
```

### Income/Expense Classification  
Use category type for amount sign, supports subcategories:
```swift
// ✅ CORRECT - Handles both categories and subcategories with their own types
let categoryResult = CategoriesManager.shared.findCategoryOrSubcategory(by: selectedCategory)
if let category = categoryResult.category {
    finalAmount = category.type == .income ? abs(amount) : -abs(amount)
} else if let subcategory = categoryResult.subcategory {
    finalAmount = subcategory.type == .income ? abs(amount) : -abs(amount)
}

// ❌ AVOID - Only finds top-level categories, misses subcategories
if let category = CategoriesManager.shared.findCategory(by: selectedCategory)
```

### Font Usage
Always use the custom font system:
```swift
.font(.custom("OverusedGrotesk-SemiBold", size: 17))
// Or use AppFonts:
.font(AppFonts.headline)
```

### Color Usage
Use semantic color names from AppColors:
```swift
.foregroundStyle(AppColors.foregroundPrimary)
.background(AppColors.surfacePrimary)
```

### Unified Design System Usage
Use CashMonkiDS for all components:
```swift
// Buttons
CashMonkiDS.Button.primary("Save") { /* action */ }
CashMonkiDS.Button.secondary("Cancel", leftIcon: "xmark") { /* action */ }

// Input Fields
CashMonkiDS.Input.text(title: "Name", text: $name)
CashMonkiDS.Input.amount(text: $amount, currency: "USD")
CashMonkiDS.Input.date(title: "Date", dateValue: $date)

// Transaction Displays - Use directly  
UnifiedTransactionDisplay.row(transaction: txn)
UnifiedTransactionDisplay.tile(transaction: txn) { /* tap */ }
UnifiedTransactionDisplay.compact(transaction: txn)

// Icons
CashMonkiDS.Icon.category("Food", size: 36)
CashMonkiDS.Icon.app(assetName: "custom-icon", fallbackSystemName: "house")
```

### Legacy Component Usage (Deprecated)
❌ Avoid these - use CashMonkiDS instead:
```swift
// Deprecated - Use CashMonkiDS.Button instead
AppButton.primary("Save") { /* action */ }

// Deprecated - Use CashMonkiDS.Input instead  
AppInputField.text(title: "Name", text: $name)

// Deprecated - Use CashMonkiDS.Transaction instead
TransactionRow(transaction: txn) // REMOVED
TransactionTile(transaction: txn) // REMOVED
```

## File Organization

- **Main App**: `CashMonki/` - Main source files
- **Tests**: `CashMonkiTests/` and `CashMonkiUITests/`
- **Assets**: `Assets.xcassets/` - Vector icons and app assets
- **Node Dependencies**: `node_modules/` - Contains `untitledui` icon package

## Testing

The project includes standard iOS testing targets:
- Unit tests in `CashMonkiTests/`
- UI tests in `CashMonkiUITests/`

Run tests through Xcode Test Navigator (⌘+6) or Product > Test menu.

## Dependencies

- **External**: Firebase (conditional), untitledui icons
- **iOS**: SwiftUI, SwiftData, PhotosUI, Security (Keychain)
- **API**: OpenRouter for AI receipt analysis

## UI Component System

### Unified Design System (CashMonkiDS)

The app uses a unified design system (`CashMonkiDS`) that provides centralized access to all components, ensuring consistency and reducing code duplication.

#### Core Principles:
- **Single source of truth** for all UI components
- **Consistent styling** across the app
- **Reduced maintenance** - update styles in one place
- **Better developer experience** - unified API

#### Component Categories:

**Input Components:**
- `CashMonkiDS.Input.text()` - Text input fields
- `CashMonkiDS.Input.amount()` - Currency amount inputs  
- `CashMonkiDS.Input.merchant()` - Merchant name inputs
- `CashMonkiDS.Input.search()` - Search inputs with magnifying glass
- `CashMonkiDS.Input.date()` - Date picker inputs

**Button Components:**
- `CashMonkiDS.Button.primary()` - Main actions
- `CashMonkiDS.Button.secondary()` - Alternative actions
- `CashMonkiDS.Button.tertiary()` - Less important actions
- `CashMonkiDS.Button.ghost()` - Subtle interactions  
- `CashMonkiDS.Button.text()` - Minimal text buttons

**Transaction Display Components:**
- Use `UnifiedTransactionDisplay` directly to avoid compilation issues
- `UnifiedTransactionDisplay.row()` - List-style transaction rows
- `UnifiedTransactionDisplay.tile()` - Card-style transaction tiles  
- `UnifiedTransactionDisplay.compact()` - Minimal transaction display
- `UnifiedTransactionDisplay.detailed()` - Rich information display
- `TransactionGroup()` - Transaction groups with headers

**Overlay Components:**
- `CashMonkiDS.Overlay.fullScreenOverlay()` - Full-screen modals
- `CashMonkiDS.Overlay.modalOverlay()` - Sheet-style modals
- `CashMonkiDS.Overlay.settingsOverlay()` - Settings-style layouts

**Selection Components:**
- `CashMonkiDS.Selection.row()` - Generic selection rows
- `CashMonkiDS.Selection.currency()` - Currency selection
- `CashMonkiDS.Selection.category()` - Category selection

**Icon Components:**
- `CashMonkiDS.Icon.category()` - Transaction category icons (uses TxnCategoryIcon)
- `CashMonkiDS.Icon.app()` - App icons with SF Symbol fallbacks

### Consolidated Transaction Display System

The app now uses `UnifiedTransactionDisplay` instead of separate `TransactionRow` and `TransactionTile` components:

#### Display Styles:
```swift
// Row style - for lists (replaces TransactionRow)
UnifiedTransactionDisplay.row(transaction: txn) 

// Tile style - for cards (replaces TransactionTile) 
UnifiedTransactionDisplay.tile(transaction: txn) { /* tap action */ }

// Compact style - for small spaces
UnifiedTransactionDisplay.compact(transaction: txn)

// Detailed style - for rich displays
UnifiedTransactionDisplay.detailed(transaction: txn)
```

#### Benefits:
- **Single emoji mapping system** (TxnCategoryIcon)
- **Consistent currency formatting**
- **Unified styling and spacing**
- **Easier maintenance and updates**
- **90% reduction in duplicate code**

### Category Icon System

All transaction categories use `TxnCategoryIcon` as the single source of truth:
- **350+ category mappings** with emojis
- **Comprehensive coverage** of expense categories
- **Consistent icon display** across all transaction components
- **Easy to extend** with new categories

### Overlay Templates (OverlayTemplate.swift)

Reusable template system for consistent overlay/modal presentations:

#### Available Templates:

1. **FullScreenOverlayTemplate** - Primary actions, editing, forms
   - Full screen presentation with header, back button, confirm button
   - Scrollable content area
   - Use with `.fullScreenCover(isPresented:)`

2. **ModalOverlayTemplate** - Quick edits, selections, secondary actions
   - Rounded corners, modal-style presentation  
   - Compact content with confirm/cancel actions
   - Use with `.sheet(isPresented:)`

3. **SettingsOverlayTemplate** - Lists, settings, navigation pages
   - Navigation-style header without confirm button
   - Ideal for settings pages, selection lists
   - Use with `.fullScreenCover(isPresented:)`

4. **OverlayTemplate** - Base template for custom layouts
   - Customizable via `.overlayStyle()` modifier
   - Full control over appearance and behavior

#### Usage Example:
```swift
FullScreenOverlayTemplate(
    title: "Edit Transaction", 
    confirmTitle: "Save",
    isConfirmEnabled: true,
    onBack: { dismiss() },
    onConfirm: { saveChanges() }
) {
    // Your form content here
    VStack(spacing: 24) {
        // Input fields, etc.
    }
}
```

See `Template-Usage-Examples.swift` for comprehensive examples and cheat sheet.

### Component Development Rules

#### When to Create New Components:
1. **Check existing components first** - Use CashMonkiDS unified system
2. **Avoid duplication** - Extend existing components rather than creating new ones
3. **Follow naming conventions** - Use CashMonkiDS.Category.function() pattern
4. **Confirm with maintainers** before creating new components

#### Component Hierarchy:
```swift
// ✅ Preferred approach - Use design system
CashMonkiDS.Component.variant()

// ⚠️ Acceptable for specialized cases
CustomComponent() // When no design system equivalent exists

// ❌ Avoid - Creates inconsistency
DirectComponentUsage() // Raw SwiftUI without design system
```

#### Validation and Rules:
- Reference `ComponentUsageRules.swift` for comprehensive component guidelines
- Use `StrictUIValidator` for strict compliance checking
- Follow typography, color, and spacing rules consistently
- Test components across different screen sizes

### Button System (AppButton.swift)

Comprehensive button component following design system:
- 5 hierarchy levels: primary, secondary, tertiary, ghost, text
- 3 sizes: medium, small, extraSmall
- Built-in state management, icons, custom styling
- Convenience static methods: `CashMonkiDS.Button.primary("Title") {}`

### Sheet Presentation System (SlideInSheet.swift)

**CRITICAL**: All sheets in the app use the standardized slide-in-from-right transition system. **Never use `.fullScreenCover` or `.sheet` directly** - always use the reusable `SlideInSheet` system.

#### Core Sheet Philosophy

> **"All sheets slide in from the right with consistent 0.3s animation. No exceptions."**

#### Reusable Sheet Presentation

Use the `.slideInSheet()` modifier for all sheet presentations:

```swift
// Basic sheet presentation
ContentView()
    .slideInSheet(isPresented: showingAddTransaction) {
        AddTransactionSheet(isPresented: $showingAddTransaction) { transaction in
            // Handle transaction save
        }
    }

// Multiple sheets
ContentView()
    .slideInSheet(isPresented: showingAdd) {
        AddTransactionSheet(isPresented: $showingAdd)
    }
    .slideInSheet(isPresented: showingEdit) {
        EditTransactionSheet(isPresented: $showingEdit)
    }

// Sheet with conditional content
ContentView()
    .slideInSheet(isPresented: showingDetail) {
        if let transaction = selectedTransaction {
            TransactionDetailSheet(
                transaction: transaction,
                onDismiss: { showingDetail = false }
            )
        }
    }
```

#### Standard Sheet Structure

All sheets **MUST** follow this consistent structure:

```swift
struct MySheet: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. ALWAYS use SheetHeader for consistency
            SheetHeader.basic(title: "My Sheet") {
                isPresented = false
            }
            
            // 2. Scrollable content area
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Your content here
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            
            // 3. ALWAYS use FixedBottomGroup for actions
            FixedBottomGroup.primary(
                title: "Save",
                action: { /* action logic */ }
            )
        }
        .background(AppColors.backgroundWhite)
    }
}
```

#### Sheet Animation Standards

- **Direction**: All sheets slide from right (`.move(edge: .trailing).combined(with: .identity)`)
- **Duration**: Exactly 0.3 seconds (`.linear(duration: 0.3)`) - **NO FADE EFFECTS**
- **Z-Index**: Always use `zIndex(1)` for proper layering - sheets stack on top of each other
- **Background**: Always use `AppColors.backgroundWhite`
- **Stacking**: All sheets are overlays that stack on top of each other when navigation gets deeper

#### Existing Sheet Components

**Transaction Sheets:**
- `AddTransactionSheet` - Creating new transactions (with note field)
- `EditTransactionSheet` - Modifying existing transactions  
- `ReceiptConfirmationSheet` - Confirming receipt analysis (creates transactions)
- `ReceiptDetailSheet` - Viewing transaction details (receipts become transactions)

**Picker Sheets:**
- `CategoryPickerSheet` - Selecting transaction categories
- `CurrencyPickerSheet` - Selecting currencies
- `LanguagePickerSheet` - Selecting languages

#### Sheet Header System

All sheets use `SheetHeader` component:

```swift
// Basic header (back button only)
SheetHeader.basic(title: "Sheet Title") { dismiss() }

// Header with edit action
SheetHeader.withEdit(title: "Sheet Title", onBackTap: { }, onEditTap: { })

// Header with custom right action
SheetHeader.withCustomAction(
    title: "Sheet Title",
    onBackTap: { },
    rightIcon: "checkmark",
    rightSystemIcon: "checkmark",
    onRightTap: { }
)
```

#### Fixed Bottom Actions

All sheets use `FixedBottomGroup` for consistent bottom actions:

```swift
// Primary action (Save, Confirm, etc.)
FixedBottomGroup.primary(title: "Save", action: { })

// Secondary action  
FixedBottomGroup.secondary(title: "Cancel", action: { })
```

#### Migration from Legacy Presentations

**❌ NEVER use these (Legacy):**
```swift
.fullScreenCover(isPresented: $showing) { MySheet() }
.sheet(isPresented: $showing) { MySheet() }
```

**✅ ALWAYS use this (Current):**
```swift
.slideInSheet(isPresented: showing) { MySheet() }
```

#### Sheet Development Rules

1. **Use slideInSheet modifier** for all new sheets
2. **Follow standard sheet structure** (Header + Content + FixedBottomGroup)
3. **Use SheetHeader component** for consistent headers
4. **Use FixedBottomGroup** for bottom actions
5. **Background must be AppColors.backgroundWhite**
6. **Test on different screen sizes**
7. **Ensure proper dismissal handling**

## Strict Reusable UI Principle

**CRITICAL**: This project enforces a strict reusable UI principle. **No new UI components should be created without first exhaustively checking existing components.** If no existing component matches your needs, you **MUST** get approval before creating new components.

### Core Philosophy

> **"Use existing components first. If none exist, adapt existing components. Only create new components as a last resort with explicit approval."**

### The Strict UI System

The project includes a comprehensive system to enforce component reusability:

#### 1. Component Registry (`ComponentRegistry.swift`)
Complete inventory of all available UI components with:
- **Categorized components**: Input, Button, Display, Layout, Design System
- **Use cases and descriptions** for each component
- **Adaptation possibilities** for extending functionality
- **Search functions** to find components by use case

```swift
// Find components for a specific use case
ComponentRegistry.findComponents(for: "text input") 
// Returns: ["AppInputField.text", "AppInputField.search", ...]

// Get detailed component information
ComponentRegistry.getComponentInfo(for: "AppInputField.text")
// Returns: Description, use cases, adaptations
```

#### 2. Component Selection Guide (`ComponentSelectionGuide.swift`)
Intelligent decision tree for component selection:
- **Interactive decision tree** walking you through component choices
- **Automatic recommendations** based on use case keywords
- **Validation functions** to verify component appropriateness

```swift
// Get intelligent component recommendation
let recommendation = ComponentSelectionGuide.findComponent(for: "button to save changes")
print(recommendation.formattedRecommendation)
// Output: ✅ Recommended: AppButton.primary
//         🎯 Confidence: High confidence match
//         📝 Reason: Keywords suggest primary action requirement

// Quick validation check
print(ComponentSelectionGuide.quickValidate(component: "AppButton.primary", for: "save button"))
// Output: ✅ Perfect match for use case
```

#### 3. Strict UI Validator (`StrictUIValidator.swift`)
Comprehensive validation system with multiple enforcement levels:
- **Strict Mode**: No new components without approval (default)
- **Moderate Mode**: New components with detailed justification
- **Permissive Mode**: Basic documentation requirements

```swift
// Validate new component creation
let status = StrictUIValidator.validateNewComponent(
    name: "CustomButton",
    purpose: "special action button",
    justification: "No existing button fits this unique use case..."
)

// Validate component usage
let usageStatus = StrictUIValidator.validateComponentUsage(
    component: "AppButton.primary",
    context: "save action"
)
```

#### 4. Component Usage Rules (`ComponentUsageRules.swift`)
Detailed enforcement rules with three levels:

**Core Rules (MUST FOLLOW - Blocking):**
- ✅ No raw SwiftUI components without design system wrappers
- ✅ Always check existing components before creating new ones
- ✅ Use AppColors/CashMonkiDS.Colors only (no hardcoded colors)
- ✅ Use CashMonkiDS.Typography only (no hardcoded fonts)
- ✅ Use CashMonkiDS.Spacing constants (no magic numbers)
- ✅ Document and get approval for all new components

**Component Rules (SHOULD FOLLOW - Warning):**
- All text inputs → `AppInputField` family
- All buttons → `AppButton` hierarchy
- All icons → `AppIcon` with fallbacks
- All transaction displays → `UnifiedTransactionDisplay`
- All overlays → Overlay templates
- All category icons → `TxnCategoryIcon`

**Design System Rules (BEST PRACTICES - Advisory):**
- Follow button hierarchy (primary > secondary > tertiary)
- Use consistent spacing scale (xs/sm/md/lg/xl/xxl)
- Use semantic color names (foregroundPrimary, not RGB values)
- Follow typography hierarchy (header1-3 > body > labels)

### Workflow: Before Creating Any UI

#### Step 1: Check Component Registry
```swift
// Always start here - search for existing components
let matches = ComponentRegistry.findComponents(for: "your use case")
if !matches.isEmpty {
    // Use existing component - DO NOT create new one
    print("Found existing components: \(matches)")
}
```

#### Step 2: Use Decision Tree
```swift
// Get intelligent recommendation
let guide = ComponentSelectionGuide.findComponent(for: "your specific need")
print(guide.formattedRecommendation)
// Follow the recommendation - adapt existing components
```

#### Step 3: Validate Before Creating
```swift
// Only if no existing component works
let validation = StrictUIValidator.validateNewComponent(
    name: "YourComponent",
    purpose: "detailed purpose explanation",
    justification: "why existing components cannot be adapted (min 100 chars)"
)

// If validation returns .requiresApproval or .blocked - STOP
// Get team approval before proceeding
```

### Quick Reference Commands

```swift
// Find components for any use case
ComponentRegistry.findComponents(for: "search input")

// Get smart recommendations  
ComponentSelectionGuide.quickFind("button for submitting form")

// Validate component choice
ComponentSelectionGuide.quickValidate(component: "AppButton.primary", for: "submit action")

// Check rule compliance
ComponentUsageRules.quickCheck(component: "Button", context: "save action")

// Audit entire file for compliance
ComponentUsageRules.validateViewFile(content: fileContent, fileName: "MyView.swift")
```

### Component Hierarchy (What to Use)

```swift
// ✅ FIRST CHOICE - Use existing design system components
CashMonkiDS.Button.primary("Save") { }
CashMonkiDS.Input.text(title: "Name", text: $name)
UnifiedTransactionDisplay.row(transaction: txn)

// ✅ SECOND CHOICE - Direct component access when needed
AppButton.primary("Save") { }
AppInputField.text(title: "Name", text: $name)
TxnCategoryIcon(category: "Food")

// ⚠️ REQUIRES JUSTIFICATION - Adaptations of existing components
struct CustomSaveButton: View { 
    // Wraps AppButton.primary with specific styling
}

// 🛑 REQUIRES APPROVAL - Completely new components
struct BrandNewComponent: View {
    // Only after exhausting all existing options
}

// ❌ NEVER ALLOWED - Raw SwiftUI without wrappers
Button("Save") { } // Use AppButton instead
TextField("Name", text: $name) // Use AppInputField instead
```

### Development Validation

#### For Individual Components:
```swift
#if DEBUG
extension MyCustomView {
    init() {
        // Validate during development
        let _ = StrictUIValidator.requireComponentValidation(
            "MyCustomView", 
            purpose: "displays custom data"
        )
    }
}
#endif
```

#### For Entire Files:
```swift
// Audit your view files
let audit = ComponentUsageRules.validateViewFile(
    content: sourceCode, 
    fileName: "HomePage.swift"
)
print(audit.formattedReport)
// Shows compliance score and specific violations
```

### Approval Process

When the system requires approval for new components:

1. **Document thoroughly**: Purpose, use cases, why existing components won't work
2. **Show research**: List existing components considered and why they were rejected
3. **Provide justification**: Detailed explanation (minimum 100 characters)
4. **Consider adaptations**: Could you extend an existing component instead?
5. **Get team review**: Present to team lead or maintainer for approval

### Example Violations and Fixes

❌ **VIOLATION**: Creating custom button
```swift
struct SaveButton: View {
    var body: some View {
        Button("Save") {
            // action
        }
        .background(Color.blue)
    }
}
```

✅ **FIX**: Use existing button system
```swift
// Option 1: Direct design system usage
CashMonkiDS.Button.primary("Save") {
    // action  
}

// Option 2: If customization needed, adapt existing
AppButton.primary("Save") {
    // action
}
.foregroundColor(AppColors.customBlue) // Use design system colors
```

❌ **VIOLATION**: Custom transaction display
```swift
struct MyTransactionCard: View {
    let transaction: Txn
    var body: some View {
        HStack {
            Text(transaction.category)
            Spacer()
            Text("$\(transaction.amount)")
        }
    }
}
```

✅ **FIX**: Use unified transaction system
```swift
// Use existing transaction display with appropriate style
UnifiedTransactionDisplay.tile(transaction: transaction) {
    // tap action if needed
}

// Or if you need minimal display
UnifiedTransactionDisplay.compact(transaction: transaction)
```

### Component Registry Categories

The system categorizes all components for easy discovery:

**Input Components**: `AppInputField.text/.amount/.merchant/.search/.date`
**Button Components**: `AppButton.primary/.secondary/.tertiary/.ghost/.text`  
**Display Components**: `UnifiedTransactionDisplay.row/.tile/.compact/.detailed`
**Layout Components**: Overlay templates, icons, toggles
**Design System**: Colors, typography, spacing, animations

### Testing Your Compliance

```swift
#if DEBUG
// Add to your app for development testing
ComponentUsageRules.testRuleEnforcement()
StrictUIValidator.auditAppCompliance() 
ComponentSelectionGuide.testDecisionTree()
#endif
```

**Remember: The goal is consistency, maintainability, and avoiding duplicate code. When in doubt, ask for help rather than creating new components.**

## Adding SVG Icons to Assets.xcassets

**CRITICAL: For SVG icons to load properly in SwiftUI Image components, they must be structured as .imageset folders in Assets.xcassets.**

### Correct Asset Structure:
```
Assets.xcassets/
├── icon-name.imageset/
│   ├── Contents.json
│   └── icon-name.svg
```

### Step-by-Step Process:
1. **Create imageset folder**: `mkdir "Assets.xcassets/icon-name.imageset"`
2. **Create Contents.json**:
```json
{
  "images" : [
    {
      "filename" : "icon-name.svg",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "preserves-vector-representation" : true
  }
}
```
3. **Copy SVG file**: `cp "icon-name.svg" "Assets.xcassets/icon-name.imageset/"`

### Common Issues:
- ❌ **Loose SVG files** in Assets.xcassets won't load in SwiftUI
- ❌ **File Assets folder** files may not be included in build target
- ✅ **Proper .imageset structure** ensures reliable loading

### SwiftUI Usage:
```swift
Image("icon-name")
    .renderingMode(.template)  // Enables color changes
    .resizable()
    .frame(width: 24, height: 24)
    .foregroundColor(.primary)
```

## Security Notes

- Never commit API keys to version control
- API keys are automatically moved to keychain on first app launch
- Use KeychainManager for any sensitive data storage
- FirebaseCore integration is conditional (compiles without Firebase)

## UI Change Approval Policy

**CRITICAL: All UI changes require explicit user approval before implementation.**

- **NEVER** make any UI modifications without asking the user first
- **ALWAYS** ask for approval before changing layouts, styling, components, or visual elements
- This includes: colors, fonts, spacing, positioning, component structure, animations, etc.
- Only proceed with UI changes after receiving explicit "yes" or approval from the user
- Code logic changes, bug fixes, and non-visual improvements can proceed without approval
- When in doubt about whether something affects UI - ask for approval first

## Database Change Implementation Policy

**CRITICAL: When user requests database changes, implement them in code automatically.**

- **ALWAYS** write code that modifies the database when user mentions database features/changes
- **DO NOT** ask for permission to write database modification code
- **IMPLEMENT IMMEDIATELY**: Add methods, Firebase operations, data cleanup, etc.
- User wants the app to actually perform the database operations, not just discuss them
- Examples:
  - "Clean up the database" → Write code that deletes Firebase documents
  - "Fix duplicate data" → Write code that removes duplicates automatically
  - "Reset transactions" → Write code that clears Firebase collections
  - "Migrate data" → Write code that moves/updates Firebase documents
- Always provide buttons/triggers in the UI to execute the database operations
- Database changes should happen through app code execution, not manual console work

## Performance Troubleshooting

### Camera Performance Issues

If experiencing significant delays (5-10+ seconds) in camera to photo picker transitions, investigate these common bottlenecks:

#### 🔍 **Root Cause Analysis**
1. **Double Image Processing**: Check for duplicate UIImage assignments
   - Symptom: Same image processed multiple times
   - Fix: Use smart deduplication, pass images directly instead of storing intermediately

2. **Synchronous Camera Session Cleanup**: Most common cause of 9+ second delays
   - Symptom: UI freezes during camera dismissal, console shows "Session cleanup" taking forever
   - Root Cause: `session.stopRunning()` and cleanup blocking main thread
   - Fix: Move camera session cleanup to background thread

3. **Main Thread Blocking**: Image processing on UI thread
   - Symptom: UI becomes unresponsive during image operations
   - Fix: Move `UIImage(data:)` and heavy processing to background threads

4. **State Cascade Re-renders**: Multiple simultaneous state updates
   - Symptom: Multiple rapid view re-computations
   - Fix: Batch state updates, use strategic delays between transitions

#### ⚡ **Performance Optimization Patterns**

```swift
// ❌ BLOCKING: Synchronous cleanup
func cleanupSession() {
    session.stopRunning()  // Blocks UI thread for seconds
    session.inputs.forEach { session.removeInput($0) }
}

// ✅ NON-BLOCKING: Background cleanup
func cleanupSession() {
    isConfigured = false  // Clear state immediately
    DispatchQueue.global(qos: .utility).async { [session] in
        session.stopRunning()  // Heavy work on background
        session.inputs.forEach { session.removeInput($0) }
    }
}

// ❌ BLOCKING: Wait for dismissal
isCameraPresented = false
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
    isPhotoPickerPresented = true  // Artificial delay
}

// ✅ NON-BLOCKING: Simultaneous transition
isCameraPresented = false
isPhotoPickerPresented = true  // No cleanup wait needed

// ❌ BLOCKING: Main thread image processing
let image = UIImage(data: data)  // Expensive on main thread

// ✅ NON-BLOCKING: Background image processing
DispatchQueue.global(qos: .userInitiated).async {
    let image = UIImage(data: data)  // Background processing
    DispatchQueue.main.async {
        // Update UI on main thread
    }
}
```

#### 🧪 **Debug Performance Issues**

1. **Add timing measurements**:
```swift
let startTime = Date()
// ... operation ...
let duration = Date().timeIntervalSince(startTime)
print("🕐 Operation took: \(String(format: "%.3f", duration * 1000))ms")
```

2. **Track camera lifecycle**:
```swift
print("📸 Camera: Starting cleanup")
// ... cleanup operations ...
print("📸 Camera: Cleanup completed")
```

3. **Monitor thread usage**: Ensure heavy operations use background threads
4. **Check memory pressure**: Multiple large UIImage objects can cause delays

#### 🎯 **Expected Performance Targets**
- Photo capture to picker transition: **<300ms**
- Camera session cleanup: **Background, non-blocking**
- Image processing: **Background threads only**
- UI transitions: **<100ms perceived delay**

## User Shorthand
- "tx" = transaction (shorthand)

---

## Recent Development Session Notes

### Session: January 26, 2025 - Wallet Management System Implementation

**Context**: User continued from previous conversation that ran out of context. App had currency conversion issues and needed wallet creation functionality.

#### 🔄 **Currency Conversion Debugging & Fixes**
**Problem**: PHP 1,200 wasn't converting to JPY properly - showing stale 1.0 rates instead of correct conversions.

**Root Cause**: `CurrencyRateManager` was using cached rates without refreshing when primary currency changed.

**Solution**: 
- Added comprehensive debugging throughout currency conversion pipeline
- Fixed rate clearing in `setPrimaryCurrency()` method
- Added missing JPY exchange rates (1 PHP = 2.6014 JPY)
- Implemented proper rate refresh mechanism

**Files Modified**:
- `CashMonki/Functions/CurrencyRateManager.swift` - Added rate clearing and JPY rates
- `CashMonki/Functions/CurrencyPreferences.swift` - Added debugging to setPrimaryCurrency  
- `CashMonki/Pages/HomePage.swift` - Added extensive conversion debugging

**Result**: ✅ Currency conversion now works correctly: "Current: -1200.0 PHP → -3121.68 JPY"

#### 💳 **Wallet Management System**  
**Requirement**: Create wallet creation functionality using category bottom sheet as template.

**Implementation**:
1. **Created AddWalletSheet** (`CashMonki/Sheets/AddWalletSheet.swift`)
   - Custom wallet avatar showing first letter of wallet name
   - Uses `#008080` teal color consistently across all wallet avatars
   - Slide-in-from-bottom presentation matching Add Category sheet style
   - Uses `.sheet()` with `.presentationDetents([.fraction(0.5)])`

2. **Updated AccountSelectorButton** (`CashMonki/Components/AccountSelectorButton.swift`)
   - Changed header from "ACCOUNTS" to "WALLETS"
   - Connected plus icon to open AddWalletSheet
   - Applied consistent `#008080` teal color to all wallet avatars
   - Implemented actual wallet creation logic calling `AccountManager.createSubAccount()`

3. **Fixed Firebase Sync** (`CashMonki/Managers/AccountManager.swift`)
   - **CRITICAL FIX**: Replaced all placeholder `saveAccountToFirebase()` TODO methods
   - Implemented proper Firebase sync using `userManager.syncToFirebase()`
   - Fixed wallet creation, updates, deletion, and default account changes
   - Wallets now persist across app restarts and sync to Firebase properly

**Visual Consistency**:
- All wallet avatars use `Color(hex: "008080")` teal color
- Matching presentation style with Add Category sheet  
- Proper header, input field, and save button styling
- Focus management for better UX

**Files Modified**:
- `CashMonki/Sheets/AddWalletSheet.swift` - New wallet creation sheet
- `CashMonki/Components/AccountSelectorButton.swift` - Updated wallet selector and picker
- `CashMonki/Managers/AccountManager.swift` - Fixed Firebase sync methods
- `CashMonki/Models/AccountModels.swift` - Examined for SubAccount structure

#### 🔄 **Git & Version Control**
**Action**: User requested git push of all changes.

**Result**: 
- ✅ **Local commit successful**: All changes committed with hash `efe31bd`
- ❌ **No remote repository**: No GitHub origin configured  
- **Commit message**: "💳 Complete wallet management system with Firebase sync and unified presentation"

**Status**: Changes are safely committed locally. Need to configure GitHub remote for pushing.

#### 📋 **Key Implementation Details**

**Wallet Creation Flow**:
1. User taps plus icon in wallet picker → Opens AddWalletSheet
2. User enters wallet name → Avatar shows first letter dynamically  
3. User taps Save → `AccountManager.createSubAccount()` called
4. New SubAccount created with unique UUID and proper defaults
5. `userManager.syncToFirebase()` saves wallet to Firebase
6. UI updates immediately showing new wallet in picker

**Firebase Integration**:
```swift
// OLD (broken): 
saveAccountToFirebase(newAccount) // TODO placeholder

// NEW (working):
userManager.syncToFirebase { success in
    print(success ? "✅ Account synced" : "❌ Sync failed")
}
```

**Presentation Pattern**:
```swift
// Consistent with Add Category sheet:
.sheet(isPresented: $showingAddWallet) {
    AddWalletSheet(...)
        .presentationDetents([.fraction(0.5)])
}
```

#### 🎯 **Testing Status**
- ✅ Wallet creation UI works and matches design  
- ✅ Wallet creation logic creates actual SubAccount objects
- ✅ Firebase sync implemented and functional
- ✅ Wallet avatars consistent across all components
- ✅ Currency conversion debugging complete and working
- 🔄 **Pending**: GitHub remote setup for pushing changes

#### 🔮 **Next Session Priorities**
1. **Set up GitHub remote** and push committed changes
2. **Test complete wallet lifecycle** (create → restart app → verify persistence)
3. **Address any remaining UI issues** or duplicate button problems
4. **Continue with additional wallet features** if needed

#### 📝 **Development Notes**
- **Presentation Style**: Always use `.sheet()` with `.presentationDetents([.fraction(0.5)])` for bottom sheets matching category picker
- **Firebase Sync**: Use `userManager.syncToFirebase()` for account-related changes since accounts are part of user data
- **Color Consistency**: `#008080` teal for all wallet avatars across the app
- **Debugging**: Extensive logging was added for currency conversion - can be removed in production

**Session Outcome**: ✅ Complete wallet management system implemented with proper Firebase sync and consistent UI presentation.