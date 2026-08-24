import Foundation
import SwiftData

// Single source of truth for building the SwiftData stack. Everything that
// needs a container (the app, previews, later the widget) goes through here so
// the store location and schema live in ONE place.
enum Persistence {

    // The full model list the container must know about. Add new @Model types here.
    static let models: [any PersistentModel.Type] = [
        Subscription.self,
        PaymentMethod.self
    ]

    // The on-device container the running app uses.
    //
    // NOTE (App Group, planned): for the widget we'll eventually store the DB in
    // a shared App Group container. When entitlements/signing are ready, build a
    // ModelConfiguration with a URL from
    //   FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)
    // and pass it below — no model or view code changes needed. For the Week-1
    // foundation we use the default local store.
    static func makeContainer() -> ModelContainer {
        let schema = Schema(models)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false   // swap in .init(schema:url:) for the App Group later
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // A container that won't build is unrecoverable at launch, so fail
            // loudly with a clear message instead of limping along.
            fatalError("Failed to build ModelContainer: \(error)")
        }
    }

    // An ephemeral, in-memory container for SwiftUI previews and tests. Nothing
    // written here touches disk, so previews start clean every time.
    static func makePreviewContainer() -> ModelContainer {
        let schema = Schema(models)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to build preview ModelContainer: \(error)")
        }
    }
}
