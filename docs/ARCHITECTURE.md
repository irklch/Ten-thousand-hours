# 10 000 Hours — архитектура

Нативное iOS-приложение: Swift 6 (strict concurrency), SwiftUI, SwiftData, MVVM. iOS 17+, только iPhone, портретная ориентация, светлая тема, русская локализация. Без сторонних зависимостей.

## Структура

```
TenThousandHours/           приложение
├── App/                    точка входа (открытие хранилища, экран ошибки с «Повторить»), корневой TabView
├── Core/
│   ├── Session/            SessionDuration/DateFormatter, SessionDurationInput
│   ├── Timer/              ElapsedTimeFormatter
│   └── Tracking/           TrackingStore — @Observable состояние для экранов
├── Features/               Home, Progress (сетка), History
└── TenThousandHours.entitlements   App Group
Shared/                     общий код приложения и Widget Extension (одна synchronized-группа в двух target)
├── Session/                SessionSnapshot, SessionRules, SessionError
├── Timer/                  TimerEngine — Play/Stop/restore по сохранённым timestamp
├── Progress/               ProgressCalculator, ProgressGoal, ProgressFormatter
├── Persistence/            @Model Session, SessionRepository + SwiftData-реализация,
│                           ModelContainerFactory (схема + URL стора в App Group), FileLockCoordinator (flock)
├── Tracking/               TrackingStatus, SharedTracking, StartTrackingIntent / StopTrackingIntent
├── Widgets/                TrackingWidgetDisplay, TrackingTimelinePlanner, TrackingWidgetView
├── DesignSystem/           цвета, типографика, отступы, компоненты
└── Localizable.xcstrings   строки (язык разработки — ru)
TenThousandHoursWidgets/    Widget Extension: WidgetBundle, TimelineProvider, Info.plist, entitlements
TenThousandHoursTests/      unit- и интеграционные тесты (XCTest)
TenThousandHoursUITests/    UI-тесты; WidgetUITests — проверка виджета на Springboard (запуск вручную)
```

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

## Главный экран (этап 3)

- `HomeViewModel` — лёгкая структура над `TrackingStore`: только форматирование (`ElapsedTimeFormatter`, `ProgressFormatter`) и действия Play/Stop. Расчётов прогресса во View нет.
- Таймер показывает длительность текущего запуска: `MM:SS`, с часа — `HH:MM:SS`, часы не сбрасываются после 24 и расширяются при необходимости.
- Ежесекундное обновление запускается через `.task(id:)` только когда таймер работает, сцена активна и экран виден; смена состояния отменяет предыдущую задачу, поэтому параллельных циклов не бывает. Тики выравниваются по границе секунды. Источник времени по-прежнему — `TimerEngine`.
- Для UI-тестов (только DEBUG) аргумент `-ui-testing` переключает хранилище на временный файл, `-ui-testing-reset` очищает его.

## Сетка прогресса (этап 4)

- `ProgressGridLayout` (чистая логика): число колонок по ширине (`floor((w + gap) / (d + gap))`), `rows = ceil(10 000 / columns)`, неполный последний ряд, заполненные точки ряда. Стили из Figma: главная — точки 6 pt / шаг 9, полноэкранный — 7 pt / шаг 11.
- `ProgressGridPositioning` / `ProgressGridScrollState`: ряд границы (первая незаполненная точка), стартовая позиция (0 % или граница уже видна без прокрутки — начало, как в Figma «1 245 точек»; 100 % — конец; иначе граница по центру, как в Figma «2 450 точек»; края ScrollView ограничивает сам), позиционирование выполняется один раз за жизнь экрана — обновления прогресса и пересоздание body ручную прокрутку не сбрасывают.
- `ProgressGridRows`: `LazyVStack` по рядам, каждый ряд — один `Canvas` (два `fill` на ряд) и `Equatable`, поэтому при заполнении новой точки перерисовывается только один ряд. Одновременно существуют лишь видимые ряды, а не 10 000 View.
- Главная (`ProgressGrid`) и полноэкранный экран (`FullscreenProgressView`) используют одни и те же `ProgressGridLayout` + `ProgressGridRows`.
- Tap/drag: `onTapGesture` на области сетки; системный pan ScrollView забирает вертикальный drag, поэтому drag прокручивает, а короткое нажатие открывает `fullScreenCover`.
- Обновление: `TrackingStore.keepRefreshing()` подсчитывает клиентов и держит один общий тикер, поэтому главная и полноэкранный экран не создают два цикла.
- Accessibility: сетка — один элемент со сводкой «Прогресс: 12,45%. Завершено часов: 1 245 из 10 000».

