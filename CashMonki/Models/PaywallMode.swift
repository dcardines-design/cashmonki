//
//  PaywallMode.swift
//  CashMonki
//
//  Why the tiered paywall was opened. Drives its headline and the
//  highlighted cell in the features table.
//

import Foundation

enum PaywallMode: Equatable {
    /// Generic entry (Settings, wallet/recurring/category gates, lapsed trial).
    /// A Plus user automatically sees the upgrade variant.
    case `default`
    /// Opened because the user hit today's limit.
    case limitHit(LimitKind)
    /// A Plus user upgrading to Pro.
    case upgrade

    enum LimitKind: String {
        case ask
        case scan
    }

    /// Short identifier for analytics (`paywall_viewed.source`).
    var analyticsSource: String {
        switch self {
        case .default: return "app"
        case .limitHit(let kind): return "limit_\(kind.rawValue)"
        case .upgrade: return "upgrade"
        }
    }

    // MARK: - Debug override

    /// DEBUG-only: `-showPaywall default|limitAsk|limitScan|upgrade` opens the tiered
    /// paywall over everything at launch (screenshots / UI checks).
    static var debugLaunchMode: PaywallMode? {
        #if DEBUG
        guard let raw = UserDefaults.standard.string(forKey: "showPaywall") else { return nil }
        switch raw.lowercased() {
        case "default": return .default
        case "limitask": return .limitHit(.ask)
        case "limitscan": return .limitHit(.scan)
        case "upgrade": return .upgrade
        default: return nil
        }
        #else
        return nil
        #endif
    }
}
