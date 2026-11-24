import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Live Activity на экране блокировки и в Dynamic Island. Макета в Figma для неё нет, поэтому это
/// простая нативная вёрстка в чёрно-белом стиле приложения. Только Stop: паузы в приложении нет.
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

/// Длительность от сохранённого `startDate`, её считает система: ни таймера в приложении, ни
/// накопленной погрешности. Часы не ограничены 24 (`1 day` показывается как `24:00:00`).
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

/// Запускает тот же `StopTrackingIntent`, что и виджеты: одна реализация Stop для всех элементов управления.
private struct StopButton: View {
    let diameter: CGFloat
    /// Dynamic Island всегда чёрный; у карточки на экране блокировки белый фон приложения.
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
