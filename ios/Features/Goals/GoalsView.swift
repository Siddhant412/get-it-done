import SwiftUI

struct GoalsView: View {
    var body: some View {
        ScrollView {
            FeaturePlaceholderView(
                title: "Goals",
                message: "Goal cards, progress bars, and skill trees will live here."
            )
        }
        .navigationTitle("Goals")
    }
}
