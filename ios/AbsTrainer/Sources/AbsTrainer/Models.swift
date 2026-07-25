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
    let items: [WorkoutItem]

    var totalDurationSec: Int {
        guard !items.isEmpty else { return 0 }
        return items.enumerated().reduce(0) { total, entry in
            let (index, item) = entry
            return total + item.durationSec + (index == items.count - 1 ? 0 : item.restAfterSec)
        }
    }
}
