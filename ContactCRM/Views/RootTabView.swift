import SwiftUI

struct RootTabView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompleted = false

    var body: some View {
        Group {
            if !hasCompleted {
                OnboardingView()
            } else {
                TabView {
                    DashboardView()
                        .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }
                    ContactListView()
                        .tabItem { Label("Contacts", systemImage: "person.crop.circle") }
                    PipelineBoardView()
                        .tabItem { Label("Pipelines", systemImage: "chart.bar.xaxis") }
                    RemindersView()
                        .tabItem { Label("Reminders", systemImage: "bell.badge") }
                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                }
            }
        }
    }
}