## История и редактирование (этап 5)

- `HistoryViewModel` получает завершённые сессии через `TrackingStore.completedSessions()` (без прямого SwiftData во View), сортировка — от новых к старым по `startDate`, активная сессия не показывается. Длительность берётся из `durationSeconds` и форматируется `SessionDurationFormatter` (полные часы и минуты, без округления вверх), дата начала — `SessionDateFormatter` (русская локаль, часовой пояс устройства).
- История перезагружается по `TrackingStore.sessionsRevision`, который меняется только при изменении данных (restore, Stop, редактирование), а не каждую секунду.
- Редактирование: нативный sheet с `Form` и двумя полями. `SessionDurationInput` валидирует ввод (целые неотрицательные часы, минуты 0–59, ≥ 1 минуты, защита от переполнения Int). Сохранение — `TrackingStore.updateDuration` → `SessionRepository.updateDuration` (меняется только `durationSeconds`; остаточные секунды обнуляются только при явном сохранении) → `reloadProgress()` пересчитывает общий прогресс, поэтому главная, сетка и полноэкранный экран обновляются сразу, а активная сессия продолжает идти.

## Виджеты, App Intents и App Group (этап 6)

- **Одно хранилище.** В production есть ровно одна база SwiftData: `<App Group group.com.irklch.TenThousandHours>/Library/Application Support/TenThousandHours.store`. Её URL и схему задаёт только `ModelContainerFactory`; приложение (`TrackingStore.open`) и виджет/intents (`SharedTracking`) открывают один и тот же файл — каждый процесс своим `ModelContainer`. Других баз, резервных копий и переключения между хранилищами нет. In-memory и временные файлы используются только в тестах, Preview и UI-тестах.
- **Недоступность хранилища** (нет App Group, SwiftData не открывается). Приложение не падает и не создаёт другую базу: вместо экранов показывается «Данные недоступны» без прогресса и Play/Stop, с кнопкой «Повторить», которая заново пытается открыть тот же файл. Существующий файл не удаляется и не пересоздаётся. Виджет показывает «Данные недоступны. Откройте приложение.» без кнопки и повторяет попытку через 15 минут; контейнер в процессе виджета кэшируется только после удачного открытия.
- **Межпроцессная координация.** SQLite-стор SwiftData безопасен для одновременного доступа нескольких процессов, но последовательность «проверить → записать» не атомарна между процессами, а `@MainActor`/actor работают только внутри процесса. Поэтому Play, Stop, редактирование длительности и чтение состояния (активная сессия + накопленный прогресс) выполняются под `flock` на файле `TenThousandHours.lock` рядом со стором (`FileLockCoordinator`). Внутри блокировки состояние перечитывается из стора и только потом пишется. Блокировка держится миллисекунды и без точек приостановки; при падении процесса система снимает её сама; ожидание ограничено 3 с, затем операция завершается ошибкой без изменений. Блокировка не реентерабельна — вложенных операций нет.
- **Свежие данные.** `SwiftDataSessionRepository(container:)` создаёт новый `ModelContext` на каждую операцию, поэтому изменения другого процесса видны сразу. Приложение перечитывает стор при возврате в `.active` (`restore()`), без polling.
- **App Intents** `StartTrackingIntent` / `StopTrackingIntent` выполняются в процессе виджета через тот же `TimerEngine`, без открытия приложения. Повторный Play/Stop ничего не меняют, короткие сессии отбрасываются по `SessionRules`. `TimerEngine`, репозиторий и модель `nonisolated`, поэтому одна и та же логика работает и в приложении, и в виджете, и в тестах с настоящей параллельностью.
- **Обновление виджетов.** `WidgetCenter.reloadTimelines(ofKind:)` после Play/Stop/редактирования в приложении и после intents. Timeline: таймер остановлен — одна запись, `.never`; таймер идёт — записи раз в минуту на час вперёд, `.atEnd`; стор недоступен — повтор через 15 минут. Секундного таймера в виджете нет.
- **UI виджетов** по Figma: Small — кнопка Play/Stop по центру; Large — процент (80 pt Light), часы, кнопка справа внизу; отступ 24 pt, `containerBackground`, `Button(intent:)`. В tinted-режимах iOS 18+ кнопка рисуется монохромной (иконка вырезана из круга).

## Подготовка к расширениям

- **Live Activity** и другие расширения подключают папку `Shared` как дополнительную synchronized-группу и работают с общим стором через `SharedTracking`.
