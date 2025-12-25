import SwiftUI

/// Wrapper that prefers vector assets from Assets.xcassets but falls back to SF Symbols
struct AppIcon: View {
    let assetName: String
    let fallbackSystemName: String
    let size: CGFloat?

    init(assetName: String, fallbackSystemName: String, size: CGFloat? = nil) {
        self.assetName = assetName
        self.fallbackSystemName = fallbackSystemName
        self.size = size
    }

    var body: some View {
        if let size = size {
            // When size is specified, make resizable and constrain to frame
            if UIImage(named: assetName) != nil {
                Image(assetName)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else {
                Image(systemName: fallbackSystemName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            }
        } else {
            // Original behavior - use intrinsic size
            if UIImage(named: assetName) != nil {
                Image(assetName)
                    .renderingMode(.template)
            } else {
                Image(systemName: fallbackSystemName)
            }
        }
    }
}



