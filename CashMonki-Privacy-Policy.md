# Privacy Policy for CashMonki

**Effective Date:** December 9, 2025  
**Last Updated:** December 9, 2025

## Introduction

CashMonki ("we," "our," or "us") is committed to protecting your privacy and personal information. This Privacy Policy explains how we collect, use, store, and protect your information when you use our iOS mobile application (the "App").

**Our Privacy Commitment:** Your financial data is sensitive, and we treat it with the highest level of security and respect. We use a privacy-first approach with local storage and minimal data sharing.

## Information We Collect

### 1. Account Information
- **Email address** - for user authentication and account management
- **Display name** - for personalization within the app
- **Authentication data** - securely managed through Firebase Authentication

### 2. Financial Transaction Data
- **Receipt images** - photos you capture or select from your device's photo library
- **Transaction details** - merchant name, amount, date, category, payment method extracted from receipts
- **Categories and subcategories** - transaction categorization data you create or select
- **Transaction notes** - personal notes you add to transactions
- **Wallet/account information** - multiple wallet setup and organization
- **Currency preferences** - primary and secondary currency settings for multi-currency support

### 3. Usage Analytics (Receipt Processing)
- **Daily usage counts** - number of receipt scans to enforce free tier limits (3 per day)
- **Receipt processing metadata** - success/failure rates for AI analysis (no image content stored)
- **Feature usage patterns** - which app features you use most frequently

### 4. Device Information and Permissions
- **Camera access** - required for receipt scanning functionality
- **Photo library access** - required for selecting existing receipt images from your device
- **Device storage** - for local data persistence using iOS secure storage (SwiftData)
- **Keychain storage** - for secure API key storage

### 5. Subscription and Billing Data
- **Subscription status** - managed through RevenueCat and Apple's App Store
- **Purchase history** - handled by Apple's in-app purchase system
- **Payment information** - processed entirely by Apple (we never see your payment details)

## How We Use Your Information

### Primary App Functions
- **Receipt Analysis** - Process receipt images using AI to extract transaction details
- **Expense Tracking** - Store and organize your financial transactions locally on your device
- **Analytics and Insights** - Generate spending patterns, charts, and financial summaries
- **Multi-Currency Support** - Convert and display amounts in your preferred currencies
- **Account Organization** - Manage multiple wallets and categorize transactions

### User Experience
- **Personalization** - Customize the app interface with your name and preferences
- **Sync Across Sessions** - Maintain your data when you reinstall the app or sign in on new devices
- **Usage Limits** - Track daily receipt scans for free tier management (3 scans per day for free users)

### Service Operations
- **Authentication** - Verify your identity and maintain secure access to your account
- **Customer Support** - Provide assistance when you contact us for help
- **App Improvement** - Analyze usage patterns to improve features and performance

## Data Storage and Security

### Local-First Storage
- **Primary Storage** - All transaction data is stored locally on your device using iOS secure storage (SwiftData)
- **Keychain Protection** - API keys and sensitive authentication data stored in iOS Keychain
- **Device Control** - You have complete control over your data deletion and export

### Cloud Backup (Optional)
- **Firebase Firestore** - Optional cloud backup for data sync across devices
- **User Control** - Cloud sync can be enabled/disabled in app settings
- **Encryption** - All cloud data is encrypted in transit and at rest

### Security Measures
- **iOS Encryption** - All local data uses iOS standard encryption
- **Secure Transmission** - All network communications use HTTPS/TLS encryption
- **API Key Security** - Third-party API keys stored securely in device keychain
- **No Payment Data Storage** - Payment information handled entirely by Apple's secure systems

## Third-Party Services

### AI Receipt Processing (OpenRouter)
- **Purpose** - Analyze receipt images to extract transaction details (merchant, amount, date, items, category)
- **Data Shared** - Receipt images are temporarily transmitted via secure HTTPS connection for analysis
- **Processing Method** - Images processed through our secure backend service (Firebase Functions) before being sent to AI provider
- **Data Retention** - Images are processed immediately and not permanently stored by the service
- **Privacy** - No personally identifiable information is sent, only receipt content
- **Security** - All API communications are encrypted and routed through our secure backend

