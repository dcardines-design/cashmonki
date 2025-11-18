import SwiftUI

// MARK: - Tab States
enum TabState {
    case selected    // Currently selected tab (black text with blue underline)
    case inactive    // Not selected, normal state (gray text, no underline)
    case hover       // Hover state (for interactions)
}

// MARK: - App Tab Component
struct AppTab: View {
    // MARK: - Properties
    let title: String
    let action: () -> Void
    
    var state: TabState = .inactive
    var leftIcon: String? = nil
    var rightIcon: String? = nil
    var isEnabled: Bool = true
    
    // MARK: - Internal State
    @State private var isPressed: Bool = false
    
    // MARK: - Computed Properties
    private var currentState: TabState {
        if !isEnabled { return .inactive }
        if isPressed { return .hover }
        return state
    }
    
    private var backgroundColor: Color {
        // No background for any state - clean design
        return Color.clear
    }
    
    private var textColor: Color {
        switch currentState {
        case .selected:
            return AppColors.foregroundPrimary  // Black text
        case .inactive:
            return AppColors.foregroundSecondary  // Gray text
        case .hover:
            return AppColors.foregroundPrimary
        }
    }
    
    private var underlineColor: Color {
        switch currentState {
        case .selected:
            return AppColors.accentBackground  // Blue underline
        case .inactive, .hover:
            return Color.clear
        }
    }
    
    private var hasUnderline: Bool {
        currentState == .selected
    }
    
    // MARK: - Body
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    // Left Icon
                    if let leftIcon = leftIcon {
                        Image(systemName: leftIcon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(textColor)
                            .opacity(isEnabled ? 1.0 : 0.5)
                    }
                    
                    // Title
                    Text(title)
                        .font(AppFonts.overusedGroteskMedium(size: 18))
                        .foregroundColor(textColor)
                        .opacity(isEnabled ? 1.0 : 0.5)
                        .transaction { transaction in
                            transaction.disablesAnimations = true
                        }
                    
                    // Right Icon
                    if let rightIcon = rightIcon {
                        Image(systemName: rightIcon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(textColor)
                            .opacity(isEnabled ? 1.0 : 0.5)
                    }
                }
                .padding(.horizontal, 12)  // Reduced horizontal padding to hug content
                .padding(.top, 12)
                .padding(.bottom, 18)  // 18px space between text and underline
                
                // Underline - positioned at very bottom, matches text width
                Rectangle()
                    .fill(underlineColor)
                    .frame(height: hasUnderline ? 3 : 0)  // 3px for selected tab
                    .padding(.horizontal, 12)  // Match the text padding
                    .transaction { transaction in
                        transaction.disablesAnimations = true
                    }
            }
        }
        .disabled(!isEnabled)
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .transaction { transaction in
            transaction.disablesAnimations = true
        }
        .animation(.none, value: currentState)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
}

// MARK: - Convenience Initializers
extension AppTab {
    // Selected tab (black text with blue underline)
    static func selected(
        _ title: String,
        leftIcon: String? = nil,
        rightIcon: String? = nil,
        action: @escaping () -> Void
    ) -> AppTab {
        AppTab(
            title: title,
            action: action,
            state: .selected,
            leftIcon: leftIcon,
            rightIcon: rightIcon
        )
    }
    
    // Inactive tab (gray text, no underline)
    static func inactive(
        _ title: String,
        leftIcon: String? = nil,
        rightIcon: String? = nil,
        action: @escaping () -> Void
    ) -> AppTab {
        AppTab(
            title: title,
            action: action,
            state: .inactive,
            leftIcon: leftIcon,
            rightIcon: rightIcon
        )
    }
}

// MARK: - Tab Group Component
struct AppTabGroup: View {
    let tabs: [TabItem]
    @Binding var selectedIndex: Int
    
    struct TabItem {
        let title: String
        let leftIcon: String?
        let rightIcon: String?
        let action: (() -> Void)?
        
        init(title: String, leftIcon: String? = nil, rightIcon: String? = nil, action: (() -> Void)? = nil) {
            self.title = title
            self.leftIcon = leftIcon
            self.rightIcon = rightIcon
            self.action = action
        }
    }
    
    var body: some View {
        HStack(spacing: 24) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                AppTab(
                    title: tab.title,
                    action: {
                        selectedIndex = index
                        tab.action?()
                    },
                    state: selectedIndex == index ? .selected : .inactive,
                    leftIcon: tab.leftIcon,
                    rightIcon: tab.rightIcon
                )
            }
        }
    }
}

// MARK: - Preview
struct AppTab_Previews: PreviewProvider {
    @State static var selectedTab = 0
    
    static var previews: some View {
        VStack(spacing: 32) {
            // Individual tabs
            VStack(spacing: 16) {
                Text("Individual Tabs")
                    .font(AppFonts.overusedGroteskSemiBold(size: 18))
                
                HStack(spacing: 12) {
                    AppTab.selected("Selected") { }
                    AppTab.inactive("Inactive") { }
                }
                
                HStack(spacing: 12) {
                    AppTab.selected("With Icons", leftIcon: "star.fill", rightIcon: "chevron.down") { }
                    AppTab.inactive("With Icons", leftIcon: "heart", rightIcon: "arrow.right") { }
                }
            }
            
            // Tab group
            VStack(spacing: 16) {
                Text("Tab Group")
                    .font(AppFonts.overusedGroteskSemiBold(size: 18))
                
                AppTabGroup(
                    tabs: [
                        AppTabGroup.TabItem(title: "Today"),
                        AppTabGroup.TabItem(title: "Week"),
                        AppTabGroup.TabItem(title: "Month"),
                        AppTabGroup.TabItem(title: "Year")
                    ],
                    selectedIndex: .constant(1)
                )
            }
        }
        .padding(32)
        .background(AppColors.surfacePrimary)
        .previewLayout(.sizeThatFits)
    }
}