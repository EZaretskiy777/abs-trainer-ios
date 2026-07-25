# AbsTrainer iOS — «Темп / Срез»

SwiftUI-реализация ключевого локального workout flow в утверждённом дизайне «Темп / Срез». Минимальная целевая версия — iOS 16 (`NavigationStack`).

## Что внутри

- `AbsTrainerApp.swift` — входная точка SwiftUI app.
- `Models.swift` — зоны пресса, упражнения, workout plan, access level.
- `ExerciseCatalog.swift` — стартовый каталог 10 упражнений.
- `WorkoutGenerator.swift` — generator v0 по `docs/product-spec.md`.
- `DesignSystem.swift` — централизованные Tempo tokens и переиспользуемые компоненты.
- `ContentView.swift` — настройка длительности/зон и typed navigation.
- `WorkoutPlanView.swift` — линейный план и лента темпа.
- `WorkoutSessionStore.swift` — reference-timestamp таймер и переходы exercise/rest/finish.
- `ExercisePlayerView.swift` — активное упражнение, пауза и ultramarine rest-state.
- `FinishView.swift` — фактическое время, результат, repeat/new actions.
- `Resources/Assets.xcassets` — named colors, включая Increase Contrast variants.
- `Resources/Localizable.xcstrings` — String Catalog с русским source language.
- `Tests/AbsTrainerTests/WorkoutSessionStoreTests.swift` — тесты session state machine.
- `Tests/AbsTrainerTests/WorkoutGeneratorTests.swift` — edge-case тесты генератора и фактической длительности.
- `AbsTrainer.xcodeproj` — app/test targets и shared scheme `AbsTrainer`.

## Статус

Проект собирается без signing для iOS Simulator. Команды сборки, тестов и ручной accessibility/visual QA приведены в `BUILD_NOTES.md`.
