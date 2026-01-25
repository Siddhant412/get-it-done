import WidgetKit
import SwiftUI

struct GetItDoneWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct GetItDoneProvider: TimelineProvider {
    func placeholder(in context: Context) -> GetItDoneWidgetEntry {
        GetItDoneWidgetEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (GetItDoneWidgetEntry) -> Void) {
        let entry = GetItDoneWidgetEntry(date: Date(), snapshot: WidgetDataStore.load())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GetItDoneWidgetEntry>) -> Void) {
        let entry = GetItDoneWidgetEntry(date: Date(), snapshot: WidgetDataStore.load())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct StreakRingWidget: Widget {
    private let kind = "GetItDone.StreakRing"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GetItDoneProvider()) { entry in
            StreakRingWidgetView(entry: entry)
        }
        .configurationDisplayName("Streak Ring")
        .description("Your streak and today progress at a glance.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct TopPrioritiesWidget: Widget {
    private let kind = "GetItDone.TopPriorities"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GetItDoneProvider()) { entry in
            TopPrioritiesWidgetView(entry: entry)
        }
        .configurationDisplayName("Top Priorities")
        .description("Keep your top three priorities visible.")
        .supportedFamilies([.systemMedium, .systemSmall])
    }
}

struct StreakRingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GetItDoneWidgetEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: min(max(entry.snapshot.todayProgress, 0), 1)) {
                Image(systemName: "flame.fill")
            } currentValueLabel: {
                Text("\(entry.snapshot.streakDays)")
            }
            .gaugeStyle(.accessoryCircular)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 4) {
                Text("Streak")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(entry.snapshot.streakDays) days")
                    .font(.headline)
                Text("Today \(Int(entry.snapshot.todayProgress * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        default:
            ZStack {
                RingBackground()
                RingProgress(progress: entry.snapshot.todayProgress)
                VStack(spacing: 4) {
                    Text("\(entry.snapshot.streakDays)")
                        .font(.system(size: 28, weight: .bold))
                    Text("day streak")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Today \(Int(entry.snapshot.todayProgress * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
        }
    }
}

struct TopPrioritiesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GetItDoneWidgetEntry

    var body: some View {
        let items = entry.snapshot.topPriorities
        let displayItems = Array(items.prefix(family == .systemSmall ? 2 : 3).enumerated())
        VStack(alignment: .leading, spacing: 8) {
            Text("Top priorities")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(displayItems, id: \.offset) { _, item in
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                    Text(item)
                        .font(.caption2)
                        .lineLimit(1)
                }
            }

            if items.isEmpty {
                Text("No priorities yet")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
    }
}

private struct RingBackground: View {
    var body: some View {
        Circle()
            .stroke(Color(.systemGray5), lineWidth: 10)
    }
}

private struct RingProgress: View {
    let progress: Double

    var body: some View {
        Circle()
            .trim(from: 0, to: min(max(progress, 0), 1))
            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
            .rotationEffect(.degrees(-90))
    }
}

@main
struct GetItDoneWidgetBundle: WidgetBundle {
    var body: some Widget {
        StreakRingWidget()
        TopPrioritiesWidget()
    }
}
