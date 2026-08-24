import SwiftUI
import Charts

// A reusable "card" that renders a donut/pie chart from a list of slices.
//
// It's a pure presentation component: the caller does all the grouping and
// summing, then hands us already-computed (label, value, color) slices. We only
// worry about drawing the chart, a legend, and a VoiceOver-friendly summary.
struct PieChartCard: View {

    // One wedge of the pie. Identifiable so Charts + ForEach can track each slice
    // across redraws; `id` is derived from the label (labels are unique per chart).
    struct Slice: Identifiable {
        var id: String { label }
        let label: String
        let value: Double
        let color: Color
    }

    let title: String
    let slices: [Slice]

    // Currency for formatting each slice's money value in the legend. Defaults to
    // "USD"; Settings will write this shared key later so all screens agree.
    @AppStorage("currencyCode") private var currencyCode: String = "USD"

    // Total of every slice — used for percentage math in the accessibility summary.
    private var total: Double {
        slices.reduce(0) { $0 + $1.value }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            // The donut itself. SectorMark is the pie/donut primitive in Swift
            // Charts (iOS 17+). One mark per slice.
            Chart(slices) { slice in
                SectorMark(
                    // `angle` sizes each wedge proportionally to its value.
                    angle: .value("Spend", slice.value),
                    // A non-zero innerRadius turns the pie into a donut (nicer to read).
                    innerRadius: .ratio(0.58),
                    // A little gap between wedges so adjacent slices are distinct.
                    angularInset: 1.5
                )
                .cornerRadius(4)
                // Color each wedge explicitly so our category/method colors are stable.
                .foregroundStyle(slice.color)
            }
            // Feed our exact colors to the built-in legend by mapping label -> color.
            .chartForegroundStyleScale(
                domain: slices.map(\.label),
                range: slices.map(\.color)
            )
            .chartLegend(position: .bottom, alignment: .leading, spacing: 8)
            .frame(height: 220)
            // Hide Charts' auto-generated a11y (per-wedge) and give one clear summary.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(title))
            .accessibilityValue(Text(accessibilitySummary))
        }
        .padding()
        // Soft rounded card to match the app's other summary blocks.
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // A spoken sentence describing the whole breakdown, e.g.
    // "Entertainment 45 percent, 12.99. Work 30 percent, 8.00. ..."
    private var accessibilitySummary: String {
        guard total > 0 else { return "No data to display." }
        return slices.map { slice in
            let pct = Int((slice.value / total * 100).rounded())
            let money = Decimal(slice.value).formatted(.currency(code: currencyCode))
            return "\(slice.label) \(pct) percent, \(money)"
        }
        .joined(separator: ". ")
    }
}

#Preview {
    // Static sample slices — this component never reads the store.
    PieChartCard(
        title: "Spend by Category",
        slices: [
            .init(label: "Entertainment", value: 25.98, color: .blue),
            .init(label: "Work", value: 12.50, color: .green),
            .init(label: "Health", value: 9.99, color: .orange),
            .init(label: "Utilities", value: 6.00, color: .purple)
        ]
    )
    .padding()
}
