# 🚀 Deploy Firebase Backend - Step by Step

## 📋 Prerequisites
✅ Firebase Functions code built successfully  
✅ Project ID: `cashmonki-app`  
✅ API Keys available in environment  

## 🔑 Step 1: Firebase Login
You need to authenticate with Firebase manually:

```bash
cd /Users/DGC/Desktop/cashooya-playground/firebase-functions
npx firebase login
```

This will:
1. Open a browser window  
2. Ask you to sign into your Google/Firebase account
3. Grant permissions to Firebase CLI

## ⚙️ Step 2: Set Environment Variables (Optional)
If you want to use Firebase's config system:

```bash
npx firebase functions:config:set \
  openrouter.api_key="[YOUR_OPENROUTER_KEY]" \
  revenuecat.api_key="[YOUR_REVENUECAT_KEY]" \
  revenuecat.test_api_key="[YOUR_REVENUECAT_TEST_KEY]"
```

## 🚀 Step 3: Deploy Functions
```bash
npx firebase deploy --only functions
```

This will:
- Upload your built functions to Firebase
- Configure the endpoints
- Provide you with the live URLs

## 🌐 Step 4: Update iOS App URLs
After deployment, Firebase will give you URLs like:
```
https://us-central1-cashmonki-app.cloudfunctions.net/api
```

Update the iOS backend service URL to use this.

## 🎯 Step 5: Test Deployment
Test your endpoints:

```bash
# Health check (no auth needed)
curl https://us-central1-cashmonki-app.cloudfunctions.net/api/api/health

# Should return:
# {"status":"healthy","timestamp":"2024-01-15T10:30:00.000Z","version":"1.0.0"}
```

## 🔧 Alternative: Local Testing First
If you want to test locally before deploying:

```bash
# Start local emulator
npm run serve

# Test locally at:
# http://localhost:5001/cashmonki-app/us-central1/api/api/health
```

## 📱 iOS App Integration
Once deployed, your iOS app will automatically use the backend when:
1. User is authenticated with Firebase
2. Backend functions are live
3. API endpoints are accessible

The app will fall back to direct API calls if the backend is unavailable.

## 🚨 Troubleshooting

### Authentication Issues
If deployment fails with auth errors:
1. Run `npx firebase logout`
2. Run `npx firebase login` again
3. Make sure you're logged into the correct Google account

### Permission Issues  
Make sure your Google account has:
- Owner or Editor role on the `cashmonki-app` Firebase project
- Billing enabled (required for Functions)

### Environment Variables
The backend will look for API keys in this order:
1. `process.env.OPENROUTER_API_KEY` / `process.env.REVENUECAT_API_KEY`
2. Firebase Functions config (if set in Step 2)

## 💰 Billing Note
Firebase Functions requires a billing account, but includes:
- **2M free invocations per month**
- **400,000 GB-seconds free compute**

Your usage should easily stay within the free tier.

## ✅ Success Indicators
After successful deployment, you should see:
```
✔ Deploy complete!

Functions deployed:
  api(us-central1)
    https://us-central1-cashmonki-app.cloudfunctions.net/api
```

Your backend is now live and secure! 🎉

## 🔄 Future Updates
To update the backend:
1. Make code changes
2. Run `npm run build`  
3. Run `npx firebase deploy --only functions`

---
**Ready to deploy? Run the commands above in Terminal!** 🚀