# Adding Lottie to CashMonki

## Step 1: Add Lottie Package Dependency

1. Open `CashMonki.xcodeproj` in Xcode
2. Select your project in the navigator
3. Go to "Package Dependencies" tab
4. Click the "+" button
5. Add this URL: `https://github.com/airbnb/lottie-ios`
6. Choose "Up to Next Major Version" with version 4.0.0+
7. Click "Add Package"
8. Select "Lottie" and add it to your CashMonki target

## Step 2: Use Lottie in SwiftUI

I've created a LottieView wrapper and example usage below.

## Common Lottie Animation Use Cases for CashMonki:

1. **Loading animations** during receipt analysis
2. **Success animations** when transactions are saved
3. **Onboarding animations** for user guidance  
4. **Empty state animations** when no transactions exist
5. **Pull-to-refresh animations** 
6. **Error state animations** for failed operations

## Next Steps:

1. Add the package dependency (above)
2. Download some Lottie animations from lottiefiles.com
3. Add them to your Assets.xcassets
4. Use the LottieView component I'm creating below