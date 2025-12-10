#!/bin/bash

echo "🔥 Firebase Setup Verification"
echo "==============================="

# Check if GoogleService-Info.plist exists
if [ -f "CashMonki/GoogleService-Info.plist" ]; then
    echo "✅ GoogleService-Info.plist found"
    
    # Extract and display key configuration values
    echo ""
    echo "📋 Configuration Details:"
    
    PROJECT_ID=$(plutil -extract PROJECT_ID raw CashMonki/GoogleService-Info.plist 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "   Project ID: $PROJECT_ID"
    fi
    
    BUNDLE_ID=$(plutil -extract BUNDLE_ID raw CashMonki/GoogleService-Info.plist 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "   Bundle ID: $BUNDLE_ID"
        if [ "$BUNDLE_ID" = "Rosebud.CashMonki" ]; then
            echo "   ✅ Bundle ID matches project"
        else
            echo "   ❌ Bundle ID mismatch! Expected: Rosebud.CashMonki"
        fi
    fi
    
    echo ""
    echo "🎯 Next steps:"
    echo "   1. Make sure Authentication is enabled in Firebase Console"
    echo "   2. Enable Email/Password sign-in method"
    echo "   3. Test the registration again"
    
else
    echo "❌ GoogleService-Info.plist NOT FOUND"
    echo ""
    echo "📍 Expected location: CashMonki/GoogleService-Info.plist"
    echo ""
    echo "🚀 To fix this:"
    echo "   1. Go to https://console.firebase.google.com/"
    echo "   2. Create/select your Firebase project"
    echo "   3. Add iOS app with bundle ID: Rosebud.CashMonki"
    echo "   4. Download GoogleService-Info.plist"
    echo "   5. Place it at: $(pwd)/CashMonki/GoogleService-Info.plist"
fi

echo ""
echo "==============================="