import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }
            ContactListView()
                .tabItem { Label("Contacts", systemImage: "person.crop.circle") }
            PipelineBoardView()
                .tabItem { Label("Pipelines", systemImage: "chart.bar.xaxis") }
        }
    }
}
