import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Live Activity on the Lock Screen and in the Dynamic Island. Figma has no mockup for it, so it is a
/// plain native layout in the app's black-and-white style. Only Stop: the app has no Pause.
struct TrackingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrackingActivityAttributes.self) { context in
            LockScreenView(startDate: context.attributes.startDate)
                .activityBackgroundTint(AppColor.background)
                .activitySystemActionForegroundColor(AppColor.primaryText)
        } dynamicIsland: { context in
            let startDate = context.attributes.startDate
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label { Text(verbatim: "10 000 Hours") } icon: { TrackingSymbol() }
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    StopButton(diameter: 44, onDark: true)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    SessionDuration(startDate: startDate)
                        .font(.system(size: 40, weight: .light).monospacedDigit())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                }
            } compactLeading: {
                TrackingSymbol()
            } compactTrailing: {
                SessionDuration(startDate: startDate)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .frame(maxWidth: 56)
            } minimal: {
                TrackingSymbol()
            }
            .keylineTint(.white)
        }
    }
}

private struct LockScreenView: View {
    let startDate: Date

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "10 000 Hours")
                    .font(.subheadline.weight(.semibold))
                Text("Идёт отслеживание")
                    .font(.footnote)
                    .foregroundStyle(AppColor.secondaryText)
                SessionDuration(startDate: startDate)
                    .font(.system(size: 40, weight: .light).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            StopButton(diameter: 56, onDark: false)
        }
        .foregroundStyle(AppColor.primaryText)
        .padding(16)
    }
}

/// Duration from the saved `startDate`, counted by the system: no timer in the app and no
/// accumulated error. The hours are not capped at 24 (`1 day` is shown as `24:00:00`).
private struct SessionDuration: View {
    let startDate: Date

    var body: some View {
        Text(timerInterval: startDate...Date.distantFuture, countsDown: false)
            .multilineTextAlignment(.leading)
            .accessibilityLabel(Text("Длительность текущей сессии"))
    }
}

private struct TrackingSymbol: View {
    var body: some View {
        Image(systemName: "timer")
            .foregroundStyle(.white)
            .accessibilityLabel(Text("Идёт отслеживание"))
    }
}

/// Runs the same `StopTrackingIntent` as the widgets: one Stop implementation for every control.
private struct StopButton: View {
    let diameter: CGFloat
    /// The Dynamic Island is always black; the Lock Screen card has the app's white background.
    let onDark: Bool

    var body: some View {
        Button(intent: StopTrackingIntent()) {
            Image(systemName: "stop.fill")
                .font(.system(size: diameter * 0.36, weight: .bold))
                .frame(width: diameter, height: diameter)
                .foregroundStyle(onDark ? Color.black : Color.white)
                .background(Circle().fill(onDark ? Color.white : Color.black))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Остановить"))
    }
}
