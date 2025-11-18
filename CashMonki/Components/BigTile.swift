import SwiftUI

// MARK: - Scanner Frame Icon

struct ScannerFrameIcon: View {
    var body: some View {
        ZStack {
            // Corner brackets
            VStack {
                HStack {
                    TopLeftCorner()
                    Spacer()
                    TopRightCorner()
                }
                Spacer()
                HStack {
                    BottomLeftCorner()
                    Spacer()
                    BottomRightCorner()
                }
            }
            .frame(width: 30, height: 30)
            
            // Center dots
            HStack(spacing: 6.375) {
                ForEach(0..<5, id: \.self) { _ in
                    Circle()
                        .fill(Color(red: 0.329, green: 0.180, blue: 1.0))
                        .frame(width: 2.84, height: 2.84)
                }
            }
        }
    }
}

struct TopLeftCorner: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 8.167))
            path.addLine(to: CGPoint(x: 0, y: 2.833))
            path.addQuadCurve(
                to: CGPoint(x: 2.833, y: 0),
                control: CGPoint(x: 0, y: 0)
            )
            path.addLine(to: CGPoint(x: 8.167, y: 0))
        }
        .stroke(Color(red: 0.329, green: 0.180, blue: 1.0), lineWidth: 1.417)
        .frame(width: 8.167, height: 8.167)
    }
}

struct TopRightCorner: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 5.334, y: 0))
            path.addQuadCurve(
                to: CGPoint(x: 8.167, y: 2.833),
                control: CGPoint(x: 8.167, y: 0)
            )
            path.addLine(to: CGPoint(x: 8.167, y: 8.167))
        }
        .stroke(Color(red: 0.329, green: 0.180, blue: 1.0), lineWidth: 1.417)
        .frame(width: 8.167, height: 8.167)
    }
}

struct BottomLeftCorner: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 8.167, y: 8.167))
            path.addLine(to: CGPoint(x: 2.833, y: 8.167))
            path.addQuadCurve(
                to: CGPoint(x: 0, y: 5.334),
                control: CGPoint(x: 0, y: 8.167)
            )
            path.addLine(to: CGPoint(x: 0, y: 0))
        }
        .stroke(Color(red: 0.329, green: 0.180, blue: 1.0), lineWidth: 1.417)
        .frame(width: 8.167, height: 8.167)
    }
}

struct BottomRightCorner: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 5.334))
            path.addQuadCurve(
                to: CGPoint(x: 2.833, y: 8.167),
                control: CGPoint(x: 0, y: 8.167)
            )
            path.addLine(to: CGPoint(x: 8.167, y: 8.167))
        }
        .stroke(Color(red: 0.329, green: 0.180, blue: 1.0), lineWidth: 1.417)
        .frame(width: 8.167, height: 8.167)
    }
}

// MARK: - Big Tile Component

struct BigTile: View {
    let icon: AnyView
    let title: String
    let isLoading: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    init(
        icon: AnyView,
        title: String,
        isLoading: Bool = false,
        onTap: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.isLoading = isLoading
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .center, spacing: 8) {
                icon
                
                Text(title)
                    .font(AppFonts.overusedGroteskSemiBold(size: 17))
                    .foregroundStyle(isLoading ? .secondary : AppColors.foregroundPrimary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
            .background(isPressed ? AppColors.surfacePrimary : .white)
            .cornerRadius(isPressed ? 14 : 12)
            .shadow(
                color: isPressed ? .clear : Color(red: 0.86, green: 0.89, blue: 0.96),
                radius: isPressed ? 0 : 0,
                x: 0,
                y: isPressed ? 0 : 4
            )
            .overlay(
                RoundedRectangle(cornerRadius: isPressed ? 14 : 12)
                    .inset(by: 0.5)
                    .stroke(AppColors.linePrimary, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Convenience Initializers

extension BigTile {
    // For standard icon tiles (like Add Transaction)
    static func icon(
        assetName: String,
        fallbackSystemName: String,
        title: String,
        isLoading: Bool = false,
        onTap: @escaping () -> Void
    ) -> BigTile {
        let iconColor = if isLoading {
            Color.secondary
        } else if assetName == "scan" || assetName == "upload-01" || assetName == "upload-cloud-01" || assetName == "upload-02" {
            Color(red: 0.329, green: 0.180, blue: 1.0) // Blue color for scan and upload icons
        } else {
            AppColors.primary
        }
        
        let iconView = AnyView(
            AppIcon(assetName: assetName, fallbackSystemName: fallbackSystemName)
                .font(AppFonts.overusedGroteskSemiBold(size: 28))
                .foregroundStyle(iconColor)
        )
        
        return BigTile(
            icon: iconView,
            title: title,
            isLoading: isLoading,
            onTap: onTap
        )
    }
    
    // For custom icon tiles (like Upload Receipt with scanner frame)
    static func customIcon<Content: View>(
        @ViewBuilder icon: () -> Content,
        title: String,
        isLoading: Bool = false,
        onTap: @escaping () -> Void
    ) -> BigTile {
        return BigTile(
            icon: AnyView(icon()),
            title: title,
            isLoading: isLoading,
            onTap: onTap
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        // Standard icon tile
        BigTile.icon(
            assetName: "plus",
            fallbackSystemName: "plus",
            title: "Add Transaction"
        ) {
            print("Add Transaction tapped")
        }
        
        // Custom icon tile
        BigTile.customIcon(
            icon: {
                ScannerFrameIcon()
            },
            title: "Upload Receipt"
        ) {
            print("Upload Receipt tapped")
        }
        
        // Loading state
        BigTile.icon(
            assetName: "scan",
            fallbackSystemName: "qrcode.viewfinder",
            title: "Processing...",
            isLoading: true
        ) {
            print("Processing tapped")
        }
    }
    .padding()
    .background(Color(UIColor.systemGray6))
}