import SwiftUI

// A reusable, friendly empty-state block: a big icon, a title, an optional
// message, and a call-to-action button. The button's action is injected as a
// closure so callers decide what "the CTA" does (Home uses it to open Add).
struct EmptyStateView: View {
    let icon: String            // SF Symbol name
    let title: String
    let message: String
    let ctaTitle: String
    let action: () -> Void      // what the CTA button does

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)   // decorative; title conveys meaning

            VStack(spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: action) {
                Text(ctaTitle)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            // Spell out the action for VoiceOver users.
            .accessibilityLabel(Text(ctaTitle))
        }
        .padding(32)
        // Center in whatever space the parent gives us, so it sits mid-screen.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView(
        icon: "tray",
        title: "No subscriptions yet",
        message: "Track your recurring bills to see totals and upcoming charges.",
        ctaTitle: "Add your first subscription",
        action: {}
    )
}
