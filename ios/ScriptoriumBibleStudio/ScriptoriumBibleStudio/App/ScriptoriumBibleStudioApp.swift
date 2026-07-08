import SwiftUI

@main
struct ScriptoriumBibleStudioApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            StudioView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
                .environmentObject(persistence)
                .tint(SBTheme.primary)
                .font(SBTheme.ui(15))
                .fullScreenCover(isPresented: Binding(
                    get: { !hasCompletedOnboarding },
                    set: { if !$0 { hasCompletedOnboarding = true } }
                )) {
                    OnboardingView {
                        hasCompletedOnboarding = true
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background {
                        persistence.save()
                    }
                }
        }
    }
}
