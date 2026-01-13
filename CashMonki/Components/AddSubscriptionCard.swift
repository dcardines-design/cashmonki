//
//  AddSubscriptionCard.swift
//  CashMonki
//
//  Card component for adding new subscriptions
//

import SwiftUI

struct AddSubscriptionCard: View {
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        // Main card content
        VStack(alignment: .leading, spacing: 8) {
            // Plus icon at top
            AppIcon(assetName: "plus", fallbackSystemName: "plus")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(AppColors.primary)

            // Text content - 8px below icon
            Text("Add Recurring or Subscriptions")
                .font(AppFonts.overusedGroteskSemiBold(size: 16))
                .foregroundColor(AppColors.foregroundPrimary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(AppColors.backgroundWhite)
        // Recurring tile image - adapts to card height
        .overlay(alignment: .topTrailing) {
            GeometryReader { geometry in
                if let image = loadRecurringTileImage() {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: geometry.size.height)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color(red: 0.86, green: 0.89, blue: 0.96), radius: 0, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .inset(by: 0.5)
                .stroke(AppColors.linePrimary, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }

    // Load the recurring tile image from File Assets
    private func loadRecurringTileImage() -> UIImage? {
        if let path = Bundle.main.path(forResource: "recurring tile image (2)", ofType: "png") {
            return UIImage(contentsOfFile: path)
        }
        return nil
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AppColors.surfacePrimary.ignoresSafeArea()

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            AddSubscriptionCard {
                print("Add subscription tapped")
            }
            .frame(height: 140)

            AddSubscriptionCard {
                print("Add subscription tapped")
            }
            .frame(height: 140)
        }
        .padding(20)
    }
}
