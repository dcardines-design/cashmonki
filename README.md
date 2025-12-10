# Cashooya Playground

An iOS expense tracking app built with SwiftUI that features AI-powered receipt scanning, transaction management, and a custom design system.

## Features

### 🧾 AI Receipt Scanning
- Photo capture and analysis using OpenRouter API
- Automatic extraction of merchant, amount, date, and category
- GPT-4 Vision integration for accurate receipt processing
- Smart categorization with confidence scoring

### 💰 Transaction Management
- Add, edit, and organize transactions
- Category-based organization with emoji icons
- Multi-currency support with currency ticker
- Date-based filtering and organization
- Receipt image attachment and storage

### 🎨 Custom Design System
- **Typography**: Overused Grotesk font family with semantic scales
- **Colors**: Consistent brand colors with semantic naming (`AppColors`)
- **Components**: Reusable UI components with proper fallbacks
- **Input Fields**: Unified `AppInputField` with currency ticker support
- **Buttons**: 5-tier button hierarchy (Primary, Secondary, Tertiary, Ghost, Text)
- **Templates**: Overlay templates for consistent modal presentations

### 🔒 Security & Privacy
- Secure API key storage using iOS Keychain
- Local data persistence with SwiftData
- Optional Firebase integration for cloud sync

## Architecture

### Core Components

- **`Cashooya_PlaygroundApp.swift`** - App entry point with SwiftData container
- **`ContentView.swift`** - Main tab view (Home, Receipts, Settings)
- **`Txn`** - Transaction model with receipt images and categorization

### AI & Processing

- **`AIReceiptAnalyzer.swift`** - OpenRouter API integration for receipt analysis
- **`ReceiptAnalysis`** - Data structure for analyzed receipt information
- **Image processing** - Base64 encoding and resizing for API efficiency

### Design System

- **`AppColors.swift`** - Brand colors with semantic naming
- **`AppFonts.swift`** - Overused Grotesk font family with fallbacks
- **`AppButton.swift`** - 5-tier button hierarchy
- **`AppInputField.swift`** - Unified input component with currency support
- **`OverlayTemplate.swift`** - Reusable modal/overlay templates

### Key Pages & Sheets

- **`HomePage.swift`** - Dashboard with spending analytics
- **`ReceiptsPage.swift`** - Receipt gallery and management
- **`SettingsPage.swift`** - App configuration and preferences
- **`ReceiptConfirmationSheet.swift`** - Review and edit scanned receipts
- **`AddTransactionSheet.swift`** - Manual transaction entry
- **`EditTransactionSheet.swift`** - Transaction modification

## Setup & Installation

### Prerequisites

- Xcode 16.0+
- iOS 18.0+ deployment target
- OpenRouter API key for receipt scanning

### Font Setup

The app uses the **Overused Grotesk** font family. To set up fonts:

1. **Font files** are located in `Cashooya Playground/DesignSystem/`
2. **Verify target membership** - Ensure all `.ttf` files are included in the "Cashooya Playground" target
3. **Font registration** - Fonts are registered in `Cashooya-Playground-Info.plist`
4. **Fallback system** - App gracefully falls back to system fonts if custom fonts fail

### API Configuration

1. **Get OpenRouter API key** from [openrouter.ai](https://openrouter.ai)
2. **Set environment variable**: `OPENROUTER_API_KEY=your_key_here`
3. **Or configure in code**: Update `Config.swift` (will be moved to keychain automatically)

### Building

```bash
# Open project
open "Cashooya Playground.xcodeproj"

# Build and run in Xcode
# No additional build steps required
```

## Design System Usage

### Colors
```swift
// Use semantic color names
Text("Hello")
    .foregroundColor(AppColors.foregroundPrimary)
    .background(AppColors.surfacePrimary)
```

### Typography
```swift
// Use AppFonts with fallback system
Text("Title")
    .font(AppFonts.headline)

// Or direct usage
Text("Custom")
    .font(AppFonts.overusedGroteskSemiBold(size: 20))
```

### Input Fields
```swift
// Amount field with currency ticker
AppInputField.amount(
    text: $amount,
    selectedCurrency: $currency,
    onCurrencyTap: { /* handle currency selection */ }
)

// Other field types
AppInputField.merchant(text: $merchant)
AppInputField.date(dateValue: $date)
AppInputField.category(selectedCategory: $category)
```

### Buttons
```swift
// Button hierarchy
AppButton.primary("Save") { /* action */ }
AppButton.secondary("Cancel") { /* action */ }
AppButton.tertiary("More", leftIcon: "ellipsis") { /* action */ }
```

### Overlay Templates
```swift
// Full screen overlays
FullScreenOverlayTemplate(
    title: "Edit Transaction",
    confirmTitle: "Save",
    isConfirmEnabled: canSave,
    onBack: { dismiss() },
    onConfirm: { save() }
) {
    // Your content here
}
```

## Project Structure

```
Cashooya Playground/
├── Components/           # Reusable UI components
│   ├── AppButton.swift
│   ├── AppInputField.swift
│   └── UnifiedTransactionDisplay.swift
├── DesignSystem/        # Design system components
│   ├── AppColors.swift
│   ├── FontManager.swift
│   ├── OverlayTemplate.swift
│   └── *.ttf            # Font files
├── Functions/           # Business logic and utilities
│   ├── AIReceiptAnalyzer.swift
│   ├── Config.swift
│   ├── KeychainManager.swift
│   └── Models.swift
├── Pages/              # Main app pages
│   ├── HomePage.swift
│   ├── ReceiptsPage.swift
│   └── SettingsPage.swift
├── Sheets/             # Modal presentations
│   ├── AddTransactionSheet.swift
│   ├── EditTransactionSheet.swift
│   └── ReceiptConfirmationSheet.swift
└── Assets.xcassets/    # App icons and images
```

## Development

### Code Style
- **No comments** unless explicitly needed
- **Semantic naming** for colors, fonts, and components
- **SwiftUI best practices** with proper state management
- **Fallback systems** for fonts and network calls

### Testing
- Unit tests in `Cashooya PlaygroundTests/`
- UI tests in `Cashooya PlaygroundUITests/`
- Run tests: `Product > Test` in Xcode

### Font Debugging
Font loading status is logged in debug builds:
```
✅ Using font: OverusedGrotesk-Medium
❌ Overused Grotesk Bold not found, using system fallback
```

### API Integration
- **OpenRouter** for AI receipt analysis
- **Conditional Firebase** integration (compiles without Firebase)
- **Keychain storage** for sensitive data

## Contributing

1. **Follow existing patterns** and design system guidelines
2. **Use AppFonts and AppColors** for consistency
3. **Add proper fallbacks** for network calls and font loading
4. **Test on multiple device sizes** and orientations
5. **Maintain semantic naming** conventions

## License

Private project - All rights reserved.

## Support

For issues or questions:
- Check font setup in `Font-Setup-Instructions.md`
- Review `CLAUDE.md` for development guidelines
- Verify API key configuration in `Config.swift`