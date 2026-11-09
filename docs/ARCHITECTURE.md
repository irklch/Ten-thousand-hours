# 10 000 Hours — архитектура

Нативное iOS-приложение: Swift 6 (strict concurrency), SwiftUI, SwiftData, MVVM. iOS 17+, только iPhone, портретная ориентация, светлая тема, русская локализация. Без сторонних зависимостей.

## Структура

```
TenThousandHours/
├── App/                    точка входа, корневой TabView, список вкладок
├── Core/
│   ├── Session/            SessionSnapshot (значение), SessionRules (минимум 60 с, секунды), SessionError
│   ├── Timer/              TimerEngine — Play/Stop/restore по сохранённым timestamp
│   ├── Progress/           ProgressCalculator, ProgressGoal (10 000 ч), ProgressFormatter
│   └── Tracking/           TrackingStore — @Observable состояние для HomeViewModel
├── DesignSystem/           цвета, типографика, отступы и радиусы
│   └── Components/         PlayStopButton, ProgressDot, HistoryRow (презентационные)
├── Data/
│   ├── Models/             @Model Session
│   ├── Repositories/       SessionRepository (протокол) + SwiftDataSessionRepository
│   └── Persistence/        ModelContainerFactory — единая точка создания SwiftData-контейнера
├── Features/
│   ├── Home/               главный экран
│   └── History/            история сессий
├── Localizable.xcstrings   строки (язык разработки — ru)
└── Assets.xcassets
TenThousandHoursTests/      unit-тесты (XCTest)
TenThousandHoursUITests/    UI-тест навигации по вкладкам
```

Папки, которые появятся на следующих этапах:

| Папка | Этап | Что будет внутри |
|---|---|---|
| `Features/Progress` | 3 | полноэкранный просмотр 10 000 точек |
| `Shared` | виджеты | контракты, общие для приложения и Widget Extension (снимок состояния таймера, идентификатор App Group) |

## Принципы

- View не содержат бизнес-логики. ViewModel (`@Observable`, `@MainActor`) появляется у фичи вместе с первой логикой — пустых ViewModel-заглушек нет.
- Зависимости передаются явно через инициализаторы и `Environment`; DI-контейнера и координаторов нет.
- Все цвета, шрифты и отступы берутся только из `DesignSystem` (источник — Design System в Figma).
- Типографика — системный SF Pro с размерами/весами/трекингом из макета и поддержкой Dynamic Type через `@ScaledMetric`.
- Таб-бар — системный `TabView`; на iOS 26+ он автоматически получает Liquid Glass, на iOS 17–18 — стандартный вид.

## Время и хранение (этап 2)

- **Источник истины — SwiftData.** `Session` хранит `startDate`, `endDate?` и `durationSeconds?`. Сессия активна, пока `endDate == nil`. У завершённой сессии длительность берётся только из `durationSeconds` (её можно редактировать, `endDate` при этом не меняется).
- **Абсолютные timestamp.** `startDate` и `endDate` округляются вниз до целой секунды. Текущее время = `max(0, now − startDate)`; UI-тикер (`TrackingStore.keepRefreshing`) только перечитывает часы раз в секунду и ничего не накапливает. Поэтому сворачивание, блокировка, убийство процесса и перезагрузка не влияют на отсчёт: при возврате в `.active` вызывается `restore()`.
- **Часы внедряются** (`now: () -> Date`), тесты используют управляемые часы без `sleep`.
- **Изоляция.** Приложение по умолчанию `@MainActor`; репозиторий работает с `mainContext`. Операции `start`/`stop` синхронны и не содержат точек приостановки, поэтому выполняются атомарно — две активные сессии не создать даже при параллельных вызовах. Дополнительно `createActiveSession` проверяет отсутствие активной сессии в хранилище, а `TimerEngine` перед каждым действием читает актуальное состояние из репозитория (готовность к App Intents из другого процесса). Чистые расчёты (`ProgressCalculator`, `SessionRules`, снимки) — `nonisolated` и `Sendable`.
- **Ошибки.** При ошибке `save()` контекст откатывается (`rollback()`), состояние движка не меняется, `TrackingStore.error` получает ошибку.
- **Изменение системного времени** не отслеживается: если часы переведены назад, прошедшее время не становится отрицательным (Stop удалит такую сессию как короткую); перевод вперёд увеличит длительность.
- **Прогресс.** `часы = totalSeconds / 3600`, `процент = totalSeconds / 36 000 000 × 100`; визуально ограничены 100 % и 10 000 точками, фактическое время не обрезается. Для UI процент выводится с двумя знаками без округления вверх (`ProgressFormatter`).

## Подготовка к расширениям

- **Widget Extension / Live Activity / App Intents**: добавляются отдельными таргетами. Общий код (`DesignSystem`, будущий `Shared`, модели SwiftData) подключается к ним как дополнительные synchronized-группы.
- **App Group**: `ModelConfiguration` использует `groupContainer: .automatic` по умолчанию — после добавления entitlement App Group хранилище SwiftData будет создаваться в общем контейнере и станет доступно виджетам. Важно добавить App Group до выпуска первой версии, иначе потребуется миграция файла хранилища.