### Authentication (Firebase Auth by Google)
- **Purpose** - Secure user authentication and account management
- **Data Shared** - Email address and authentication tokens
- **Privacy Policy** - [Google's Privacy Policy](https://policies.google.com/privacy)

### Cloud Storage (Firebase Firestore by Google) - Optional
- **Purpose** - Optional backup and sync of transaction data across devices
- **Data Shared** - Transaction details, categories, and user preferences (only when enabled)
- **Privacy Policy** - [Google's Privacy Policy](https://policies.google.com/privacy)

### Subscription Management (RevenueCat)
- **Purpose** - Manage premium subscriptions and in-app purchases
- **Data Shared** - Subscription status and anonymous user identifiers
- **No Financial Data** - Payment processing handled entirely by Apple
- **Privacy Policy** - [RevenueCat Privacy Policy](https://www.revenuecat.com/privacy)

### Currency Exchange Rates
- **Purpose** - Provide real-time currency conversion for international transactions
- **Data Shared** - Currency symbols and conversion requests (no personal data)
- **No User Data** - Only anonymous currency rate requests

## Data Retention

### Transaction Data
- **Local Storage** - Remains on your device until you delete it
- **Cloud Backup** - Retained as long as your account exists (can be deleted anytime)
- **Account Deletion** - All data permanently deleted when you delete your account

### Receipt Images
- **AI Processing** - Images processed immediately and not stored by third-party services
- **Local Storage** - Receipt images stored locally on your device as part of transaction records
- **User Control** - You can delete individual transactions with their receipt images anytime

### Usage Analytics
- **Daily Usage Counts** - Reset every 24 hours for free tier management
- **Aggregate Analytics** - Anonymized usage patterns retained for app improvement

## Your Privacy Rights

### Data Access and Control
- **View Data** - Access all your stored transaction data within the app
- **Edit Data** - Modify or update transaction details, categories, and notes
- **Delete Data** - Remove individual transactions or clear all data
- **Export Data** - Generate reports of your financial data (premium feature)

### Account Management
- **Account Deletion** - Permanently delete your account and all associated data
- **Data Download** - Request a copy of your data
- **Sync Control** - Enable/disable cloud backup and sync features

### Privacy Preferences
- **Disable Analytics** - Opt out of usage analytics in app settings
- **Camera Permissions** - Grant or revoke camera access (affects receipt scanning)
- **Photo Library Permissions** - Control access to your photo library

## Children's Privacy

Our app is not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13. If we become aware that we have collected personal information from a child under 13, we will take steps to delete such information.

## International Users

If you are using our app outside the United States, please note that your data may be processed in countries where our third-party services operate (primarily United States). We ensure appropriate safeguards are in place for international data transfers in compliance with applicable privacy laws.

## Changes to This Policy

We may update this Privacy Policy from time to time to reflect changes in our practices or legal requirements. We will notify you of any material changes by:
- Posting the new Privacy Policy in the app
- Updating the "Last Updated" date
- Providing in-app notifications for significant changes
- Sending email notifications for major policy changes (if you've provided email consent)

## Financial Data Security

We understand that financial data is highly sensitive. Our specific commitments:

### What We Never Do
- **Never sell your financial data** to third parties
- **Never share transaction details** for advertising purposes
- **Never track your spending** for marketing to other companies
- **Never store payment information** (handled by Apple's secure systems)

### Our Security Practices
- **Local-first storage** keeps your data on your device
- **Minimal data sharing** only for essential services (receipt analysis)
- **Encrypted transmission** for all network communications
- **Regular security updates** and monitoring

## Contact Us

If you have questions about this Privacy Policy or our data practices, please contact us:

**Email:** dante@rosebudstudio.co  
**Privacy:** dante@rosebudstudio.co  
**Support:** Available through the app's Settings > Help & Support  
**Developer:** Dante Cardines III - Rosebud Studio

## Legal Compliance

This Privacy Policy complies with:
- **Apple App Store Guidelines** for iOS applications
- **California Consumer Privacy Act (CCPA)** where applicable
- **General Data Protection Regulation (GDPR)** for EU users
- **iOS Privacy Requirements** and best practices

## Data Protection Summary

| Data Type | Storage Location | Third-Party Sharing | User Control |
|-----------|------------------|-------------------|--------------|
| Transactions | Local Device + Optional Cloud | Never shared | Full control |
| Receipt Images | Local Device | Temporary AI processing only | Full control |
| Authentication | Firebase (Google) | Only for login | Account deletion |
| Subscription | RevenueCat + Apple | Anonymous status only | Cancellation anytime |
| Usage Analytics | Local Device | Anonymized patterns only | Opt-out available |

---

**By using CashMonki, you acknowledge that you have read and understood this Privacy Policy and agree to the collection and use of your information as described herein.**

---

*This privacy policy is specifically tailored for CashMonki's current features including receipt scanning, transaction management, multi-currency support, wallet organization, and premium subscriptions. Last reviewed by legal counsel on [Date].*