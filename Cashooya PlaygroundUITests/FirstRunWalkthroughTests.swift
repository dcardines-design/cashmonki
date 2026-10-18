//
//  FirstRunWalkthroughTests.swift
//  Drives the app the way a brand-new user would, printing what's on screen at each
//  step so the flow can be inspected without a Simulator window.
//

import XCTest

final class FirstRunWalkthroughTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    /// Prints every button/field currently on screen, tagged so it's greppable in the log.
    private func dump(_ app: XCUIApplication, _ label: String) {
        print("===== SCREEN \(label) =====")
        for button in app.buttons.allElementsBoundByIndex.prefix(30) {
            let id = button.identifier
            let text = button.label
            if !text.isEmpty || !id.isEmpty {
                print("BUTTON | \(text) | id=\(id) | hittable=\(button.isHittable)")
            }
        }
        for field in app.textFields.allElementsBoundByIndex.prefix(10) {
            print("FIELD | \(field.label) | id=\(field.identifier) | value=\(String(describing: field.value))")
        }
        for view in app.textViews.allElementsBoundByIndex.prefix(10) {
            print("TEXTVIEW | \(view.label) | id=\(view.identifier)")
        }
        for text in app.staticTexts.allElementsBoundByIndex.prefix(25) where !text.label.isEmpty {
            print("TEXT | \(text.label)")
        }
        print("===== END \(label) =====")
    }

    /// Taps the first button whose label matches any of the candidates. Returns what it tapped.
    @discardableResult
    private func tapFirst(_ app: XCUIApplication, _ candidates: [String]) -> String? {
        for candidate in candidates {
            let button = app.buttons[candidate]
            if button.exists && button.isHittable {
                button.tap()
                print("TAPPED >>> \(candidate)")
                sleep(2)
                return candidate
            }
        }
        return nil
    }

    func testFirstRunWalkthrough() throws {
        let app = XCUIApplication()
        app.launch()
        sleep(5)

        dump(app, "LAUNCH")

        // Walk whatever onboarding/permission screens appear.
        let forward = ["Continue", "Next", "Get Started", "Allow", "OK", "Done",
                       "Skip", "Maybe Later", "Not Now", "Continue as Guest", "Start"]
        for step in 1...14 {
            guard tapFirst(app, forward) != nil else {
                print("NO FORWARD BUTTON at step \(step) - stopping walk")
                break
            }
            dump(app, "AFTER-STEP-\(step)")
        }

        dump(app, "FINAL")
    }
}
