import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2")
                }
                .tag(0)

            ProjectsListView()
                .tabItem {
                    Label("Projects", systemImage: "folder")
                }
                .tag(1)

            AssigneesView()
                .tabItem {
                    Label("Team", systemImage: "person.3")
                }
                .tag(2)

            ActivityView()
                .tabItem {
                    Label("Activity", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(3)

            OverdueView()
                .tabItem {
                    Label {
                        Text("Overdue")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                }
                .badge(appState.overdueTasks.count > 0 ? appState.overdueTasks.count : 0)
                .tag(4)
        }
    }
}
