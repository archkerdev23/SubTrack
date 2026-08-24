import SwiftUI
import SwiftData

// The Home tab: a totals header, an optional balance warning, and the list of
// subscriptions sorted by their next bill date. Owns the "+" / Add flow.
struct HomeView: View {
    // modelContext is how we delete rows (writes go through the context).
    @Environment(\.modelContext) private var modelContext

    // Pull every subscription. NOTE: nextBillDate is a *computed* property, not
    // stored, so @Query can't sort on it in the database — we fetch createdAt
    // ordered (stable) and re-sort by nextBillDate in-memory below.
    @Query(sort: \Subscription.createdAt, order: .forward)
    private var subscriptions: [Subscription]

    // Every payment method, so we can evaluate balance health for the banner.
    // Order doesn't matter here — we pick the single most-severe result below.
    @Query private var paymentMethods: [PaymentMethod]

    // Shared currency source for formatting the shortfall message here (the
    // banner takes a finished string so it stays currency-agnostic).
    @AppStorage("currencyCode") private var currencyCode: String = "USD"

    // Drives the placeholder Add sheet. The "+" and the empty-state CTA both
    // flip this true. TODO: replace the sheet body with the real one later.
    @State private var showingAddSheet = false

    // Subscriptions ordered by soonest bill first — the spec's required order.
    private var sortedSubscriptions: [Subscription] {
        subscriptions.sorted { $0.nextBillDate < $1.nextBillDate }
    }

    // Sum the normalized costs for the header via TotalsService, the single
    // source of truth the Home header and the Widget both share (no divergence).
    private var monthlyTotal: Double {
        TotalsService.monthlyTotal(subscriptions)
    }
    private var yearlyTotal: Double {
        TotalsService.yearlyTotal(subscriptions)
    }

    // ── BALANCE BANNER WIRING SPOT ─────────────────────────────────────────
    // This is where the Tech Lead maps the real BalanceService.status() into
    // the banner's BannerState. Today it's hardcoded to .hidden so nothing
    // shows and there's no dependency on the unbuilt Services layer.
    //
    // To wire it: find the payment method(s) worth warning about (e.g. the most
    // at-risk), call BalanceService.status(for:), and map:
    //   .ok    -> .hidden
    //   .stale -> .stale("Balance may be out of date")
    //   .atRisk(let shortfall) ->
    //       .warning("\(method.name) is short " +
    //                "\(Decimal(shortfall).formatted(.currency(code: currencyCode))) " +
    //                "for upcoming charges.")
    // Return that BannerState from here.
    private var bannerState: BannerState {
        // Evaluate every method's balance health, then reduce to a single banner
        // by severity: at-risk beats stale beats ok/hidden. Among multiple
        // at-risk methods, the one with the LARGEST shortfall wins.
        var worstAtRisk: (method: PaymentMethod, shortfall: Double)?
        var sawStale = false

        for method in paymentMethods {
            switch BalanceService.status(for: method) {
            case .ok:
                continue
            case .stale:
                sawStale = true
            case .atRisk(let shortfall):
                // Keep the biggest shortfall seen so far.
                if worstAtRisk == nil || shortfall > worstAtRisk!.shortfall {
                    worstAtRisk = (method, shortfall)
                }
            }
        }

        // At-risk is the most severe — show it if any method is short.
        if let risk = worstAtRisk {
            // Format the shortfall HERE using the view's currency code so the
            // banner stays currency-agnostic (it just renders the finished string).
            let amount = Decimal(risk.shortfall).formatted(.currency(code: currencyCode))
            return .warning("\(risk.method.name) is short \(amount) for upcoming charges.")
        }

        // No at-risk method, but at least one balance is out of date.
        if sawStale {
            return .stale("Balance may be out of date")
        }

        // Nothing worth showing.
        return .hidden
    }
    // ───────────────────────────────────────────────────────────────────────

    var body: some View {
        NavigationStack {
            Group {
                if subscriptions.isEmpty {
                    // Friendly empty state; its CTA opens the same Add sheet.
                    EmptyStateView(
                        icon: "tray",
                        title: "No subscriptions yet",
                        message: "Track your recurring bills to see totals and upcoming charges.",
                        ctaTitle: "Add your first subscription",
                        action: { showingAddSheet = true }
                    )
                } else {
                    subscriptionList
                }
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    // VoiceOver reads the intent, not just "plus".
                    .accessibilityLabel("Add subscription")
                }
            }
            // TODO: replace with the real AddEditSubscriptionView once it exists.
            .sheet(isPresented: $showingAddSheet) {
                AddSubscriptionPlaceholderView()
            }
        }
    }

    // The header + optional banner + list, shown when we have rows.
    private var subscriptionList: some View {
        List {
            // Header and banner ride in their own non-selectable section so
            // they scroll with the list but don't look like tappable rows.
            Section {
                VStack(spacing: 12) {
                    TotalsHeader(monthlyTotal: monthlyTotal, yearlyTotal: yearlyTotal)
                    // Renders nothing when .hidden, so no empty gap appears.
                    BalanceWarningBanner(state: bannerState)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            // The actual subscriptions, soonest bill first, swipe-to-delete.
            Section {
                ForEach(sortedSubscriptions) { subscription in
                    SubscriptionRow(subscription: subscription)
                }
                .onDelete(perform: deleteSubscriptions)
            }
        }
        .listStyle(.insetGrouped)
    }

    // Delete swiped rows. IndexSet indexes into `sortedSubscriptions` (what the
    // ForEach shows), so map back to those objects before removing them.
    private func deleteSubscriptions(at offsets: IndexSet) {
        for index in offsets {
            let subscription = sortedSubscriptions[index]
            modelContext.delete(subscription)
        }
    }
}

// Temporary stand-in for the Add screen so the "+" flow works and compiles.
// TODO: delete this and present the real AddEditSubscriptionView.
private struct AddSubscriptionPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Add subscription",
                systemImage: "plus.circle",
                description: Text("Coming soon")
            )
            .navigationTitle("New Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Dismiss add subscription")
                }
            }
        }
    }
}

#Preview {
    // Seed a real in-memory container with a few subscriptions + a payment
    // method so the list, header, and rows all render with real content.
    let container = Persistence.makePreviewContainer()
    let context = container.mainContext

    let chase = PaymentMethod(name: "Chase", balance: 200)
    context.insert(chase)

    let seeds: [Subscription] = [
        Subscription(name: "Netflix", price: 15.49, cycle: .monthly,
                     firstBillDate: .now, category: .entertainment, paymentMethod: chase),
        Subscription(name: "Spotify", price: 11.99, cycle: .monthly,
                     firstBillDate: Calendar.current.date(byAdding: .day, value: 3, to: .now)!,
                     category: .entertainment, paymentMethod: chase),
        Subscription(name: "iCloud+", price: 2.99, cycle: .monthly,
                     firstBillDate: Calendar.current.date(byAdding: .day, value: 1, to: .now)!,
                     category: .utilities)
    ]
    for sub in seeds { context.insert(sub) }

    return HomeView()
        .modelContainer(container)
}
