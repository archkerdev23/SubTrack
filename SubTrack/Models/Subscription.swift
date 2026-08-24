import Foundation
import SwiftData

// The core record: one subscription or recurring bill the user tracks.
// Fields here match the FROZEN CONTRACT (PRD §5.2.1) exactly — do not rename.
@Model
final class Subscription {
    var name: String
    var price: Double            // amount charged per cycle
    var cycleRaw: String         // backing storage for BillingCycle (see `cycle`)
    var firstBillDate: Date      // anchor date; nextBillDate is computed, never stored
    var categoryRaw: String      // backing storage for Category (see `category`)
    var remindMe: Bool
    var notes: String
    var createdAt: Date
    var paymentMethod: PaymentMethod?   // SwiftData relationship (inverse lives on PaymentMethod)

    // Designated initializer. Defaults keep call sites short and give SwiftData
    // a stored anchor for every field.
    init(
        name: String,
        price: Double,
        cycle: BillingCycle = .monthly,
        firstBillDate: Date,
        category: Category = .other,
        remindMe: Bool = true,
        notes: String = "",
        createdAt: Date = .now,
        paymentMethod: PaymentMethod? = nil
    ) {
        self.name = name
        self.price = price
        self.cycleRaw = cycle.rawValue          // store the enum's raw string
        self.firstBillDate = firstBillDate
        self.categoryRaw = category.rawValue    // store the enum's raw string
        self.remindMe = remindMe
        self.notes = notes
        self.createdAt = createdAt
        self.paymentMethod = paymentMethod
    }
}

// MARK: - Computed accessors & date math (PRD §5.2.5)
// These are pure (no stored state) so they're safe to implement now and easy to
// unit-test. Views read them directly.
extension Subscription {

    // Map the stored raw string back to the enum; fall back to a safe default
    // if the string is ever unexpected (keeps the UI from crashing).
    var cycle: BillingCycle {
        BillingCycle(rawValue: cycleRaw) ?? .monthly
    }

    var category: Category {
        Category(rawValue: categoryRaw) ?? .other
    }

    // The next time this subscription bills, at/after today.
    //
    // ANCHOR-DAY APPROACH (fixes month-end drift):
    // For monthly/yearly cycles we re-derive every future occurrence from the
    // ORIGINAL anchor's day-of-month (`firstBillDate`), clamped to each target
    // month's last valid day — we do NOT iteratively add to an already-clamped
    // candidate. The old approach permanently "stuck" a Jan-31 sub on Feb 28
    // (28 -> 28 -> 28 ...). By always starting from the anchor day of 31 and
    // clamping per month, a Jan-31 sub correctly reads Feb 28, Mar 31, Apr 30 —
    // month-end every time. Weekly stays exact (add 7 days). A bounded guard
    // means a bad date can never crash or spin forever.
    var nextBillDate: Date {
        let calendar = Calendar.current
        // Normalize to the start of the day so comparisons ignore clock time.
        let today = calendar.startOfDay(for: .now)
        let anchor = calendar.startOfDay(for: firstBillDate)

        // If the anchor is already today or in the future, that IS the next bill.
        if anchor >= today {
            return anchor
        }

        switch cycle {
        case .weekly:
            // Weekly is exact and immune to month-end issues: step 7 days.
            // Coarse jump close to today, then fine-step (bounded guard).
            var candidate = anchor
            let daysBehind = calendar.dateComponents([.day], from: anchor, to: today).day ?? 0
            if daysBehind >= 7,
               let jumped = calendar.date(byAdding: .day, value: (daysBehind / 7) * 7, to: anchor) {
                candidate = jumped
            }
            var guardCount = 0
            while candidate < today && guardCount < 10_000 {
                guard let next = calendar.date(byAdding: .day, value: 7, to: candidate) else { break }
                candidate = next
                guardCount += 1
            }
            return candidate

        case .monthly, .yearly:
            // How many months each cycle spans (yearly == 12 months).
            let monthStep = (cycle == .yearly) ? 12 : 1
            // The anchor's day-of-month — the number we re-apply every occurrence
            // (e.g. 31), clamped per target month so it lands on month-end.
            let anchorDay = calendar.component(.day, from: anchor)

            // Coarse start: land at or just below the true answer, then walk up so
            // we return the SMALLEST occurrence >= today (integer floor + a -1
            // buffer guarantees we never overshoot the earliest valid date).
            let monthsBehind = calendar.dateComponents([.month], from: anchor, to: today).month ?? 0
            var n = max(1, (monthsBehind / monthStep) - 1)

            var candidate = anchor
            var guardCount = 0
            while guardCount < 10_000 {
                guardCount += 1
                // Advance the anchor's month by n cycle-steps. Only the year/month
                // of this result are used; its day (which Calendar may itself
                // clamp) is discarded and replaced by our anchor-day clamp below.
                guard let baseMonth = calendar.date(byAdding: .month, value: monthStep * n, to: anchor) else { break }
                // Clamp the anchor day to this month's real length (31 -> 28/29/30).
                let daysInMonth = calendar.range(of: .day, in: .month, for: baseMonth)?.count ?? 28
                var comps = calendar.dateComponents([.year, .month], from: baseMonth)
                comps.day = min(anchorDay, daysInMonth)
                guard let occurrence = calendar.date(from: comps) else { break }
                candidate = calendar.startOfDay(for: occurrence)
                // First occurrence on/after today is the answer (smallest, since we
                // started at/below it and step upward).
                if candidate >= today { break }
                n += 1
            }
            return candidate
        }
    }

    // Normalize every cycle to a comparable monthly figure.
    var monthlyCost: Double {
        switch cycle {
        case .weekly:  return price * 52.0 / 12.0   // 52 weeks spread over 12 months
        case .monthly: return price
        case .yearly:  return price / 12.0
        }
    }

    // Yearly is just the monthly figure times twelve.
    var yearlyCost: Double {
        monthlyCost * 12.0
    }

    // Whole days from today until the next bill (0 == due today).
    var daysUntilNextBill: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let next = calendar.startOfDay(for: nextBillDate)
        return calendar.dateComponents([.day], from: today, to: next).day ?? 0
    }
}
