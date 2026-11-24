import SwiftUI
import WidgetKit

@main
struct TenThousandHoursWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TrackingWidget()
        TrackingLiveActivity()
    }
}

/// One widget in two sizes: Small (Play/Stop) and Large (progress + Play/Stop).
struct TrackingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: TrackingWidgetKind.tracking, provider: TrackingTimelineProvider()) { entry in
            TrackingWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("10 000 Hours")
        .description("Запуск и остановка таймера, прогресс к 10 000 часов.")
        .supportedFamilies([.systemSmall, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct TrackingWidgetEntryView: View {
    let entry: TrackingWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        TrackingWidgetView(display: TrackingWidgetDisplay(state: entry.state, date: entry.date), family: family)
    }
}
