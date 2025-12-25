import SwiftUI

// MARK: - Button Enums
enum ButtonHierarchy {
    case primary    // 1st - Purple background
    case secondary  // 2nd - White background, purple text
    case tertiary   // 3rd - White background, black text
    case ghost      // 4th - No background, black text
    case text       // 5th - Text only, underlined on hover
}

enum ButtonSize {
    case medium           // med - 24px text, 30px icons
    case small            // sm - 20px text, 28px icons
    case extraSmall       // xs - 18px text, 24px icons
    case doubleExtraSmall // 2xs - 18px text, 14px h-padding, 10px v-padding
}

enum ButtonState {
    case active
    case hover
    case pressed
    case disabled
}

// MARK: - App Button Component
struct AppButton: View {
    // MARK: - Properties
    let title: String
    let action: () -> Void

    var hierarchy: ButtonHierarchy = .primary
    var size: ButtonSize = .medium
    var state: ButtonState = .active
    var leftIcon: String? = nil
    var rightIcon: String? = nil
    var isEnabled: Bool = true
    var iconColorOverride: Color? = nil  // Optional override for icon color

    // MARK: - Custom SVG Icon Names (UIImage doesn't detect SVGs in asset catalogs)
    private static let customIconNames: Set<String> = [
        "plus",
        "arrow-narrow-left",
        "edit-02",
        "clock-refresh",
        "horizontal-bar-chart-03",
        "chevron-left",
        "chevron-right"
    ]

    // MARK: - Internal State
    @State private var isPressed: Bool = false
    
    // MARK: - Computed Properties
    private var buttonState: ButtonState {
        if !isEnabled { return .disabled }
        if isPressed { return .pressed }
        return state
    }
    
    private var textSize: CGFloat {
        switch size {
        case .medium: return 24
        case .small: return 20
        case .extraSmall: return 18
        case .doubleExtraSmall: return 18
        }
    }
    
    private var iconSize: CGFloat {
        switch size {
        case .medium: return 30
        case .small: return 28
        case .extraSmall: return 40  // 40 * 0.6 = 24px actual
        case .doubleExtraSmall: return 40  // 40 * 0.6 = 24px actual
        }
    }
    
    private var cornerRadius: CGFloat {
        switch size {
        case .medium, .small: return 14
        case .extraSmall: return 12
        case .doubleExtraSmall: return 10
        }
    }
    
    private var horizontalPadding: CGFloat {
        switch size {
        case .medium: return 24
        case .small: return 18
        case .extraSmall: return 16
        case .doubleExtraSmall: return 14
        }
    }
    
    private var verticalPadding: CGFloat {
        switch size {
        case .medium: return 14
        case .small: return 12
        case .extraSmall: return 12
        case .doubleExtraSmall: return 10
        }
    }
    
    private var backgroundColor: Color {
        switch (hierarchy, buttonState) {
        case (.primary, .active):
            return AppColors.accentBackground
        case (.primary, .hover):
            return Color(red: 0x36/255.0, green: 0x10/255.0, blue: 0xe1/255.0) // Hover color
        case (.primary, .pressed):
            return AppColors.accentHoverFill
        case (.primary, .disabled):
            return Color(red: 0x36/255.0, green: 0x10/255.0, blue: 0xe1/255.0) // AccentDarkBackground equivalent
            
        case (.secondary, .active), (.secondary, .hover):
            return AppColors.backgroundWhite
        case (.secondary, .pressed):
            return AppColors.surfacePrimary
        case (.secondary, .disabled):
            return AppColors.surfacePrimary // Same as pressed state
            
        case (.tertiary, .active):
            return AppColors.backgroundWhite
        case (.tertiary, .hover):
            return AppColors.surfacePrimary
        case (.tertiary, .pressed):
            return AppColors.surfacePrimary
        case (.tertiary, .disabled):
            return AppColors.surfacePrimary // Same as pressed state
            
        case (.ghost, .active), (.ghost, .pressed):
            return AppColors.backgroundWhite
        case (.ghost, .hover):
            return AppColors.surfacePrimary
        case (.ghost, .disabled):
            return AppColors.backgroundWhite // Same as pressed state
            
        case (.text, .active), (.text, .pressed):
            return Color.clear
        case (.text, .hover):
            return Color.clear
        case (.text, .disabled):
            return Color.clear // Same as pressed state
        }
    }
    
