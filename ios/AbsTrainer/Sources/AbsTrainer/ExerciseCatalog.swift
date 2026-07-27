import Foundation

enum ExerciseCatalog {
    static let starter: [Exercise] = [
        Exercise(id: "crunch", title: "Скручивания", zones: [.upper], difficulty: .beginner, defaultDurationSec: 40, restAfterSec: 12, mediaName: "exercise_crunch_v1", isPlaceholderMedia: false, accessLevel: .free),
        Exercise(id: "reverse_crunch", title: "Обратные скручивания", zones: [.lower], difficulty: .beginner, defaultDurationSec: 40, restAfterSec: 12, mediaName: "exercise_reverse_crunch_v1", isPlaceholderMedia: false, accessLevel: .free),
        Exercise(id: "bicycle_twist", title: "Велосипед с поворотом", zones: [.obliques, .full], difficulty: .intermediate, defaultDurationSec: 40, restAfterSec: 12, mediaName: "exercise_bicycle_twist_v1", isPlaceholderMedia: false, accessLevel: .free),
        Exercise(id: "plank", title: "Планка", zones: [.full], difficulty: .beginner, defaultDurationSec: 45, restAfterSec: 15, mediaName: "exercise_plank_v1", isPlaceholderMedia: false, accessLevel: .free),
        Exercise(id: "mountain_climber", title: "Альпинист", zones: [.lower, .full], difficulty: .intermediate, defaultDurationSec: 40, restAfterSec: 15, mediaName: "exercise_mountain_climber_v1", isPlaceholderMedia: false, accessLevel: .free),
        Exercise(id: "toe_touch", title: "Касания стоп", zones: [.upper], difficulty: .beginner, defaultDurationSec: 40, restAfterSec: 12, mediaName: "exercise_toe_touch_v1", isPlaceholderMedia: false, accessLevel: .free),
        Exercise(id: "leg_raise", title: "Подъём ног", zones: [.lower], difficulty: .intermediate, defaultDurationSec: 40, restAfterSec: 15, mediaName: "exercise_leg_raise_v1", isPlaceholderMedia: false, accessLevel: .free),
        Exercise(id: "russian_twist", title: "Русские скручивания", zones: [.obliques], difficulty: .intermediate, defaultDurationSec: 40, restAfterSec: 12, mediaName: "exercise_russian_twist_v1", isPlaceholderMedia: false, accessLevel: .free),
        Exercise(id: "dead_bug", title: "Мёртвый жук", zones: [.full], difficulty: .beginner, defaultDurationSec: 45, restAfterSec: 12, mediaName: "exercise_dead_bug_v1", isPlaceholderMedia: false, accessLevel: .free),
        Exercise(id: "hollow_hold", title: "Удержание лодочки", zones: [.full], difficulty: .intermediate, defaultDurationSec: 35, restAfterSec: 15, mediaName: "exercise_hollow_hold_v1", isPlaceholderMedia: false, accessLevel: .free)
    ]
}
