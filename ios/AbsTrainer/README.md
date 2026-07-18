# AbsTrainer iOS Skeleton

Первый SwiftUI skeleton для MVP v0.2.

## Что внутри

- `AbsTrainerApp.swift` — входная точка SwiftUI app.
- `Models.swift` — зоны пресса, упражнения, workout plan, access level.
- `ExerciseCatalog.swift` — стартовый каталог 10 упражнений.
- `WorkoutGenerator.swift` — generator v0 по `docs/product-spec.md`.
- `DesignSystem.swift` — базовая Apple/Fitness-like dark theme.
- `ContentView.swift` — выбор времени/зон и генерация плана.
- `WorkoutPlanView.swift` — экран сгенерированной тренировки.
- `ExercisePlayerView.swift` — экран упражнения с таймером и placeholder 3D media.
- `FinishView.swift` — итог тренировки.

## Статус

Это source-level skeleton. В текущей Linux-среде Hermes нельзя собрать iOS app через Xcode, поэтому финальная проверка выполняется на Mac пользователя.
