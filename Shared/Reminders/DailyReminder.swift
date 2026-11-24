import Foundation
import os
import UserNotifications

/// Какие дни получают напоминание в 20:00. Чистая функция: время, календарь и состояние передаются явно.
///
/// - Цель завершена — напоминаний нет.
/// - Сегодня пропускается, если таймер сегодня запускали или останавливали (даже отброшенную короткую сессию),
///   если он идёт прямо сейчас или если 20:00 уже прошло.
/// - Дальше — по одному напоминанию на каждый из следующих дней. Дата задаётся компонентами без часового пояса,
///   поэтому система показывает его в 20:00 того часового пояса, где сейчас устройство; переход на летнее и зимнее
///   время на 20:00 не влияет.
nonisolated enum DailyReminderPlan {
    static let hour = 20
    /// Запас на случай, если приложение и виджет долго не открывают. Лимит iOS — 64 ожидающих уведомления.
    static let dayCount = 30

    static func fireDates(
        now: Date,
        calendar: Calendar,
        lastTrackingDate: Date?,
        isRunning: Bool,
        isGoalCompleted: Bool
    ) -> [DateComponents] {
        guard !isGoalCompleted else { return [] }
        let today = calendar.startOfDay(for: now)
        let trackedToday = lastTrackingDate.map { calendar.isDate($0, inSameDayAs: now) } ?? false
        let reminderTimeToday = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: today) ?? today
        let firstOffset = isRunning || trackedToday || now >= reminderTimeToday ? 1 : 0

        return (firstOffset..<firstOffset + dayCount).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = hour
            components.minute = 0
            return components
        }
    }
}

/// Планирует локальные напоминания через `UNUserNotificationCenter`. Ничего не держит в памяти: каждый вызов
/// заменяет весь набор ожидающих напоминаний планом по текущему состоянию. Других уведомлений у приложения нет.
enum DailyReminderScheduler {
    private static let logger = Logger(subsystem: "com.irklch.TenThousandHours", category: "Reminders")
    nonisolated private static let identifierPrefix = "daily-reminder-"

    /// Вызывается после Play, Stop, правки истории, сброса и при каждом возврате в приложение.
    /// Ошибки только пишутся в лог: таймер от уведомлений не зависит.
    static func reschedule(
        isRunning: Bool,
        isGoalCompleted: Bool,
        preferences: SharedPreferences = .shared,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async {
        // Таймер идёт сегодня — значит, сегодня уже занимались (сессия могла начаться в другой день).
        if isRunning {
            preferences.recordTracking(at: now)
        }
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        let dates = DailyReminderPlan.fireDates(
            now: now,
            calendar: calendar,
            lastTrackingDate: preferences.lastTrackingDate,
            isRunning: isRunning,
            isGoalCompleted: isGoalCompleted
        )
        for components in dates {
            let request = UNNotificationRequest(
                identifier: identifier(for: components),
                content: content(),
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            do {
                try await center.add(request)
            } catch {
                logger.error("Reminder was not scheduled: \(error.localizedDescription, privacy: .public)")
                return
            }
        }
    }

    /// Системный запрос показывается один раз — пока пользователь не ответил. После отказа повторно не спрашиваем.
    /// - Returns: `true`, если разрешение только что выдано и напоминания стоит перепланировать.
    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        guard await center.notificationSettings().authorizationStatus == .notDetermined else { return false }
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            logger.error("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    nonisolated static func identifier(for components: DateComponents) -> String {
        "\(identifierPrefix)\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    /// Текст по макету Figma «Notification»; заголовок — название приложения, его показывает система.
    private static func content() -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.body = String(localized: "Даже 1 минута ближе к 10 000, чем 0 минут")
        content.sound = .default
        return content
    }
}
