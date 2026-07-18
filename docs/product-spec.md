# Product specification — ABS Trainer iOS MVP v0.2

## Цель
Локальное iOS-приложение для тренировок пресса: пользователь выбирает длительность и зоны пресса, приложение генерирует тренировку из разных упражнений и ведет пользователя по упражнениям с таймером и 3D-видео/заглушками.

## Scope MVP v0.2

### Входит
- iOS-only SwiftUI-приложение.
- Локальная работа без backend и регистрации.
- Установка на личный iPhone через Mac + Xcode + бесплатный Apple ID.
- Выбор длительности: 5 / 10 / 15 минут.
- Выбор зон пресса:
  - верхний пресс;
  - нижний пресс;
  - косые/боковой пресс;
  - полный пресс.
- Стартовый каталог: 10 упражнений.
- Генерация тренировки под выбранные зоны и время.
- Экран выполнения: видео/placeholder, таймер, пауза, следующее упражнение, завершение.
- Временные 3D-заглушки разрешены; финальные 3D-видео не блокируют первую сборку.
- Задел под будущую монетизацию: `AccessLevel.free/premium`, без реальных платежей.

### Не входит в MVP v0.2
- App Store публикация.
- TestFlight / Ad Hoc.
- Реальные In-App Purchases / StoreKit purchase flow.
- Backend, аккаунты, синхронизация.
- Персональные медицинские рекомендации.
- Полная библиотека 30–50 упражнений.

## Пользовательские сценарии

### S1 — Быстрый старт тренировки
1. Пользователь открывает приложение.
2. Выбирает длительность: 5/10/15 минут.
3. Выбирает зоны пресса.
4. Нажимает `Generate workout`.
5. Видит план тренировки.
6. Нажимает `Start`.
7. Выполняет упражнения по таймеру.
8. Видит экран завершения.

### S2 — Тренировка конкретной зоны
1. Пользователь выбирает одну или несколько зон.
2. Генератор подбирает упражнения только под эти зоны.
3. Если упражнений недостаточно, допускается добор из `full abs`.

### S3 — Личная установка
1. Пользователь открывает проект в Xcode на Mac.
2. Выбирает свой Apple ID в Signing Team.
3. Подключает iPhone.
4. Запускает приложение через Run.

## Экраны MVP

1. `Home / Parameters`
   - выбор длительности;
   - выбор зон;
   - CTA генерации.

2. `Generated Workout`
   - список упражнений;
   - общее время;
   - зоны;
   - CTA Start.

3. `Exercise Player`
   - 3D-видео или placeholder;
   - название упражнения;
   - таймер;
   - progress;
   - Pause / Resume;
   - Next.

4. `Rest / Transition`
   - короткий отдых;
   - следующее упражнение;
   - skip.

5. `Finish`
   - итог времени;
   - выполненные упражнения;
   - повторить / новая тренировка.

6. `Settings / About`
   - инструкция Xcode/free signing;
   - версия;
   - будущий premium placeholder.

## Сущности данных

```swift
enum AbsZone: String, Codable, CaseIterable {
    case upper
    case lower
    case obliques
    case full
}

enum Difficulty: String, Codable {
    case beginner
    case intermediate
    case advanced
}

enum AccessLevel {
    case free
    case premium
}

struct Exercise: Identifiable, Codable {
    let id: String
    let title: String
    let zones: [AbsZone]
    let difficulty: Difficulty
    let defaultDurationSec: Int
    let restAfterSec: Int
    let mediaName: String
    let isPlaceholderMedia: Bool
    let accessLevel: AccessLevel
}

struct WorkoutPlan: Identifiable, Codable {
    let id: String
    let targetDurationMin: Int
    let selectedZones: [AbsZone]
    let items: [WorkoutItem]
}

struct WorkoutItem: Identifiable, Codable {
    let id: String
    let exerciseId: String
    let durationSec: Int
    let restAfterSec: Int
    let order: Int
}
```

## Стартовый каталог 10 упражнений

| ID | Название | Зоны | Длительность | Медиа |
|---|---|---|---:|---|
| crunch | Crunch | upper | 40s | placeholder |
| reverse_crunch | Reverse Crunch | lower | 40s | placeholder |
| bicycle_twist | Bicycle Twist | obliques, full | 40s | placeholder |
| plank | Plank | full | 45s | placeholder |
| mountain_climber | Mountain Climber | lower, full | 40s | placeholder |
| toe_touch | Toe Touch | upper | 40s | placeholder |
| leg_raise | Leg Raise | lower | 40s | placeholder |
| russian_twist | Russian Twist | obliques | 40s | placeholder |
| dead_bug | Dead Bug | full | 45s | placeholder |
| hollow_hold | Hollow Hold | full | 35s | placeholder |

## Правила генерации v0

1. Вход:
   - `targetDurationMin`: 5, 10 или 15;
   - `selectedZones`: одна или несколько зон.

2. Фильтрация:
   - выбрать упражнения, где `exercise.zones` пересекаются с `selectedZones`;
   - если выбрана `full`, разрешить все упражнения;
   - если упражнений меньше 4, добавить упражнения зоны `full`.

3. Баланс:
   - не ставить два одинаковых упражнения подряд;
   - чередовать зоны, если выбрано несколько;
   - начинать с более простых упражнений;
   - в 5-минутной тренировке не использовать advanced-упражнения на старте MVP.

4. Расчет времени:
   - упражнение 35–45 сек;
   - отдых 10–15 сек;
   - набрать план максимально близко к выбранной длительности;
   - допустимое отклонение: ±30 сек.

5. Повторяемость:
   - генератор может использовать deterministic shuffle по timestamp/session id;
   - для MVP допускается простая рандомизация.

## Acceptance criteria для аналитики

- [x] Список экранов определен.
- [x] Сущности данных определены.
- [x] Правила генерации v0 определены.
- [x] MVP / non-MVP разделены.
- [x] Риски указаны.
- [x] Установка через Xcode учтена.

## Риски

| Риск | Влияние | Митигирование |
|---|---|---|
| 3D-видео с нуля долго | Сдвиг сроков | Используем placeholder assets для первой сборки |
| Бесплатная подпись Xcode | Переустановка через ~7 дней | Документируем в инструкции |
| Нет Xcode в среде Hermes | Нельзя проверить iOS build здесь | Пользователь проверит на Mac, Hermes помогает по скринам/логам |
| App Store из РФ | Риск для v1.0 | Отдельная проверка перед монетизацией |

## Следующий шаг

Передать эту спецификацию в `ABS-IOS-003` для реализации skeleton и в `ABS-IOS-002` для финализации high-fidelity макетов.
