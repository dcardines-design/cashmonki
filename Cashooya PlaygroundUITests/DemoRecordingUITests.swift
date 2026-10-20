//
//  DemoRecordingUITests.swift
//  Drives the app for marketing screen recordings. Not part of the regular suite.
//

import XCTest

final class DemoRecordingUITests: XCTestCase {

    /// Host directory used to hand off with the recording script.
    /// Pass `TEST_RUNNER_DEMO_DIR=/path` to xcodebuild to override.
    static let dir = ProcessInfo.processInfo.environment["DEMO_DIR"] ?? "/tmp/cashmonki-demo"

    override func setUpWithError() throws {
        continueAfterFailure = false
        try? FileManager.default.createDirectory(atPath: Self.dir, withIntermediateDirectories: true)
    }

    // MARK: - Scripted Ask demo
    //
    // Expects a fresh install. Gets through guest onboarding, logs three expenses so Home
    // isn't empty, then writes `<dir>/ready` and waits for `<dir>/recording` (created by the
    // host once `simctl io recordVideo` is running) before playing the Ask segment.
    // Event timestamps are appended to `<dir>/events.txt` for trimming.

    private func mark(_ event: String) {
        let line = String(format: "%.3f %@\n", Date().timeIntervalSince1970, event)
        let path = Self.dir + "/events.txt"
        if let h = FileHandle(forWritingAtPath: path) {
            h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); h.closeFile()
        } else {
            try? line.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }

    private func pause(_ s: Double) { Thread.sleep(forTimeInterval: s) }

    @MainActor
    private func allowSystemAlerts(_ rounds: Int = 2) {
        let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<rounds {
            let allow = sb.buttons["Allow"]
            if allow.waitForExistence(timeout: 2.5) { allow.tap(); pause(0.8) }
        }
    }

    @MainActor
    private func tapButton(_ app: XCUIApplication, _ label: String, timeout: Double = 10) {
        let b = app.buttons[label].firstMatch
        XCTAssertTrue(b.waitForExistence(timeout: timeout), "Missing button \(label)")
        b.tap()
    }

