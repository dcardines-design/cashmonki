//
//  FeedbackInboxSheet.swift
//  CashMonki
//
//  The Feedback board entry screen: segmented tabs (Open/Done, plus New for
//  admins), a list of feedback cards, and an "Add feedback" button.
//

import SwiftUI
import UIKit

struct FeedbackInboxSheet: View {
    @Binding var isPresented: Bool

    @ObservedObject private var feedback = FeedbackManager.shared

    @State private var selectedTab: FeedbackTab = .open
    @State private var selectedItem: FeedbackItem? = nil
    @State private var showingAddFeedback = false

    private var visibleTabs: [FeedbackTab] {
        feedback.isAdmin ? [.new, .open, .done] : [.open, .done]
    }

    private var filteredItems: [FeedbackItem] {
        let all = feedback.items
        switch selectedTab {
        case .new:
            return all.filter { !$0.approved }
                .sorted { $0.createdAt > $1.createdAt }
        case .open:
            let open: [FeedbackItem]
            if feedback.isAdmin {
                open = all.filter { $0.approved && $0.status != .done }
            } else {
                // Users also see their own not-yet-approved submissions here.
                open = all.filter { ($0.approved || $0.authorEmail.lowercased() == feedback.currentUserEmail) && $0.status != .done }
            }
            // Most-upvoted first; newest breaks ties.
            return open.sorted {
                $0.upvotes != $1.upvotes ? $0.upvotes > $1.upvotes : $0.createdAt > $1.createdAt
            }
        case .done:
            return all.filter { $0.approved && $0.status == .done }
                .sorted { $0.createdAt > $1.createdAt }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader.basic(title: "Feedback Inbox") {
                isPresented = false
            }

            // Segmented tabs — same TabChip treatment as the Expense/Income/Balance filter
            HStack(spacing: 8) {
                ForEach(visibleTabs, id: \.self) { tab in
                    TabChip.basic(title: tab.rawValue, isSelected: selectedTab == tab) {
                        withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(6)
            .background(AppColors.backgroundWhite)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // List
            ScrollView(showsIndicators: false) {
                if filteredItems.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredItems) { item in
                            FeedbackCard(
                                item: item,
                                showApprove: feedback.isAdmin && selectedTab == .new,
                                onTap: { open(item) },
                                onUpvote: { feedback.toggleUpvote(itemID: item.id) },
                                onApprove: { feedback.approve(itemID: item.id) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }

            // Add feedback — bordered white container per Figma (secondary button, black icon)
            VStack(spacing: 0) {
                AppButton(
                    title: "Add feedback",
                    action: { showingAddFeedback = true },
                    hierarchy: .secondary,
                    size: .extraSmall,
                    leftIcon: "plus",
                    iconColorOverride: AppColors.foregroundPrimary
                )
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 34)
            }
            .background(AppColors.surfacePrimary)
        }
        .background(AppColors.surfacePrimary)
        .fullScreenCover(item: $selectedItem) { item in
            FeedbackPostSheet(
                itemID: item.id,
                isPresented: Binding(
                    get: { selectedItem != nil },
                    set: { if !$0 { selectedItem = nil } }
                )
            )
        }
        .slideInSheet(isPresented: $showingAddFeedback) {
            AddFeedbackSheet(isPresented: $showingAddFeedback)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundColor(AppColors.foregroundTertiary)
            Text("Nothing here yet")
                .font(AppFonts.overusedGroteskMedium(size: 16))
                .foregroundColor(AppColors.foregroundSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private func open(_ item: FeedbackItem) {
        selectedItem = item
    }
}

#Preview {
    FeedbackInboxSheet(isPresented: .constant(true))
}
