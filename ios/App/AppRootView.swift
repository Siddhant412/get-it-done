import SwiftUI
import SwiftData

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        AppTabView()
            .task {
                SampleDataSeeder.seedIfNeeded(in: modelContext)
            }
    }
}