    /// Taps the keyboard's Done key only when it is actually on screen (it can be mid-animation).
    @MainActor
    private func dismissKeyboard(_ app: XCUIApplication, _ done: XCUIElement) {
        guard done.waitForExistence(timeout: 2) else { return }
        let h = app.windows.firstMatch.frame.height
        for _ in 0..<6 {
            let f = done.frame
            if f.maxY <= h && f.minY > 0 {
                app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: f.midX, dy: f.midY)).tap()
                return
            }
            pause(0.25)
        }
    }

    @MainActor
    private func addExpense(_ app: XCUIApplication, amount: String, search: String, category: String) {
        tapButton(app, "Add")
        pause(1.2)
        app.typeText(amount)
        tapButton(app, "Select Category")
        // The field's placeholder is rendered as a separate text; tapping it focuses the field.
        let field = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Search for a category'")).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        app.typeText(search)
        pause(0.8)
        let row = app.staticTexts[category].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Missing category \(category)")
        row.tap()
        pause(0.8)
        tapButton(app, "Save")
        pause(1.8)
    }

    /// Fresh-install path: guest login, skip name, choose currency, skip survey, close paywall.
    @MainActor
    private func onboardGuest(_ app: XCUIApplication, currencyCode: String) {
        app.launch()
        allowSystemAlerts()

        // Login: guest
        tapButton(app, "Continue as Guest", timeout: 20)
        allowSystemAlerts(1)

        // Value pages
        for _ in 0..<4 { tapButton(app, "Continue"); pause(1.0) }
        // Name step: skip (no name)
        XCTAssertTrue(app.staticTexts["What should we call you?"].waitForExistence(timeout: 5))
        tapButton(app, "Skip"); pause(1.0)
        // Currency
        let current = app.buttons.matching(NSPredicate(format: "label CONTAINS ' - ' OR label CONTAINS ' – '")).firstMatch
        let codeShown = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", currencyCode + " ")).firstMatch
        if !codeShown.waitForExistence(timeout: 3) {
            let row = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'PHP' OR label CONTAINS 'Peso'")).firstMatch
            if row.exists { row.tap() } else { current.tap() }
            pause(1.0)
            let search = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Search for a currency'")).firstMatch
            XCTAssertTrue(search.waitForExistence(timeout: 5))
            search.tap()
            app.typeText(currencyCode)
            pause(1.2)
            let pick = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@ AND NOT (label BEGINSWITH 'Search')", currencyCode)).element(boundBy: 0)
            XCTAssertTrue(pick.waitForExistence(timeout: 5))
            pick.tap()
            pause(1.0)
        }
        XCTAssertTrue(codeShown.waitForExistence(timeout: 5), "Currency \(currencyCode) not selected")
        tapButton(app, "Continue"); pause(1.0)
        // Goal
        let goal = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Track daily spending'")).firstMatch
        XCTAssertTrue(goal.waitForExistence(timeout: 5)); goal.tap(); pause(0.4)
        tapButton(app, "Continue"); pause(1.0)
        // Survey questions: skip until the social-proof page
        for _ in 0..<8 {
            if app.staticTexts["Average Rating"].exists { break }
            let skip = app.buttons["Skip"].firstMatch
            guard skip.waitForExistence(timeout: 3) else { break }
            skip.tap(); pause(1.0)
        }
        tapButton(app, "Continue"); pause(1.0)
        tapButton(app, "Complete"); pause(2.0)
        // Paywall: close X, then confirm skipping the offer
        tapButton(app, "Close", timeout: 15); pause(0.8)
        tapButton(app, "Skip"); pause(2.0)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Wallet'")).firstMatch.waitForExistence(timeout: 10))
    }

    private func resetHandoffFiles() {
        for f in ["ready", "recording", "events.txt", "finished"] {
            try? FileManager.default.removeItem(atPath: Self.dir + "/" + f)
        }
    }

    /// Writes `ready`, then blocks until the host creates `recording`.
    private func waitForRecordingHandoff() throws {
        try "ready".write(toFile: Self.dir + "/ready", atomically: true, encoding: .utf8)
        let deadline = Date().addingTimeInterval(120)
        while !FileManager.default.fileExists(atPath: Self.dir + "/recording") && Date() < deadline { pause(0.2) }
        pause(1.0)
    }

    @MainActor
    func testRecordAskDemo() throws {
        resetHandoffFiles()
        let app = XCUIApplication()
        onboardGuest(app, currencyCode: "USD")

        // Seed a few believable USD expenses so Home isn't empty
        addExpense(app, amount: "5", search: "Coffee", category: "Coffee")
        addExpense(app, amount: "18", search: "Taxi", category: "Rideshare")
        addExpense(app, amount: "62", search: "Restaurant", category: "Restaurants")
        // The 3rd transaction triggers the one-time App Store review prompt
        let notNow = app.buttons["Not Now"].firstMatch
        if notNow.waitForExistence(timeout: 5) { notNow.tap() }
        pause(1.5)
        // Settle on a clean Home: visit Ask once (so its first-open layout is warm), back to Home
        tapButton(app, "Ask"); pause(1.5)
        tapButton(app, "Home"); pause(1.5)

        try waitForRecordingHandoff()

        // --- Recorded segment ---
        mark("home-start")
        pause(1.5)
        tapButton(app, "Ask")
        mark("ask-open")
        pause(1.2)
        let input = app.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        pause(0.5)
        mark("type-start")
        // Word-sized chunks: per-character typeText is slow (~0.4 s/char), chunks read as natural typing
        for (i, word) in "45 groceries and 6 for milk".split(separator: " ").enumerated() {
            app.typeText((i == 0 ? "" : " ") + word)
            pause(0.08)
        }
        mark("type-end")
        pause(0.5)
        tapButton(app, "send-01")
        mark("sent")
        pause(0.4)
        let done = app.keyboards.buttons["Done"].firstMatch
        dismissKeyboard(app, done)
        mark("kb-dismissed")

        let addAll = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Add all'")).firstMatch
        XCTAssertTrue(addAll.waitForExistence(timeout: 60), "No confirmation card")
        mark("card")
        pause(1.6)
        addAll.tap()
        mark("confirmed")
        pause(1.6)
        tapButton(app, "Home")
        mark("home-end")
        pause(2.2)
        mark("end")
        try "done".write(toFile: Self.dir + "/finished", atomically: true, encoding: .utf8)
    }

    // MARK: - Scripted charts tour

    /// Sends one Ask message (unrecorded seeding) and adds every draft on the card.
    @MainActor
    private func askSeed(_ app: XCUIApplication, _ sentence: String) {
        let input = app.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        app.typeText(sentence)
        tapButton(app, "send-01")
        let done = app.keyboards.buttons["Done"].firstMatch
        dismissKeyboard(app, done)
        let addAll = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Add all'")).firstMatch
        XCTAssertTrue(addAll.waitForExistence(timeout: 60), "No card for: \(sentence)")
        pause(0.5)
        addAll.tap()
        pause(1.5)
        let notNow = app.buttons["Not Now"].firstMatch   // one-time App Store review prompt
        if notNow.waitForExistence(timeout: 2.5) { notNow.tap(); pause(1.0) }
    }

    @MainActor
    func testRecordChartsDemo() throws {
        resetHandoffFiles()
        let app = XCUIApplication()
        onboardGuest(app, currencyCode: "USD")

        // Seed ~20 USD transactions over the past ~5 weeks via dated Ask messages
        tapButton(app, "Ask"); pause(1.5)
        askSeed(app, "86 groceries on Oct 2, 41 dinner at a restaurant on Oct 4, 6 coffee on Oct 6, 22 rideshare on Oct 8")
        askSeed(app, "salary 2400 on Oct 1, 64 electricity bill on Oct 5, 38 groceries on Oct 9, 54 clothes shopping on Oct 11")
        askSeed(app, "12 lunch on Oct 13, 5 coffee on Oct 14, 95 groceries on Oct 15, 18 rideshare on Oct 16")
        askSeed(app, "29 movie tickets on Oct 17, 47 dinner at a restaurant on Oct 18, 33 groceries yesterday, 15 lunch today")
        askSeed(app, "salary 2400 on Sep 15, 72 groceries on Sep 20, 110 internet and phone bill on Sep 25, 36 dinner on Sep 28")

        // Starting state: Home, Expense, line chart, 1M
        tapButton(app, "Home"); pause(1.5)
        tapButton(app, "1M"); pause(1.0)

        try waitForRecordingHandoff()

        // --- Recorded segment ---
        mark("home-1m-line")
        pause(1.6)
        tapButton(app, "bar-chart-01"); mark("bar"); pause(1.4)
        tapButton(app, "7D"); mark("7d"); pause(1.2)
        tapButton(app, "3M"); mark("3m"); pause(1.2)
        tapButton(app, "Income"); mark("income"); pause(1.2)
        tapButton(app, "Balance"); mark("balance"); pause(1.5)
        tapButton(app, "Transactions"); mark("transactions"); pause(1.2)
        tapButton(app, "Expense"); mark("tx-expense"); pause(1.3)
        // Tap the first (largest) segment of the category bar under the "Total expenses" title
        let title = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Total expenses'")).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        let f = title.frame
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: f.minX + 70, dy: f.midY + 85)).tap()
        mark("segment")
        pause(2.0)
        mark("end")
        try "done".write(toFile: Self.dir + "/finished", atomically: true, encoding: .utf8)
    }

    // MARK: - Scripted Ask chart answer

    /// Waits until more `$` texts than `before` exist and their count has held steady for `settle` s
    /// (streamed answers grow, then stop).
    @MainActor
    private func waitForAnswer(_ app: XCUIApplication, dollarTextsBefore before: Int, timeout: Double = 60, settle: Double = 1.5) -> Bool {
        let q = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '$'"))
        let deadline = Date().addingTimeInterval(timeout)
        var last = -1
        var stableSince = Date()
        while Date() < deadline {
            let c = q.count
            if c != last { last = c; stableSince = Date() }
            if c > before && Date().timeIntervalSince(stableSince) >= settle { return true }
            pause(0.25)
        }
        return false
    }

    /// Host-side step: the test quits the app and asks the host to delete the local Ask chat
    /// file (seeding chat), then relaunches so Ask opens on its empty state.
    @MainActor
    private func relaunchWithClearedChat(_ app: XCUIApplication) throws {
        app.terminate()
        try "cleanup".write(toFile: Self.dir + "/cleanup", atomically: true, encoding: .utf8)
        let deadline = Date().addingTimeInterval(60)
        while !FileManager.default.fileExists(atPath: Self.dir + "/cleaned") && Date() < deadline { pause(0.2) }
        app.launch()
        allowSystemAlerts(1)
        let close = app.buttons["Close"].firstMatch     // in case a paywall shows on relaunch
        if close.waitForExistence(timeout: 3) { close.tap(); pause(0.8)
            let skip = app.buttons["Skip"].firstMatch
            if skip.waitForExistence(timeout: 2) { skip.tap(); pause(1.0) }
        }
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Wallet'")).firstMatch.waitForExistence(timeout: 15))
    }

    @MainActor
    func testRecordAskChartDemo() throws {
        resetHandoffFiles()
        for f in ["cleanup", "cleaned"] { try? FileManager.default.removeItem(atPath: Self.dir + "/" + f) }
        let app = XCUIApplication()
        onboardGuest(app, currencyCode: "USD")

        // Seed this month + last month via dated Ask messages (not recorded)
        tapButton(app, "Ask"); pause(1.5)
        askSeed(app, "86 groceries on Oct 2, 41 dinner at a restaurant on Oct 4, 6 coffee on Oct 6, 22 rideshare on Oct 8")
        askSeed(app, "salary 2400 on Oct 1, 64 electricity bill on Oct 5, 38 groceries on Oct 9, 54 clothes shopping on Oct 11")
        askSeed(app, "12 lunch on Oct 13, 5 coffee on Oct 14, 95 groceries on Oct 15, 18 rideshare on Oct 16")
        askSeed(app, "29 movie tickets on Oct 17, 47 dinner at a restaurant on Oct 18, 33 groceries yesterday, 15 lunch today")
        // Keep last month's entries >30 days back: the chart tool's "this month" window is a rolling 30 days
        askSeed(app, "salary 2400 on Sep 1, 72 groceries on Sep 6, 110 internet and phone bill on Sep 10, 36 dinner on Sep 13")

        try relaunchWithClearedChat(app)
        tapButton(app, "Home"); pause(1.0)
        tapButton(app, "1M"); pause(1.0)

        try waitForRecordingHandoff()

        // --- Recorded segment ---
        mark("home")
        pause(1.0)
        tapButton(app, "Ask"); mark("ask-open")
        pause(1.4)
        let chipLabel = "📈 Chart my spending this month"
        let chip = app.buttons[chipLabel].firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        // The chips row scrolls horizontally; drag it (slowly, no fling) until the chip is fully on screen.
        let winW = app.windows.firstMatch.frame.width
        for _ in 0..<3 where chip.frame.maxX > winW - 16 {
            let dx = min(330, chip.frame.maxX - (winW - 20))
            let y = chip.frame.midY
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: 370, dy: y))
                .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: 370 - dx, dy: y)),
                       withVelocity: 500, thenHoldForDuration: 0.25)
            pause(0.5)
        }
        let dollarsBefore = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '$'")).count
        if chip.frame.minX >= 0 && chip.frame.maxX <= winW {
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: chip.frame.midX, dy: chip.frame.midY)).tap()
            mark("chip")
        } else {
            let input = app.textFields.firstMatch
            input.tap()
            for (i, w) in "chart my spending this month".split(separator: " ").enumerated() { app.typeText((i == 0 ? "" : " ") + w); pause(0.08) }
            tapButton(app, "send-01"); mark("typed-chart")
            let done = app.keyboards.buttons["Done"].firstMatch
            dismissKeyboard(app, done)
        }
        XCTAssertTrue(waitForAnswer(app, dollarTextsBefore: dollarsBefore), "No chart answer")
        mark("chart")
        pause(3.0)

        // Follow-up question
        let dollarsBefore2 = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '$'")).count
        let input = app.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap(); pause(0.4)
        mark("type2-start")
        for (i, w) in "what did I spend on dining this week?".split(separator: " ").enumerated() {
            app.typeText((i == 0 ? "" : " ") + w); pause(0.08)
        }
        pause(0.4)
        tapButton(app, "send-01"); mark("sent2")
        let done = app.keyboards.buttons["Done"].firstMatch
        dismissKeyboard(app, done)
        mark("kb2")
        _ = waitForAnswer(app, dollarTextsBefore: dollarsBefore2)
        mark("answer2")
        pause(2.5)
        mark("end")
        try "done".write(toFile: Self.dir + "/finished", atomically: true, encoding: .utf8)
    }

    // MARK: - Verification: calendar periods (no recording)

    private func saveScreen(_ name: String, _ app: XCUIApplication) {
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: Self.dir + "/verify-\(name).png"))
        try? app.debugDescription.write(toFile: Self.dir + "/verify-\(name).txt", atomically: true, encoding: .utf8)
    }

    @MainActor
    private func askAndWait(_ app: XCUIApplication, _ text: String) {
        let before = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '$'")).count
        let input = app.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        app.typeText(text)
        tapButton(app, "send-01")
        let done = app.keyboards.buttons["Done"].firstMatch
        dismissKeyboard(app, done)
        XCTAssertTrue(waitForAnswer(app, dollarTextsBefore: before, settle: 2.5), "No answer for: \(text)")
        pause(1.0)
    }

    @MainActor
    func testVerifyCalendarPeriods() throws {
        let app = XCUIApplication()
        onboardGuest(app, currencyCode: "USD")
        tapButton(app, "Ask"); pause(1.5)
        askSeed(app, "110 electricity bill on Sep 25, 36 dinner on Sep 28, 70 clothes shopping on Aug 10, 45 groceries on Sep 5")
        askSeed(app, "86 groceries on Oct 2, 41 dinner at a restaurant on Oct 4, 64 electricity bill on Oct 5, 22 rideshare on Oct 8")
        askSeed(app, "95 groceries on Oct 15, 18 rideshare on Oct 16, 47 dinner on Oct 18, 15 lunch today")
        saveScreen("seeded", app)

        askAndWait(app, "Chart my spending this month")
        saveScreen("ask-chart", app)
        askAndWait(app, "what did I spend this week?")
        saveScreen("ask-week", app)

        tapButton(app, "Home"); pause(1.5)
        tapButton(app, "Expense"); pause(0.5)
        tapButton(app, "3M"); pause(1.5)
        saveScreen("home-3m-line", app)
        tapButton(app, "bar-chart-01"); pause(1.5)
        saveScreen("home-3m-bar", app)
    }
}
