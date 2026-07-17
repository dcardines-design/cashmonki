//
//  AskMessageSchema.swift
//  CashMonki
//
//  Shared schema module for structured AI chat messages. The model's output is
//  constrained to a fixed menu of types ("text", "table", "transaction_draft");
//  anything unknown or malformed falls back to plain text — never a broken
//  widget. Future types (charts, stat cards) = new schema here + a renderer.
//

import Foundation

// MARK: - Structured message menu

enum AskStructuredMessage {
    case text(String)
    /// A question with tappable answer chips.
    case question(String, [String])
    case table(AskTableMessage)
    case transactionDraft(AskTransactionDraft)
    case transactionUpdate(AskTransactionUpdate)
    case transaction(AskTransactionRef)
    case transactionDelete(AskTransactionDelete)
    case chart(AskChartMessage)
    case stat(AskStatMessage)
    case categoryDraft(AskCategoryDraft)
}

// MARK: - Category suggestion

/// Proposed new category or subcategory. Created ONLY after the user
/// confirms — and category creation is a Pro feature, so free users get
/// the paywall instead.
struct AskCategoryDraft: Codable {
    let type: String
    let name: String
    let emoji: String?
    /// Existing parent category name (from get_categories) for subcategories.
    let parent: String?
    /// "expense" (default) or "income".
    let category_type: String?
}

// MARK: - Stat card (hero number + trend)

struct AskStatMessage: Codable {
    let type: String
    let title: String
    /// Computed from tool data by the model; soft-validated against the
    /// cached rows client-side (see AskChatService).
    let value: Double
    let compare_value: Double?
    let compare_label: String?
    /// Which direction is good for this metric ("down" for spending).
    let good_direction: String?
    let source: String?
    /// 2-3 suggested next questions, shown as chips under the card.
    let followups: [String]?
}

// MARK: - Chart (horizontal bars)

struct AskChartItem: Codable {
    let label: String
    let value: Double
    /// Secondary figure shown right of the bar (e.g. transaction count).
    let count: String?
}

/// Horizontal bar chart. Like tables, items are NEVER trusted from the model —
/// the client builds them from the cached tool result rows.
struct AskChartMessage: Codable {
    let type: String
    let title: String
    let source: String?
    /// Optional cap ("top 5") — rows are already ranked by the tool.
    let limit: Int?
    /// 2-3 suggested next questions, shown as chips under the chart.
    let followups: [String]?

    /// Injected client-side; not part of the model's JSON.
    var items: [AskChartItem]? = nil

    private enum CodingKeys: String, CodingKey { case type, title, source, limit, items, followups }
}

/// Proposed deletion of 1-10 existing transactions. Ids must come from tool
/// results. Applied ONLY after the user confirms.
struct AskTransactionDelete: Codable {
    let type: String
    let transaction_id: String?
    let transaction_ids: [String]?

    var ids: [String] {
        if let transaction_ids, !transaction_ids.isEmpty { return transaction_ids }
        if let transaction_id { return [transaction_id] }
        return []
    }
}

/// Points at 1-3 existing transactions to display as cards (4+ should be a
/// table). Ids must come from tool results.
struct AskTransactionRef: Codable {
    let type: String
    let transaction_id: String?
    let transaction_ids: [String]?

    var ids: [String] {
        if let transaction_ids, !transaction_ids.isEmpty { return transaction_ids }
        if let transaction_id { return [transaction_id] }
        return []
    }
}

// MARK: - Table

struct AskTableColumn: Codable {
    let key: String
    let label: String
    /// "left" (default) or "right". Money columns are right-aligned.
    let align: String?
    /// "currency" formats the cell with the smart currency formatter.
    let format: String?

    var isRightAligned: Bool { align == "right" || format == "currency" }
    var isCurrency: Bool { format == "currency" }
}

struct AskTableMessage: Codable {
    let type: String
    let title: String
    let columns: [AskTableColumn]
    /// Optional cap ("top 5") — rows are already ranked by the tool.
    let limit: Int?
    /// 2-3 suggested next questions, shown as chips under the table.
    let followups: [String]?
    /// Rows are NEVER trusted from the model — the client injects them from
    /// the cached MCP-style tool result (see AskChatService). The model only
    /// chooses title + which columns to show.
    var rows: [[String: String]]?
    /// Tool-call id the rows come from; nil = most recent tool result.
    let source: String?
}

// MARK: - Transaction draft

struct AskSuggestedCategory: Codable, Identifiable {
    let id: String
    let name: String
    let confidence: Double
}

struct AskTransactionDraft: Codable {
    let type: String
    let amount: Double
    let currency: String?
    let merchant: String?
    /// ISO date "yyyy-MM-dd"; nil = today.
    let date: String?
    let note: String?
    let suggested_categories: [AskSuggestedCategory]?
}

// MARK: - Transaction update

/// Proposed edit to an existing transaction. `transaction_id` must come from
/// a tool result (get_recent_transactions rows carry ids); only the fields
/// being changed are set. Applied ONLY after the user confirms.
struct AskTransactionUpdate: Codable {
    let type: String
    /// Single target, or `transaction_ids` for the same change applied to many.
    let transaction_id: String?
    let transaction_ids: [String]?
    let amount: Double?
    let currency: String?
    let merchant: String?
    let date: String?
    let note: String?
    let category_id: String?

