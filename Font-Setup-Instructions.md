# Overused Grotesk Font Setup Instructions

## Step 1: Download Font Files ✅
Download the Overused Grotesk font family files (.ttf or .otf format):
- OverusedGrotesk-Roman.ttf ✅
- OverusedGrotesk-Medium.ttf ✅
- OverusedGrotesk-SemiBold.ttf ✅
- OverusedGrotesk-Bold.ttf ✅

## Step 2: Add Fonts to Xcode Project ✅
1. The font files are located in the `DesignSystem` folder ✅
2. If you need to add new fonts, drag and drop the font files into this folder
3. Make sure "Add to target" is checked for "Cashooya Playground"
4. Ensure "Copy items if needed" is selected

## Step 3: Font Registration ✅ UPDATED
Fonts are now registered in the main `Info.plist` file with the following entries:

```xml
<key>UIAppFonts</key>
<array>
    <string>DesignSystem/OverusedGrotesk-Roman.ttf</string>
    <string>DesignSystem/OverusedGrotesk-Medium.ttf</string>
    <string>DesignSystem/OverusedGrotesk-SemiBold.ttf</string>
    <string>DesignSystem/OverusedGrotesk-Bold.ttf</string>
</array>
```

## Step 4: Verify Font Names
Add this code to your app temporarily to print available fonts:

```swift
// Add this to your ContentView's onAppear to verify font names
for family in UIFont.familyNames.sorted() {
    print("Font Family: \(family)")
    for name in UIFont.fontNames(forFamilyName: family) {
        print("  Font Name: \(name)")
    }
}
```

## Step 5: Usage
After setup, use the fonts via the AppFonts struct:

```swift
Text("Hello World")
    .font(AppFonts.headline)

Text("Large Amount")
    .font(AppFonts.amountLarge)
```

Alternatively, use the direct font reference:

```swift
Text("Hello World")
    .font(.custom("OverusedGrotesk-SemiBold", size: 17))

Text("Body Text")
    .font(.custom("OverusedGrotesk-Roman", size: 16))
```

## Troubleshooting

If fonts aren't loading correctly:

1. Check that the font files are properly added to the DesignSystem folder
2. Verify that FontRegistration.plist contains the correct font file paths
3. Make sure the font names in your code match the actual font files
4. Clean and rebuild the project (Product > Clean Build Folder)
5. Run the font name verification code to see if fonts are registered correctly