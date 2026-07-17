//
//  FeedbackComponents.swift
//  CashMonki
//
//  Reusable building blocks for the Feedback board: avatar, creator badge,
//  status pill, upvote button, feedback card, and comment row.
//

import SwiftUI

// MARK: - Avatar

/// Small circular avatar showing the first letter of a handle, with a
/// deterministic color derived from the handle.
struct FeedbackAvatar: View {
    let handle: String
    var size: CGFloat = 24

    private var initial: String {
        String(handle.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
    }

    /// Deterministic pastel-ish color from the handle so each user is consistent.
    private var color: Color {
        let palette: [Color] = [
            AppColors.successForeground,
            AppColors.accentOrange,
            AppColors.accentBlue,
            AppColors.walletAvatar,
            AppColors.accentBackground,
            AppColors.destructiveForeground
        ]
        // Deterministic across launches (String.hashValue is seeded per-run).
        let sum = handle.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[sum % palette.count]
    }

    var body: some View {
        ZStack {
            Circle().fill(color)
            Text(initial)
                .font(AppFonts.overusedGroteskSemiBold(size: size * 0.45))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Creator Badge

/// "creator" label marking the app team.
struct CreatorBadge: View {
    var body: some View {
        Text("creator")
            .font(AppFonts.overusedGroteskMedium(size: 12))
            .foregroundColor(AppColors.successForeground)
    }
}

// MARK: - Status Pill

struct StatusPill: View {
    let status: FeedbackStatus

    var body: some View {
        Chip(
            title: status.displayName,
            iconAsset: status.iconAsset,
            iconFallback: status.systemIcon,
            foreground: status.foregroundColor,
            background: status.backgroundColor
        )
    }
}

// MARK: - Upvote Button

struct UpvoteButton: View {
    enum Style { case boxed, inline }

    let count: Int
    let isUpvoted: Bool
    var style: Style = .inline
    var boxedSize: ButtonSize = .doubleExtraSmall
    let action: () -> Void

    /// Increments on each new upvote to trigger the Mario-style hop.
    @State private var jumpCount = 0

    var body: some View {
        Group {
            switch style {
            case .boxed:
                // Uses the app's button component; thumb turns purple when upvoted.
                AppButton(
                    title: "\(count)",
                    action: handleTap,
                    hierarchy: .secondary,
                    size: boxedSize,
                    leftIcon: isUpvoted ? "thumbs-up-filled" : "thumbs-up",
                    iconColorOverride: isUpvoted ? AppColors.accentBackground : AppColors.foregroundPrimary
                )
                .fixedSize()
            case .inline:
                Button(action: handleTap) {
                    HStack(spacing: 6) {
                        AppIcon(assetName: isUpvoted ? "thumbs-up-filled" : "thumbs-up", fallbackSystemName: isUpvoted ? "hand.thumbsup.fill" : "hand.thumbsup", size: 15)
                        Text("\(count)")
                            .font(AppFonts.overusedGroteskMedium(size: 15))
                    }
                    .foregroundColor(isUpvoted ? AppColors.accentBackground : AppColors.foregroundSecondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        // Mario-style hop: quick leap up, springy landing.
        .keyframeAnimator(initialValue: 0.0, trigger: jumpCount) { view, offsetY in
            view.offset(y: offsetY)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(-8, duration: 0.08)
                SpringKeyframe(0, duration: 0.22, spring: .snappy)
            }
        }
    }

    /// Hop only when liking (not when removing an upvote).
    private func handleTap() {
        if !isUpvoted { jumpCount += 1 }
        action()
    }
}

// MARK: - Author line ("avatar  handle  creator  · 12h ago")

struct FeedbackAuthorLine: View {
    let handle: String
    let isCreator: Bool
    let createdAt: Date
    var avatarSize: CGFloat = 24
    /// When set, appends "· 💬 count" to the meta line (used on inbox cards).
    var commentCount: Int? = nil

    var body: some View {
        HStack(spacing: 8) {
            FeedbackAvatar(handle: handle, size: avatarSize)
            Text(handle)
                .font(AppFonts.overusedGroteskSemiBold(size: 14))
                .foregroundColor(AppColors.foregroundPrimary)
                .lineLimit(1)
            if isCreator {
                CreatorBadge()
            }
            separatorDot
            Text(feedbackRelativeTime(createdAt))
                .font(AppFonts.overusedGroteskMedium(size: 12))
                .foregroundColor(AppColors.foregroundTertiary)
            if let commentCount {
                separatorDot
                HStack(spacing: 4) {
                    AppIcon(assetName: "message-square-01", fallbackSystemName: "bubble.left", size: 12)
                    Text("\(commentCount)")
                        .font(AppFonts.overusedGroteskMedium(size: 12))
                }
                .foregroundColor(AppColors.foregroundTertiary)
            }
        }
    }

    private var separatorDot: some View {
        Circle()
            .fill(AppColors.line1stLine)
            .frame(width: 2, height: 2)
    }
}

// MARK: - Feedback Card (inbox list)

struct FeedbackCard: View {
    let item: FeedbackItem
    /// When true, shows the admin "Approve" button below the footer.
    var showApprove: Bool = false
    let onTap: () -> Void
    let onUpvote: () -> Void
    var onApprove: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Status chip (top-left) + upvote (top-right), over the title/description stack
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    StatusPill(status: item.status)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.title)
                            .font(AppFonts.overusedGroteskSemiBold(size: 16))
                            .foregroundColor(AppColors.foregroundPrimary)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        if !item.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(item.detail)
                                .font(AppFonts.overusedGroteskRegular(size: 14))
                                .foregroundColor(AppColors.foregroundSecondary)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                UpvoteButton(count: item.upvotes, isUpvoted: item.upvotedByMe, style: .boxed, action: onUpvote)
            }

            // Footer: avatar · handle · creator · time · comments
            FeedbackAuthorLine(
                handle: item.authorHandle,
                isCreator: item.authorIsCreator,
                createdAt: item.createdAt,
                commentCount: item.totalCommentCount
            )

            // Admin approve action
            if showApprove, let onApprove = onApprove {
                AppButton.secondary("Approve", size: .doubleExtraSmall, leftIcon: "check") {
                    onApprove()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundWhite)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .inset(by: 0.5)
                .stroke(AppColors.line1stLine, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Comment Row (comment + one level of replies)

struct FeedbackCommentRow: View {
    let comment: FeedbackComment
    let onUpvote: (UUID) -> Void
    let onReply: (FeedbackComment) -> Void
    let onOverflow: (FeedbackComment) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            singleComment(comment)

            // Nested replies, indented behind a thread line
            if !comment.replies.isEmpty {
                HStack(alignment: .top, spacing: 15) {
                    Rectangle()
                        .fill(AppColors.line1stLine)
                        .frame(width: 1)
                    VStack(alignment: .leading, spacing: 28) {
                        ForEach(comment.replies) { reply in
                            singleComment(reply)
                        }
                    }
                }
                .padding(.leading, 12)
            }
        }
    }

    @ViewBuilder
    private func singleComment(_ c: FeedbackComment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                FeedbackAuthorLine(handle: c.authorHandle, isCreator: c.authorIsCreator, createdAt: c.createdAt, avatarSize: 22)
                Spacer(minLength: 8)
                Button {
                    onOverflow(c)
                } label: {
                    AppIcon(assetName: "dots-vertical", fallbackSystemName: "ellipsis", size: 16)
                        .foregroundColor(AppColors.foregroundTertiary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(PlainButtonStyle())
            }

            commentText(for: c)
                .font(AppFonts.overusedGroteskMedium(size: 15))
                .foregroundColor(AppColors.foregroundPrimary)

            HStack(spacing: 16) {
                UpvoteButton(count: c.upvotes, isUpvoted: c.upvotedByMe, style: .inline) {
                    onUpvote(c.id)
                }
                Button {
                    onReply(c)
                } label: {
                    AppIcon(assetName: "message-square-01", fallbackSystemName: "bubble.left", size: 15)
                        .foregroundColor(AppColors.foregroundSecondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, 6)
        }
    }

    /// Highlights a leading @mention in the accent color.
    /// Renders the @tag from the structured `replyToHandle` field, keeping the
    /// comment text itself clean (so edits can't destroy the tag).
    private func commentText(for c: FeedbackComment) -> Text {
        guard let handle = c.replyToHandle else { return Text(c.text) }
        return Text("@\(handle) ").foregroundColor(AppColors.accentBackground) + Text(c.text)
    }
}
