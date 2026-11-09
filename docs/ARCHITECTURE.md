# 10 000 Hours — архитектура

Нативное iOS-приложение: Swift 6 (strict concurrency), SwiftUI, SwiftData, MVVM. iOS 17+, только iPhone, портретная ориентация, светлая тема, русская локализация. Без сторонних зависимостей.

## Структура

```
TenThousandHours/
├── App/                    точка входа, корневой TabView, список вкладок
├── DesignSystem/           цвета, типографика, отступы и радиусы
│   └── Components/         PlayStopButton, ProgressDot, HistoryRow (презентационные)
├── Data/
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
| `Data/Models` | 2 | `@Model Session`; регистрируется в `ModelContainerFactory.models` |
| `Data/Repositories` | 2 | `SessionRepository` поверх `ModelContext` |
| `Core` | 2 | состояние таймера, расчёт прогресса, форматирование длительности |
| `Features/Progress` | 3 | полноэкранный просмотр 10 000 точек |
| `Shared` | виджеты | контракты, общие для приложения и Widget Extension (снимок состояния таймера, идентификатор App Group) |

## Принципы

- View не содержат бизнес-логики. ViewModel (`@Observable`, `@MainActor`) появляется у фичи вместе с первой логикой — пустых ViewModel-заглушек нет.
- Зависимости передаются явно через инициализаторы и `Environment`; DI-контейнера и координаторов нет.
- Все цвета, шрифты и отступы берутся только из `DesignSystem` (источник — Design System в Figma).
- Типографика — системный SF Pro с размерами/весами/трекингом из макета и поддержкой Dynamic Type через `@ScaledMetric`.
- Таб-бар — системный `TabView`; на iOS 26+ он автоматически получает Liquid Glass, на iOS 17–18 — стандартный вид.

## Подготовка к расширениям

- **Widget Extension / Live Activity / App Intents**: добавляются отдельными таргетами. Общий код (`DesignSystem`, будущий `Shared`, модели SwiftData) подключается к ним как дополнительные synchronized-группы.
- **App Group**: `ModelConfiguration` использует `groupContainer: .automatic` по умолчанию — после добавления entitlement App Group хранилище SwiftData будет создаваться в общем контейнере и станет доступно виджетам. Важно добавить App Group до выпуска первой версии, иначе потребуется миграция файла хранилища.
