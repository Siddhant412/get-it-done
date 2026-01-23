import SwiftUI

struct AppTabView: View {
    enum Tab: Hashable {
        case today
        case goals
        case tasks
        case calendar
        case insights
        case profile
    }

    @State private var selectedTab: Tab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TodayView()
            }
            .tabItem {
                Label("Today", systemImage: "sun.max")
            }
            .tag(Tab.today)

            NavigationStack {
                GoalsView()
            }
            .tabItem {
                Label("Goals", systemImage: "flag")
            }
            .tag(Tab.goals)

            NavigationStack {
                TasksView()
            }
            .tabItem {
                Label("Tasks", systemImage: "checklist")
            }
            .tag(Tab.tasks)

            NavigationStack {
                CalendarView()
            }
            .tabItem {
                Label("Calendar", systemImage: "calendar")
            }
            .tag(Tab.calendar)

            NavigationStack {
                InsightsView()
            }
            .tabItem {
                Label("Insights", systemImage: "chart.bar.xaxis")
            }
            .tag(Tab.insights)

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle")
            }
            .tag(Tab.profile)
        }
    }
}
