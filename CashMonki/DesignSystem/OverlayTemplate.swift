import SwiftUI

// MARK: - Overlay Template Component
struct OverlayTemplate<Content: View>: View {
    // MARK: - Properties
    let title: String
    let onBack: () -> Void
    let onConfirm: (() -> Void)?
    let confirmTitle: String
    let isConfirmEnabled: Bool
    let content: Content
    
    // Optional customization
    var showConfirmButton: Bool = true
    var backgroundColor: Color = AppColors.backgroundWhite
    var headerBackgroundColor: Color = AppColors.backgroundWhite
    var cornerRadius: CGFloat = 0
    var hasScrollView: Bool = true
    
    // MARK: - Initializer
    init(
        title: String,
        confirmTitle: String = "Confirm",
        isConfirmEnabled: Bool = true,
        onBack: @escaping () -> Void,
        onConfirm: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.confirmTitle = confirmTitle
        self.isConfirmEnabled = isConfirmEnabled
        self.onBack = onBack
        self.onConfirm = onConfirm
        self.content = content()
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Content
                contentView
                
                Spacer()
            }
            .background(backgroundColor)
            .navigationBarHidden(true)
        }
        .cornerRadius(cornerRadius)
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                // Back Button
                Button(action: onBack) {
                    Image("chevron-left")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 24, height: 24)
                        .foregroundColor(AppColors.foregroundSecondary)
                        .contentShape(Rectangle())
                }
                
                Spacer()
                
                // Title
                Text(title)
                    .font(AppFonts.overusedGroteskSemiBold(size: 18))
                    .foregroundColor(AppColors.foregroundPrimary)
                
                Spacer()
                
                // Confirm Button (if enabled)
                if showConfirmButton {
                    Button(action: onConfirm ?? {}) {
                        Text(confirmTitle)
                            .font(AppFonts.overusedGroteskSemiBold(size: 18))
                            .fontWeight(.semibold)
                            .foregroundColor(isConfirmEnabled ? AppColors.accentBackground : AppColors.foregroundSecondary)
                    }
                    .disabled(!isConfirmEnabled || onConfirm == nil)
                } else {
                    // Invisible spacer to balance the layout
                    Spacer()
                        .frame(width: 30, height: 30)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(headerBackgroundColor)
            
            // Divider
            Rectangle()
                .fill(AppColors.linePrimary)
                .frame(height: 1)
        }
    }
    
    // MARK: - Content View
    @ViewBuilder
    private var contentView: some View {
        if hasScrollView {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    content
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 20)
            }
        } else {
            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Overlay Template Modifiers
extension OverlayTemplate {
    // Modifier for customizing appearance
    func overlayStyle(
        backgroundColor: Color = AppColors.backgroundWhite,
        headerBackgroundColor: Color = AppColors.backgroundWhite,
        cornerRadius: CGFloat = 0,
        hasScrollView: Bool = true,
        showConfirmButton: Bool = true
    ) -> OverlayTemplate {
        var template = self
        template.backgroundColor = backgroundColor
        template.headerBackgroundColor = headerBackgroundColor
        template.cornerRadius = cornerRadius
        template.hasScrollView = hasScrollView
        template.showConfirmButton = showConfirmButton
        return template
    }
}

// MARK: - Convenience Templates

// Modal-style overlay with rounded corners
struct ModalOverlayTemplate<Content: View>: View {
    let title: String
    let onBack: () -> Void
    let onConfirm: (() -> Void)?
    let confirmTitle: String
    let isConfirmEnabled: Bool
    let content: Content
    
    init(
        title: String,
        confirmTitle: String = "Confirm",
        isConfirmEnabled: Bool = true,
        onBack: @escaping () -> Void,
        onConfirm: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.confirmTitle = confirmTitle
        self.isConfirmEnabled = isConfirmEnabled
        self.onBack = onBack
        self.onConfirm = onConfirm
        self.content = content()
    }
    
    var body: some View {
        OverlayTemplate(
            title: title,
            confirmTitle: confirmTitle,
            isConfirmEnabled: isConfirmEnabled,
            onBack: onBack,
            onConfirm: onConfirm
        ) {
            content
        }
        .overlayStyle(
            backgroundColor: AppColors.backgroundWhite,
            headerBackgroundColor: AppColors.backgroundWhite,
            cornerRadius: 16,
            hasScrollView: true
        )
    }
}

// Full-screen overlay (like current confirmation screen)
struct FullScreenOverlayTemplate<Content: View>: View {
    let title: String
    let onBack: () -> Void
    let onConfirm: (() -> Void)?
    let confirmTitle: String
    let isConfirmEnabled: Bool
    let content: Content
    
    init(
        title: String,
        confirmTitle: String = "Confirm",
        isConfirmEnabled: Bool = true,
        onBack: @escaping () -> Void,
        onConfirm: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.confirmTitle = confirmTitle
        self.isConfirmEnabled = isConfirmEnabled
        self.onBack = onBack
        self.onConfirm = onConfirm
        self.content = content()
    }
    
    var body: some View {
        OverlayTemplate(
            title: title,
            confirmTitle: confirmTitle,
            isConfirmEnabled: isConfirmEnabled,
            onBack: onBack,
            onConfirm: onConfirm
        ) {
            content
        }
        .overlayStyle(
            backgroundColor: AppColors.backgroundWhite,
            headerBackgroundColor: AppColors.backgroundWhite,
            cornerRadius: 0,
            hasScrollView: true
        )
    }
}

// Settings-style overlay with no confirm button
struct SettingsOverlayTemplate<Content: View>: View {
    let title: String
    let onBack: () -> Void
    let content: Content
    
    init(
        title: String,
        onBack: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.onBack = onBack
        self.content = content()
    }
    
    var body: some View {
        OverlayTemplate(
            title: title,
            onBack: onBack
        ) {
            content
        }
        .overlayStyle(
            backgroundColor: AppColors.backgroundWhite,
            headerBackgroundColor: AppColors.backgroundWhite,
            showConfirmButton: false
        )
    }
}

// MARK: - Preview
struct OverlayTemplate_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Full Screen Template
            FullScreenOverlayTemplate(
                title: "Confirm Transaction",
                confirmTitle: "Save",
                isConfirmEnabled: true,
                onBack: {},
                onConfirm: {}
            ) {
                VStack(spacing: 24) {
                    Text("Sample content for full screen overlay")
                        .font(AppFonts.overusedGroteskMedium(size: 16))
                    
                    AppInputField.merchant(text: .constant("Sample Store"))
                }
            }
            .previewDisplayName("Full Screen Template")
            
            // Modal Template
            ModalOverlayTemplate(
                title: "Edit Details",
                onBack: {},
                onConfirm: {}
            ) {
                VStack(spacing: 16) {
                    Text("Sample modal content")
                        .font(AppFonts.overusedGroteskMedium(size: 16))
                    
                    AppButton.primary("Sample Button") {}
                }
            }
            .previewDisplayName("Modal Template")
            
            // Settings Template
            SettingsOverlayTemplate(
                title: "Settings",
                onBack: {}
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Setting Option 1")
                        .font(AppFonts.overusedGroteskMedium(size: 16))
                    
                    Text("Setting Option 2")
                        .font(AppFonts.overusedGroteskMedium(size: 16))
                }
            }
            .previewDisplayName("Settings Template")
        }
    }
}