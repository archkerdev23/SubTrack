import SwiftUI
import SwiftData

// One row in the Home subscriptions list. Shows, left to right:
//   category icon · name + payment method · price + "in X days"
// Pure presentation — it reads only the passed-in subscription and the shared
// currency code. No writes, no business logic.
struct SubscriptionRow: View {
    let subscription: Subscription

    // Same single currency source the rest of the app uses.
    @AppStorage("currencyCode") private var currencyCode: String = "USD"

    var body: some View {
        HStack(spacing: 12) {
            // Category SF Symbol in a soft rounded tile.
            Image(systemName: subscription.category.icon)
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                // Icon is decorative; the name carries the meaning for VoiceOver.
                .accessibilityHidden(true)

            // Name on top, payment method underneath ("—" when none set).
            VStack(alignment: .leading, spacing: 2) {
                Text(subscription.name)
                    .font(.body)
                Text(subscription.paymentMethod?.name ?? "—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            // Price on top, days-until label underneath, right-aligned.
            VStack(alignment: .trailing, spacing: 2) {
                Text(Decimal(subscription.price).formatted(.currency(code: currencyCode)))
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(dueLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        // Read the whole row as one VoiceOver sentence.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    // Turn the day count into friendly copy: Today / Tomorrow / in N days
    // (and a sensible past-tense fallback that shouldn't normally appear since
    // nextBillDate never lands before today).
    private var dueLabel: String {
        let days = subscription.daysUntilNextBill
        switch days {
        case 0:          return "Today"
        case 1:          return "Tomorrow"
        case let n where n > 1: return "in \(n) days"
        default:         return "Overdue"
        }
    }

    // Spell out the whole row for VoiceOver, including the formatted price.
    private var accessibilityText: Text {
        let price = Decimal(subscription.price).formatted(.currency(code: currencyCode))
        let method = subscription.paymentMethod?.name ?? "no payment method"
        return Text("\(subscription.name), \(price), \(method), due \(dueLabel)")
    }
}

#Preview {
    // Seed a real container so the row renders against actual model objects.
    let container = Persistence.makePreviewContainer()
    let method = PaymentMethod(name: "Chase", balance: 200)
    let sub = Subscription(
        name: "Netflix",
        price: 15.49,
        cycle: .monthly,
        firstBillDate: .now,
        category: .entertainment,
        paymentMethod: method
    )
    container.mainContext.insert(sub)

    return List {
        SubscriptionRow(subscription: sub)
    }
    .modelContainer(container)
}
