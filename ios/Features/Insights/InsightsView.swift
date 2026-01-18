import SwiftUI

struct InsightsView: View {
    var body: some View {
        ScrollView {
            FeaturePlaceholderView(
                title: "Insights",
                message: "Trends, consistency, and time analytics will live here."
            )
        }
        .navigationTitle("Insights")
    }
}
