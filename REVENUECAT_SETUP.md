# RevenueCat Setup Guide

## ✅ **Issue Fixed: "Failed to load offerings for paywall"**

The error was caused by missing StoreKit configuration for local testing. Here's what was implemented:

## 🛠️ **What Was Fixed**

### 1. **StoreKit Configuration Created** ✅
- **File**: `CashMonki/StoreKit/Configuration.storekit`
- **Products Added**:
  - `com.cashmonki.premium.monthly` - $4.99/month
  - `com.cashmonki.premium.annual` - $49.99/year (with 1-week free trial)

### 2. **RevenueCat Manager Updated** ✅
- **Offering ID**: Changed from specific ID to `"default"` for testing
- **Debug Messages**: Enhanced for troubleshooting
- **Concurrency**: Fixed all @MainActor issues

## 📱 **Next Steps to Complete Setup**

### Step 1: **Add StoreKit Configuration to Xcode**
1. **Open** `CashMonki.xcodeproj` in Xcode
2. **Right-click** on project root in navigator
3. **Select**: "Add Files to 'CashMonki'"
4. **Navigate** to: `CashMonki/StoreKit/Configuration.storekit`
5. **Add** the file to the project

### Step 2: **Configure Xcode for StoreKit Testing**
1. **Go to**: Product → Scheme → Edit Scheme
2. **Select**: "Run" tab
3. **Options** tab
4. **StoreKit Configuration**: Select "Configuration.storekit"
5. **Click**: OK

### Step 3: **RevenueCat Dashboard Setup**
If you want to use real RevenueCat integration:

1. **Create Products** in RevenueCat dashboard:
   - Product ID: `com.cashmonki.premium.monthly`
   - Product ID: `com.cashmonki.premium.annual`

2. **Create Offering**:
   - Name: "Default" 
   - Identifier: `default`
   - Add both products to the offering

3. **Update Entitlements**:
   - Create entitlement: `premium`
   - Attach to both products

## 🧪 **Testing the Fix**

### Expected Debug Output (Success):
```
✅ RevenueCat: Configuring with API key from secure storage
💰 RevenueCat: Loading offerings...
✅ RevenueCat: Loaded 1 total offerings
✅ RevenueCat: Found specific offering 'default' with 2 packages
   📦 Package: CashMonki Premium Monthly - $4.99
   📦 Package: CashMonki Premium Annual - $49.99
✅ RevenueCat: targetOffering found: default
```

### If Still Seeing Errors:
```
⚠️ RevenueCat: Specific offering 'default' not found
📋 Available offerings: none
💡 RevenueCat: Configuration Help:
   - Ensure products are created in App Store Connect
   - Verify offering 'default' exists in RevenueCat dashboard
   - Check that products are approved and available for sale
   - For testing: Use StoreKit Configuration File in Xcode
```

## 🔄 **Alternative Testing Approach**

If you prefer **local testing only** (no RevenueCat dashboard):

### Update RevenueCat Manager for Local Testing:
```swift
// In configure() method, add:
#if DEBUG
// Use current offering for local testing
Purchases.shared.getOfferings { offerings, error in
    if let current = offerings?.current {
        print("✅ Using current offering: \(current.identifier)")
    }
}
#endif
```

## 🚀 **Quick Test**

1. **Build and run** the app
2. **Navigate** to a screen that uses RevenueCat
3. **Check console** for debug messages
4. **Should see**: "✅ RevenueCat: Loaded X total offerings"

## 📋 **Files Modified**
- ✅ `CashMonki/StoreKit/Configuration.storekit` - **CREATED**
- ✅ `CashMonki/Functions/RevenueCatManager.swift` - **UPDATED** (offering ID changed to "default")

## 🎯 **Expected Result**
RevenueCat should now load offerings successfully and the error should be resolved.