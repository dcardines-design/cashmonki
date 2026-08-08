# Changelog

All notable changes to CashMonki will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.7.1] - 2026-08-08

### Fixed
- **Placeholder posts flashed on the feedback board.** `FeedbackManager` seeded four mock items in
  its initialiser, so opening the board rendered fake posts until the first Firestore snapshot
  replaced them a second later. The seed was not behind `#if DEBUG`, so App Store users saw them
  too. Firestore is now the only source; an empty collection means an empty board.

### Internal
- **Ask is instrumented.** Ten events cover the flow: message sent (typed vs starter chip), reply
  received with latency and reply type, reply failed, unrenderable reply, daily limit reached, card
  shown, confirmed, cancelled, superseded by a revision, and batch rows added.
- **Feedback board is instrumented.** Submitted, upvoted, commented, deleted, approved,
  status changed.
- **Events that were declared but never fired now fire** — wallet switched/edited, budget edited,
  currency changed, language changed, settings opened, transaction viewed, roast attached, trial
  started, subscription cancelled, sync failed, and onboarding skipped on all eight Skip buttons
  (seven of which called the same handler as Continue, making skips invisible).
- **Every event carries `app_environment`** (`app_store` / `testflight` / `debug`) plus
  `is_production_install`, so TestFlight activity no longer lands in production numbers.
- Analytics payloads carry shape only — counts, lengths, timings and flags. No user content.
- Removed a `test_event` capture that fired on every launch.

## [3.7.0] - 2026-08-07

### Added
- **Ask can log several transactions at once** — "add 300 groceries, 150 milk and 90 bread" renders
  one card with a row per transaction. Add them individually, tap a row to edit it before adding, or
  Add all. Nothing is written until you tap.
- **Ask can manage budgets** — set, edit, pause/resume and delete budgets from chat, each behind a
  confirmation card. Paused budgets stay visible to the assistant so they can be resumed.
- **Ask can manage recurring items / subscriptions** — track a new one, change its amount, frequency
  or next due date, turn auto-add off, pause, or delete. Free accounts keep the 2-item limit.
- **Pending suggestions can be revised in chat** — "make it 150", "that's food not coffee" now
  updates the card you are looking at instead of being ignored. A revision replaces the old card, so
  only one proposal is ever tappable.
- **Composer placeholder cycles through examples** with a typing animation, doubling as a tour of
  what Ask can do. Respects Reduce Motion.

### Fixed
- **A new wallet was created on every logout and sign-in.** Signing out resets the profile, so each
  re-login took the "new user" path and minted a wallet with an unregistered id that the cloud merge
  then kept as if it were real. Every app-generated default wallet now comes from one registered
  minter, keyed per account.
- **The selected wallet is remembered.** It was reset to the account default on every launch and
  after every app update, because the choice was never stored.
- **Raw JSON could appear in the chat.** A structured reply that failed to decode fell back to
  printing itself. Malformed replies now show a short apology and log the envelope for diagnosis.
- Revising a pending transaction no longer loses its category.

## [1.0.0] - 2024-11-19

### Added
- **Complete iOS expense tracking app** built with SwiftUI
- **Receipt scanning with AI analysis** using OpenRouter GPT-4 Vision
  - Extracts merchant, amount, date, category, and line items
  - Supports actual date/time extraction from receipts
  - Vietnamese currency format support (periods as thousand separators)
- **Transaction management system**
  - Add, edit, view transactions with category grouping
  - Smart currency formatting (hides .00, shows .01)
  - Income/expense classification with subcategory support
  - Notes and receipt image storage
- **Multi-wallet support** with account-based organization
- **Currency system**
  - Multi-currency support with real-time conversion
  - Period-over-period chart comparisons with proper date alignment
  - Currency preferences and automatic detection
- **Analytics and charts**
  - Dynamic pie charts with tab-based highlighting
  - Period comparisons with visual charts
  - Line charts with hover data showing equivalent dates
- **Authentication system**
  - User registration and login
  - Apple Sign In integration
  - Firebase Auth with email verification
  - Skip logic for already verified users across devices
- **Premium features integration**
  - RevenueCat SDK integration with native paywall
  - Secure API key storage in iOS Keychain
  - Premium feature gating system
- **Design system**
  - Unified CashMonkiDS component system
  - Overused Grotesk font family integration
  - 5-tier button hierarchy and consistent styling
  - Slide-in sheet presentation system
- **Security features**
  - Secure API key storage using KeychainManager
  - Firebase integration with conditional compilation
  - Privacy-focused data handling

### Technical Implementation
- **SwiftUI + SwiftData** for modern iOS development
- **Firebase** integration (Auth, Firestore) with fallback support
- **RevenueCat** for subscription management
- **PhotosUI** for receipt image capture
- **Conditional compilation** for optional dependencies
- **Smart currency parsing** supporting international formats

### Fixed
- OnboardingFlow compilation error with EmailConfirmationViewContainer
- Email verification consistency across devices
- Vietnamese currency format recognition
- Period-over-period chart date calculations
- Currency conversion rate refresh mechanisms

### Security
- API keys stored securely in iOS Keychain
- No hardcoded credentials in source code
- Firebase security rules implementation
- Privacy-compliant data handling

---

## Version Control Guidelines

### Semantic Versioning (SemVer)
We follow [Semantic Versioning](https://semver.org/):
- **MAJOR** (X.0.0) - Breaking changes, major feature overhauls
- **MINOR** (1.X.0) - New features, backward compatible
- **PATCH** (1.0.X) - Bug fixes, small improvements

### Release Process
1. Update version in Xcode project settings
2. Update CHANGELOG.md with new version
3. Commit changes with version tag
4. Create GitHub release with tag
5. Deploy to TestFlight/App Store if applicable

### Example Versioning
- `1.0.0` - Initial release
- `1.1.0` - Add new receipt categories
- `1.1.1` - Fix currency conversion bug  
- `2.0.0` - Complete UI redesign

---

## Unreleased

### Planned Features
- [ ] Export transaction data
- [ ] Advanced analytics dashboard  
- [ ] Custom category creation
- [ ] Cloud backup and sync
- [ ] Widget support
- [ ] Watch app companion

### Known Issues
- None currently identified

---

*For technical details, see [CLAUDE.md](CLAUDE.md) for development guidelines.*