# Savepoint — CashMonki: prod data recovery DONE + What's New + pending hardening

**Date:** 2026-07-08
**Working in:** `~/Desktop/cashooya-playground` (CashMonki iOS/SwiftUI). Repo `dcardines-design/cashmonki`. CAVEMAN MODE ACTIVE (full); dropped to normal prose for data-loss/security parts.

(Saved to project's own savepoints/, not skill's doodlecraft default — active project is CashMonki. Continues auto_2026-07-08_00-00.md.)

## What we were doing
Recovered user's real transaction history that "disappeared" after an App Store update to v3.5.2. RESOLVED — user confirmed "all good now". Then wrote App Store What's New copy for 3.5.2.

## Part B — data-loss incident: RESOLVED
Root cause: App Store update to 3.5.2 dropped Firebase Auth session. Before update, `AuthenticationManager.currentUser?.firebaseUID` was nil so data saved under fallback key derived from `UserData.id.uuidString` = `currentUser_firebase_84C5F092-F787-4A0E-A13C-9446BC633509` (517KB, ~700 txns, "Dante"/"Dante's Wallet"). After update Firebase auth worked and minted a NEW anonymous UID `u7P5bVWvsEhJbt360Ru7YUX0vks2` → app looked under that key, found nothing, set up empty guest. Dante's blob never overwritten (empty-save went to the new guest key).

**Fix applied (temporary, DEBUG-only, in CashMonkiApp.swift init()):**
- `dumpUserStorageForRecovery()` — READ-ONLY dump, saved RECOVERY_*.json to Documents. Confirmed blob intact.
- `restoreDanteData()` — one-shot (flag `didRestoreDante_20260708`). Copies Dante blob from `84C5F092...` into active guest key `u7P5...`, backs up guest blob to `..._preRestoreBackup` first, sets `currentUserName`=Dante. Source blob left untouched. User ran it, force-quit, relaunched → history reappeared.
- `cleanupCrossContaminatedData` verified SAFE — only nukes accounts named test/sample/rosebud; "Dante's Wallet" survives.
- Subscription loss: separate, recoverable via Restore Purchases (Apple ID tied). Not yet confirmed done.

## Files touched
- `CashMonki/CashMonkiApp.swift` — added TEMP DEBUG `dumpUserStorageForRecovery()` + `restoreDanteData()` in `init()`. **Both must be removed now recovery done.**
- (Part A, prior, still uncommitted) `CashMonki/Pages/AskPage.swift`, `CashMonki/Functions/AskChatService.swift` — AI-chat echo fix (`.systemNote` case, reworded history markers, 2 systemPrompt rules).

## Open threads / next steps
- [ ] **Remove temp recovery code** from CashMonkiApp.swift (dump + restore). Leave `84C5F092...` blob + `_preRestoreBackup` in UserDefaults a few days as safety copies.
- [ ] **Root-cause fix to SHIP:** make empty-user fallback at `UserManager.swift:330` non-destructive — never `saveCurrentUserLocally()` over an existing non-empty blob without a confirmed successful decode. Prevents recurrence on future updates. Also address auth-loss-on-update if feasible.
- [ ] **Part A:** build + verify AI-chat echo fix ("add 20 coffees" → repeated Yes; real tile each add, no stray marker/✅ text), then commit.
- [ ] Confirm subscription restored (Restore Purchases).
- [ ] Version is 3.5.2. What's New copy written (no emojis): Ask AI assistant, Recurring & Subscriptions + reminders, Feedback Board, category suggestion chips, more accurate multi-currency totals, bug fixes.

## Context worth preserving
- Storage LOCAL-FIRST: `enableFirebaseSync` OFF. One JSON blob per user in UserDefaults key `currentUser_firebase_<firebaseUID>`, firebaseUID = `AuthenticationManager.shared.currentUser?.firebaseUID ?? id.uuidString`. Nothing in Firestore (permissions test failed = local-only confirmed). No iCloud/Finder backups.
- Never had user delete/reinstall/offload app or log out during incident — would have destroyed only copy.
- Lots of uncommitted work in tree beyond Part A: Feedback feature (AddFeedbackSheet, FeedbackManager, FeedbackModels, Feedback*Sheet), recurring/subscription changes, FeedbackComponents, Array+Chunked. Not authored this session — pre-existing uncommitted.
- Verify command: `xcrun swiftc -parse <file>`. SourceKit "No such module UIKit" / "cannot find X" / "@main" = known cross-file single-file-parse noise, ignore.
