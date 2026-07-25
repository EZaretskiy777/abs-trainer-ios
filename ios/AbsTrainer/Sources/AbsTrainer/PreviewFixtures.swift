import Foundation

extension WorkoutPlan {
    static let preview: WorkoutPlan = WorkoutGenerator().generate(
        targetDurationMin: 5,
        selectedZones: [.full]
    )
}