//
//  RecurringFrequencyPickerSheet.swift
//  CashMonki
//
//  Bottom sheet for selecting recurring transaction frequency
//

import SwiftUI

struct RecurringFrequencyPickerSheet: View {
    @Binding var isPresented: Bool
    @Binding var selectedFrequency: RecurringFrequency

    // Local selection state (commit on Continue)
    @State private var localSelection: RecurringFrequency

    init(isPresented: Binding<Bool>, selectedFrequency: Binding<RecurringFrequency>) {
        self._isPresented = isPresented
        self._selectedFrequency = selectedFrequency
        self._localSelection = State(initialValue: selectedFrequency.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            SheetHeader.basic(
                title: "How often does this repeat?",
                onBackTap: { isPresented = false }
            )

            // Frequency Options
            VStack(spacing: 16) {
                ForEach(RecurringFrequency.allCases, id: \.self) { frequency in
                    ChoiceTile(
                        title: frequency.displayName,
                        isSelected: localSelection == frequency,
                        onTap: {
                            localSelection = frequency
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 24)

            // Continue Button
            FixedBottomGroup.primary(
                title: "Continue",
                action: {
                    selectedFrequency = localSelection
                    isPresented = false
                }
            )
        }
        .background(Color.white)
    }
}

// MARK: - Preview

#Preview {
    RecurringFrequencyPickerSheet(
        isPresented: .constant(true),
        selectedFrequency: .constant(.monthly)
    )
}
