# Recommended Lottie Animations for CashMonki

## Where to Download
Go to [LottieFiles.com](https://lottiefiles.com) and download these animations (search for these terms):

## 🧾 Receipt Processing
1. **"receipt-scanning"** - Search: "receipt scan", "document scan", "paper scan"
2. **"checkmark-success"** - Search: "checkmark", "success", "tick mark"
3. **"error-warning"** - Search: "error", "warning", "x mark", "failed"

## 💰 Money & Transactions
4. **"money-flow"** - Search: "money", "cash flow", "payment"
5. **"coins-drop"** - Search: "coins", "money drop", "falling coins"
6. **"empty-wallet"** - Search: "empty wallet", "no money", "broke"

## 📱 App States
7. **"loading-dots"** - Search: "loading", "dots", "spinner"
8. **"pull-refresh"** - Search: "refresh", "reload", "sync"
9. **"welcome-wave"** - Search: "welcome", "hello", "greeting"
10. **"setup-complete"** - Search: "complete", "done", "finished"

## 📁 How to Add to Project

1. Download .json files from LottieFiles
2. In Xcode, open Assets.xcassets
3. Right-click → "New Data Set"
4. Name it (e.g., "receipt-scanning")
5. Drag your .json file into the data set
6. Use the name in your code: `LottieView(animationName: "receipt-scanning")`

## 🔧 File Naming Convention

Use these exact names when adding to Assets.xcassets:
- `receipt-scanning`
- `checkmark-success`
- `error-warning`
- `money-flow`
- `coins-drop`
- `empty-wallet`
- `loading-dots`
- `pull-refresh`
- `welcome-wave`
- `setup-complete`

## 🎯 Usage Examples

After adding animations, you can use them like:

```swift
// In HomePage during receipt analysis
if isAnalyzingReceipt {
    LottieAnimations.receiptAnalyzing()
}

// In empty states
if transactions.isEmpty {
    LottieAnimations.emptyTransactions()
}

// After successful transaction save
LottieAnimations.transactionSuccess()
```

## 📏 Recommended Sizes
- **Loading indicators**: 60x60 to 100x100
- **Success/Error feedback**: 80x80 to 120x120  
- **Empty states**: 150x150 to 250x200
- **Onboarding**: 200x200 to 300x250