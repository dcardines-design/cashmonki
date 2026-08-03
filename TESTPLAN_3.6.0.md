# Test plan — 3.6.0 (10+) data & sync changes

Every case below maps to a specific change made on 2026-08-02/03. Each has a **log line** you can
grep for, because several of these fixes are invisible in the UI when they work.

Console: `xcrun simctl launch --console-pty <udid> com.dante.cashmonki > /tmp/log 2>&1`
(`print()` does NOT reach the unified log, so `log stream` will not show these.)

Two devices are required for cases 4, 5, 6, 7. "Device B" can be a second simulator signed into the
same Google account.

---

## 1. Launch pulls before it pushes  (`a29d5625`)

**Was:** a device with a local box never pulled at launch; it uploaded its local box over the cloud
user document, which could overwrite the account's wallet list with stale data.

1. Sign in on device A. Confirm wallets are correct.
2. On device B (or the Firebase console), rename a wallet.
3. Force-quit device A. Relaunch.

**Pass:** device A shows the renamed wallet without any other interaction.
**Log:** `☁️ UserManager: launch pull for signed-in user — N local transaction(s) before merge`
followed by `☁️ UserManager: launch pull merged — N transaction(s)`.
**Fail:** the old name persists, or the rename disappears on device B (that is the overwrite).

### 1b. Failed pull must not push
1. Enable Airplane Mode. Relaunch the app.

**Pass:** local data still shows; **no** user-doc push is attempted.
**Log:** `⚠️ UserManager: launch pull failed — keeping local, skipping the user-doc push`

---

## 2. No new empty wallet on Gmail login  (`ef889592`)

**Was:** each sign-in on a device without a local box added an empty placeholder wallet, and the app
then selected it — making synced data look missing.

1. Erase the simulator (Device ▸ Erase All Content and Settings) or delete the app.
2. Install, launch, sign in with Google.

**Pass:** wallet list matches the account exactly. No extra empty wallet. The selected wallet is the
account's real default, and transactions are visible immediately.
**Log:** `🧹 Dropping pristine placeholder wallet '…' — the account has real wallets`
**Also check:** a wallet you created yourself and never used must NOT be dropped — it is identified
by id, not name, so create "Test Wallet" before signing in and confirm it survives.

---

## 3. Cloud default wallet wins  (`29fb950c`)

1. On device A create a new wallet, make it default.
2. Sign in on device B.

**Pass:** device B lands on the **account's** default wallet, not one it minted locally.
**Log:** `🔧 Cleared local default on '…' — cloud default wins`

---

## 4. Transaction deletion propagates  (`6ae08aa8`)

**Was:** deleting on A left the row on B forever, and B could re-upload it.

1. Both devices signed in and showing the same transaction.
2. Delete it on device A.

**Pass:** it disappears on device B without a relaunch.
**Log (B):** `🗑️ UserManager: removed N transaction(s) deleted on another device`
**Then:** force-quit and relaunch B. It must stay deleted (no resurrection).
**Firestore:** `users/<uid>/meta/deletions` contains the id.

---

## 5. Wallet deletion propagates  (`29fb950c`)

1. Delete a wallet on device A (one with no transactions, to keep case 9 separate).
2. Watch device B, then relaunch B.

**Pass:** gone on both, and it stays gone after relaunch.
**Fail:** it returns on either device — that is the resurrection bug.

---

## 6. Subscription edits and deletes propagate  (`4a975439`)

**Was:** the merge was additions-only, so edits and deletions never crossed devices.

1. Edit a subscription's amount on device A. Check device B.  **Pass:** new amount appears.
2. Delete a subscription on device A. Check device B.  **Pass:** it disappears and stays gone.
**Log (B):** `📡 CloudSync: applied N cloud subscriptions → M live`

---

## 7. No duplicate subscription transaction on first sign-in  (`bc82cf15`)

**Was:** signing in generated a second copy of an occurrence the cloud already had.

1. Have a subscription whose transaction was already generated and synced.
2. Erase the simulator, reinstall, sign in.

**Pass:** exactly ONE transaction for that occurrence.
**Log:** `↩️ SubscriptionManager: '<name>' occurrence <date> already exists — advancing without generating`

---

## 8. Download cloud data  (`52c07079`, `fb9a31e8`, `ace5a242`)

1. Settings ▸ Data ▸ **Download cloud data**.

**Pass:** toast names the transaction count. In **Local save files** a green cloud disk appears,
titled with your account name (not "Cloud backup 2026-…"), status line reads
`LAST UPDATE JUST NOW · CLOUD BACKUP`.
**Verify the count against Firestore** — this reads the server, not local state, so a mismatch with
what the app shows on screen means the local copy is wrong, not the download.

2. Download 4 times.  **Pass:** only the newest 3 remain.
**Log:** `🧹 UserManager: pruned old cloud snapshot …`

---

## 9. Restore from a save file  (`705935c7`, `ace5a242`)

**Destructive — do this last, and download a fresh backup first.**

1. Download cloud data (this is your restore point).
2. Add a throwaway transaction. Confirm it syncs.
3. Local save files ▸ tap the backup ▸ **Restore from this file** ▸ confirm.

**Pass:** the throwaway transaction is gone locally AND in Firestore, and does not come back on
device B or after relaunch.
**Log:** `♻️ UserManager: RESTORE — removing N cloud transaction(s) absent from the save file`
**Also:** a wallet deleted before the restore must STAY deleted (tombstones are unioned, not
replaced — this was a bug fixed in `ace5a242`).

---

## 10. Backup off  (`78c56554`, verified copy)

1. Settings ▸ Sync to Cloud ▸ off ▸ confirm sheet ▸ Turn off backup.
2. Add a transaction. Check Firestore.

**Pass:** nothing new appears server-side; the existing cloud copy is untouched; the local
transaction saves normally. Turning it back on resumes uploads.

---

## 11. Delete cloud data  (`87bdaa4a`)

**Destructive.**

1. Settings ▸ Data ▸ **Delete cloud data** ▸ confirm.

**Pass:** `users/<uid>` is gone in Firestore **including** the `categories`, `subscriptions`,
`ask_chat` and `meta` documents (deleting the parent doc does not remove subcollections — that was
the bug). This phone keeps every transaction. You stay signed in.

---

## Regression watch (things that must NOT change)

- Adding, editing and deleting a transaction on one device, offline and online.
- Receipt scan → transaction still works (it is not gated by the sync flag).
- Onboarding does not reappear for an existing user on launch.
- The free-tier subscription limit still counts live subscriptions only (tombstoned ones excluded).
