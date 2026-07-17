//
//  FeedbackCommentActionSheet.swift
//  CashMonki
//
//  Bottom action menu for a comment: Edit / Reply / Delete.
//  Edit is disabled when the current user isn't the author; Delete is shown
//  destructive (red) for admins moderating others' comments.
//

import SwiftUI

struct FeedbackCommentActionSheet: View {
    @Binding var isPresented: Bool
    /// Edit is only offered on the user's own post/comment; Delete also for admins.
    let canEdit: Bool
    let canDelete: Bool
    let onEdit: () -> Void
    let onReply: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            if canEdit {
                AppButton(
                    title: "Edit",
                    action: { dismissThen(onEdit) },
                    hierarchy: .secondary,
                    size: .doubleExtraSmall
                )
            }

            AppButton(
                title: "Reply",
                action: { dismissThen(onReply) },
                hierarchy: .secondary,
                size: .doubleExtraSmall
            )

            if canDelete {
                AppButton(
                    title: "Delete",
                    action: { dismissThen(onDelete) },
                    hierarchy: .secondary,
                    size: .doubleExtraSmall,
                    textColorOverride: AppColors.destructiveForeground
                )
            }
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(AppColors.backgroundWhite)
    }

    private func dismissThen(_ action: @escaping () -> Void) {
        isPresented = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            action()
        }
    }
}

#Preview {
    FeedbackCommentActionSheet(
        isPresented: .constant(true),
        canEdit: true,
        canDelete: true,
        onEdit: {}, onReply: {}, onDelete: {}
    )
}
