# What's New — 3.7.1 (13)

Paste into App Store Connect → 3.7.1 → What's New in This Version.

---

Fixes

• The feedback board no longer shows placeholder posts for a moment when you open it. It now waits for your real feedback to load.

---

## Notes for review submission
- Version 3.7.1, build 13, from branch `firestore-source-of-truth`.
- User-facing change is the feedback board fix. Everything else in this build is
  internal analytics instrumentation with no visible behaviour change.
- Analytics captures shape only — event names, counts, lengths and timings. No
  message text, transaction amounts, merchant names, post titles, comment bodies
  or email addresses are sent to the analytics provider.
- Events are now tagged with `app_environment` (app_store / testflight / debug)
  so beta traffic can be separated from production in reporting.
