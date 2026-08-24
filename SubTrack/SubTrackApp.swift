import SwiftUI
import SwiftData

// The app entry point. @main tells Swift this struct owns the app lifecycle.
@main
struct SubTrackApp: App {
    // Build the SwiftData container once and hand it to the whole view tree.
    // Persistence.makeContainer() is our single factory — swap the store URL
    // (e.g. an App Group URL for the widget) there later without touching views.
    let modelContainer: ModelContainer = Persistence.makeContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // .modelContainer injects the container into the SwiftUI environment so
        // every child view can use @Query (to read) and modelContext (to write).
        .modelContainer(modelContainer)
    }
}