    private var textColor: Color {
        switch (hierarchy, buttonState) {
        case (.primary, _):
            return AppColors.backgroundWhite

        case (.secondary, .active), (.secondary, .hover), (.secondary, .pressed):
            return AppColors.foregroundPrimary  // Black text for secondary
        case (.secondary, .disabled):
            return AppColors.foregroundTertiary

        case (.tertiary, .active), (.tertiary, .hover), (.tertiary, .pressed):
            return AppColors.foregroundPrimary
        case (.tertiary, .disabled):
            return AppColors.foregroundPrimary // Same as pressed state

        case (.ghost, .active), (.ghost, .hover), (.ghost, .pressed):
            return AppColors.foregroundPrimary
        case (.ghost, .disabled):
            return AppColors.foregroundPrimary // Same as pressed state

        case (.text, .active), (.text, .hover), (.text, .pressed):
            return AppColors.foregroundPrimary
        case (.text, .disabled):
            return AppColors.foregroundPrimary // Same as pressed state
        }
    }

    private var iconColor: Color {
        // Use override if provided
        if let override = iconColorOverride {
            return buttonState == .disabled ? AppColors.foregroundTertiary : override
        }

        switch (hierarchy, buttonState) {
        case (.primary, _):
            return AppColors.backgroundWhite

        case (.secondary, .active), (.secondary, .hover), (.secondary, .pressed):
            return AppColors.primary  // Purple icons for secondary
        case (.secondary, .disabled):
            return AppColors.foregroundTertiary

        default:
            return textColor  // All other cases use same color as text
        }
    }
    
    private var borderColor: Color {
        switch (hierarchy, buttonState) {
        case (.primary, .active):
            return Color(red: 0x2c/255.0, green: 0x06/255.0, blue: 0xd7/255.0) // Border color
        case (.primary, .hover):
            return AppColors.accentBackground
        case (.primary, .pressed):
            return Color.clear
        case (.primary, .disabled):
            return AppColors.line1stLine // Use line color for disabled border
            
        case (.secondary, .active), (.secondary, .pressed):
            return AppColors.line1stLine
        case (.secondary, .hover):
            return AppColors.accentBackground
        case (.secondary, .disabled):
            return AppColors.line1stLine // Same as pressed state
            
        case (.tertiary, _):
            return Color.clear
            
        case (.ghost, _), (.text, _):
            return Color.clear
        }
    }
    
    private var shadowColor: Color {
        switch (hierarchy, buttonState) {
        case (.primary, .active), (.primary, .hover):
            return Color(red: 0x2c/255.0, green: 0x06/255.0, blue: 0xd7/255.0) // #2C06D7
        case (.secondary, .active), (.secondary, .hover):
            return AppColors.line1stLine // #dce2f4
        case (.tertiary, .active), (.tertiary, .hover):
            return Color.clear
        default:
            return Color.clear
        }
    }
    
    private var hasShadow: Bool {
        switch (hierarchy, buttonState) {
        case (.primary, .active), (.primary, .hover):
            return true
        case (.primary, .pressed):
            return false
        case (.secondary, .active), (.secondary, .hover):
            return true
        case (.secondary, .pressed):
            return false
        case (.tertiary, _):
            return false
        case (.ghost, _), (.text, _), (_, .disabled):
            return false
        }
    }
    
    private var isTextUnderlined: Bool {
        hierarchy == .text && buttonState == .hover
    }
    
    // MARK: - Body
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Left Icon
                if let leftIcon = leftIcon {
                    // Try custom asset first, fallback to system icon
                    if Self.customIconNames.contains(leftIcon) || UIImage(named: leftIcon) != nil {
                        Image(leftIcon)
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: iconSize * 0.6, height: iconSize * 0.6)
                            .foregroundColor(iconColor)
                    } else {
                        Image(systemName: leftIcon)
                            .font(.system(size: iconSize * 0.6, weight: .medium))
                            .foregroundColor(iconColor)
                    }
                }
                
                // Title (only show if not empty)
                if !title.isEmpty {
                    Text(title)
                        .font(AppFonts.overusedGroteskSemiBold(size: textSize))
                        .fontWeight(.semibold)
                        .foregroundColor(textColor)
                        .underline(isTextUnderlined)
                }
                
                // Right Icon
                if let rightIcon = rightIcon {
                    // Try custom asset first, fallback to system icon
                    if Self.customIconNames.contains(rightIcon) || UIImage(named: rightIcon) != nil {
                        Image(rightIcon)
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: iconSize * 0.6, height: iconSize * 0.6)
                            .foregroundColor(iconColor)
                    } else {
                        Image(systemName: rightIcon)
                            .font(.system(size: iconSize * 0.6, weight: .medium))
                            .foregroundColor(iconColor)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .shadow(
                color: hierarchy == .primary && buttonState == .active ? 
                    Color(red: 0.17, green: 0.02, blue: 0.84) : (hasShadow ? shadowColor : Color.clear),
                radius: 0,
                x: 0,
                y: hasShadow ? 4 : 0
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .inset(by: 0.5)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .disabled(!isEnabled)
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .opacity(buttonState == .disabled ? 0.8 : 1.0) // 80% opacity for disabled state
        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {
            // This executes when long press completes, but we handle the action in the Button above
        })
        .animation(.easeInOut(duration: 0.1), value: buttonState)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
}

