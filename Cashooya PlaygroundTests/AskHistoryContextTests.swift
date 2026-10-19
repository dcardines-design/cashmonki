//
//  AskHistoryContextTests.swift
//  Guards the conversation context the Ask chat sends back to the model. A rendered
//  table/chart/stat used to collapse to its title alone, which is why follow-ups like
//  "top 3 only" or "same but last month" came back with invented numbers.
//

import XCTest
@testable import CashMonki

final class AskHistoryContextTests: XCTestCase {

    private func historyText(_ content: AskDisplayMessage.Content) -> String {
        AskDisplayMessage(isUser: false, content: content).historyText
    }

    func testTableHistoryCarriesQueryColumnsAndRows() {
        let table = AskTableMessage(
            type: "table",
            title: "September spending",
            columns: [
                AskTableColumn(key: "category", label: "Category", align: nil, format: nil),
                AskTableColumn(key: "amount", label: "Amount", align: nil, format: nil)
            ],
            limit: nil,
            followups: nil,
            rows: [["category": "Food", "amount": "1200"], ["category": "Transport", "amount": "450"]],
            source: "call_1",
            query: AskQueryDescriptor(tool: "get_spending_by_category", arguments: "{\"period\":\"month\"}")
        )

        let text = historyText(.table(table))
        XCTAssertTrue(text.contains("get_spending_by_category"), "query tool missing: \(text)")
        XCTAssertTrue(text.contains("period=month"), "query arguments missing: \(text)")
        XCTAssertTrue(text.contains("Category | Amount"), "columns missing: \(text)")
        XCTAssertTrue(text.contains("Food | 1200"), "row values missing: \(text)")
        XCTAssertTrue(text.contains("Transport | 450"), "row values missing: \(text)")
    }

    func testTableHistoryClipsVeryLongRowSets() {
        let rows = (1...80).map { ["category": "Cat\($0)", "amount": "\($0)"] }
        let table = AskTableMessage(
            type: "table",
            title: "Everything",
            columns: [AskTableColumn(key: "category", label: "Category", align: nil, format: nil)],
            limit: nil,
            followups: nil,
            rows: rows,
            source: nil,
            query: nil
        )

        let text = historyText(.table(table))
        XCTAssertTrue(text.contains("(+30 more)"), "expected 50 rows kept and the rest noted: \(text)")
        XCTAssertFalse(text.contains("Cat80"), "rows past the cap should be dropped: \(text)")
    }

    func testChartHistoryCarriesBars() {
        let chart = AskChartMessage(
            type: "chart",
            title: "By category",
            source: "call_2",
            limit: nil,
            followups: nil,
            items: [AskChartItem(label: "Food", value: 1200, count: "8")],
            query: AskQueryDescriptor(tool: "get_spending_by_category", arguments: "{\"period\":\"week\"}")
        )

        let text = historyText(.chart(chart))
        XCTAssertTrue(text.contains("Food=1200"), "bar values missing: \(text)")
        XCTAssertTrue(text.contains("period=week"), "query missing: \(text)")
    }

    func testStatHistoryCarriesComparisonAndQuery() {
        let stat = AskStatMessage(
            type: "stat",
            title: "This month",
            value: 2500,
            compare_value: 1800,
            compare_label: "last month",
            good_direction: "down",
            source: "call_3",
            followups: nil,
            query: AskQueryDescriptor(tool: "compare_spending", arguments: "{}")
        )

        let text = historyText(.stat(stat))
        XCTAssertTrue(text.contains("2500"), "value missing: \(text)")
        XCTAssertTrue(text.contains("1800"), "comparison value missing: \(text)")
        XCTAssertTrue(text.contains("last month"), "comparison label missing: \(text)")
        XCTAssertTrue(text.contains("compare_spending"), "query missing: \(text)")
    }

    func testEditCardHistoryCarriesProposedValues() {
        let update = AskTransactionUpdate(
            type: "transaction_update",
            transaction_id: "ABC-123",
            transaction_ids: nil,
            amount: 500,
            currency: "USD",
            merchant: "Jollibee",
            date: "2026-10-19",
            note: nil,
            category_id: nil
        )

        let text = historyText(.update(update))
        XCTAssertTrue(text.contains("amount 500.0 USD"), "amount missing: \(text)")
        XCTAssertTrue(text.contains("merchant Jollibee"), "merchant missing: \(text)")
        XCTAssertTrue(text.contains("ABC-123"), "id missing: \(text)")
    }

    func testQueryDescriptorSummaryFallsBackToToolName() {
        let descriptor = AskQueryDescriptor(tool: "get_budgets", arguments: "not json")
        XCTAssertEqual(descriptor.summary, "get_budgets")
    }
}
