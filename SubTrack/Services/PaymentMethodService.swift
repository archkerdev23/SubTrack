import Foundation
import SwiftData

// Business logic for resolving and suggesting PaymentMethods. Namespaced as a
// case-less enum (static functions only, never instantiated) so the Add/Edit
// view stays thin and the dedup rule lives in ONE place. This is the FROZEN
// CONTRACT — do not change the two signatures below.
enum PaymentMethodService {

    // Find an existing method by CASE-INSENSITIVE, TRIMMED name match; if none
    // exists, create + insert one and return it. Empty/whitespace-only name
    // returns nil (the subscription simply has no payment method).
    //
    // Dedup rule (plan): "dana" and "Dana" and "  dana " must all resolve to the
    // SAME PaymentMethod so we never create a near-duplicate wallet.
    static func findOrCreate(name: String, in context: ModelContext) -> PaymentMethod? {
        // Trim surrounding whitespace/newlines so " Dana " matches "Dana".
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // A blank name means "no payment method" — bail before touching the store.
        guard !trimmed.isEmpty else { return nil }

        // Fetch every existing method; the set is tiny (a handful of wallets), so
        // an in-memory case-insensitive scan is simpler and safer than trying to
        // express a localized-caseless predicate in SwiftData.
        let existing = (try? context.fetch(FetchDescriptor<PaymentMethod>())) ?? []

        // Case-insensitive comparison: compare both sides lowercased + trimmed so
        // "dana" == "Dana" == " DANA ". Returns the first stored match if any.
        if let match = existing.first(where: {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            return match
        }

        // No match — create a fresh method with the plan's defaults and insert it
        // so SwiftData tracks it and the relationship wires up on save.
        let method = PaymentMethod(
            name: trimmed,           // store the trimmed display name the user typed
            balance: 0,              // new methods start at zero balance
            balanceUpdatedAt: .now,  // stamp creation time
            trackBalance: false      // opt-in feature — off until the user enables it
        )
        context.insert(method)
        return method
    }

    // Autocomplete source: existing PaymentMethods whose name CONTAINS the trimmed
    // query, case-insensitive. An empty query returns ALL existing methods (so the
    // field can show every wallet the moment it's focused). Always sorted by name.
    static func suggestions(matching query: String, in context: ModelContext) -> [PaymentMethod] {
        // Same tiny-set rationale as above: fetch all, filter in memory.
        let existing = (try? context.fetch(FetchDescriptor<PaymentMethod>())) ?? []
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        // Empty query -> offer everything, alphabetically.
        guard !trimmed.isEmpty else {
            return existing.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        // Substring match, case-insensitive (localizedStandardContains folds case
        // AND diacritics the way a user expects while typing).
        return existing
            .filter { $0.name.localizedStandardContains(trimmed) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
