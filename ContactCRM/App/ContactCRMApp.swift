import SwiftUI

@main
struct ContactCRMApp: App {
    @StateObject private var session = AppLockSession()
    private let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ZStack {
                if session.isUnlocked {
                    RootTabView()
                        .environment(\.managedObjectContext, persistence.container.viewContext)
                } else {
                    AppLockView(session: session)
                }
            }
            .onAppear { session.requestUnlock() }
        }
    }
}
