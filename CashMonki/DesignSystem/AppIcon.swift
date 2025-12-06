import SwiftUI

/// Wrapper that prefers vector assets from Assets.xcassets but falls back to SF Symbols
struct AppIcon: View {
    let assetName: String
    let fallbackSystemName: String

    init(assetName: String, fallbackSystemName: String) {
        self.assetName = assetName
        self.fallbackSystemName = fallbackSystemName
    }

    var body: some View {
        if UIImage(named: assetName) != nil {
            Image(assetName)
                .renderingMode(.template)
        } else {
            Image(systemName: fallbackSystemName)
        }
    }
}



