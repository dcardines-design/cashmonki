//
//  CloudSync.swift
//  CashMonki
//
//  Live cross-device sync. One place that attaches Firestore snapshot listeners to every
//  user-owned path and routes what arrives through the SAME merge functions the one-shot
//  fetches use.
//
//  Why this exists: uploads were already instant (delta pushTransactionToCloud on add), but
//  nothing pulled. The only listeners in the app were dead — TransactionSyncManager's was
//  disabled in the sync cleanup, and FirestoreRepository's is dormant behind a feature flag —
//  so a transaction added on one device only appeared on another after a relaunch.
//
//  Safety rules this file must keep:
//    - NEVER replace local state. Every apply hook merges, so a snapshot arriving mid-edit
//      cannot drop local work.
//    - Every apply must be idempotent. Our own writes echo back through the listener, and an
//      apply that "changes" something on every echo is a write loop.
//    - Listeners attach ONCE per session. Attaching re-reads the whole collection, so
//      reattaching on every foreground would cost a full read each time.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

final class CloudSync {
    static let shared = CloudSync()

    private init() {
        // Identity is only trustworthy once a load has completed — syncUID() falls back to a
        // throwaway UUID before Firebase Auth resolves, and listeners bound to that would watch
        // a document that does not exist. Every path that settles identity posts this.
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UserManagerFirebaseLoadComplete"), object: nil, queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }

    /// The identity the current listeners are bound to; nil when detached.
    private(set) var attachedUID: String?

    #if canImport(FirebaseFirestore)
    private var registrations: [ListenerRegistration] = []
    #endif

    /// Attach listeners for `uid`. Safe to call repeatedly — a second call for the same identity
    /// is ignored, and a call for a different identity swaps cleanly.
    func start(uid: String) {
        guard !uid.isEmpty else { return }
        guard UserManager.shared.currentUser.enableFirebaseSync else {
            print("📡 CloudSync: backup is off — not attaching listeners")
            return
        }
        guard attachedUID != uid else { return }

        stop()

        #if canImport(FirebaseFirestore)
        let service = FirestoreService.shared

        if let reg = service.observeUserDoc(userId: uid, onChange: { cloud in
            DispatchQueue.main.async { UserManager.shared.applyCloudUserDoc(cloud) }
        }) { registrations.append(reg) }

        if let reg = service.observeTransactions(userId: uid, onChange: { txns in
            DispatchQueue.main.async { UserManager.shared.applyCloudTransactions(txns) }
        }) { registrations.append(reg) }

        if let reg = service.observeCategories(userId: uid, onChange: { unified, _ in
            DispatchQueue.main.async {
                // pushIfNothingNew: false — echoing our own snapshot back would be a write loop.
                CategoriesManager.shared.applyCloudCategories(unified: unified, pushIfNothingNew: false)
            }
        }) { registrations.append(reg) }

        if let reg = service.observeSubscriptions(userId: uid, onChange: { data in
            Task { @MainActor in SubscriptionManager.shared.applyCloudSubscriptions(data) }
        }) { registrations.append(reg) }

        attachedUID = uid
        print("📡 CloudSync: attached \(registrations.count) listeners for \(uid.prefix(8))")
        #endif
    }

    /// Detach everything. Call on sign-out, identity change, or when backup is switched off.
    func stop() {
        #if canImport(FirebaseFirestore)
        guard !registrations.isEmpty else {
            attachedUID = nil
            return
        }
        registrations.forEach { $0.remove() }
        registrations.removeAll()
        #endif
        if let uid = attachedUID {
            print("📡 CloudSync: detached listeners for \(uid.prefix(8))")
        }
        attachedUID = nil
    }

    /// Attach for the signed-in user if there is one, otherwise ensure we're detached. Call after
    /// sign-in, sign-out, and when the cloud-backup toggle changes.
    func refresh() {
        guard AuthenticationManager.shared.isAuthenticated,
              UserManager.shared.currentUser.enableFirebaseSync else {
            stop()
            return
        }
        start(uid: UserManager.shared.syncUID())
    }
}
