import Foundation

struct WorkoutGenerator {
    let catalog: [Exercise]

    init(catalog: [Exercise] = ExerciseCatalog.starter) {
        self.catalog = catalog
    }

    func generate(targetDurationMin: Int, selectedZones: [AbsZone]) -> WorkoutPlan {
        let zones = selectedZones.isEmpty ? [.full] : selectedZones
        let targetSec = targetDurationMin * 60
        var pool = filteredExercises(for: zones)

        if pool.count < 4 {
            let fullBody = catalog.filter { $0.zones.contains(.full) }
            pool.append(contentsOf: fullBody.filter { !pool.contains($0) })
        }

        pool = balanced(pool, zones: zones)

        var items: [WorkoutItem] = []
        var total = 0
        var index = 0
        var lastExerciseId: String?

        while total < targetSec - 30, !pool.isEmpty {
            let candidate = pool[index % pool.count]
            index += 1
            guard candidate.id != lastExerciseId else { continue }

            let item = WorkoutItem(
                id: UUID().uuidString,
                exercise: candidate,
                durationSec: candidate.defaultDurationSec,
                restAfterSec: candidate.restAfterSec,
                order: items.count + 1
            )

            items.append(item)
            total += item.durationSec + item.restAfterSec
            lastExerciseId = candidate.id
        }

        return WorkoutPlan(
            id: UUID().uuidString,
            targetDurationMin: targetDurationMin,
            selectedZones: zones,
            items: items
        )
    }

    private func filteredExercises(for zones: [AbsZone]) -> [Exercise] {
        if zones.contains(.full) { return catalog }
        return catalog.filter { exercise in
            !Set(exercise.zones).intersection(Set(zones)).isEmpty
        }
    }

    private func balanced(_ exercises: [Exercise], zones: [AbsZone]) -> [Exercise] {
        let zoneOrder = zones.contains(.full) ? AbsZone.allCases : zones
        var result: [Exercise] = []
        for zone in zoneOrder {
            result.append(contentsOf: exercises.filter { $0.zones.contains(zone) && !result.contains($0) })
        }
        result.append(contentsOf: exercises.filter { !result.contains($0) })
        return result
    }
}
