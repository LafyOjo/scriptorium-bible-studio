import SwiftUI

@main
struct ScriptoriumBibleStudioApp: App {
    @StateObject private var persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            StudioView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
                .environmentObject(persistence)
        }
    }
}
