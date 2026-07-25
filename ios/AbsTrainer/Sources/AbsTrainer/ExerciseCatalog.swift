import Foundation

enum ExerciseCatalog {
    static let starter: [Exercise] = [
        Exercise(id: "crunch", title: "Скручивания", zones: [.upper], difficulty: .beginner, defaultDurationSec: 40, restAfterSec: 12, mediaName: "placeholder_crunch", isPlaceholderMedia: true, accessLevel: .free),
        Exercise(id: "reverse_crunch", title: "Обратные скручивания", zones: [.lower], difficulty: .beginner, defaultDurationSec: 40, restAfterSec: 12, mediaName: "placeholder_reverse_crunch", isPlaceholderMedia: true, accessLevel: .free),
        Exercise(id: "bicycle_twist", title: "Велосипед с поворотом", zones: [.obliques, .full], difficulty: .intermediate, defaultDurationSec: 40, restAfterSec: 12, mediaName: "placeholder_bicycle_twist", isPlaceholderMedia: true, accessLevel: .free),
        Exercise(id: "plank", title: "Планка", zones: [.full], difficulty: .beginner, defaultDurationSec: 45, restAfterSec: 15, mediaName: "placeholder_plank", isPlaceholderMedia: true, accessLevel: .free),
        Exercise(id: "mountain_climber", title: "Альпинист", zones: [.lower, .full], difficulty: .intermediate, defaultDurationSec: 40, restAfterSec: 15, mediaName: "placeholder_mountain_climber", isPlaceholderMedia: true, accessLevel: .free),
        Exercise(id: "toe_touch", title: "Касания стоп", zones: [.upper], difficulty: .beginner, defaultDurationSec: 40, restAfterSec: 12, mediaName: "placeholder_toe_touch", isPlaceholderMedia: true, accessLevel: .free),
        Exercise(id: "leg_raise", title: "Подъём ног", zones: [.lower], difficulty: .intermediate, defaultDurationSec: 40, restAfterSec: 15, mediaName: "placeholder_leg_raise", isPlaceholderMedia: true, accessLevel: .free),
        Exercise(id: "russian_twist", title: "Русские скручивания", zones: [.obliques], difficulty: .intermediate, defaultDurationSec: 40, restAfterSec: 12, mediaName: "placeholder_russian_twist", isPlaceholderMedia: true, accessLevel: .free),
        Exercise(id: "dead_bug", title: "Мёртвый жук", zones: [.full], difficulty: .beginner, defaultDurationSec: 45, restAfterSec: 12, mediaName: "placeholder_dead_bug", isPlaceholderMedia: true, accessLevel: .free),
        Exercise(id: "hollow_hold", title: "Удержание лодочки", zones: [.full], difficulty: .intermediate, defaultDurationSec: 35, restAfterSec: 15, mediaName: "placeholder_hollow_hold", isPlaceholderMedia: true, accessLevel: .free)
    ]
}
