//
//  FeedbackPostSheet.swift
//  CashMonki
//
//  Detail view for a single feedback item: post, action row, threaded comments
//  with one level of replies, and a composer. Admins see Approve (for unapproved
//  items) and can change status / delete any comment.
//

import SwiftUI

struct FeedbackPostSheet: View {
    let itemID: UUID
    @Binding var isPresented: Bool

    @ObservedObject private var feedback = FeedbackManager.shared
    @EnvironmentObject private var toastManager: ToastManager

    // Composer state
    @State private var composeText: String = ""
    @State private var replyingTo: FeedbackComment? = nil
    @State private var editingComment: FeedbackComment? = nil
    @FocusState private var composerFocused: Bool

    // Sub-sheets
    @State private var actionTargetComment: FeedbackComment? = nil
    @State private var showingActionSheet = false
    @State private var showingChangeStatus = false

    // Post body truncation ("See more")
    @State private var showingFullPost = false
    @State private var isPostTruncated = false

    // Edit-own-post sheet
    @State private var showingEditPost = false

    private var item: FeedbackItem? {
        feedback.items.first(where: { $0.id == itemID })
    }

    /// Sheet header shows the post title capped at 22 characters with an ellipsis.
    private func headerTitle(for item: FeedbackItem) -> String {
        let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.count > 22 else { return title }
        return String(title.prefix(22)).trimmingCharacters(in: .whitespaces) + "…"
    }

    /// Admin looking at an item that still needs approval.
    private var isAdminPendingApproval: Bool {
        guard let item else { return false }
        return feedback.isAdmin && !item.approved
    }

    var body: some View {
        Group {
            if let item {
                content(for: item)
            } else {
                // Item was deleted — close.
                Color.clear.onAppear { isPresented = false }
            }
        }
    }

