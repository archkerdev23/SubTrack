import Foundation
import SwiftData

// A place money is paid from — a card, bank, or wallet the user names freely.
// Fields match the FROZEN CONTRACT (PRD §5.2.2) exactly.
@Model
final class PaymentMethod {
    var name: String             // free text, e.g. Dana / Chase / Nubank
    var balance: Double          // manually entered by the user
    var balanceUpdatedAt: Date   // when the balance was last edited (drives the "stale" warning)
    var trackBalance: Bool       // whether the user wants balance/at-risk tracking on

    // Inverse side of the Subscription.paymentMethod relationship. SwiftData
    // keeps both ends in sync: setting sub.paymentMethod = method adds the sub
    // here automatically. Deleting a method nullifies the subs' pointer.
    @Relationship(inverse: \Subscription.paymentMethod)
    var subscriptions: [Subscription]

    init(
        name: String,
        balance: Double = 0,
        balanceUpdatedAt: Date = .now,
        trackBalance: Bool = false,
        subscriptions: [Subscription] = []
    ) {
        self.name = name
        self.balance = balance
        self.balanceUpdatedAt = balanceUpdatedAt
        self.trackBalance = trackBalance
        self.subscriptions = subscriptions
    }
}
