# Firebase New Project Setup - Action Required

## ✅ **What I've Fixed:**

### **1. Google Sign-In URL Scheme Updated:**
- **Old:** `com.googleusercontent.apps.532055465059-6ekfmiahkt0l4m1dqcjgc1cqjr0nm49r`
- **New:** `com.googleusercontent.apps.817492386994-458ac9b231c9f8631095ab`

### **2. Bundle ID Alignment:**
- **App Bundle ID:** `com.dante.cashmonki` ✅
- **Firebase Project:** `cashmonki-app` ✅

## ⚠️ **What YOU Need to Do in Firebase Console:**

### **1. Create Firestore Database:**
**Error:** `The database (default) does not exist for project cashmonki-app`

**Fix Required:**
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your `cashmonki-app` project
3. Go to **Firestore Database** in the left menu
4. Click **"Create database"**
5. Select **"Start in production mode"** (or test mode for now)
6. Choose a location (preferably close to your users)
7. Click **"Done"**

### **2. Enable Google Sign-In:**
1. In Firebase Console → **Authentication**
2. Go to **"Sign-in method"** tab
3. Click **"Google"** provider
4. **Enable** the toggle
5. Set support email (your email)
6. Click **"Save"**

### **3. Get Complete GoogleService-Info.plist:**
**Current file is missing some keys!**

**Fix Required:**
1. In Firebase Console → **Project Settings** (gear icon)
2. Go to **"Your apps"** section
3. Find your iOS app (`com.dante.cashmonki`)
4. Click **"GoogleService-Info.plist"** download
5. **Replace** the current file with the complete one

The complete file should have these keys:
```
- CLIENT_ID
- REVERSED_CLIENT_ID  
- GOOGLE_APP_ID
- API_KEY
- GCM_SENDER_ID
- PROJECT_ID
- STORAGE_BUCKET
- BUNDLE_ID
```

## 🔧 **RevenueCat API Key Issue:**

**Error:** `Invalid API Key` for RevenueCat

**The RevenueCat keys in your environment might not match the new Firebase project.**

**Options:**
1. **Use existing RevenueCat project** (if you have one)
2. **Create new RevenueCat project** for the new app
3. **Temporarily disable RevenueCat** for testing

## 🎯 **Priority Actions:**

### **High Priority (Required for app to work):**
1. ✅ **Create Firestore database** (Firebase Console)
2. ✅ **Enable Google Sign-In** (Firebase Console)  
3. ✅ **Download complete GoogleService-Info.plist**

### **Medium Priority (For subscriptions):**
4. **Fix RevenueCat API keys** or create new project

## 🚀 **After You Complete Firebase Setup:**

1. **Replace GoogleService-Info.plist** with complete version
2. **Test Google Sign-In** - should work properly
3. **Test data storage** - Firestore should save transactions
4. **Test authentication** - users should be able to sign in

## ⚡ **Quick Test:**

After setup, the error messages should disappear:
- ❌ `Authentication Error - Google Sign-In configuration error`
- ❌ `The database (default) does not exist`
- ❌ `Could not reach Cloud Firestore backend`

Let me know when you've completed the Firebase setup and I can help test everything!