    @ViewBuilder
    private func content(for item: FeedbackItem) -> some View {
        VStack(spacing: 0) {
            SheetHeader.basic(title: headerTitle(for: item)) {
                isPresented = false
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Post section (white)
                    VStack(alignment: .leading, spacing: 24) {
                        // Author + status
                        HStack {
                            FeedbackAuthorLine(handle: item.authorHandle, isCreator: item.authorIsCreator, createdAt: item.createdAt)
                            Spacer(minLength: 8)
                            // Full opacity for everyone; only admins can tap to change status.
                            Button {
                                if feedback.isAdmin { showingChangeStatus = true }
                            } label: {
                                StatusPill(status: item.status)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .allowsHitTesting(feedback.isAdmin)
                        }

                        // Title + description (subtext collapses when empty)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.title)
                                .font(AppFonts.overusedGroteskBold(size: 22))
                                .foregroundColor(AppColors.foregroundPrimary)
                            if !item.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(item.detail)
                                    .font(AppFonts.overusedGroteskMedium(size: 16))
                                    .foregroundColor(AppColors.foregroundSecondary)
                                    .lineLimit(showingFullPost ? nil : 3)
                                    .background(
                                        // Detects whether the full text overflows the
                                        // 3-line frame: Color.clear is only chosen (and
                                        // onAppear fired) when the hidden full text
                                        // doesn't fit the truncated height.
                                        ViewThatFits(in: .vertical) {
                                            Text(item.detail)
                                                .font(AppFonts.overusedGroteskMedium(size: 16))
                                                .hidden()
                                            Color.clear.onAppear { isPostTruncated = true }
                                        }
                                    )

                                if isPostTruncated {
                                    AppButton(
                                        title: showingFullPost ? "See less" : "See more",
                                        action: { showingFullPost.toggle() },
                                        hierarchy: .textPrimary,
                                        size: .tripleExtraSmall
                                    )
                                    .fixedSize()
                                }
                            }
                        }

                        // Action row (hidden for admins approving a new item)
                        if !isAdminPendingApproval {
                            HStack(spacing: 20) {
                                UpvoteButton(count: item.upvotes, isUpvoted: item.upvotedByMe, style: .boxed, boxedSize: .tripleExtraSmall) {
                                    feedback.toggleUpvote(itemID: item.id)
                                }
                                AppButton(
                                    title: "Comment",
                                    action: startNewComment,
                                    hierarchy: .secondary,
                                    size: .tripleExtraSmall,
                                    leftIcon: "message-square-01",
                                    iconColorOverride: AppColors.foregroundPrimary
                                )

                                Button {
                                    openPostActionSheet()
                                } label: {
                                    AppIcon(assetName: "dots-vertical", fallbackSystemName: "ellipsis", size: 16)
                                        .foregroundColor(AppColors.foregroundTertiary)
                                        .frame(width: 20, height: 44)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 22)
                    .padding(.bottom, 24)
                    .background(AppColors.backgroundWhite)

                    // Comments tile on grey backdrop
                    if !isAdminPendingApproval && !item.comments.isEmpty {
                        VStack(alignment: .leading, spacing: 28) {
                            ForEach(item.comments) { comment in
                                FeedbackCommentRow(
                                    comment: comment,
                                    onUpvote: { id in feedback.toggleCommentUpvote(commentID: id, inItem: item.id) },
                                    onReply: { startReply(to: $0) },
                                    onOverflow: { openActionSheet(for: $0) }
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 22)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(AppColors.backgroundWhite)
                        )
                        .padding(12)
                    }
                }
            }
            .background(AppColors.surfacePrimary)

            // Bottom bar: Approve (admin/unapproved) or composer
            if isAdminPendingApproval {
                FixedBottomGroup.primary(title: "Approve") {
                    feedback.approve(itemID: item.id)
                    isPresented = false
                }
            } else {
                composerBar(for: item)
            }
        }
        .background(AppColors.backgroundWhite)
        .sheet(isPresented: $showingChangeStatus) {
            ChangeStatusSheet(isPresented: $showingChangeStatus, currentStatus: item.status) { newStatus in
                feedback.setStatus(newStatus, itemID: item.id)
            }
            .presentationDetents([.height(382)])
            .presentationCornerRadius(20)
        }
        .sheet(isPresented: $showingActionSheet) {
            actionSheet(for: item)
                .presentationDetents([.height(actionSheetHeight(for: item))])
                .presentationCornerRadius(20)
        }
        .slideInSheet(isPresented: $showingEditPost) {
            AddFeedbackSheet(isPresented: $showingEditPost, editingItem: item)
        }
    }

    // MARK: - Composer

    @ViewBuilder
    private func composerBar(for item: FeedbackItem) -> some View {
        VStack(spacing: 0) {
            Divider().background(AppColors.linePrimary)

            // Context row for reply / edit
            if replyingTo != nil || editingComment != nil {
                HStack {
                    Text(editingComment != nil ? "Editing comment" : "Replying to @\(replyingTo?.authorHandle ?? "")")
                        .font(AppFonts.overusedGroteskMedium(size: 13))
                        .foregroundColor(AppColors.foregroundSecondary)
                    Spacer()
                    Button {
                        cancelComposerContext()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.foregroundTertiary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField(composerPlaceholder, text: $composeText, axis: .vertical)
                    .font(AppFonts.overusedGroteskMedium(size: 15))
                    .lineLimit(1...4)
                    .focused($composerFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.surfacePrimary)
                    )

                Button {
                    submitComposer(item: item)
                } label: {
                    AppIcon(assetName: "send-01", fallbackSystemName: "paperplane.fill", size: 22)
                        .foregroundColor(isComposeValid ? AppColors.accentBackground : AppColors.foregroundTertiary)
                        .padding(.vertical, 10)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!isComposeValid)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 34)
        }
        .background(AppColors.backgroundWhite)
    }

    private var composerPlaceholder: String {
        if editingComment != nil { return "Edit your comment" }
        if let replyingTo { return "Reply to @\(replyingTo.authorHandle)" }
        return "Add a comment"
    }

    private var isComposeValid: Bool {
        !composeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Action sheet builder

    @ViewBuilder
    private func actionSheet(for item: FeedbackItem) -> some View {
        // The overflow menu is only ever opened from a comment row, so a target
        // is always present; guard defensively and render nothing otherwise.
        if let target = actionTargetComment {
            let isOwnComment = target.authorEmail.lowercased() == feedback.currentUserEmail
            let canModify = feedback.canModifyComment(authorEmail: target.authorEmail)

            FeedbackCommentActionSheet(
                isPresented: $showingActionSheet,
                canEdit: isOwnComment,
                canDelete: canModify,
                onEdit: { startEdit(target) },
                onReply: { startReply(to: target) },
                onDelete: {
                    guard canModify else { return }
                    feedback.deleteComment(commentID: target.id, inItem: item.id)
                    toastManager.showDeleted("Comment deleted")
                }
            )
        } else {
            // Post-level menu (opened from the ⋮ in the action row).
            let isOwnPost = item.authorEmail.lowercased() == feedback.currentUserEmail
            let canModify = feedback.canModifyComment(authorEmail: item.authorEmail)

            FeedbackCommentActionSheet(
                isPresented: $showingActionSheet,
                canEdit: isOwnPost,
                canDelete: canModify,
                onEdit: { showingEditPost = true },
                onReply: { startNewComment() },
                onDelete: {
                    guard canModify else { return }
                    feedback.deleteFeedback(itemID: item.id)
                    isPresented = false
                    toastManager.showDeleted("Post deleted")
                }
            )
        }
    }

    /// Sheet height tracks how many actions are visible (Reply always; Edit/Delete only when allowed).
    private func actionSheetHeight(for item: FeedbackItem) -> CGFloat {
        let canEdit: Bool
        let canDelete: Bool
        if let target = actionTargetComment {
            canEdit = target.authorEmail.lowercased() == feedback.currentUserEmail
            canDelete = feedback.canModifyComment(authorEmail: target.authorEmail)
        } else {
            canEdit = item.authorEmail.lowercased() == feedback.currentUserEmail
            canDelete = feedback.canModifyComment(authorEmail: item.authorEmail)
        }
        let buttons = 1 + (canEdit ? 1 : 0) + (canDelete ? 1 : 0)
        return CGFloat(buttons) * 44 + CGFloat(buttons - 1) * 16 + 66
    }

    private func openPostActionSheet() {
        actionTargetComment = nil
        showingActionSheet = true
    }

    // MARK: - Intent helpers

    private func startNewComment() {
        editingComment = nil
        replyingTo = nil
        composeText = ""
        composerFocused = true
    }

    private func startReply(to comment: FeedbackComment) {
        editingComment = nil
        replyingTo = comment
        composeText = ""
        composerFocused = true
    }

    private func startEdit(_ comment: FeedbackComment) {
        replyingTo = nil
        editingComment = comment
        composeText = comment.text
        composerFocused = true
    }

    private func cancelComposerContext() {
        replyingTo = nil
        editingComment = nil
        composeText = ""
        composerFocused = false
    }

    private func openActionSheet(for comment: FeedbackComment) {
        actionTargetComment = comment
        showingActionSheet = true
    }

    private func submitComposer(item: FeedbackItem) {
        let text = composeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if let editingComment {
            feedback.editComment(commentID: editingComment.id, inItem: item.id, newText: text)
        } else if let replyingTo {
            // The @tag is handled by FeedbackManager via replyToHandle.
            feedback.addReply(text: text, toComment: replyingTo.id, inItem: item.id)
        } else {
            feedback.addComment(text: text, toItem: item.id)
        }

        composeText = ""
        replyingTo = nil
        editingComment = nil
        composerFocused = false
    }
}
