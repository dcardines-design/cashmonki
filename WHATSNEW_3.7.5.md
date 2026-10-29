# What's New — 3.7.5 (17)

Paste into App Store Connect → 3.7.5 → What's New in This Version.

---

Snap a receipt, Ask does the rest

• Send Ask a photo of a receipt, bill or payment screenshot, and it reads the merchant, date and total and gets the transaction ready for you to add. Attach up to 4 photos at once, from your camera or your library.
• Hide your amounts on the Transactions page too, with the same eye icon as Home. Handy when someone's looking over your shoulder.

Fixes

• Pro subscribers now see a plain note about their plan on the upgrade screen, instead of trial and billing details meant for new subscribers.

---

## Notes for review submission
- Version 3.7.5, build 17, from local branch `release/3.7.5` (`ask-photos` with `feat/transactions-hide-amounts` merged in).
- Each photo sent to Ask counts as one receipt scan toward the daily limit (Plus: 10 a day, Pro: unlimited).
- Photos are sent to the AI service only for the message they're attached to, and are otherwise stored on the device. The cloud copy of the chat holds only photo ids, not images. Check that the App Privacy answers still match, since Ask now receives photo content.
- Camera and photo library access are requested only when the user picks Take photo or Choose from library in Ask.