// MARK: - Convenience Initializers
extension AppButton {
    // Primary button
    static func primary(
        _ title: String,
        size: ButtonSize = .medium,
        leftIcon: String? = nil,
        rightIcon: String? = nil,
        action: @escaping () -> Void
    ) -> AppButton {
        AppButton(
            title: title,
            action: action,
            hierarchy: .primary,
            size: size,
            leftIcon: leftIcon,
            rightIcon: rightIcon
        )
    }
    
    // Secondary button
    static func secondary(
        _ title: String,
        size: ButtonSize = .medium,
        leftIcon: String? = nil,
        rightIcon: String? = nil,
        action: @escaping () -> Void
    ) -> AppButton {
        AppButton(
            title: title,
            action: action,
            hierarchy: .secondary,
            size: size,
            leftIcon: leftIcon,
            rightIcon: rightIcon
        )
    }
    
    // Tertiary button
    static func tertiary(
        _ title: String,
        size: ButtonSize = .medium,
        leftIcon: String? = nil,
        rightIcon: String? = nil,
        action: @escaping () -> Void
    ) -> AppButton {
        AppButton(
            title: title,
            action: action,
            hierarchy: .tertiary,
            size: size,
            leftIcon: leftIcon,
            rightIcon: rightIcon
        )
    }
    
    // Ghost button
    static func ghost(
        _ title: String,
        size: ButtonSize = .medium,
        leftIcon: String? = nil,
        rightIcon: String? = nil,
        action: @escaping () -> Void
    ) -> AppButton {
        AppButton(
            title: title,
            action: action,
            hierarchy: .ghost,
            size: size,
            leftIcon: leftIcon,
            rightIcon: rightIcon
        )
    }
    
    // Text button
    static func text(
        _ title: String,
        size: ButtonSize = .medium,
        leftIcon: String? = nil,
        rightIcon: String? = nil,
        action: @escaping () -> Void
    ) -> AppButton {
        AppButton(
            title: title,
            action: action,
            hierarchy: .text,
            size: size,
            leftIcon: leftIcon,
            rightIcon: rightIcon
        )
    }
}

// MARK: - Preview
struct AppButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Primary buttons
            HStack(spacing: 15) {
                AppButton.primary("Edit", size: .medium, leftIcon: "arrow.left", rightIcon: "arrow.right") { }
                AppButton.primary("Edit", size: .small, leftIcon: "arrow.left", rightIcon: "arrow.right") { }
                AppButton.primary("Edit", size: .extraSmall, leftIcon: "arrow.left", rightIcon: "arrow.right") { }
            }
            
            // Secondary buttons
            HStack(spacing: 15) {
                AppButton.secondary("Edit", size: .medium, leftIcon: "arrow.left", rightIcon: "arrow.right") { }
                AppButton.secondary("Edit", size: .small, leftIcon: "arrow.left", rightIcon: "arrow.right") { }
                AppButton.secondary("Edit", size: .extraSmall, leftIcon: "arrow.left", rightIcon: "arrow.right") { }
            }
            
            // Tertiary buttons
            HStack(spacing: 15) {
                AppButton.tertiary("Edit", size: .medium, leftIcon: "arrow.left", rightIcon: "arrow.right") { }
                AppButton.tertiary("Edit", size: .small, leftIcon: "arrow.left", rightIcon: "arrow.right") { }
                AppButton.tertiary("Edit", size: .extraSmall, leftIcon: "arrow.left", rightIcon: "arrow.right") { }
            }
            
            // Ghost buttons
            HStack(spacing: 15) {
                AppButton.ghost("Edit", size: .medium, leftIcon: "arrow.left", rightIcon: "arrow.right") { }
                AppButton.ghost("Edit", size: .small, leftIcon: "arrow.left", rightIcon: "arrow.right") { }
                AppButton.ghost("Edit", size: .extraSmall, leftIcon: "arrow.left", rightIcon: "arrow.right") { }
            }
            
            // Text buttons
            HStack(spacing: 15) {
                AppButton.text("Edit", size: .medium, leftIcon: "arrow.left", rightIcon: "arrow.right") { }
                AppButton.text("Edit", size: .small, leftIcon: "arrow.left", rightIcon: "arrow.right") { }
                AppButton.text("Edit", size: .extraSmall, leftIcon: "arrow.left", rightIcon: "arrow.right") { }
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
