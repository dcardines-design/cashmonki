//
//  FeedbackManager.swift
//  CashMonki
//
//  Store for the Feedback board, backed by the Firestore `feedback_items`
//  collection. Exposes all mutations (add / upvote / comment / reply / edit /
//  delete / approve / set-status), each written through to the remote doc.
//

import SwiftUI
import Combine
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

final class FeedbackManager: ObservableObject {
    static let shared = FeedbackManager()

    /// All feedback items (approved and not). Views filter by tab.
    @Published var items: [FeedbackItem] = []

    /// Admin preview toggle (set from Debug settings). Reveals the "New" tab,
    /// Approve actions, Change Status, and delete-any-comment.
    @Published var isAdminMode: Bool {
        didSet { UserDefaults.standard.set(isAdminMode, forKey: Self.adminModeKey) }
    }

    private static let adminModeKey = "feedbackAdminModePreview"

    private init() {
        self.isAdminMode = UserDefaults.standard.bool(forKey: Self.adminModeKey)
        // No local seeding: mock rows rendered for the second before the first
        // Firestore snapshot arrived, then vanished. Firestore is the only source.
        // Firebase may not be configured yet at first singleton touch.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.startSync()
        }
    }

    // MARK: - Current user identity

    /// Full lowercase email — the ownership identity stored on posts/comments.
    var currentUserEmail: String {
        (AuthenticationManager.shared.currentUser?.email
            ?? UserManager.shared.currentUser.email)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    /// Display handle (email prefix); falls back to "you".
    var currentUserHandle: String {
        feedbackHandle(fromEmail: currentUserEmail)
    }

    /// True when the signed-in user's role is "admin" (assigned by
    /// UserManager.ensureRoleAssigned and stored on the user record).
    /// The long-press preview toggle only works in debug builds.
    var isAdmin: Bool {
        #if DEBUG || targetEnvironment(simulator)
        if isAdminMode { return true }
        #endif
        return UserManager.shared.currentUser.isAdmin
    }

    /// The current user is treated as "creator" (app team) while an admin.
    var currentUserIsCreator: Bool { isAdmin }

    // MARK: - Item mutations

    func addFeedback(title: String, detail: String) {
        let item = FeedbackItem(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
            authorEmail: currentUserEmail,
            authorIsCreator: currentUserIsCreator,
            createdAt: Date(),
            // Creator-authored posts are auto-approved; user posts await admin approval.
            approved: currentUserIsCreator,
            status: .pending
        )
        items.insert(item, at: 0)
        // Lengths only — the post's wording is the user's, and it syncs to
        // Firestore anyway where it can be read properly.
        AnalyticsManager.shared.track(.feedbackSubmitted, properties: [
            "is_creator": item.authorIsCreator,
            "auto_approved": item.approved,
            "title_length": item.title.count,
            "detail_length": item.detail.count
        ])
        saveRemote(item)
    }

    func toggleUpvote(itemID: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
        let me = currentUserEmail
        let adding = !items[idx].upvoters.contains(me)
        if adding {
            items[idx].upvoters.append(me)
        } else {
            items[idx].upvoters.removeAll { $0 == me }
        }
        AnalyticsManager.shared.track(.feedbackUpvoted, properties: [
            "added": adding,
            "upvote_count": items[idx].upvoters.count,
            "is_own_post": items[idx].authorEmail.lowercased() == me
        ])
        saveRemote(items[idx])
    }

    func approve(itemID: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[idx].approved = true
        AnalyticsManager.shared.track(.feedbackApproved, properties: [
            "upvote_count": items[idx].upvoters.count,
            "comment_count": items[idx].comments.count
        ])
        saveRemote(items[idx])
    }

    func setStatus(_ status: FeedbackStatus, itemID: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
        let previous = items[idx].status
        items[idx].status = status
        AnalyticsManager.shared.track(.feedbackStatusChanged, properties: [
            "from_status": previous.rawValue,
            "to_status": status.rawValue,
            "upvote_count": items[idx].upvoters.count
        ])
        saveRemote(items[idx])
    }

    func editFeedback(itemID: UUID, title: String, detail: String) {
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[idx].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        items[idx].detail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        saveRemote(items[idx])
    }

    func deleteFeedback(itemID: UUID) {
        // Read the post before it goes: an admin clearing someone else's post is
        // moderation, an author removing their own is a change of mind.
        if let item = items.first(where: { $0.id == itemID }) {
            AnalyticsManager.shared.track(.feedbackDeleted, properties: [
                "by_admin": isAdmin,
                "was_own_post": item.authorEmail.lowercased() == currentUserEmail,
                "was_approved": item.approved,
                "upvote_count": item.upvoters.count,
                "comment_count": item.comments.count
            ])
        }
        items.removeAll { $0.id == itemID }
        deleteRemote(itemID)
    }

    // MARK: - Comment mutations

    func addComment(text: String, toItem itemID: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
        let comment = FeedbackComment(
            authorEmail: currentUserEmail,
            authorIsCreator: currentUserIsCreator,
            text: text.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        items[idx].comments.append(comment)
        AnalyticsManager.shared.track(.feedbackCommented, properties: [
            "is_reply": false,
            "is_creator": comment.authorIsCreator,
            "on_own_post": items[idx].authorEmail.lowercased() == currentUserEmail,
            "text_length": comment.text.count
        ])
        saveRemote(items[idx])
    }

    func addReply(text: String, toComment commentID: UUID, inItem itemID: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
        // Resolve the top-level comment: either the target itself, or the parent
        // of the target reply — replying to a reply flattens into the same thread
        // since nesting is capped at one level.
        guard let cIdx = items[idx].comments.firstIndex(where: { comment -> Bool in
            if comment.id == commentID { return true }
            return comment.replies.contains(where: { $0.id == commentID })
        }) else { return }

        // Tag whoever is being answered (comment or flattened reply), unless
        // it's the current user replying to themselves.
        let parent = items[idx].comments[cIdx]
        let targetEmail = parent.id == commentID
            ? parent.authorEmail
            : parent.replies.first(where: { $0.id == commentID })?.authorEmail
        let replyTo: String? = {
            guard let targetEmail, targetEmail.lowercased() != currentUserEmail else { return nil }
            return feedbackHandle(fromEmail: targetEmail)
        }()

        // If the user typed the @tag themselves, strip it — the tag lives in
        // replyToHandle, not in the text.
        var cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let replyTo, cleanText.lowercased().hasPrefix("@\(replyTo.lowercased())") {
            cleanText = String(cleanText.dropFirst(replyTo.count + 1))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let reply = FeedbackComment(
            authorEmail: currentUserEmail,
            authorIsCreator: currentUserIsCreator,
            text: cleanText,
            replyToHandle: replyTo
        )
        items[idx].comments[cIdx].replies.append(reply)
        AnalyticsManager.shared.track(.feedbackCommented, properties: [
            "is_reply": true,
            "is_creator": reply.authorIsCreator,
            "on_own_post": items[idx].authorEmail.lowercased() == currentUserEmail,
            "text_length": reply.text.count,
            "tagged_someone": reply.replyToHandle != nil
        ])
        saveRemote(items[idx])
    }

    func editComment(commentID: UUID, inItem itemID: UUID, newText: String) {
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        mutateComment(commentID: commentID, in: &items[idx].comments) { $0.text = trimmed }
        saveRemote(items[idx])
    }

    func deleteComment(commentID: UUID, inItem itemID: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
        removeComment(commentID: commentID, from: &items[idx].comments)
        saveRemote(items[idx])
    }

    func toggleCommentUpvote(commentID: UUID, inItem itemID: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
        let me = currentUserEmail
        mutateComment(commentID: commentID, in: &items[idx].comments) { c in
            if c.upvoters.contains(me) {
                c.upvoters.removeAll { $0 == me }
            } else {
                c.upvoters.append(me)
            }
        }
        saveRemote(items[idx])
    }

    /// True when the current user may edit/delete content authored by `email`.
    /// Users manage their own; admins can delete anyone's.
    func canModifyComment(authorEmail: String) -> Bool {
        isAdmin || authorEmail.lowercased() == currentUserEmail
    }

    // MARK: - Firestore sync (feedback_items collection)

    /// True once the snapshot listener is attached.
    private var isSyncing = false
    #if canImport(FirebaseFirestore)
    private var listener: ListenerRegistration?

    private var db: Firestore? {
        guard FirebaseApp.app() != nil else { return nil }
        return Firestore.firestore()
    }
    #endif

    /// Attaches the live listener. The board starts empty and only ever shows
    /// what Firestore sends — an empty collection means an empty board.
    func startSync() {
        #if canImport(FirebaseFirestore)
        guard !isSyncing, let db else {
            if !isSyncing { print("📮 FeedbackManager: Firestore unavailable — staying on mock data") }
            return
        }
        isSyncing = true
        listener = db.collection("feedback_items").addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            if let error {
                print("📮 FeedbackManager: listener error \(error.localizedDescription)")
                return
            }
            guard let documents = snapshot?.documents else { return }
            // Remote is the source of truth — an empty collection means an
            // empty board (no seed uploads; mock data is offline-preview only).
            let decoded = documents.compactMap { Self.decodeItem($0.data()) }
            DispatchQueue.main.async {
                self.items = decoded.sorted { $0.createdAt > $1.createdAt }
            }
        }
        #endif
    }

    private func saveRemote(_ item: FeedbackItem) {
        #if canImport(FirebaseFirestore)
        guard let db, let dict = Self.encodeItem(item) else { return }
        db.collection("feedback_items").document(item.id.uuidString).setData(dict) { error in
            if let error { print("📮 FeedbackManager: save failed \(error.localizedDescription)") }
        }
        #endif
    }

    private func deleteRemote(_ itemID: UUID) {
        #if canImport(FirebaseFirestore)
        guard let db else { return }
        db.collection("feedback_items").document(itemID.uuidString).delete { error in
            if let error { print("📮 FeedbackManager: delete failed \(error.localizedDescription)") }
        }
        #endif
    }

    private static func encodeItem(_ item: FeedbackItem) -> [String: Any]? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(item),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return dict
    }

    private static func decodeItem(_ dict: [String: Any]) -> FeedbackItem? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(FeedbackItem.self, from: data)
    }

    // MARK: - Recursive comment helpers (one level of replies)

    private func mutateComment(commentID: UUID, in comments: inout [FeedbackComment], _ change: (inout FeedbackComment) -> Void) {
        for i in comments.indices {
            if comments[i].id == commentID {
                change(&comments[i])
                return
            }
            for j in comments[i].replies.indices where comments[i].replies[j].id == commentID {
                change(&comments[i].replies[j])
                return
            }
        }
    }

    private func removeComment(commentID: UUID, from comments: inout [FeedbackComment]) {
        if comments.contains(where: { $0.id == commentID }) {
            comments.removeAll { $0.id == commentID }
            return
        }
        for i in comments.indices {
            comments[i].replies.removeAll { $0.id == commentID }
        }
    }

}

// MARK: - Relative time formatting ("12h ago")

func feedbackRelativeTime(_ date: Date) -> String {
    let seconds = max(0, Date().timeIntervalSince(date))
    let minutes = Int(seconds / 60)
    let hours = Int(seconds / 3600)
    let days = Int(seconds / 86400)

    if days >= 7 {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    } else if days >= 1 {
        return "\(days)d ago"
    } else if hours >= 1 {
        return "\(hours)h ago"
    } else if minutes >= 1 {
        return "\(minutes)m ago"
    } else {
        return "Just now"
    }
}
