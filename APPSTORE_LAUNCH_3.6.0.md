# App Store launch pack — Cashmonki 3.6.0 (build 3)

Apple ID 6755343516 · Bundle `com.dante.cashmonki` · Live version 3.5.2
Categories: Finance (primary) / Productivity (secondary) — keep as is.

> Name, subtitle, category and privacy-policy URL only take effect with a NEW version. 3.6.0 is the vehicle. Everything else (promo text, keywords are version-scoped too; promo text is editable anytime).

---

## 1. Localizable information (English U.S.)

### App name — 29/30
```
Cashmonki: AI Expense Tracker
```
Why change from "Cashmonki: Budget & Expense": "AI" and "Expense Tracker" are the two highest-volume terms the app actually earns. "Budget" moves to subtitle/keywords, so nothing is lost.

Keep-current option if you don't want to risk the ranking reset: leave `Cashmonki: Budget & Expense`, and take only the subtitle change below.

### Subtitle — 27/30
```
AI receipt scanner & budget
```
Alternates: `Scan receipts, track budgets` (28) · `Snap receipts, AI does rest` (27)

Current subtitle "Track Income, Bills & Spending" spends all 30 chars on generic terms and never says AI — the one thing competitors don't have.

### Promotional text — 161/170 (editable without a new version; use for campaigns)
```
New: Ask — chat with your money. Ask "how much on food last month?" and get real numbers, charts, and one-tap transactions. Plus faster launch and steadier sync.
```

### Keywords — 100/100 (no spaces after commas; never repeat name/subtitle words)
```
spending,money,bills,subscription,finance,tracker,wallet,recurring,budgeting,cost,split,save,scan
```
Deliberately excluded (already in name/subtitle, Apple indexes those): ai, receipt, expense, budget, cashmonki. Do not add "free" or plural forms — Apple matches stems.

---

## 2. Description

```
Snap a receipt. Cashmonki's AI reads it and files it. That's the whole job.

No more typing merchant names, hunting for amounts, or promising yourself you'll catch up on Sunday.

AI THAT ACTUALLY DOES THE WORK
• Scan a receipt — merchant, amount, date, category and line items are extracted for you
• Ask: chat with your own money. "How much did I spend on food last month?" gets a real answer, a real table, a real chart — built from your transactions, not guesses
• Ask can also draft a transaction from a sentence. You tap Confirm, it saves. Nothing is written without you
• Roast My Receipt: let the AI have a go at your spending. You have been warned

MONEY YOU CAN SEE
• Budgets per category, with live progress as you spend
• Recurring transactions and subscriptions on a timeline, so renewals stop ambushing you
• Income vs expense split, pie breakdowns, and month-over-month comparison
• 350+ categories with icons, plus your own custom categories and subcategories

BUILT FOR PEOPLE WHO CROSS BORDERS
• Multi-currency with live exchange rates
• Show a second currency alongside your main one — handy for expats, travellers and remote workers
• Currency suggested from where you are

WALLETS, NOT ONE BIG PILE
• Separate wallets for cash, card, business or a side project
• Every transaction knows which wallet it belongs to

STAYS OUT OF YOUR WAY
• Reminders that skip the days you already logged
• Renewal reminders before a subscription bills you
• Works offline, syncs when you're back

SHIP-WHAT-YOU-ASK
Post a feature request in the app, vote on other people's, watch the status change. A lot of what's in this release started there.

FREE VS PRO
Free: 3 receipt scans a day, 10 Ask messages a day, and every tracking feature — budgets, wallets, recurring, multi-currency.
Pro: unlimited receipt scans, unlimited Ask, unlimited subscriptions tracked.

Pro is an auto-renewing subscription. Payment is charged to your Apple ID at confirmation of purchase. It renews automatically unless cancelled at least 24 hours before the end of the current period; your account is charged for renewal within 24 hours prior to the end of the period. Manage or cancel in your Apple ID Account Settings after purchase.

Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: <YOUR_PRIVACY_POLICY_URL>
```

Two things I deliberately did **not** write, because they are not true of this build:
- "Your financial data never leaves your device" — it syncs to Firebase, and receipt images are sent to OpenRouter for analysis. Claiming otherwise contradicts your privacy labels and is a review-rejection risk.
- "Bank-level encryption" — unverifiable marketing claim, and Finance apps get looked at harder for it.

The old `CashMonki_AppStore_Optimization.md` contains both. Don't copy from it.

---

## 3. What's New (3.6.0)

