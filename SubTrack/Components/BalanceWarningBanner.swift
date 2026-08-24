import SwiftUI

// A reusable warning banner shown at the top of Home when a payment method's
// balance needs the user's attention.
//
// ── WIRING NOTE FOR THE TECH LEAD ──────────────────────────────────────────
// This banner deliberately does NOT depend on Services/. It takes a small local
// `BannerState` so it compiles today, before BalanceService exists. When you
// wire the real service, map BalanceStatus → BannerState at the call site in
// HomeView (see `bannerState` there). Suggested mapping:
//
//     switch BalanceService.status(for: method) {
//     case .ok:                     return .hidden
//     case .stale:                  return .stale("Balance may be out of date")
//     case .atRisk(let shortfall):  return .warning(shortfallMessage(shortfall))
//     }
//
// Keep the currency formatting for the shortfall on the HomeView side (it owns
// the @AppStorage currency code) and pass the finished string in here.
// ───────────────────────────────────────────────────────────────────────────
enum BannerState: Equatable {
    case hidden            // nothing to show (maps from BalanceStatus.ok)
    case stale(String)     // soft reminder (maps from BalanceStatus.stale)
    case warning(String)   // hard warning w/ shortfall (maps from BalanceStatus.atRisk)
}

struct BalanceWarningBanner: View {
    let state: BannerState

    var body: some View {
        // For .hidden we render truly nothing, so the banner takes no space.
        switch state {
        case .hidden:
            EmptyView()
        case .stale(let message):
            banner(
                icon: "clock.badge.exclamationmark",
                message: message,
                tint: .yellow,
                isHard: false
            )
        case .warning(let message):
            banner(
                icon: "exclamationmark.triangle.fill",
                message: message,
                tint: .red,
                isHard: true
            )
        }
    }

    // Shared banner layout. `isHard` bumps the emphasis for the at-risk case.
    private func banner(icon: String, message: String, tint: Color, isHard: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .fontWeight(isHard ? .semibold : .regular)
                // Wrap freely under large Dynamic Type instead of truncating.
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding()
        // Soft tinted fill; the hard case reads stronger via the border.
        .background(tint.opacity(isHard ? 0.18 : 0.12),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tint.opacity(isHard ? 0.6 : 0.0), lineWidth: 1)
        )
        .padding(.horizontal)
        // One combined VoiceOver phrase; flag the urgent one as such.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(isHard ? "Warning. \(message)" : message))
    }
}

#Preview("Warning") {
    VStack(spacing: 16) {
        BalanceWarningBanner(state: .warning("Chase is short $12.40 for upcoming charges."))
        BalanceWarningBanner(state: .stale("Balance may be out of date."))
        // .hidden renders nothing — proves it collapses to zero height.
        BalanceWarningBanner(state: .hidden)
    }
}
