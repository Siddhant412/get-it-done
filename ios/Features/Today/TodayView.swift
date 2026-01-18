import SwiftUI

struct TodayView: View {
    @State private var animatedProgress: Double = 0.0

    private let todayProgress: Double = 0.68
    private let topPriorities = [
        PriorityItem(title: "Ship onboarding flow", detail: "Build | 40 min", isSmallWin: false),
        PriorityItem(title: "LeetCode: 1 medium problem", detail: "DSA | 25 min", isSmallWin: true),
        PriorityItem(title: "Read 20 min", detail: "Focus | 20 min", isSmallWin: true)
    ]
    private let habits = [
        HabitItem(title: "Gym", streak: 6, progress: 0.8),
        HabitItem(title: "Journal", streak: 12, progress: 0.6),
        HabitItem(title: "LeetCode", streak: 9, progress: 0.5),
        HabitItem(title: "Hydration", streak: 15, progress: 0.7)
    ]

    var body: some View {
        ZStack {
            TodayBackground()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    HeaderRow(dateText: dateText)

                    HeroCard(progress: animatedProgress, streakDays: 14, focusMinutes: 38)

                    SectionHeader(title: "Top 3 priorities", actionTitle: "Edit")
                    ForEach(topPriorities) { item in
                        PriorityRow(item: item)
                    }

                    SectionHeader(title: "Habits to keep alive", actionTitle: "All")
                    HabitRow(items: habits)

                    MomentumCard(progress: 0.76)

                    QuickActionsCard()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) {
                animatedProgress = todayProgress
            }
        }
    }

    private var dateText: String {
        TodayView.dateFormatter.string(from: Date())
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()
}

private struct TodayBackground: View {
    var body: some View {
        LinearGradient(
            colors: [TodayTheme.backgroundTop, TodayTheme.backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(TodayTheme.glow)
                .frame(width: 220, height: 220)
                .offset(x: 90, y: -80)
        }
        .overlay(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(TodayTheme.panelSoft)
                .frame(width: 240, height: 140)
                .rotationEffect(.degrees(-8))
                .offset(x: -60, y: 70)
        }
    }
}

private struct HeaderRow: View {
    let dateText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Today")
                .font(.custom("Avenir Next", size: 32))
                .fontWeight(.bold)
                .foregroundStyle(TodayTheme.ink)
            Text(dateText)
                .font(.custom("Avenir Next", size: 16))
                .foregroundStyle(TodayTheme.inkSoft)
        }
        .padding(.top, 6)
    }
}

private struct HeroCard: View {
    let progress: Double
    let streakDays: Int
    let focusMinutes: Int

    var body: some View {
        HStack(spacing: 18) {
            ProgressRing(progress: progress)

            VStack(alignment: .leading, spacing: 10) {
                Text("Daily momentum")
                    .font(.custom("Avenir Next", size: 18))
                    .fontWeight(.semibold)
                    .foregroundStyle(TodayTheme.ink)

                Text("Complete one small win to keep your streak alive.")
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundStyle(TodayTheme.inkSoft)

                HStack(spacing: 12) {
                    StatPill(title: "Streak", value: "\(streakDays) days")
                    StatPill(title: "Focus", value: "\(focusMinutes) min")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(TodayTheme.cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(TodayTheme.cardBorder, lineWidth: 1)
        )
    }
}

private struct ProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(TodayTheme.ringTrack, lineWidth: 10)
            Circle()
                .trim(from: 0, to: max(0.02, progress))
                .stroke(
                    TodayTheme.ringGradient,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(Int(progress * 100))%")
                    .font(.custom("Avenir Next", size: 18))
                    .fontWeight(.bold)
                Text("today")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(TodayTheme.inkSoft)
            }
            .foregroundStyle(TodayTheme.ink)
        }
        .frame(width: 84, height: 84)
    }
}

private struct StatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.custom("Avenir Next", size: 10))
                .fontWeight(.semibold)
                .foregroundStyle(TodayTheme.inkSoft)
            Text(value)
                .font(.custom("Avenir Next", size: 13))
                .fontWeight(.semibold)
                .foregroundStyle(TodayTheme.ink)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(TodayTheme.pillBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SectionHeader: View {
    let title: String
    let actionTitle: String

    var body: some View {
        HStack {
            Text(title)
                .font(.custom("Avenir Next", size: 20))
                .fontWeight(.semibold)
                .foregroundStyle(TodayTheme.ink)
            Spacer()
            Button(actionTitle) { }
                .font(.custom("Avenir Next", size: 14))
                .foregroundStyle(TodayTheme.accent)
        }
        .padding(.top, 6)
    }
}

private struct PriorityRow: View {
    let item: PriorityItem

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .strokeBorder(TodayTheme.accent, lineWidth: 2)
                .frame(width: 22, height: 22)
                .overlay(
                    Circle()
                        .fill(item.isSmallWin ? TodayTheme.highlight : Color.clear)
                        .frame(width: 10, height: 10)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.custom("Avenir Next", size: 16))
                    .fontWeight(.semibold)
                    .foregroundStyle(TodayTheme.ink)
                Text(item.detail)
                    .font(.custom("Avenir Next", size: 13))
                    .foregroundStyle(TodayTheme.inkSoft)
            }

            Spacer()

            Text(item.isSmallWin ? "Tiny win" : "Core")
                .font(.custom("Avenir Next", size: 12))
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(item.isSmallWin ? TodayTheme.badgeSoft : TodayTheme.badgeStrong)
                .foregroundStyle(TodayTheme.ink)
                .clipShape(Capsule())
        }
        .padding(14)
        .background(TodayTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: TodayTheme.shadow, radius: 8, x: 0, y: 5)
    }
}

