//
//  AppUpdateManager.swift
//  CashMonki
//
//  Created by Claude on 1/4/26.
//

import Foundation
import UIKit

/// Manages app version checking and force update alerts
class AppUpdateManager: ObservableObject {
    static let shared = AppUpdateManager()

    @Published var updateRequired: Bool = false
    @Published var latestVersion: String = ""

    private let bundleId = "com.dante.cashmonki"
    private var hasChecked = false

    private init() {}

    /// Current app version from bundle
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// Check App Store for newer version and show native alert if update needed
    func checkForUpdate() {
        guard !hasChecked else { return }
        hasChecked = true

        let urlString = "https://itunes.apple.com/lookup?bundleId=\(bundleId)&country=us"
        guard let url = URL(string: urlString) else { return }

        print("🔄 AppUpdate: Checking for updates...")
        print("🔄 AppUpdate: Current version: \(currentVersion)")

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else {
                print("❌ AppUpdate: Network error")
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let results = json["results"] as? [[String: Any]],
                   let firstResult = results.first,
                   let appStoreVersion = firstResult["version"] as? String {

                    print("🔄 AppUpdate: App Store version: \(appStoreVersion)")

                    if self.isVersionNewer(appStoreVersion, than: self.currentVersion) {
                        print("⚠️ AppUpdate: UPDATE REQUIRED")
                        DispatchQueue.main.async {
                            self.latestVersion = appStoreVersion
                            self.updateRequired = true
                            self.showNativeUpdateAlert()
                        }
                    } else {
                        print("✅ AppUpdate: App is up to date")
                    }
                } else {
                    print("ℹ️ AppUpdate: App not found on App Store yet")
                }
            } catch {
                print("❌ AppUpdate: JSON error - \(error)")
            }
        }.resume()
    }

    /// Show native iOS alert for force update
    private func showNativeUpdateAlert() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else { return }

        // Find the topmost presented view controller
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        let alert = UIAlertController(
            title: "Update Required",
            message: "A new version of CashMonki (v\(latestVersion)) is available. Please update to continue.",
            preferredStyle: .alert
        )

        // Only "Update" button - no cancel option (force update)
        alert.addAction(UIAlertAction(title: "Update", style: .default) { [weak self] _ in
            self?.openAppStore()
            // Show alert again after returning from App Store
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self?.showNativeUpdateAlert()
            }
        })

        topVC.present(alert, animated: true)
    }

    /// Compare semantic versions
    private func isVersionNewer(_ newVersion: String, than currentVersion: String) -> Bool {
        let new = newVersion.split(separator: ".").compactMap { Int($0) }
        let current = currentVersion.split(separator: ".").compactMap { Int($0) }

        let maxLen = max(new.count, current.count)
        var n = new; var c = current
        while n.count < maxLen { n.append(0) }
        while c.count < maxLen { c.append(0) }

        for i in 0..<maxLen {
            if n[i] > c[i] { return true }
            if n[i] < c[i] { return false }
        }
        return false
    }

    /// Open App Store
    private func openAppStore() {
        if let url = URL(string: "itms-apps://itunes.apple.com/app/\(bundleId)") {
            UIApplication.shared.open(url)
        }
    }
}
