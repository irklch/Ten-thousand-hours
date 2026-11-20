import AppIntents
import SwiftUI
import WidgetKit

/// Widget content per Figma: Small is a Play/Stop button in the middle; Large is the percent, the
/// hours and Play/Stop in the bottom right corner.
struct TrackingWidgetView: View {
    let display: TrackingWidgetDisplay
    let family: WidgetFamily

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        Group {
            switch display.content {
            case .ready(let ready):
                switch family {
                case .systemSmall:
                    smallContent(ready)
                default:
                    largeContent(ready)
                }
            case .unavailable(let message):
                unavailableContent(message)
            }
        }
        .padding(Layout.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            AppColor.background
        }
    }

    private func smallContent(_ ready: TrackingWidgetDisplay.Ready) -> some View {
        controlButton(ready)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func largeContent(_ ready: TrackingWidgetDisplay.Ready) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Layout.progressSpacing) {
                Text(verbatim: ready.percentText)
                    .appTextStyle(.largeTimer)
                    .foregroundStyle(AppColor.primaryText)
                    .accessibilityLabel(Text(verbatim: ready.percentAccessibilityLabel))
                Text(verbatim: ready.hoursText)
                    .appTextStyle(.body)
                    .foregroundStyle(AppColor.secondaryText)
                    .accessibilityLabel(Text(verbatim: ready.hoursAccessibilityLabel))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .dynamicTypeSize(...DynamicTypeSize.xLarge)

            Spacer(minLength: Layout.minimumGap)

            HStack {
                Spacer(minLength: 0)
                controlButton(ready)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func unavailableContent(_ message: String) -> some View {
        // No button: tapping the widget opens the app, which prepares the data.
        Text(verbatim: message)
            .appTextStyle(family == .systemSmall ? .caption : .body)
            .foregroundStyle(AppColor.secondaryText)
            .multilineTextAlignment(family == .systemSmall ? .center : .leading)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: family == .systemSmall ? .center : .topLeading
            )
    }

    @ViewBuilder
    private func controlButton(_ ready: TrackingWidgetDisplay.Ready) -> some View {
        let label = PlayStopButtonLabel(
            isRunning: ready.isRunning,
            appearance: renderingMode == .fullColor ? .standard : .monochrome
        )
        Group {
            if ready.isRunning {
                Button(intent: StopTrackingIntent()) { label }
            } else {
                Button(intent: StartTrackingIntent()) { label }
            }
        }
        .buttonStyle(.plain)
        .widgetAccentable()
        .accessibilityLabel(Text(verbatim: ready.buttonAccessibilityLabel))
    }
}

private extension TrackingWidgetView {
    enum Layout {
        static let padding: CGFloat = 24
        static let progressSpacing: CGFloat = 4
        static let minimumGap: CGFloat = 12
    }
}

#if DEBUG
private extension TrackingWidgetDisplay {
    static func preview(isRunning: Bool, hours: Int) -> TrackingWidgetDisplay {
        TrackingWidgetDisplay(
            state: .ready(TrackingStatus(
                activeSessionStartDate: isRunning ? Date() : nil,
                completedSessionsSeconds: hours * ProgressGoal.secondsPerHour
            )),
            date: Date()
        )
    }
}

#Preview("Small — Play", traits: .fixedLayout(width: 170, height: 170)) {
    TrackingWidgetView(display: .preview(isRunning: false, hours: 1_245), family: .systemSmall)
}

#Preview("Small — Stop", traits: .fixedLayout(width: 170, height: 170)) {
    TrackingWidgetView(display: .preview(isRunning: true, hours: 1_245), family: .systemSmall)
}

#Preview("Large — 12,45%", traits: .fixedLayout(width: 364, height: 382)) {
    TrackingWidgetView(display: .preview(isRunning: false, hours: 1_245), family: .systemLarge)
}

#Preview("Large — 100%", traits: .fixedLayout(width: 338, height: 354)) {
    TrackingWidgetView(display: .preview(isRunning: true, hours: 10_000), family: .systemLarge)
}
#endif
