import Foundation

enum AbsZone: String, Codable, CaseIterable, Identifiable {
    case upper
    case lower
    case obliques
    case full

    var id: String { rawValue }

    var title: String {
        switch self {
        case .upper: return "Верхний"
        case .lower: return "Нижний"
        case .obliques: return "Косые"
        case .full: return "Весь пресс"
        }
    }

    var setupTitle: String {
        switch self {
        case .upper: return "Верхний пресс"
        case .lower: return "Нижний пресс"
        case .obliques: return "Косые мышцы"
        case .full: return "Весь пресс"
        }
    }
}

enum Difficulty: String, Codable {
    case beginner
    case intermediate
    case advanced
}

enum WorkoutIntensity: String, Codable, CaseIterable, Identifiable {
    case light
    case balanced
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: return "Мягкая"
        case .balanced: return "Обычная"
        case .high: return "Высокая"
        }
    }

    var planTitle: String {
        "\(title.lowercased()) интенсивность"
    }
}

struct WorkoutSetup: Equatable {
    var targetDurationMin: Int
    var selectedZones: Set<AbsZone>
    var intensity: WorkoutIntensity

    static let `default` = WorkoutSetup(
        targetDurationMin: 10,
        selectedZones: [.full],
        intensity: .balanced
    )

    var normalized: WorkoutSetup {
        WorkoutSetup(
            targetDurationMin: DurationDialContract.allowedValues[
                DurationDialContract.nearestIndex(to: targetDurationMin)
            ],
            selectedZones: Set(canonicalZones),
            intensity: intensity
        )
    }

    var canonicalZones: [AbsZone] {
        guard !selectedZones.isEmpty, !selectedZones.contains(.full) else { return [.full] }
        return AbsZone.allCases.filter(selectedZones.contains)
    }
}

enum AccessLevel: String, Codable {
    case free
    case premium
}

struct Exercise: Identifiable, Codable, Equatable {
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

enum RepetitionCountingUnit: String, Codable, Equatable {
    case fullCycle
    case perSideAlternating
}

enum WorkoutPrescription: Codable, Equatable {
    case timeBased(durationSec: Int)
    case repetitionBased(
        targetCount: Int,
        countingUnit: RepetitionCountingUnit,
        cadenceMillisPerCount: Int,
        estimatedDurationSec: Int
    )

    var estimatedDurationSec: Int {
        switch self {
        case let .timeBased(durationSec): return durationSec
        case let .repetitionBased(_, _, _, estimate): return estimate
        }
    }

    var targetCount: Int? {
        guard case let .repetitionBased(target, _, _, _) = self else { return nil }
        return target
    }

    var countingUnit: RepetitionCountingUnit? {
        guard case let .repetitionBased(_, unit, _, _) = self else { return nil }
        return unit
    }

    var cadenceMillisPerCount: Int? {
        guard case let .repetitionBased(_, _, cadence, _) = self else { return nil }
        return cadence
    }

    private enum CodingKeys: String, CodingKey {
        case kind, durationSec, targetCount, countingUnit, cadenceMillisPerCount, estimatedDurationSec
    }

    private enum Kind: String, Codable {
        case timeBased
        case repetitionBased
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .timeBased:
            let duration = try container.decode(Int.self, forKey: .durationSec)
            guard duration > 0 else {
                throw DecodingError.dataCorruptedError(
                    forKey: .durationSec,
                    in: container,
                    debugDescription: "Timed duration must be positive"
                )
            }
            self = .timeBased(durationSec: duration)
        case .repetitionBased:
            let target = try container.decode(Int.self, forKey: .targetCount)
            let unit = try container.decode(RepetitionCountingUnit.self, forKey: .countingUnit)
            let cadence = try container.decode(Int.self, forKey: .cadenceMillisPerCount)
            let estimate = try container.decode(Int.self, forKey: .estimatedDurationSec)
            let (durationProduct, overflowed) = target.multipliedReportingOverflow(by: cadence)
            guard target > 0,
                  cadence >= 2_000,
                  !overflowed,
                  estimate == Int(ceil(Double(durationProduct) / 1_000)),
                  unit != .perSideAlternating || target.isMultiple(of: 2) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .targetCount,
                    in: container,
                    debugDescription: "Invalid repetition prescription"
                )
            }
            self = .repetitionBased(
                targetCount: target,
                countingUnit: unit,
                cadenceMillisPerCount: cadence,
                estimatedDurationSec: estimate
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .timeBased(duration):
            try container.encode(Kind.timeBased, forKey: .kind)
            try container.encode(duration, forKey: .durationSec)
        case let .repetitionBased(target, unit, cadence, estimate):
            try container.encode(Kind.repetitionBased, forKey: .kind)
            try container.encode(target, forKey: .targetCount)
            try container.encode(unit, forKey: .countingUnit)
            try container.encode(cadence, forKey: .cadenceMillisPerCount)
            try container.encode(estimate, forKey: .estimatedDurationSec)
        }
    }
}

