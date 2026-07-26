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

struct WorkoutItem: Identifiable, Codable, Equatable {
    let id: String
    let exercise: Exercise
    let durationSec: Int
    let restAfterSec: Int
    let order: Int
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
