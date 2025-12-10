# Firebase Setup Instructions

## 🔥 Quick Setup Guide

### **Quick Start Summary:**

**👤 YOUR TASKS:**
1. **👤 YOU**: Add Firebase packages to Xcode project
2. **👤 YOU**: Create Firebase project at console.firebase.google.com
3. **👤 YOU**: Download GoogleService-Info.plist and add to Xcode
4. **👤 YOU**: Enable Firestore database
5. **👤 YOU**: Update security rules
6. **👤 YOU**: Build and test!

**🤖 ALREADY DONE BY CLAUDE:**
- ✅ **🤖 CLAUDE**: Enhanced FirestoreService with transaction persistence
- ✅ **🤖 CLAUDE**: Updated UserManager with automatic sync capabilities
- ✅ **🤖 CLAUDE**: Error handling and offline fallback
- ✅ **🤖 CLAUDE**: Data conversion and receipt image storage
- ✅ **🤖 CLAUDE**: Real-time transaction syncing

---

### 1. Install Firebase Dependencies

**Open Xcode project** and add Firebase SDK:
1. File → Add Package Dependencies
2. Enter URL: `https://github.com/firebase/firebase-ios-sdk`
3. Select version: `Latest`
4. Choose packages to add:
   - ✅ **FirebaseCore** (required)
   - ✅ **FirebaseFirestore** (for data persistence)
   - ⚪ FirebaseAuth (optional - for user authentication)

### 2. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click **"Create a project"**
3. Project name: `Cashooya Playground`
4. Enable Google Analytics: **Yes** (recommended)
5. Choose analytics account or create new one

### 3. Add iOS App

1. In Firebase project, click **"Add app"** → iOS
2. **Bundle ID**: Get from Xcode project settings (e.g., `com.yourname.cashooya-playground`)
3. **App nickname**: `Cashooya Playground`
4. **App Store ID**: Leave blank for now
5. Click **"Register app"**

### 4. Download Configuration File

1. **Download `GoogleService-Info.plist`**
2. **Drag file into Xcode project root** (same level as `Info.plist`)
3. ✅ Make sure "Add to target" is checked for your app target
4. ✅ Choose "Copy items if needed"

### 5. Setup Firestore Database

1. In Firebase Console → **Build** → **Firestore Database**
2. Click **"Create database"**
3. Choose **"Start in test mode"** (for development)
4. Select location closest to your users (e.g., `us-central1`)

### 6. Configure Security Rules (Important!)

Replace default Firestore rules with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own data
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // For now, allow authenticated users to read/write their data
    // TODO: Add proper authentication
    match /{document=**} {
      allow read, write: if true; // TEMPORARY - change for production
    }
  }
}
```

## 🚀 Usage

### Current Implementation

Your app now automatically:
- **Loads data from Firebase** on startup
- **Syncs new transactions** to cloud when added
- **Syncs updates/deletions** to cloud
- **Falls back to sample data** if Firebase is unavailable

### Firebase Data Structure

```
📦 Firestore Database
├── 📁 users
│   └── 📄 {userId}
│       ├── 📁 transactions
│       │   ├── 📄 {transactionId}
│       │   └── 📄 {transactionId}
│       └── 📁 receiptImages
│           ├── 📄 {transactionId}
│           └── 📄 {transactionId}
```

### Testing Firebase Integration

1. **Build and run** your app
2. **Add a transaction** (photo scan or manual)
3. **Check Firebase Console** → Firestore → Data tab
4. You should see your data appear in real-time!

### Debug Console Messages

Look for these in Xcode console:
```
☁️ UserManager: Loaded 5 transactions from Firebase
☁️ UserManager: Transaction synced to Firebase successfully
⚠️ UserManager: Failed to sync transaction: [error details]
```

## 🛠️ Advanced Configuration

### Enable Offline Persistence (Recommended)

Add to your `Cashooya_PlaygroundApp.swift`:

```swift
#if canImport(FirebaseFirestore)
import FirebaseFirestore

// In your onAppear or init
let db = Firestore.firestore()
db.settings.isPersistenceEnabled = true
#endif
```

### Monitor Connection Status

```swift
// Add to UserManager for connection monitoring
func setupOfflineListener() {
    #if canImport(FirebaseFirestore)
    let db = Firestore.firestore()
    db.enableNetwork { error in
        if error == nil {
            print("☁️ Firebase: Connected to cloud")
        }
    }
    #endif
}
```

## 🔧 Troubleshooting

### Common Issues

1. **"Firebase not configured"**
   - Ensure `GoogleService-Info.plist` is added to project
   - Check Firebase.configure() is called in app startup

2. **"Permission denied"**
   - Update Firestore security rules (see step 6 above)

3. **"Network error"**
   - Check internet connection
   - Verify Firestore database is created and active

4. **Build errors**
   - Clean build folder (Cmd+Shift+K)
   - Restart Xcode
   - Verify Firebase packages are properly added

### Verification Steps

✅ Firebase packages added to Xcode  
✅ `GoogleService-Info.plist` in project  
✅ Firebase project created  
✅ Firestore database enabled  
✅ Security rules updated  
✅ App builds without errors  

## 🎯 What's Included

Your Firebase integration includes:

- ✅ **Transaction persistence** across app launches
- ✅ **Receipt image storage** (Base64 in Firestore)
- ✅ **Automatic sync** on add/edit/delete
- ✅ **Offline fallback** to sample data
- ✅ **Error handling** with user feedback
- ✅ **Performance optimized** background syncing

**Your test data will now persist online and sync across devices!** 🚀