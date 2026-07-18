# BUILD_NOTES — запуск через Xcode

## Быстрый путь для MVP

1. Откройте Xcode на Mac.
2. Создайте новый проект: `iOS App` → Product Name: `AbsTrainer` → Interface: `SwiftUI` → Language: `Swift`.
3. Скопируйте файлы из `ios/AbsTrainer/Sources/AbsTrainer/` в созданный Xcode project.
4. В Xcode откройте project settings → Signing & Capabilities.
5. Team: выберите ваш Apple ID.
6. Bundle Identifier: например `com.ezaretskiy.abstrainer`.
7. Подключите iPhone кабелем.
8. На iPhone включите Developer Mode, если Xcode попросит.
9. Выберите iPhone как target device.
10. Нажмите `Run`.

## Ограничение бесплатного Apple ID

Сборка, установленная через бесплатный Apple ID, может перестать запускаться примерно через 7 дней. Для личного MVP это нормально: повторите запуск через Xcode.

## Почему пока не `.xcodeproj`

Hermes работает в Linux-среде без Xcode. Xcode project лучше создать на Mac, чтобы Xcode сам сгенерировал корректные signing/team настройки под ваш Apple ID.
