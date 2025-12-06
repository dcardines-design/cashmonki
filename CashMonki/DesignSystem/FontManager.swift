import SwiftUI

// MARK: - Font Manager with Fallback System

struct AppFonts {
    
    // MARK: - Font Debugging
    static func debugAvailableFonts() {
        print("=== AVAILABLE FONTS DEBUG ===")
        
        // Print ALL font families to see what's actually loaded
        let fontFamilies = UIFont.familyNames.sorted()
        for family in fontFamilies {
            if family.lowercased().contains("grotesk") || family.lowercased().contains("overused") {
                print("Found font family: \(family)")
                let fonts = UIFont.fontNames(forFamilyName: family)
                for font in fonts {
                    print("  - \(font)")
                }
            }
        }
        
        // Check specific font names we're looking for
        let fontNames = [
            "OverusedGrotesk-Medium", "OverusedGrotesk-Medium", 
            "OverusedGrotesk-Medium", "OverusedGrotesk-SemiBold", "OverusedGrotesk-Bold",
            "Overused Grotesk Medium", "Overused Grotesk Regular",
            "Overused Grotesk Medium", "Overused Grotesk SemiBold", "Overused Grotesk Bold"
        ]
        
        for fontName in fontNames {
            if let font = UIFont(name: fontName, size: 16) {
                print("✅ Font available: \(fontName) -> \(font.fontName)")
            } else {
                print("❌ Font not found: \(fontName)")
            }
        }
        
        // Check if bundle contains the font files
        let bundle = Bundle.main
        let fontFiles = ["OverusedGrotesk-Medium.ttf", "OverusedGrotesk-Medium.ttf", 
                        "OverusedGrotesk-SemiBold.ttf", "OverusedGrotesk-Bold.ttf"]
        
        for fontFile in fontFiles {
            if let path = bundle.path(forResource: fontFile.replacingOccurrences(of: ".ttf", with: ""), ofType: "ttf") {
                print("✅ Font file found in bundle: \(fontFile) at \(path)")
            } else if let path = bundle.path(forResource: "DesignSystem/\(fontFile.replacingOccurrences(of: ".ttf", with: ""))", ofType: "ttf") {
                print("✅ Font file found in bundle: \(fontFile) at \(path)")
            } else {
                print("❌ Font file NOT in bundle: \(fontFile)")
            }
        }
        
        print("=== END FONT DEBUG ===")
    }
    // MARK: - Overused Grotesk Font Family with Fallbacks
    
    static func overusedGroteskMedium(size: CGFloat) -> Font {
        let fontNames = ["OverusedGrotesk-Medium", "Overused Grotesk Medium"]
        
        for fontName in fontNames {
            if UIFont(name: fontName, size: size) != nil {
                return Font.custom(fontName, size: size)
            }
        }
        
        print("❌ Overused Grotesk Medium not found, using system fallback")
        return Font.system(size: size, weight: .medium, design: .default)
    }
    
    static func overusedGroteskSemiBold(size: CGFloat) -> Font {
        let fontNames = ["OverusedGrotesk-SemiBold", "OverusedGrotesk-Semibold", "Overused Grotesk SemiBold", "Overused Grotesk Semibold"]
        
        for fontName in fontNames {
            if UIFont(name: fontName, size: size) != nil {
                return Font.custom(fontName, size: size)
            }
        }
        
        print("❌ Overused Grotesk SemiBold not found, using system fallback")
        return Font.system(size: size, weight: .semibold, design: .default)
    }
    
    static func overusedGroteskBold(size: CGFloat) -> Font {
        let fontNames = ["OverusedGrotesk-Bold", "Overused Grotesk Bold"]
        
        for fontName in fontNames {
            if UIFont(name: fontName, size: size) != nil {
                return Font.custom(fontName, size: size)
            }
        }
        
        print("❌ Overused Grotesk Bold not found, using system fallback")
        return Font.system(size: size, weight: .bold, design: .default)
    }
    
    // MARK: - App Typography Scale
    
    // Headlines
    static let largeTitle = overusedGroteskBold(size: 34)
    static let title1 = overusedGroteskBold(size: 28)
    static let title2 = overusedGroteskBold(size: 22)
    static let title3 = overusedGroteskSemiBold(size: 20)
    
    // Body text
    static let headline = overusedGroteskSemiBold(size: 17)
    static let body = overusedGroteskMedium(size: 17)
    static let callout = overusedGroteskMedium(size: 16)
    static let subheadline = overusedGroteskMedium(size: 15)
    static let footnote = overusedGroteskMedium(size: 13)
    static let caption1 = overusedGroteskMedium(size: 12)
    static let caption2 = overusedGroteskMedium(size: 11)
    
    // Custom app-specific sizes
    static let amountLarge = overusedGroteskBold(size: 72)
    static let amountMedium = overusedGroteskSemiBold(size: 32)
    static let buttonText = overusedGroteskSemiBold(size: 17)
}

// MARK: - Font Extension for SwiftUI

extension Font {
    static func overusedGrotesk(_ weight: AppFontWeight, size: CGFloat) -> Font {
        switch weight {
        case .medium:
            return AppFonts.overusedGroteskMedium(size: size)
        case .semibold:
            return AppFonts.overusedGroteskSemiBold(size: size)
        case .bold:
            return AppFonts.overusedGroteskBold(size: size)
        }
    }
}

enum AppFontWeight {
    case medium
    case semibold
    case bold
}

