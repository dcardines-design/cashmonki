import SwiftUI

enum AppColors {
    // MARK: - Foreground Colors
    /// Primary text color - #000000
    static let foregroundPrimary = Color(red: 0x00/255.0, green: 0x00/255.0, blue: 0x00/255.0)
    
    /// Secondary text color - #72788a
    static let foregroundSecondary = Color(red: 0x72/255.0, green: 0x78/255.0, blue: 0x8a/255.0)
    
    /// Tertiary text color - #a0a6b8
    static let foregroundTertiary = Color(red: 0xa0/255.0, green: 0xa6/255.0, blue: 0xb8/255.0)
    
    // MARK: - Accent Colors
    /// Accent/Primary brand color - #542eff
    static let accentBackground = Color(red: 0x54/255.0, green: 0x2e/255.0, blue: 0xff/255.0)
    
    /// Accent hover/pressed fill color - #3610e1
    static let accentHoverFill = Color(red: 0x36/255.0, green: 0x10/255.0, blue: 0xe1/255.0)
    
    // MARK: - Line/Border Colors
    /// Primary border/line color - #dce2f4
    static let linePrimary = Color(red: 0xdc/255.0, green: 0xe2/255.0, blue: 0xf4/255.0)
    
    /// Line 1st Line (alias for linePrimary)
    static let line1stLine = linePrimary
    
    // MARK: - Surface Colors
    /// Primary surface/background color - #f3f5f8
    static let surfacePrimary = Color(red: 0xf3/255.0, green: 0xf5/255.0, blue: 0xf8/255.0)
    
    /// Secondary surface color - #e5e7eb
    static let surfaceSecondary = Color(red: 0xe5/255.0, green: 0xe7/255.0, blue: 0xeb/255.0)
    
    // MARK: - Background Colors
    /// Pure white background - #ffffff
    static let backgroundWhite = Color(red: 0xff/255.0, green: 0xff/255.0, blue: 0xff/255.0)
    
    /// Secondary background color - #f8f9fa
    static let backgroundSecondary = Color(red: 0xf8/255.0, green: 0xf9/255.0, blue: 0xfa/255.0)
    
    /// Foreground white (alias for backgroundWhite)
    static let foregroundWhite = backgroundWhite
    
    // MARK: - Destructive/Error Colors
    /// Error/destructive action color - #de4706
    static let destructiveForeground = Color(red: 0xde/255.0, green: 0x47/255.0, blue: 0x06/255.0)
    
    /// Error/destructive background color (light red) - #fef2f2
    static let errorBackground = Color(red: 0xfe/255.0, green: 0xf2/255.0, blue: 0xf2/255.0)
    
    /// Error foreground (alias for destructiveForeground)
    static let errorForeground = destructiveForeground
    
    // MARK: - Success Colors
    /// Success/positive action color - #08AD93
    static let successForeground = Color(red: 0x08/255.0, green: 0xad/255.0, blue: 0x93/255.0)
    
    /// Success background color (light green) - #f0f9f0
    static let successBackground = Color(red: 0xf0/255.0, green: 0xf9/255.0, blue: 0xf0/255.0)
    
    // MARK: - QA System Accent Colors
    /// Accent green for success states - #08AD93
    static let accentGreen = Color(red: 0x08/255.0, green: 0xad/255.0, blue: 0x93/255.0)
    
    /// Accent red for error/critical states - uses destructiveForeground (#de4706)
    static let accentRed = destructiveForeground
    
    /// Accent blue for info states - #3b82f6
    static let accentBlue = Color(red: 0x3b/255.0, green: 0x82/255.0, blue: 0xf6/255.0)
    
    /// Accent orange for warning states - #f97316
    static let accentOrange = Color(red: 0xf9/255.0, green: 0x73/255.0, blue: 0x16/255.0)
    
    // MARK: - Chart Color Palettes
    /// Chart previous period color - #A0A6B8
    static let chartPreviousPeriod = Color(red: 0xa0/255.0, green: 0xa6/255.0, blue: 0xb8/255.0)
    
    // Income chart color gradient (teal shades)
    /// Income chart color position 1 (darkest) - #008F75
    static let chartIncome1 = Color(red: 0x00/255.0, green: 0x8F/255.0, blue: 0x75/255.0)
    
    /// Income chart color position 2 - #08AD93
    static let chartIncome2 = Color(red: 0x08/255.0, green: 0xAD/255.0, blue: 0x93/255.0)
    
    /// Income chart color position 3 - #12CBAE
    static let chartIncome3 = Color(red: 0x12/255.0, green: 0xCB/255.0, blue: 0xAE/255.0)
    
    /// Income chart color position 4 (lightest) - #12B6CB
    static let chartIncome4 = Color(red: 0x12/255.0, green: 0xB6/255.0, blue: 0xCB/255.0)
    
    // Expense chart color gradient (red/orange shades)
    /// Expense chart color position 1 (darkest) - #DE4706
    static let chartExpense1 = Color(red: 0xDE/255.0, green: 0x47/255.0, blue: 0x06/255.0)
    
    /// Expense chart color position 2 - #FF6C29
    static let chartExpense2 = Color(red: 0xFF/255.0, green: 0x6C/255.0, blue: 0x29/255.0)
    
    /// Expense chart color position 3 - #FFA100
    static let chartExpense3 = Color(red: 0xFF/255.0, green: 0xA1/255.0, blue: 0x00/255.0)
    
    /// Expense chart color position 4 (lightest) - #F7CD07
    static let chartExpense4 = Color(red: 0xF7/255.0, green: 0xCD/255.0, blue: 0x07/255.0)
    
    // MARK: - Wallet System Colors
    /// Wallet avatar background color - #008080 (teal)
    static let walletAvatar = Color(red: 0x00/255.0, green: 0x80/255.0, blue: 0x80/255.0)
    
    // MARK: - Blue Color Variants
    /// Blue 500 - #3b82f6 (accessibility friendly)
    static let blue500 = Color(red: 0x3b/255.0, green: 0x82/255.0, blue: 0xf6/255.0)
    
    // MARK: - Convenience Color Arrays
    /// Income chart gradient array [darkest to lightest] + "All Others" fallback
    static let chartIncomeGradient = [chartIncome1, chartIncome2, chartIncome3, chartIncome4, linePrimary]
    
    /// Expense chart gradient array [darkest to lightest] + "All Others" fallback
    static let chartExpenseGradient = [chartExpense1, chartExpense2, chartExpense3, chartExpense4, linePrimary]
    
    // MARK: - Legacy Colors (for backwards compatibility)
    /// @deprecated Use accentBackground instead
    static let primary = accentBackground
}