enum WorkoutOutcome: Equatable {
    case completed
    case completedEarly(actualDisplayedCount: Int)
    case skipped
}

struct WorkoutItem: Identifiable, Codable, Equatable {
    let id: String
    let exercise: Exercise
    let prescription: WorkoutPrescription
    let restAfterSec: Int
    let order: Int

    var durationSec: Int { prescription.estimatedDurationSec }

    init(
        id: String,
        exercise: Exercise,
        prescription: WorkoutPrescription,
        restAfterSec: Int,
        order: Int
    ) {
        self.id = id
        self.exercise = exercise
        self.prescription = prescription
        self.restAfterSec = restAfterSec
        self.order = order
    }

    init(id: String, exercise: Exercise, durationSec: Int, restAfterSec: Int, order: Int) {
        self.init(
            id: id,
            exercise: exercise,
            prescription: .timeBased(durationSec: durationSec),
            restAfterSec: restAfterSec,
            order: order
        )
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, exercise, prescription, durationSec, restAfterSec, order
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        exercise = try container.decode(Exercise.self, forKey: .exercise)
        restAfterSec = try container.decode(Int.self, forKey: .restAfterSec)
        order = try container.decode(Int.self, forKey: .order)
        if let canonical = try container.decodeIfPresent(WorkoutPrescription.self, forKey: .prescription) {
            prescription = canonical
        } else {
            let duration = try container.decode(Int.self, forKey: .durationSec)
            guard duration > 0 else {
                throw DecodingError.dataCorruptedError(
                    forKey: .durationSec,
                    in: container,
                    debugDescription: "Legacy duration must be positive"
                )
            }
            prescription = .timeBased(durationSec: duration)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(2, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encode(exercise, forKey: .exercise)
        try container.encode(prescription, forKey: .prescription)
        try container.encode(durationSec, forKey: .durationSec)
        try container.encode(restAfterSec, forKey: .restAfterSec)
        try container.encode(order, forKey: .order)
    }
}

struct WorkoutPlan: Identifiable, Codable, Equatable {
    let id: String
    let targetDurationMin: Int
    let selectedZones: [AbsZone]
    let intensity: WorkoutIntensity
    let items: [WorkoutItem]

    var totalDurationSec: Int {
        guard !items.isEmpty else { return 0 }
        return items.enumerated().reduce(0) { total, entry in
            let (index, item) = entry
            return total + item.durationSec + (index == items.count - 1 ? 0 : item.restAfterSec)
        }
    }

    var totalEstimatedDurationSec: Int { totalDurationSec }

    private enum CodingKeys: String, CodingKey {
        case id
        case targetDurationMin
        case selectedZones
        case intensity
        case items
    }

    init(
        id: String,
        targetDurationMin: Int,
        selectedZones: [AbsZone],
        intensity: WorkoutIntensity,
        items: [WorkoutItem]
    ) {
        self.id = id
        self.targetDurationMin = targetDurationMin
        self.selectedZones = selectedZones
        self.intensity = intensity
        self.items = items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        targetDurationMin = try container.decode(Int.self, forKey: .targetDurationMin)
        selectedZones = try container.decode([AbsZone].self, forKey: .selectedZones)
        intensity = try container.decodeIfPresent(WorkoutIntensity.self, forKey: .intensity) ?? .balanced
        items = try container.decode([WorkoutItem].self, forKey: .items)
    }
}
