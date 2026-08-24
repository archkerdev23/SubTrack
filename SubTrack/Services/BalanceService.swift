import Foundation

// The result of evaluating a payment method's balance health.
// FROZEN CONTRACT — do not rename cases or change associated values.
enum BalanceStatus: Equatable {
    case ok                              // nothing to warn about (or tracking is off)
    case atRisk(shortfall: Double)       // upcoming charges exceed the balance
    case stale                           // the balance is too old to trust
}

// Pure, stateless business logic for the balance banner. Namespaced as an enum
// (no cases) so it can never be instantiated — just a home for static helpers.
enum BalanceService {

    // Sum the `price` of every subscription on this method that bills within the
    // next 7 days, INCLUSIVE of today through today+7. Uses each sub's computed
    // nextBillDate (already normalized to the next on/after-today occurrence).
    static func upcomingChargeTotal(for method: PaymentMethod, from today: Date = .now) -> Double {
        let calendar = Calendar.current
        // Normalize both ends of the window to day boundaries so clock time never
        // tips a same-day charge in or out of range.
        let start = calendar.startOfDay(for: today)
        // Inclusive upper bound: today + 7 days, taken at the START of that day so
        // any charge dated on day+7 (regardless of its time) still counts.
        guard let endDay = calendar.date(byAdding: .day, value: 7, to: start) else { return 0 }
        let end = calendar.startOfDay(for: endDay)

        return method.subscriptions.reduce(0) { running, sub in
            let bill = calendar.startOfDay(for: sub.nextBillDate)
            // Window is [start, end] inclusive on both ends.
            let inWindow = bill >= start && bill <= end
            return running + (inWindow ? sub.price : 0)
        }
    }

    // Evaluate a method's balance health. ORDER IS CRITICAL and intentional:
    //   1. tracking off        -> .ok      (user opted out entirely)
    //   2. balance too old     -> .stale   (checked BEFORE at-risk: never cry
    //                                        wolf on numbers we can't trust)
    //   3. charges > balance   -> .atRisk(shortfall)
    //   4. otherwise           -> .ok
    static func status(for method: PaymentMethod, from today: Date = .now) -> BalanceStatus {
        // 1. The user hasn't asked us to track this method's balance.
        guard method.trackBalance else { return .ok }

        let calendar = Calendar.current
        // 2. Staleness gate. If the balance was last updated more than 14 days
        // ago, we can't trust it — surface .stale and stop (don't risk a false
        // at-risk warning off a number the user may have already topped up).
        let daysSinceUpdate = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: method.balanceUpdatedAt),
            to: calendar.startOfDay(for: today)
        ).day ?? 0
        if daysSinceUpdate > 14 {
            return .stale
        }

        // 3. Trusted balance: compare the 7-day upcoming charges against it.
        let total = upcomingChargeTotal(for: method, from: today)
        if total > method.balance {
            return .atRisk(shortfall: total - method.balance)
        }

        // 4. Tracked, fresh, and covered.
        return .ok
    }
}
