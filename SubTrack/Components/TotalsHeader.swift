import SwiftUI

// Header card shown at the top of Home: the user's total monthly and yearly
// spend across every tracked subscription, formatted in the chosen currency.
//
// This is a pure presentation component — it takes already-summed Doubles and
// only worries about layout and formatting. The parent (HomeView) does the
// summing from the subscription list.
struct TotalsHeader: View {
    let monthlyTotal: Double
    let yearlyTotal: Double

    // Single source of truth for the app's currency. Settings will write this
    // key later; for now it defaults to "USD". We format money with a real
    // currency FormatStyle so we NEVER hardcode a "$".
    @AppStorage("currencyCode") private var currencyCode: String = "USD"

    var body: some View {
        // Two columns: monthly on the left, yearly on the right.
        HStack(alignment: .top) {
            totalColumn(title: "Monthly", amount: monthlyTotal)
            Spacer()
            totalColumn(title: "Yearly", amount: yearlyTotal)
        }
        .padding()
        // A soft rounded card so the header reads as a distinct summary block.
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
    }

    // One labelled money column. Extracted so both totals share exact styling.
    private func totalColumn(title: String, amount: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            // Decimal + .currency FormatStyle localizes grouping/decimals and
            // uses the chosen code — no manual symbols, no string concatenation.
            Text(Decimal(amount).formatted(.currency(code: currencyCode)))
                .font(.title2.weight(.semibold))
                // Let big Dynamic Type sizes shrink slightly instead of clipping.
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        // Merge the two Text views into one VoiceOver phrase, e.g. "Monthly, $42.00".
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    // Static numbers are fine here — this component doesn't read the store.
    TotalsHeader(monthlyTotal: 42.97, yearlyTotal: 515.64)
}
