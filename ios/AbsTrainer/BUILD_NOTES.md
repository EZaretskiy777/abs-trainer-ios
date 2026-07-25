# BUILD_NOTES — запуск через Xcode

## Xcode / Simulator

1. Откройте `ios/AbsTrainer/AbsTrainer.xcodeproj`.
2. Выберите shared scheme `AbsTrainer` и iOS Simulator с iOS 16 или новее.
3. Выполните `Product → Build`, затем `Product → Test`.

Воспроизводимые CLI-команды без signing:

`xcodebuild -project ios/AbsTrainer/AbsTrainer.xcodeproj -scheme AbsTrainer -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO build`

`xcodebuild -project ios/AbsTrainer/AbsTrainer.xcodeproj -scheme AbsTrainer -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO test`

## Обязательная проверка перед merge

1. `Product → Test` — все 10 тестов `WorkoutSessionStoreTests` и `WorkoutGeneratorTests` должны пройти.
2. Пройти настройка → план → упражнение → отдых → результат; проверить pause/resume, skip rest, repeat и new workout.
3. Проверить iPhone SE (3rd gen), iPhone 15 Pro и landscape: строки без clipping, controls доступны.
4. Проверить Dynamic Type до Accessibility 3, VoiceOver order/labels, Reduce Motion и Increase Contrast.
5. Убедиться, что системный chrome светлый на exercise/rest и тёмный на setup/plan/result.

Для запуска на физическом iPhone отдельно настройте собственные Team, Bundle Identifier и provisioning в локальном Xcode. Production signing, archive и upload этим проектом не выполняются.
