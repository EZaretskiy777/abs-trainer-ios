# Monetization roadmap — ABS Trainer iOS

Решение пользователя: личный MVP делаем сейчас, но архитектурно оставляем путь к публичной версии и монетизации.

## Рекомендованная модель

**Freemium + Premium subscription**.

Почему:
- фитнес-приложению нужна регулярная ценность: новые упражнения, планы, прогресс;
- подписка лучше окупает 3D-видео и контент;
- бесплатный слой помогает проверить спрос.

## Free layer

- 5–7 базовых упражнений;
- тренировки 5/10 минут;
- базовая зона `full abs`;
- простая генерация тренировки;
- ограниченное количество 3D-видео/placeholder assets.

## Premium layer

- 30–50 упражнений;
- все зоны пресса: верхний, нижний, косые, full abs;
- длительности 5/10/15/20/30 минут;
- уровни сложности;
- готовые программы на 4–8 недель;
- история тренировок;
- прогресс и streaks;
- напоминания;
- Apple Health integration;
- расширенные 3D-видео.

## Технические закладки

Для MVP v0.2 реальные платежи не делаем, но желательно не блокировать будущую монетизацию:

- `isPremium` / `Entitlement` model;
- feature flags;
- paywall placeholder screen;
- premium badges на будущих функциях;
- StoreKit 2 compatibility later;
- Restore Purchases later;
- Privacy Policy / Terms placeholders later.

## Roadmap

| Версия | Scope |
|---|---|
| v0.2 | Личный MVP: тренировки, генерация, 3D-заглушки, установка через Xcode. |
| v0.3 | Polish UX, больше упражнений, финальные 3D-видео. |
| v0.4 | Paywall-заглушка, premium flags, структура StoreKit 2 без включенных платежей. |
| v1.0 | App Store, Apple Developer Program, StoreKit subscription, Privacy Policy, Terms, скриншоты, review. |

## Не делаем сейчас

- Реальные In-App Purchases;
- публикацию App Store;
- внешний платеж в обход Apple;
- рекламу/баннеры в MVP.

## Ближайшее архитектурное решение

При старте iOS skeleton добавить простую модель доступа:

```swift
enum AccessLevel {
    case free
    case premium
}
```

И использовать её только как задел, без реального StoreKit.
