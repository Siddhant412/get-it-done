import SwiftUI
import Photos
import UserNotifications

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var page = 0
    @State private var notificationState: PermissionState = .unknown
    @State private var photoState: PermissionState = .unknown

    var body: some View {
        ZStack {
            OnboardingBackground()

            VStack(spacing: 24) {
                TabView(selection: $page) {
                    OnboardingWelcomePage()
                        .tag(0)
                    OnboardingNotificationPage(
                        state: notificationState,
                        onAllow: requestNotifications
                    )
                    .tag(1)
                    OnboardingPhotoPage(
                        state: photoState,
                        onAllow: requestPhotoAccess
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                HStack(spacing: 12) {
                    if page > 0 {
                        Button("Back") {
                            withAnimation {
                                page = max(0, page - 1)
                            }
                        }
                        .font(.custom("Avenir Next", size: 14))
                        .foregroundStyle(OnboardingTheme.ink)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(OnboardingTheme.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Button(page == 2 ? "Get started" : "Continue") {
                        if page == 2 {
                            hasCompletedOnboarding = true
                        } else {
                            withAnimation {
                                page = min(2, page + 1)
                            }
                        }
                    }
                    .font(.custom("Avenir Next", size: 14))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(OnboardingTheme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .padding(.top, 40)
        }
        .task {
            await refreshPermissionStates()
        }
    }

    private func requestNotifications() {
        Task {
            let granted = await NotificationManager.requestAuthorization()
            notificationState = granted ? .granted : .denied
        }
    }

    private func requestPhotoAccess() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    photoState = .granted
                case .denied, .restricted:
                    photoState = .denied
                default:
                    photoState = .unknown
                }
            }
        }
    }

    private func refreshPermissionStates() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationState = settings.authorizationStatus == .authorized ? .granted : .unknown

        let photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch photoStatus {
        case .authorized, .limited:
            photoState = .granted
        case .denied, .restricted:
            photoState = .denied
        default:
            photoState = .unknown
        }
    }
}

private struct OnboardingWelcomePage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome to GetItDone")
                .font(.custom("Avenir Next", size: 28))
                .fontWeight(.bold)
                .foregroundStyle(OnboardingTheme.ink)
            Text("Build momentum with streaks, quests, and a visual heatmap of your progress.")
                .font(.custom("Avenir Next", size: 15))
                .foregroundStyle(OnboardingTheme.inkSoft)
            OnboardingBullet(text: "Track habits, tasks, and milestones")
            OnboardingBullet(text: "Stay consistent with weekly quests")
            OnboardingBullet(text: "Celebrate progress with XP and streaks")
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

private struct OnboardingNotificationPage: View {
    let state: PermissionState
    let onAllow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Stay on track")
                .font(.custom("Avenir Next", size: 26))
                .fontWeight(.bold)
                .foregroundStyle(OnboardingTheme.ink)
            Text("Enable notifications for gentle streak reminders and habit nudges.")
                .font(.custom("Avenir Next", size: 15))
                .foregroundStyle(OnboardingTheme.inkSoft)
            PermissionStatusPill(state: state)
            Button("Allow notifications", action: onAllow)
                .font(.custom("Avenir Next", size: 14))
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(OnboardingTheme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

private struct OnboardingPhotoPage: View {
    let state: PermissionState
    let onAllow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Proof of progress")
                .font(.custom("Avenir Next", size: 26))
                .fontWeight(.bold)
                .foregroundStyle(OnboardingTheme.ink)
            Text("Attach a quick photo or screenshot to daily logs and milestones.")
                .font(.custom("Avenir Next", size: 15))
                .foregroundStyle(OnboardingTheme.inkSoft)
            PermissionStatusPill(state: state)
            Button("Allow photo access", action: onAllow)
                .font(.custom("Avenir Next", size: 14))
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(OnboardingTheme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

private struct OnboardingBullet: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(OnboardingTheme.primary)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.custom("Avenir Next", size: 14))
                .foregroundStyle(OnboardingTheme.ink)
        }
    }
}

private struct PermissionStatusPill: View {
    let state: PermissionState

    var body: some View {
        Text(state.label)
            .font(.custom("Avenir Next", size: 12))
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(state == .granted ? .white : OnboardingTheme.ink)
            .background(state == .granted ? OnboardingTheme.primary : OnboardingTheme.secondary)
            .clipShape(Capsule())
    }
}

private struct OnboardingBackground: View {
    var body: some View {
        LinearGradient(
            colors: [OnboardingTheme.backgroundTop, OnboardingTheme.backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private enum PermissionState {
    case unknown
    case granted
    case denied

    var label: String {
        switch self {
        case .unknown:
            return "Not set"
        case .granted:
            return "Granted"
        case .denied:
            return "Denied"
        }
    }
}

private enum OnboardingTheme {
    static let backgroundTop = Color(red: 0.95, green: 0.94, blue: 0.98)
    static let backgroundBottom = Color(red: 0.98, green: 0.98, blue: 0.96)
    static let primary = Color(red: 0.24, green: 0.52, blue: 0.56)
    static let secondary = Color(red: 0.92, green: 0.93, blue: 0.95)
    static let ink = AppPalette.ink
    static let inkSoft = AppPalette.inkSoft
}
