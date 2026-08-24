import Foundation

// How often a subscription bills. Stored on Subscription as `cycleRaw` (String)
// and surfaced through the computed `cycle` accessor.
enum BillingCycle: String, CaseIterable {
    case weekly
    case monthly
    case yearly

    // Human-readable label for pickers and rows.
    var label: String {
        switch self {
        case .weekly:  return "Weekly"
        case .monthly: return "Monthly"
        case .yearly:  return "Yearly"
        }
    }
}

// What kind of thing the subscription is. Stored as `categoryRaw` (String) and
// surfaced through the computed `category` accessor.
enum Category: String, CaseIterable {
    case entertainment
    case work
    case health
    case utilities
    case other

    // Human-readable label for pickers and rows.
    var label: String {
        switch self {
        case .entertainment: return "Entertainment"
        case .work:          return "Work"
        case .health:        return "Health"
        case .utilities:     return "Utilities"
        case .other:         return "Other"
        }
    }

    // SF Symbol name shown as the row icon per category.
    var icon: String {
        switch self {
        case .entertainment: return "play.tv"
        case .work:          return "briefcase"
        case .health:        return "heart"
        case .utilities:     return "bolt"
        case .other:         return "square.grid.2x2"
        }
    }
}