```
• Faster, more reliable launch — fixed a hang that could leave the app on a blank screen
• Fixed onboarding restarting for accounts that had already finished it
• Steadier sync, with new guardrails so your transactions can't be lost during a sync
• New home card: save your data to the cloud in one tap
• Category suggestions while adding a transaction
```

Confirm the last two shipped in this build before submitting — the sync card is in the uncommitted working tree as of the last savepoint.

---

## 4. Screenshots — 6.9" and 6.5" required, plus 13" iPad if you keep iPad in the listing

Order matters more than art; the first two are ~80% of the conversion.

| # | Screen | Caption (short, big type) |
|---|---|---|
| 1 | Receipt scan → filled transaction | Snap it. AI files it. |
| 2 | Ask tab with a chart answer | Ask your money anything |
| 3 | Home with balance + pie | Where it all went, at a glance |
| 4 | Budgets with progress bars | Budgets that warn you early |
| 5 | Recurring/subscription timeline | Never get surprised by a renewal |
| 6 | Roast My Receipt | Your spending, roasted |

App Preview video (optional, high payoff): 15–20s — receipt photo, AI fills fields, cut to Ask answering a question, cut to Roast. No voiceover needed.

---

## 5. App Review information

- **Demo account**: REQUIRED — the app gates onboarding and sync behind login. Create a dedicated reviewer account with pre-seeded transactions and put credentials in the review notes. Do not give a reviewer a real user's account.
- **Notes to reviewer** (draft):
```
Cashmonki analyses user-supplied receipt photos with a third-party AI model (OpenRouter) to extract merchant, amount, date and category. No receipt data is used for advertising or model training.

The Ask tab is an AI chat restricted to the user's own transaction data. It can propose a transaction, but nothing is written until the user taps Confirm.

Demo account: <EMAIL> / <PASSWORD> — pre-loaded with sample transactions, budgets and subscriptions.
Pro features can be reviewed with the sandbox subscription; free tier is 3 scans/day and 10 Ask messages/day.
```
- **Sign in with Apple**: if you offer Google/email social login, Apple requires Sign in with Apple as an equivalent option. Verify before submitting — this is a common rejection.
- **Age rating**: 4+ is fine. "Roast My Receipt" generates AI text — if the roasts can get crude, answer the *Infrequent/Mild Mature or Suggestive Themes* question honestly rather than risk a post-launch complaint.

---

## 6. App Privacy labels — must match reality

| Data | Collected | Linked to user | Tracking | Source |
|---|---|---|---|---|
| Email address, name | Yes | Yes | No | Firebase Auth, UserManager |
| Financial info (transactions, amounts) | Yes | Yes | No | Firestore/Firebase sync |
| Photos (receipt images) | Yes | Yes | No | Receipt scan → OpenRouter |
| Purchase history | Yes | Yes | No | RevenueCat |
| Product interaction / usage | Yes | Yes | Check | Mixpanel, PostHog |
| Diagnostics / crash | Yes | Maybe | No | Firebase |
| Coarse location | Verify | — | No | LocationCurrencyService — confirm whether it reads device location or IP; label accordingly |

Verify the analytics rows against what Mixpanel/PostHog are configured to send. If either is set up for cross-app attribution, "Used for Tracking" flips to Yes and you need ATT.

Privacy policy must name the third-party AI processor. The current `CashMonki-Privacy-Policy.md` should be checked for an OpenRouter/AI-processing clause before you paste the URL.

---

## 7. Pre-submission checklist

Build:
- [ ] Commit the working tree (blank-screen fix, monotonic onboarding guard, sync promo carousel, 2 imagesets) — currently uncommitted on `firestore-source-of-truth`
- [ ] Confirm `FeatureFlags.firestoreSourceOfTruth` is OFF for the release build
- [ ] Clean build (Shift+Cmd+K) then archive 3.6.0 (3) — module-cache corruption silently produces stale builds
- [ ] Ship to TestFlight, run one real device through: fresh install → onboarding → scan → Ask → purchase → restore

Store Connect:
- [ ] Create 3.6.0 version (needed for the name/subtitle change)
- [ ] Paste name, subtitle, keywords, description, what's new
- [ ] Upload screenshots for every required size
- [ ] Review notes + demo account
- [ ] Confirm privacy labels + privacy policy URL

Backend / monetisation:
- [ ] RevenueCat: set transfer behaviour to "Transfer to new App User ID"
- [ ] Firestore security rules published (`auth.uid == uid`)
- [ ] App Check debug token registered for the test device
- [ ] Confirm subscription products are in "Ready to Submit" and attached to the version — a subscription not attached is the single most common Finance-app rejection
- [ ] Verify paywall shows correct localised price in the reviewer's storefront
```
