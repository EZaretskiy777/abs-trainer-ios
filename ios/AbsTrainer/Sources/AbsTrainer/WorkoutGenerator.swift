import Foundation

struct WorkoutGenerator {
    let catalog: [Exercise]

    init(catalog: [Exercise] = ExerciseCatalog.starter) {
        self.catalog = catalog
    }

    func generate(
        targetDurationMin: Int,
        selectedZones: [AbsZone],
        intensity: WorkoutIntensity = .balanced
    ) -> WorkoutPlan {
        let setup = WorkoutSetup(
            targetDurationMin: targetDurationMin,
            selectedZones: Set(selectedZones),
            intensity: intensity
        ).normalized
        let pool = rankedExercises(for: setup)
        let items = closestItems(to: setup.targetDurationMin * 60, from: pool)

        return WorkoutPlan(
            id: UUID().uuidString,
            targetDurationMin: setup.targetDurationMin,
            selectedZones: setup.canonicalZones,
            intensity: setup.intensity,
            items: items
        )
    }

    private func rankedExercises(for setup: WorkoutSetup) -> [Exercise] {
        let uniqueCatalog = uniqueExercises(catalog)
        let zones = setup.canonicalZones
        let isFull = zones == [.full]
        let selected = Set(zones)
        let primary = isFull ? uniqueCatalog : uniqueCatalog.filter {
            !Set($0.zones).intersection(selected).isEmpty
        }
        let fullFallback = isFull ? [] : uniqueCatalog.filter {
            $0.zones.contains(.full) && !primary.contains($0)
        }
        let rankedPrimary = rankedByIntensity(primary, setup: setup)
        let allowedFallback = allowedExercises(fullFallback, setup: setup)
        let allowedPrimary = allowedExercises(primary, setup: setup)

        switch setup.intensity {
        case .light:
            let primaryBeginners = allowedPrimary.filter { $0.difficulty == .beginner }
            let fallbackBeginners = allowedFallback.filter { $0.difficulty == .beginner }
            if !primaryBeginners.isEmpty {
                return primaryBeginners + (primaryBeginners.count < 4 ? fallbackBeginners : [])
            }
            if !fallbackBeginners.isEmpty { return fallbackBeginners }
            let primaryIntermediate = allowedPrimary.filter { $0.difficulty == .intermediate }
            let fallbackIntermediate = allowedFallback.filter { $0.difficulty == .intermediate }
            return primaryIntermediate + (primaryIntermediate.count < 4 ? fallbackIntermediate : [])
        case .balanced:
            return rankedPrimary.count < 4
                ? rankedPrimary + rankedByIntensity(fullFallback, setup: setup)
                : rankedPrimary
        case .high:
            guard rankedPrimary.count < 4 else { return rankedPrimary }
            let primaryPreferred = allowedPrimary.filter { $0.difficulty == .intermediate }
                + allowedPrimary.filter { $0.difficulty == .advanced }
            let fallbackPreferred = allowedFallback.filter { $0.difficulty == .intermediate }
                + allowedFallback.filter { $0.difficulty == .advanced }
            return primaryPreferred
                + fallbackPreferred
                + allowedPrimary.filter { $0.difficulty == .beginner }
                + allowedFallback.filter { $0.difficulty == .beginner }
        }
    }

    private func rankedByIntensity(_ exercises: [Exercise], setup: WorkoutSetup) -> [Exercise] {
        let allowed = allowedExercises(exercises, setup: setup)

        switch setup.intensity {
        case .light:
            let beginners = allowed.filter { $0.difficulty == .beginner }
            return beginners.isEmpty ? allowed.filter { $0.difficulty == .intermediate } : beginners
        case .balanced:
            return interleaved(
                allowed.filter { $0.difficulty == .beginner },
                allowed.filter { $0.difficulty == .intermediate }
            )
        case .high:
            return allowed.filter { $0.difficulty == .intermediate }
                + allowed.filter { $0.difficulty == .advanced }
                + allowed.filter { $0.difficulty == .beginner }
        }
    }

    private func allowedExercises(_ exercises: [Exercise], setup: WorkoutSetup) -> [Exercise] {
        exercises.filter { exercise in
            !(setup.targetDurationMin == 5 && exercise.difficulty == .advanced)
        }
    }

    private func uniqueExercises(_ exercises: [Exercise]) -> [Exercise] {
        var ids: Set<String> = []
        return exercises.filter { ids.insert($0.id).inserted }
    }

    private func interleaved(_ first: [Exercise], _ second: [Exercise]) -> [Exercise] {
        var result: [Exercise] = []
        for index in 0..<max(first.count, second.count) {
            if first.indices.contains(index) { result.append(first[index]) }
            if second.indices.contains(index) { result.append(second[index]) }
        }
        return result
    }

    private func closestItems(to targetSeconds: Int, from pool: [Exercise]) -> [WorkoutItem] {
        guard !pool.isEmpty else { return [] }
        var candidates: [WorkoutItem] = []
        var bestCount = 1
        var bestDuration = Int.max
        let minimumWork = max(1, pool.map(\.defaultDurationSec).filter { $0 > 0 }.min() ?? 1)
        let maximumItems = max(1, (targetSeconds + 60) / minimumWork + pool.count + 1)

        for index in 0..<maximumItems {
            let exercise = pool[index % pool.count]
            candidates.append(
                WorkoutItem(
                    id: UUID().uuidString,
                    exercise: exercise,
                    durationSec: exercise.defaultDurationSec,
                    restAfterSec: exercise.restAfterSec,
                    order: index + 1
                )
            )
            let duration = executableDuration(of: candidates)
            let distance = abs(duration - targetSeconds)
            let bestDistance = abs(bestDuration - targetSeconds)
            let winsTie = distance == bestDistance
                && duration <= targetSeconds
                && bestDuration > targetSeconds
            if distance < bestDistance || winsTie {
                bestCount = candidates.count
                bestDuration = duration
            }
            if duration > targetSeconds + 60 { break }
        }

        return Array(candidates.prefix(bestCount))
    }

    private func executableDuration(of items: [WorkoutItem]) -> Int {
        items.enumerated().reduce(0) { total, entry in
            total + entry.element.durationSec
                + (entry.offset == items.count - 1 ? 0 : entry.element.restAfterSec)
        }
    }
}
