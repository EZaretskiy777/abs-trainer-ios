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

    static func prescription(
        for exercise: Exercise,
        targetDurationMin: Int,
        intensity: WorkoutIntensity
    ) -> WorkoutPrescription {
        let band = DurationBand(minutes: targetDurationMin)
        switch exercise.id {
        case "plank":
            let seconds = band.select(short: (30, 35, 40), standard: (35, 40, 45), long: (40, 45, 50), intensity: intensity)
            return .timeBased(durationSec: seconds)
        case "hollow_hold":
            let seconds = band.select(short: (20, 25, 30), standard: (25, 30, 35), long: (30, 35, 40), intensity: intensity)
            return .timeBased(durationSec: seconds)
        case "crunch", "toe_touch":
            return repetition(
                band: band,
                intensity: intensity,
                counts: ((9, 11, 13), (10, 12, 14), (11, 13, 15)),
                cadence: (4_000, 3_400, 3_000),
                unit: .fullCycle
            )
        case "reverse_crunch", "leg_raise":
            return repetition(
                band: band,
                intensity: intensity,
                counts: ((8, 10, 12), (9, 11, 13), (10, 12, 14)),
                cadence: (4_500, 3_800, 3_200),
                unit: .fullCycle
            )
        case "bicycle_twist", "mountain_climber", "russian_twist":
            return repetition(
                band: band,
                intensity: intensity,
                counts: ((14, 16, 18), (16, 18, 20), (18, 20, 22)),
                cadence: (2_500, 2_200, 2_000),
                unit: .perSideAlternating
            )
        case "dead_bug":
            return repetition(
                band: band,
                intensity: intensity,
                counts: ((12, 14, 16), (14, 16, 18), (16, 18, 20)),
                cadence: (3_000, 2_600, 2_300),
                unit: .perSideAlternating
            )
        default:
            return .timeBased(durationSec: max(1, exercise.defaultDurationSec))
        }
    }

    private typealias IntensityTriple = (light: Int, balanced: Int, high: Int)

    private static func repetition(
        band: DurationBand,
        intensity: WorkoutIntensity,
        counts: (short: IntensityTriple, standard: IntensityTriple, long: IntensityTriple),
        cadence: IntensityTriple,
        unit: RepetitionCountingUnit
    ) -> WorkoutPrescription {
        let target = band.select(
            short: counts.short,
            standard: counts.standard,
            long: counts.long,
            intensity: intensity
        )
        let cadenceMilliseconds = value(cadence, for: intensity)
        return .repetitionBased(
            targetCount: target,
            countingUnit: unit,
            cadenceMillisPerCount: cadenceMilliseconds,
            estimatedDurationSec: Int(ceil(Double(target * cadenceMilliseconds) / 1_000))
        )
    }

    private static func value(_ values: IntensityTriple, for intensity: WorkoutIntensity) -> Int {
        switch intensity {
        case .light: return values.light
        case .balanced: return values.balanced
        case .high: return values.high
        }
    }

    private enum DurationBand {
        case short
        case standard
        case long

        init(minutes: Int) {
            if minutes <= 7 { self = .short }
            else if minutes <= 11 { self = .standard }
            else { self = .long }
        }

        func select(
            short: IntensityTriple,
            standard: IntensityTriple,
            long: IntensityTriple,
            intensity: WorkoutIntensity
        ) -> Int {
            switch self {
            case .short: return ExerciseCatalog.value(short, for: intensity)
            case .standard: return ExerciseCatalog.value(standard, for: intensity)
            case .long: return ExerciseCatalog.value(long, for: intensity)
            }
        }
    }
}
