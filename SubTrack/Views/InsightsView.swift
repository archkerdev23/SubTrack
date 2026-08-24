import SwiftUI
import SwiftData
import Charts

// The Insights tab: a scrollable dashboard of WHERE the money goes.
//
// It reads every subscription, then does all the grouping/summing IN MEMORY
// (monthlyCost, category, and paymentMethod are computed/relationship values, so
// they can't be part of a SwiftData #Predicate/sort — we sort the query by the
// stored `createdAt` field and crunch the rest here).
struct InsightsView: View {

    // Pull all subscriptions, ordered by a STORED field (createdAt). Any work on
    // computed values (monthlyCost) happens below, not in the query.
    @Query(sort: \Subscription.createdAt, order: .reverse)
    private var subscriptions: [Subscription]

    // Shared currency code. Settings will own this key later; "USD" is the default.
    @AppStorage("currencyCode") private var currencyCode: String = "USD"

    var body: some View {
        NavigationStack {
            Group {
                if subscriptions.isEmpty {
                    // Nothing tracked yet — show a calm, self-contained empty state.
                    // (Local view on purpose: we avoid touching the shared
                    // EmptyStateView.swift another agent may be editing.)
                    InsightsEmptyState()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Pie 1: spend split by category.
                            PieChartCard(title: "Spend by Category", slices: categorySlices)

                            // Pie 2: spend split by payment method — the key differentiator.
                            PieChartCard(title: "Spend by Payment Method", slices: paymentMethodSlices)

                            // The five priciest subscriptions, normalized to monthly cost.
                            topSpendersCard
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Insights")
        }
    }

    // MARK: - Top 5 card

    // A card listing the five most expensive subscriptions (by monthly cost).
    private var topSpendersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top 5 by Monthly Cost")
                .font(.headline)

            // Sort a COPY by monthlyCost descending, then take the first five.
            let top = subscriptions
                .sorted { $0.monthlyCost > $1.monthlyCost }
                .prefix(5)

            ForEach(Array(top)) { sub in
                HStack(spacing: 12) {
                    // Category icon in a tinted circle for quick visual scanning.
                    Image(systemName: sub.category.icon)
                        .font(.body.weight(.semibold))
                        .frame(width: 32, height: 32)
                        .background(color(for: sub.category).opacity(0.18), in: Circle())
                        .foregroundStyle(color(for: sub.category))
                        .accessibilityHidden(true)   // decorative; name conveys meaning

                    Text(sub.name)
                        .font(.body)
                        .lineLimit(1)

                    Spacer()

                    // Money via Decimal + currency FormatStyle — never a hardcoded symbol.
                    Text(Decimal(sub.monthlyCost).formatted(.currency(code: currencyCode)))
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                }
                // Read as one phrase, e.g. "Netflix, $15.99".
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("\(sub.name), \(Decimal(sub.monthlyCost).formatted(.currency(code: currencyCode))) per month"))

                if sub.id != top.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Grouping (all in-memory)

    // Sum monthlyCost per category, then turn each group into a colored slice.
    // Only categories that actually have spend appear.
    private var categorySlices: [PieChartCard.Slice] {
        // Dictionary(grouping:) buckets the subs by their category enum.
        let grouped = Dictionary(grouping: subscriptions, by: { $0.category })
        return grouped
            .map { category, subs in
                PieChartCard.Slice(
                    label: category.label,
                    value: subs.reduce(0) { $0 + $1.monthlyCost },
                    color: color(for: category)
                )
            }
            // Biggest wedge first so the chart + legend read largest-to-smallest.
            .sorted { $0.value > $1.value }
    }

    // Sum monthlyCost per payment method name; nil methods collapse into "Unassigned".
    private var paymentMethodSlices: [PieChartCard.Slice] {
        let grouped = Dictionary(grouping: subscriptions) { sub in
            sub.paymentMethod?.name ?? "Unassigned"
        }
        // Sort the group KEYS first so each name always maps to the SAME color
        // (dictionary order isn't stable), then build the slices.
        let orderedNames = grouped.keys.sorted()
        return orderedNames.enumerated().map { index, name in
            let subs = grouped[name] ?? []
            return PieChartCard.Slice(
                label: name,
                value: subs.reduce(0) { $0 + $1.monthlyCost },
                color: paletteColor(at: index)
            )
        }
        .sorted { $0.value > $1.value }
    }

    // MARK: - Colors

    // A fixed color per category so the same category is always the same hue.
    private func color(for category: Category) -> Color {
        switch category {
        case .entertainment: return .blue
        case .work:          return .green
        case .health:        return .pink
        case .utilities:     return .orange
        case .other:         return .purple
        }
    }

    // A stable palette for payment methods (names are user-defined, so we index
    // into a rotating list rather than switching on fixed cases).
    private func paletteColor(at index: Int) -> Color {
        let palette: [Color] = [.teal, .indigo, .mint, .orange, .pink, .cyan, .brown, .yellow]
        return palette[index % palette.count]
    }
}

// MARK: - Local empty state

// A small, self-contained empty view. Kept private here so we don't import or
// edit the shared EmptyStateView.swift (owned by another workstream right now).
private struct InsightsEmptyState: View {
    var body: some View {
        ContentUnavailableView {
            Label("No insights yet", systemImage: "chart.pie")
        } description: {
            Text("Add a few subscriptions to see where your money goes.")
        }
    }
}

#Preview {
    // Build an in-memory container and seed ~5 subs across multiple categories
    // AND payment methods so BOTH pies and the top-5 list render real data.
    let container = Persistence.makePreviewContainer()
    let context = container.mainContext

    // Two payment methods so the payment-method pie has more than one slice.
    let card = PaymentMethod(name: "Chase Card")
    let wallet = PaymentMethod(name: "Dana Wallet")
    context.insert(card)
    context.insert(wallet)

    // Five subscriptions spanning several categories and cycles. One is left on
    // no payment method to exercise the "Unassigned" bucket.
    let now = Date.now
    context.insert(Subscription(name: "Netflix",  price: 15.99, cycle: .monthly, firstBillDate: now, category: .entertainment, paymentMethod: card))
    context.insert(Subscription(name: "Spotify",  price: 9.99,  cycle: .monthly, firstBillDate: now, category: .entertainment, paymentMethod: wallet))
    context.insert(Subscription(name: "Figma",    price: 144.0, cycle: .yearly,  firstBillDate: now, category: .work,          paymentMethod: card))
    context.insert(Subscription(name: "Gym",      price: 29.99, cycle: .monthly, firstBillDate: now, category: .health,        paymentMethod: wallet))
    context.insert(Subscription(name: "Electric", price: 12.0,  cycle: .weekly,  firstBillDate: now, category: .utilities,     paymentMethod: nil))

    return InsightsView()
        .modelContainer(container)
}
