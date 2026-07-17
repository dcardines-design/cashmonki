//
//  FeedbackModels.swift
//  CashMonki
//
//  Data models for the Feedback board (feature requests, comments, upvotes).
//  Currently backed by in-memory mock data via FeedbackManager; designed to be
//  swapped for Firestore once auth is re-enabled.
//

import SwiftUI

// MARK: - Status

/// Lifecycle status of a feedback item. Shown as a colored pill and changed by admins.
enum FeedbackStatus: String, CaseIterable, Codable {
    case pending = "Pending"
    case inProgress = "In progress"
    case done = "Done"

    var displayName: String { rawValue }

    /// untitledui asset shown inside the status chip.
    var iconAsset: String {
        switch self {
        case .pending: return "clock"
        case .inProgress: return "tool-01"
        case .done: return "check"
        }
    }

    /// SF Symbol fallback for the status chip icon.
    var systemIcon: String {
        switch self {
        case .pending: return "clock"
        case .inProgress: return "wrench.fill"
        case .done: return "checkmark"
        }
    }

    var foregroundColor: Color {
        switch self {
        case .pending: return AppColors.foregroundSecondary
        case .inProgress: return AppColors.statusInProgressForeground
        case .done: return AppColors.statusDoneForeground
        }
    }

    var backgroundColor: Color {
        switch self {
        case .pending: return AppColors.statusPendingBackground
        case .inProgress: return AppColors.statusInProgressBackground
        case .done: return AppColors.statusDoneBackground
        }
    }
}

// MARK: - Comment

/// A comment (or nested reply) on a feedback item. Replies are one level deep.
struct FeedbackComment: Identifiable, Codable {
    let id: UUID
    /// Full email of the author — the ownership identity. Never displayed.
    var authorEmail: String
    var authorIsCreator: Bool
    var text: String

    /// Display name shown in the UI (email prefix).
    var authorHandle: String { feedbackHandle(fromEmail: authorEmail) }
    /// Handle of the person this comment replies to (rendered as a leading
    /// @tag). Stored separately from `text` so edits can't destroy it and it
    /// survives future handle changes.
    var replyToHandle: String?
    var createdAt: Date
    /// Emails of users who upvoted — server-side truth for count and state.
    var upvoters: [String]
    var upvotes: Int { upvoters.count }
    var upvotedByMe: Bool { upvoters.contains(FeedbackManager.shared.currentUserEmail) }
    var replies: [FeedbackComment]

    init(
        id: UUID = UUID(),
        authorEmail: String,
        authorIsCreator: Bool = false,
        text: String,
        replyToHandle: String? = nil,
        createdAt: Date = Date(),
        upvoters: [String] = [],
        replies: [FeedbackComment] = []
    ) {
        self.id = id
        self.authorEmail = authorEmail
        self.authorIsCreator = authorIsCreator
        self.text = text
        self.replyToHandle = replyToHandle
        self.createdAt = createdAt
        self.upvoters = upvoters
        self.replies = replies
    }
}

// MARK: - Feedback Item

/// A single feature-request / feedback post.
/// Display handle derived from an email — identity is the full email,
/// but we never render it; only the prefix shows in the UI.
func feedbackHandle(fromEmail email: String) -> String {
    let prefix = email.components(separatedBy: "@").first?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return prefix.isEmpty ? "you" : prefix
}

struct FeedbackItem: Identifiable, Codable {
    let id: UUID
    var title: String
    var detail: String
    /// Full email of the author — the ownership identity. Never displayed.
    var authorEmail: String
    var authorIsCreator: Bool

    /// Display name shown in the UI (email prefix).
    var authorHandle: String { feedbackHandle(fromEmail: authorEmail) }
    var createdAt: Date
    /// Emails of users who upvoted — server-side truth for count and state.
    var upvoters: [String]
    var upvotes: Int { upvoters.count }
    var upvotedByMe: Bool { upvoters.contains(FeedbackManager.shared.currentUserEmail) }
    /// Once approved by an admin the item becomes visible to all users.
    /// Unapproved items only appear in the admin "New" tab.
    var approved: Bool
    var status: FeedbackStatus
    var comments: [FeedbackComment]

    init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        authorEmail: String,
        authorIsCreator: Bool = false,
        createdAt: Date = Date(),
        upvoters: [String] = [],
        approved: Bool = false,
        status: FeedbackStatus = .pending,
        comments: [FeedbackComment] = []
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.authorEmail = authorEmail
        self.authorIsCreator = authorIsCreator
        self.createdAt = createdAt
        self.upvoters = upvoters
        self.approved = approved
        self.status = status
        self.comments = comments
    }

    /// Total comment count including nested replies (for the footer count).
    var totalCommentCount: Int {
        comments.reduce(0) { $0 + 1 + $1.replies.count }
    }
}

// MARK: - Inbox Tabs

/// Segmented tabs shown at the top of the inbox. `new` is admin-only.
enum FeedbackTab: String, CaseIterable {
    case new = "New"
    case open = "Open"
    case done = "Done"
}
