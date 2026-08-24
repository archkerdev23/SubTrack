import Foundation

// Pure spending-total helpers shared by the Home header and the Widget so both
// surfaces compute the same numbers from a single source of truth. Namespaced
// as a case-less enum: static functions only, never instantiated.
enum TotalsService {

    // Total normalized monthly spend across the given subscriptions. Each sub's
    // `monthlyCost` already converts weekly/yearly into a monthly figure.
    static func monthlyTotal(_ subs: [Subscription]) -> Double {
        subs.reduce(0) { $0 + $1.monthlyCost }
    }

    // Yearly spend is simply the monthly figure times twelve — kept consistent
    // with Subscription.yearlyCost so header and widget can't diverge.
    static func yearlyTotal(_ subs: [Subscription]) -> Double {
        monthlyTotal(subs) * 12.0
    }
}
