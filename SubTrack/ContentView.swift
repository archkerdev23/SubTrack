import SwiftUI
import SwiftData

// Root view: a 3-tab shell. The Home tab now hosts the real HomeView; Insights
// and Settings stay as placeholders until their workstreams land.
struct ContentView: View {
    var body: some View {
        TabView {
            // Home tab — the live subscriptions list, totals, and Add flow.
            HomeView()
                .tabItem { Label("Home", systemImage: "list.bullet") }

            // Insights tab — spend breakdown pies and top spenders.
            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.pie") }

            // Settings tab — reminders, payment methods, paywall.
            PlaceholderScreen(title: "Settings", systemImage: "gearshape")
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

// Tiny reusable stand-in so the not-yet-built tabs show something meaningful.
private struct PlaceholderScreen: View {
    let title: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text("Coming soon")
        )
    }
}

#Preview {
    // In-memory container so the preview needs no disk store.
    ContentView()
        .modelContainer(Persistence.makePreviewContainer())
}
