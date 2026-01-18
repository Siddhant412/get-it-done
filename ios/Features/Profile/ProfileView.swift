import SwiftUI

struct ProfileView: View {
    var body: some View {
        ScrollView {
            FeaturePlaceholderView(
                title: "Profile",
                message: "Rewards, themes, and settings will live here."
            )
        }
        .navigationTitle("Profile")
    }
}
