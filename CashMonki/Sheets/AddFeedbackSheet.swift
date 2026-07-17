//
//  AddFeedbackSheet.swift
//  CashMonki
//
//  Sheet for submitting a new feedback / feature request.
//

import SwiftUI

struct AddFeedbackSheet: View {
    @Binding var isPresented: Bool
    /// When set, the sheet edits this existing post instead of creating one.
    var editingItem: FeedbackItem? = nil
    @ObservedObject private var feedback = FeedbackManager.shared
    @EnvironmentObject private var toastManager: ToastManager

    @State private var title: String = ""
    @State private var detail: String = ""
    @FocusState private var isTitleFocused: Bool

    init(isPresented: Binding<Bool>, editingItem: FeedbackItem? = nil) {
        self._isPresented = isPresented
        self.editingItem = editingItem
        self._title = State(initialValue: editingItem?.title ?? "")
        self._detail = State(initialValue: editingItem?.detail ?? "")
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader.basic(title: editingItem == nil ? "Add Feedback" : "Edit Feedback") {
                isPresented = false
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    AppInputField.text(
                        title: "Title",
                        text: $title,
                        placeholder: "What would you like to see?",
                        size: .md,
                        focusBinding: $isTitleFocused
                    )

                    AppInputField.multiline(
                        title: "Description",
                        text: $detail,
                        placeholder: "Add more detail (optional)",
                        size: .md
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 100)
            }

            FixedBottomGroup.primary(
                title: editingItem == nil ? "Submit feedback" : "Save changes",
                action: {
                    if let editingItem {
                        feedback.editFeedback(itemID: editingItem.id, title: title, detail: detail)
                        isPresented = false
                        toastManager.showSuccess("Feedback updated!")
                    } else {
                        feedback.addFeedback(title: title, detail: detail)
                        isPresented = false
                        toastManager.showSuccess("Feedback submitted!")
                    }
                },
                isEnabled: isValid
            )
        }
        .background(AppColors.backgroundWhite)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTitleFocused = true
            }
        }
    }
}

#Preview {
    AddFeedbackSheet(isPresented: .constant(true))
}
