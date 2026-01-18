import SwiftUI

struct CalendarView: View {
    var body: some View {
        ScrollView {
            FeaturePlaceholderView(
                title: "Calendar",
                message: "Heatmaps, streaks, and journey views will live here."
            )
        }
        .navigationTitle("Calendar")
    }
}
