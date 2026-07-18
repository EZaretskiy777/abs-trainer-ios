import Foundation

enum ExerciseCatalog {
    static let starter: [Exercise] = [
        Exercise(id: "crunch", title: "Crunch", zones: [.upper], difficulty: .beginner, defaultDurationSec: 40, restAfterSec: 12, mediaName: "placeholder_crunch", isPlaceholderMedia: true, accessLevel: .free),
        Exercise(id: "reverse_crunch", title: "Reverse Crunch", zones: [.lower], difficulty: .beginner, defaultDurationSec: 40, restAfterSec: 12, mediaName: "placeholder_reverse_crunch", isPlaceholderMedia: true, accessLevel: .free),
        Exercise(id: "bicycle_twist", title: "Bicycle Twist", zones: [.obliques, .full], difficulty: .intermediate, defaultDurationSec: 40, restAfterSec: 12, mediaName: "placeholder_bicycle_twist", isPlaceholderMedia: true, accessLevel: .free),
        Exercise(id: "plank", title: "Plank", zones: [.full], difficulty: .beginner, defaultDurationSec: 45, restAfterSec: 15, mediaName: "placeholder_plank", isPlaceholderMedia: true, accessLevel: .free),
        Exercise(id: "mountain_climber", title: "Mountain Climber", zones: [.lower, .full], difficulty: .intermediate, defaultDurationSec: 40, restAfterSec: 15, mediaName: "placeholder_mountain_climber", isPlaceholderMedia: true, accessLevel: .free),
        Exercise(id: "toe_touch", title: "Toe Touch", zones: [.upper], difficulty: .beginner, defaultDurationSec: 40, restAfterSec: 12, mediaName: "placeholder_toe_touch", isPlaceholderMedia: true, accessLevel: .free),
        Exercise(id: "leg_raise", title: "Leg Raise", zones: [.lower], difficulty: .intermediate, defaultDurationSec: 40, restAfterSec: 15, mediaName: "placeholder_leg_raise", isPlaceholderMedia: true, accessLevel: .free),
        Exercise(id: "russian_twist", title: "Russian Twist", zones: [.obliques], difficulty: .intermediate, defaultDurationSec: 40, restAfterSec: 12, mediaName: "placeholder_russian_twist", isPlaceholderMedia: true, accessLevel: .free),
        Exercise(id: "dead_bug", title: "Dead Bug", zones: [.full], difficulty: .beginner, defaultDurationSec: 45, restAfterSec: 12, mediaName: "placeholder_dead_bug", isPlaceholderMedia: true, accessLevel: .free),
        Exercise(id: "hollow_hold", title: "Hollow Hold", zones: [.full], difficulty: .intermediate, defaultDurationSec: 35, restAfterSec: 15, mediaName: "placeholder_hollow_hold", isPlaceholderMedia: true, accessLevel: .free)
    ]
}