    var ids: [String] {
        if let transaction_ids, !transaction_ids.isEmpty { return transaction_ids }
        if let transaction_id { return [transaction_id] }
        return []
    }

    var hasChanges: Bool {
        amount != nil || currency != nil || merchant != nil || date != nil || note != nil || category_id != nil
    }
}

// MARK: - Decoder with fallback

enum AskMessageDecoder {
    private struct Envelope: Codable { let type: String }

    /// Strictly validates against the known schemas; any failure returns the
    /// raw string as a plain text message.
    static func decode(_ raw: String) -> AskStructuredMessage {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Models sometimes wrap JSON in markdown fences despite instructions —
        // strip ```json ... ``` (or plain ```) before validating.
        if trimmed.hasPrefix("```") {
            var lines = trimmed.components(separatedBy: .newlines)
            lines.removeFirst() // ``` or ```json
            if let last = lines.last, last.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                lines.removeLast()
            }
            trimmed = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Models sometimes prefix prose before the JSON ("Here they are: {…}").
        if !trimmed.hasPrefix("{") {
            // A complete embedded structured object → use it.
            if let embedded = extractJSONObject(from: trimmed) {
                let decoded = decode(embedded)
                if case .text = decoded {} else { return decoded }
            } else if let marker = trimmed.range(of: "{\"type\"", options: .backwards)
                        ?? trimmed.range(of: "{ \"type\"", options: .backwards) {
                // The model tacked a TRUNCATED envelope onto its prose (stream cut mid-JSON).
                // Show only the prose so raw JSON never leaks into the chat.
                let prose = String(trimmed[..<marker.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !prose.isEmpty { return .text(prose) }
            }
        }

        guard trimmed.hasPrefix("{"), let data = trimmed.data(using: .utf8) else {
            return .text(trimmed)
        }
        let decoder = JSONDecoder()
        guard let envelope = try? decoder.decode(Envelope.self, from: data) else {
            return .text(trimmed)
        }

        switch envelope.type {
        case "table":
            guard let table = try? decoder.decode(AskTableMessage.self, from: data),
                  !table.title.isEmpty,
                  !table.columns.isEmpty,
                  table.columns.allSatisfy({ !$0.key.isEmpty && !$0.label.isEmpty })
            else { return .text(trimmed) }
            return .table(table)

        case "transaction_draft":
            guard let draft = try? decoder.decode(AskTransactionDraft.self, from: data),
                  draft.amount > 0
            else { return .text(trimmed) }
            return .transactionDraft(draft)

        case "transaction":
            guard let ref = try? decoder.decode(AskTransactionRef.self, from: data),
                  (1...3).contains(ref.ids.count),
                  ref.ids.allSatisfy({ UUID(uuidString: $0) != nil })
            else { return .text(trimmed) }
            return .transaction(ref)

        case "category_draft":
            guard let draft = try? decoder.decode(AskCategoryDraft.self, from: data),
                  !draft.name.trimmingCharacters(in: .whitespaces).isEmpty,
                  draft.name.count <= 40
            else { return .text(trimmed) }
            return .categoryDraft(draft)

        case "stat":
            guard let stat = try? decoder.decode(AskStatMessage.self, from: data),
                  !stat.title.isEmpty,
                  stat.value.isFinite
            else { return .text(trimmed) }
            return .stat(stat)

        case "chart":
            guard let chart = try? decoder.decode(AskChartMessage.self, from: data),
                  !chart.title.isEmpty
            else { return .text(trimmed) }
            return .chart(chart)

        case "transaction_delete":
            guard let delete = try? decoder.decode(AskTransactionDelete.self, from: data),
                  (1...10).contains(delete.ids.count),
                  delete.ids.allSatisfy({ UUID(uuidString: $0) != nil })
            else { return .text(trimmed) }
            return .transactionDelete(delete)

        case "transaction_update":
            guard let update = try? decoder.decode(AskTransactionUpdate.self, from: data),
                  (1...10).contains(update.ids.count),
                  update.ids.allSatisfy({ UUID(uuidString: $0) != nil }),
                  update.hasChanges
            else { return .text(trimmed) }
            return .transactionUpdate(update)

        case "text":
            struct TextMessage: Codable { let text: String; let choices: [String]? }
            guard let message = try? decoder.decode(TextMessage.self, from: data) else {
                return .text(trimmed)
            }
            if let choices = message.choices, !choices.isEmpty {
                return .question(message.text, Array(choices.prefix(4)))
            }
            return .text(message.text)

        default:
            return .text(trimmed)
        }
    }

    /// Pulls the first balanced `{…}` block out of mixed prose+JSON content.
    private static func extractJSONObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var previous: Character = " "
        for index in text.indices[start...] {
            let char = text[index]
            if inString {
                if char == "\"" && previous != "\\" { inString = false }
            } else {
                switch char {
                case "\"": inString = true
                case "{": depth += 1
                case "}":
                    depth -= 1
                    if depth == 0 { return String(text[start...index]) }
                default: break
                }
            }
            previous = char
        }
        return nil
    }
}