private struct HabitRow: View {
    let items: [HabitItem]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(items) { item in
                    HabitCard(item: item)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct HabitCard: View {
    let item: HabitItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.title)
                .font(.custom("Avenir Next", size: 16))
                .fontWeight(.semibold)
                .foregroundStyle(TodayTheme.ink)

            Text("\(item.streak)-day streak")
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(TodayTheme.inkSoft)

            ProgressBar(progress: item.progress)
        }
        .padding(14)
        .frame(width: 160)
        .background(TodayTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: TodayTheme.shadow, radius: 8, x: 0, y: 5)
    }
}

private struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(TodayTheme.ringTrack)
                Capsule()
                    .fill(TodayTheme.progressFill)
                    .frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: 8)
    }
}

private struct MomentumCard: View {
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Momentum meter")
                .font(.custom("Avenir Next", size: 18))
                .fontWeight(.semibold)
                .foregroundStyle(TodayTheme.ink)
            Text("You are close to your best streak. One small task keeps the chain unbroken.")
                .font(.custom("Avenir Next", size: 13))
                .foregroundStyle(TodayTheme.inkSoft)
            ProgressBar(progress: progress)
        }
        .padding(16)
        .background(TodayTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: TodayTheme.shadow, radius: 8, x: 0, y: 5)
    }
}

private struct QuickActionsCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Button("Start focus") { }
                .font(.custom("Avenir Next", size: 15))
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(TodayTheme.primaryButton)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button("Quick add") { }
                .font(.custom("Avenir Next", size: 15))
                .fontWeight(.semibold)
                .foregroundStyle(TodayTheme.ink)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(TodayTheme.secondaryButton)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(16)
        .background(TodayTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: TodayTheme.shadow, radius: 8, x: 0, y: 5)
    }
}

private struct PriorityItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let isSmallWin: Bool
}

private struct HabitItem: Identifiable {
    let id = UUID()
    let title: String
    let streak: Int
    let progress: Double
}

private enum TodayTheme {
    static let backgroundTop = Color(red: 0.97, green: 0.94, blue: 0.90)
    static let backgroundBottom = Color(red: 0.94, green: 0.98, blue: 0.98)
    static let glow = Color(red: 0.93, green: 0.76, blue: 0.58, opacity: 0.45)
    static let panelSoft = Color(red: 0.87, green: 0.93, blue: 0.92, opacity: 0.6)
    static let cardSurface = Color(red: 0.99, green: 0.98, blue: 0.97, opacity: 0.95)
    static let cardGradient = LinearGradient(
        colors: [
            Color(red: 0.99, green: 0.97, blue: 0.94),
            Color(red: 0.96, green: 0.98, blue: 0.97)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let cardBorder = Color(red: 0.85, green: 0.87, blue: 0.88, opacity: 0.6)
    static let ink = Color(red: 0.15, green: 0.16, blue: 0.18)
    static let inkSoft = Color(red: 0.38, green: 0.40, blue: 0.44)
    static let accent = Color(red: 0.19, green: 0.55, blue: 0.50)
    static let highlight = Color(red: 0.92, green: 0.42, blue: 0.32)
    static let badgeSoft = Color(red: 0.95, green: 0.86, blue: 0.76)
    static let badgeStrong = Color(red: 0.86, green: 0.93, blue: 0.90)
    static let ringTrack = Color(red: 0.88, green: 0.90, blue: 0.92)
    static let ringGradient = AngularGradient(
        colors: [
            Color(red: 0.22, green: 0.62, blue: 0.54),
            Color(red: 0.96, green: 0.58, blue: 0.32)
        ],
        center: .center
    )
    static let progressFill = LinearGradient(
        colors: [
            Color(red: 0.23, green: 0.64, blue: 0.55),
            Color(red: 0.98, green: 0.70, blue: 0.42)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let pillBackground = Color(red: 0.94, green: 0.93, blue: 0.90)
    static let primaryButton = LinearGradient(
        colors: [
            Color(red: 0.20, green: 0.58, blue: 0.51),
            Color(red: 0.18, green: 0.45, blue: 0.40)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let secondaryButton = Color(red: 0.94, green: 0.90, blue: 0.84)
    static let shadow = Color(red: 0.15, green: 0.16, blue: 0.18, opacity: 0.08)
}
