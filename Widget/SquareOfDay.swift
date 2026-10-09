import SwiftUI
import WidgetKit

struct DayEntry: TimelineEntry {
    let date: Date
    let n: Int
}

struct DayProvider: TimelineProvider {
    func placeholder(in context: Context) -> DayEntry { DayEntry(date: Date(), n: 47) }

    func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
        completion(DayEntry(date: Date(), n: Daily.number()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
        let now = Date()
        let midnight = Calendar.current.startOfDay(for: now.addingTimeInterval(86_400))
        let entries = [DayEntry(date: now, n: Daily.number(on: now)), DayEntry(date: midnight, n: Daily.number(on: midnight))]
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }
}

private let coral = Color(red: 0xEE / 255, green: 0x5C / 255, blue: 0x3E / 255)
private let jungle = Color(red: 0x17 / 255, green: 0x38 / 255, blue: 0x27 / 255)
private let lavender = Color(red: 0x8F / 255, green: 0x95 / 255, blue: 0xF9 / 255)
private let peach = Color(red: 0xFF / 255, green: 0xC4 / 255, blue: 0x7B / 255)

struct SquareOfDayView: View {
    var entry: DayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Square of the day").font(.system(size: 13, weight: .bold)).foregroundStyle(peach)
                Spacer(minLength: 0)
                (Text(verbatim: "\(entry.n)").font(.system(size: 44, weight: .heavy))
                    + Text(verbatim: "2").font(.system(size: 20, weight: .heavy)).baselineOffset(20))
                    .foregroundStyle(.white)
                Text(verbatim: "= \(entry.n * entry.n)").font(.system(size: 22, weight: .heavy)).foregroundStyle(.white.opacity(0.9))
            }
            .environment(\.layoutDirection, .leftToRight)
            if family == .systemMedium {
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: "\(entry.n) × \(entry.n)").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                    Text("Open the app to capture it on your field").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .frame(maxWidth: 140, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            ZStack {
                jungle
                Circle().fill(coral).frame(width: 90, height: 90).offset(x: 45, y: -45)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                Circle().fill(lavender.opacity(0.9)).frame(width: 50, height: 50).offset(x: 25, y: 25)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
    }
}

@main
struct SquareOfDayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SquareOfDay", provider: DayProvider()) { SquareOfDayView(entry: $0) }
            .configurationDisplayName(Text("Square of the day"))
            .description(Text("A new square every day"))
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
