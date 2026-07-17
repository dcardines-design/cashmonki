//
//  FirestoreRepository.swift
//  CashMonki
//
//  Phase 1 of the Firestore-as-source-of-truth migration.
//
//  A thin READ layer: live listeners on users/{uid}/<collection> that decode into @Published
//  arrays. Everything here is DORMANT until the `firestoreSourceOfTruth` feature flag is ON — the
//  app still reads/writes through the legacy UserManager box by default, so this is non-destructive
//  and ships safely alongside the current code. Phase 2 adds the write path; Phase 3 migrates data.
//

import SwiftUI

#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

// MARK: - Feature flag

enum FeatureFlags {
    /// Firestore is the source of truth (offline persistence + live listeners) instead of the
    /// hand-rolled UserDefaults boxes. OFF by default — flip only once proven in the field. Stored
    /// in UserDefaults so a debug toggle can flip it without a rebuild.
    static var firestoreSourceOfTruth: Bool {
        UserDefaults.standard.bool(forKey: "ff_firestoreSourceOfTruth")
    }
    static func setFirestoreSourceOfTruth(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: "ff_firestoreSourceOfTruth")
    }
}

// MARK: - Identity

/// The Firestore document owner. Uses the live Firebase uid (anonymous OR linked — same id),
/// which is exactly what the security rules gate on (request.auth.uid == uid).
enum FirestoreIdentity {
    static var uid: String? {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.uid
        #else
        return nil
        #endif
    }
}

// MARK: - Generic live collection

/// Live view of one subcollection under users/{uid}. Decodes each doc via the model's Codable.
/// Offline-safe: Firestore serves the local cache first, then reconciles with the server.
@MainActor
final class FirestoreCollection<T>: ObservableObject where T: Codable & Identifiable, T.ID == UUID {
    @Published private(set) var items: [T] = []
    @Published private(set) var isLoaded = false

    private let collectionName: String
    #if canImport(FirebaseFirestore)
    private var listener: ListenerRegistration?
    #endif

    init(_ collectionName: String) { self.collectionName = collectionName }

    /// Attach a live listener on users/{uid}/<collectionName>.
    func start(uid: String) {
        #if canImport(FirebaseFirestore)
        guard FirebaseApp.app() != nil else { return }
        stop()
        let ref = Firestore.firestore()
            .collection("users").document(uid)
            .collection(collectionName)
        listener = ref.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("⚠️ FirestoreCollection[\(self.collectionName)]: \(error.localizedDescription)")
                return
            }
            guard let docs = snapshot?.documents else { return }
            let decoded: [T] = docs.compactMap { try? $0.data(as: T.self) }
            Task { @MainActor in
                self.items = decoded
                self.isLoaded = true
            }
        }
        #endif
    }

    func stop() {
        #if canImport(FirebaseFirestore)
        listener?.remove()
        listener = nil
        #endif
        isLoaded = false
    }

    deinit {
        #if canImport(FirebaseFirestore)
        listener?.remove()
        #endif
    }
}

// MARK: - Store (Phase 1: core collections)

/// Aggregates the live collections. Dormant unless the feature flag is on. Phase 2 adds writes;
/// categories, subscriptions, and ask-messages get their own collections then.
@MainActor
final class FirestoreStore: ObservableObject {
    static let shared = FirestoreStore()

    let transactions = FirestoreCollection<Txn>("transactions")
    let wallets      = FirestoreCollection<AccountData>("accounts")
    let budgets      = FirestoreCollection<Budget>("budgets")

    private init() {
        // Re-attach listeners for whoever becomes the current user (login / launch restore).
        // No-ops while the flag is off, so this is inert until we opt in.
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UserManagerFirebaseLoadComplete"), object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.startIfEnabled() }
        }
    }

    /// Begin listening for the current identity — only when the flag is on. Safe to call on every
    /// login / load-complete; no-ops while the flag is off.
    func startIfEnabled() {
        guard FeatureFlags.firestoreSourceOfTruth, let uid = FirestoreIdentity.uid else { return }
        print("🔥 FirestoreStore: starting live listeners for \(uid.prefix(8))")
        transactions.start(uid: uid)
        wallets.start(uid: uid)
        budgets.start(uid: uid)
    }

    func stopAll() {
        transactions.stop()
        wallets.stop()
        budgets.stop()
    }
}
