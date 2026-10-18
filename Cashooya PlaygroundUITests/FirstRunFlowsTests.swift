//
//  FirstRunFlowsTests.swift
//  Walks the two flows a new user hits first: adding a transaction by hand, and
//  asking the AI chat a question. Each step prints what's on screen.
//

import XCTest

final class FirstRunFlowsTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    private func dump(_ app: XCUIApplication, _ label: String) {
        print("===== SCREEN \(label) =====")
        for button in app.buttons.allElementsBoundByIndex.prefix(250) where !button.label.isEmpty {
            print("BUTTON | \(button.label)")
        }
        for field in app.textFields.allElementsBoundByIndex.prefix(12) {
            print("FIELD | \(field.label) | value=\(String(describing: field.value))")
        }
        for view in app.textViews.allElementsBoundByIndex.prefix(12) {
            print("TEXTVIEW | \(view.label) | value=\(String(describing: view.value))")
        }
        for text in app.staticTexts.allElementsBoundByIndex.prefix(40) where !text.label.isEmpty {
            print("TEXT | \(text.label)")
        }
        print("===== END \(label) =====")
    }

    private func enterAsGuest(_ app: XCUIApplication) {
        let guest = app.buttons["Continue as Guest"]
        if guest.waitForExistence(timeout: 20) {
            guest.tap()
            print("TAPPED >>> Continue as Guest")
            sleep(4)
        }
    }

    func testManualTransaction() throws {
        let app = XCUIApplication()
        app.launch()
        sleep(5)
        enterAsGuest(app)
        dump(app, "HOME")

        let add = app.buttons["Add"]
        XCTAssertTrue(add.waitForExistence(timeout: 15), "No Add button on home")
        add.tap()
        print("TAPPED >>> Add")
        sleep(9)
        dump(app, "ADD-SHEET")

        // Type an amount into whichever field is focused / first available.
        let fields = app.textFields.allElementsBoundByIndex
        print("FIELD COUNT >>> \(fields.count)")
        if let amountField = fields.first {
            amountField.tap()
            amountField.typeText("42")
            print("TYPED >>> 42 into field 0")
            sleep(1)
            for (i, f) in app.textFields.allElementsBoundByIndex.enumerated() {
                print("FIELD[\(i)] value=\(String(describing: f.value))")
            }
            // Category is required before Save will commit.
            let category = app.buttons["Select Category"]
            if category.exists {
                category.tap()
                print("TAPPED >>> Select Category")
                sleep(3)
                dump(app, "CATEGORY-PICKER")
                let match = app.buttons.matching(
                    NSPredicate(format: "label CONTAINS[c] %@", "Food")
                ).firstMatch
                if match.exists {
                    match.tap()
                    print("TAPPED CATEGORY MATCH >>> \(match.label)")
                    sleep(3)
                    for b in app.buttons.allElementsBoundByIndex where b.label.contains("Food") || b.label.contains("Auto") || b.label.contains("Category") {
                        print("CATEGORY-STATE | \(b.label)")
                    }
                }
            }
        } else {
            // Amount pads are often plain buttons.
            for digit in ["4", "2"] where app.buttons[digit].exists {
                app.buttons[digit].tap()
                print("TAPPED DIGIT >>> \(digit)")
            }
        }
        dump(app, "AMOUNT-ENTERED")

        for label in ["Save", "Done", "Add Transaction", "Confirm", "Next"] {
            let button = app.buttons[label]
            if button.exists {
                button.tap()
                print("TAPPED >>> \(label)")
                sleep(4)
                break
            }
        }
        dump(app, "AFTER-SAVE")

        let txns = app.buttons["Transactions"]
        if txns.exists {
            txns.tap()
            sleep(3)
            dump(app, "TRANSACTIONS-TAB")
        }
    }

    func testAskChat() throws {
        let app = XCUIApplication()
        app.launch()
        sleep(5)
        enterAsGuest(app)

        let ask = app.buttons["Ask"]
        XCTAssertTrue(ask.waitForExistence(timeout: 15), "No Ask tab")
        ask.tap()
        print("TAPPED >>> Ask")
        sleep(4)
        dump(app, "ASK-TAB")

        // Find the chat input: text view first, then text field.
        var typed = false
        if let input = app.textViews.allElementsBoundByIndex.first, input.exists {
            input.tap()
            input.typeText("How much did I spend this week?")
            typed = true
        } else if let input = app.textFields.allElementsBoundByIndex.first, input.exists {
            input.tap()
            input.typeText("How much did I spend this week?")
            typed = true
        }
        print("TYPED MESSAGE >>> \(typed)")
        sleep(2)
        dump(app, "ASK-TYPED")

        for label in ["send-01", "Send", "arrow-up", "Submit"] {
            let button = app.buttons[label]
            if button.exists {
                button.tap()
                print("TAPPED >>> \(label)")
                break
            }
        }

        // Give the model time to answer.
        sleep(25)
        dump(app, "ASK-RESPONSE")
    }
}
