import XCTest
@testable import AbsTrainer

final class WorkoutGeneratorTests: XCTestCase {
    func testSetupDefaultsAndNormalizationPreserveApprovedDomain() {
        XCTAssertEqual(WorkoutSetup.default.targetDurationMin, 10)
        XCTAssertEqual(WorkoutSetup.default.selectedZones, [.full])
        XCTAssertEqual(WorkoutSetup.default.intensity, .balanced)

        let normalized = WorkoutSetup(
            targetDurationMin: 12,
            selectedZones: [.lower, .full, .upper],
            intensity: .high
        ).normalized

        XCTAssertEqual(normalized.targetDurationMin, 10)
        XCTAssertEqual(normalized.canonicalZones, [.full])
        XCTAssertEqual(normalized.intensity, .high)
    }

    func testSpecificZonesAreCanonicalAndEmptyFallsBackToFull() {
        XCTAssertEqual(
            WorkoutSetup(targetDurationMin: 10, selectedZones: [.obliques, .upper], intensity: .light)
                .canonicalZones,
            [.upper, .obliques]
        )
        XCTAssertEqual(
            WorkoutSetup(targetDurationMin: 10, selectedZones: [], intensity: .light).canonicalZones,
            [.full]
        )
    }

    func testSingleExerciseCatalogTerminatesAndBuildsPlan() {
        let exercise = Exercise(
            id: "only",
            title: "Планка",
            zones: [.full],
            difficulty: .beginner,
            defaultDurationSec: 40,
            restAfterSec: 10,
            mediaName: "placeholder",
            isPlaceholderMedia: true,
            accessLevel: .free
        )

        let plan = WorkoutGenerator(catalog: [exercise]).generate(
            targetDurationMin: 5,
            selectedZones: [.full],
            intensity: .balanced
        )

        XCTAssertFalse(plan.items.isEmpty)
        XCTAssertTrue(plan.items.allSatisfy { $0.exercise.id == exercise.id })
    }

    func testPlanDurationDoesNotIncludeUnusedFinalRest() {
        let plan = WorkoutGenerator().generate(
            targetDurationMin: 5,
            selectedZones: [.full],
            intensity: .balanced
        )
        let expected = plan.items.enumerated().reduce(0) { total, entry in
            total + entry.element.durationSec + (entry.offset == plan.items.count - 1 ? 0 : entry.element.restAfterSec)
        }

        XCTAssertEqual(plan.totalDurationSec, expected)
    }

    func testEmptySelectionFallsBackToFullZone() {
        let plan = WorkoutGenerator().generate(
            targetDurationMin: 5,
            selectedZones: [],
            intensity: .balanced
        )

        XCTAssertEqual(plan.selectedZones, [.full])
    }

    func testIntensityChangesDifficultyRankingWithoutChangingAuthoredIntervals() {
        let catalog = [
            exercise("beginner", difficulty: .beginner, zones: [.upper]),
            exercise("intermediate", difficulty: .intermediate, zones: [.upper]),
            exercise("advanced", difficulty: .advanced, zones: [.upper])
        ]
        let generator = WorkoutGenerator(catalog: catalog)

        let light = generator.generate(targetDurationMin: 10, selectedZones: [.upper], intensity: .light)
        let balanced = generator.generate(targetDurationMin: 10, selectedZones: [.upper], intensity: .balanced)
        let high = generator.generate(targetDurationMin: 10, selectedZones: [.upper], intensity: .high)

        XCTAssertEqual(light.items.first?.exercise.difficulty, .beginner)
        XCTAssertEqual(balanced.items.prefix(2).map(\.exercise.difficulty), [.beginner, .intermediate])
        XCTAssertEqual(high.items.prefix(2).map(\.exercise.difficulty), [.intermediate, .advanced])
        XCTAssertTrue([light, balanced, high].flatMap(\.items).allSatisfy {
            $0.durationSec == $0.exercise.defaultDurationSec && $0.restAfterSec == $0.exercise.restAfterSec
        })
    }

    func testFiveMinuteHighExcludesAdvancedAndAvoidsAdjacentDuplicates() {
        let catalog = [
            exercise("intermediate", difficulty: .intermediate, zones: [.full]),
            exercise("advanced", difficulty: .advanced, zones: [.full]),
            exercise("beginner", difficulty: .beginner, zones: [.full])
        ]

        let plan = WorkoutGenerator(catalog: catalog).generate(
            targetDurationMin: 5,
            selectedZones: [.full],
            intensity: .high
        )

        XCTAssertFalse(plan.items.contains { $0.exercise.difficulty == .advanced })
        for pair in zip(plan.items, plan.items.dropFirst()) {
            XCTAssertNotEqual(pair.0.exercise.id, pair.1.exercise.id)
        }
    }

    func testStarterCatalogHitsDurationToleranceForEverySupportedSetup() {
        for duration in DurationDialContract.allowedValues {
            for intensity in WorkoutIntensity.allCases {
                let plan = WorkoutGenerator().generate(
                    targetDurationMin: duration,
                    selectedZones: [.full],
                    intensity: intensity
                )
                XCTAssertLessThanOrEqual(
                    abs(plan.totalDurationSec - duration * 60),
                    30,
                    "duration=\(duration), intensity=\(intensity)"
                )
            }
        }
    }

    func testEmptyCatalogReturnsControlledEmptyPlan() {
        let plan = WorkoutGenerator(catalog: []).generate(
            targetDurationMin: 10,
            selectedZones: [.full],
            intensity: .balanced
        )

        XCTAssertTrue(plan.items.isEmpty)
        XCTAssertEqual(plan.targetDurationMin, 10)
        XCTAssertEqual(plan.intensity, .balanced)
    }

    func testLegacyPlanWithoutIntensityDecodesAsBalanced() throws {
        let plan = WorkoutGenerator().generate(
            targetDurationMin: 5,
            selectedZones: [.full],
            intensity: .high
        )
        let encoded = try JSONEncoder().encode(plan)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "intensity")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(WorkoutPlan.self, from: legacyData)

        XCTAssertEqual(decoded.intensity, .balanced)
        XCTAssertEqual(decoded.selectedZones, [.full])
        XCTAssertEqual(decoded.items, plan.items)
    }

    func testSpecificFocusKeepsCanonicalSelectionAndStartsWithMatchingExercise() {
        let plan = WorkoutGenerator().generate(
            targetDurationMin: 10,
            selectedZones: [.obliques, .upper, .obliques],
            intensity: .balanced
        )

        XCTAssertEqual(plan.selectedZones, [.upper, .obliques])
        XCTAssertFalse(plan.items.isEmpty)
        XCTAssertTrue(
            plan.items.first.map { !Set($0.exercise.zones).intersection([.upper, .obliques]).isEmpty } ?? false
        )
    }

    func testIntensityFilteringAddsFullFallbackAfterIneligiblePrimaryCandidates() {
        let catalog = [
            exercise("advanced-upper-1", difficulty: .advanced, zones: [.upper]),
            exercise("advanced-upper-2", difficulty: .advanced, zones: [.upper]),
            exercise("advanced-upper-3", difficulty: .advanced, zones: [.upper]),
            exercise("advanced-upper-4", difficulty: .advanced, zones: [.upper]),
            exercise("beginner-full", difficulty: .beginner, zones: [.full])
        ]

        let plan = WorkoutGenerator(catalog: catalog).generate(
            targetDurationMin: 10,
            selectedZones: [.upper],
            intensity: .balanced
        )

        XCTAssertFalse(plan.items.isEmpty)
        XCTAssertTrue(plan.items.allSatisfy { $0.exercise.id == "beginner-full" })
        XCTAssertEqual(plan.selectedZones, [.upper])
    }

    func testLightPrefersBeginnerFullFallbackOverIntermediateSelectedFocus() {
        let catalog = [
            exercise("intermediate-upper-1", difficulty: .intermediate, zones: [.upper]),
            exercise("intermediate-upper-2", difficulty: .intermediate, zones: [.upper]),
            exercise("intermediate-upper-3", difficulty: .intermediate, zones: [.upper]),
            exercise("intermediate-upper-4", difficulty: .intermediate, zones: [.upper]),
            exercise("beginner-full", difficulty: .beginner, zones: [.full])
        ]

        let plan = WorkoutGenerator(catalog: catalog).generate(
            targetDurationMin: 10,
            selectedZones: [.upper],
            intensity: .light
        )

        XCTAssertTrue(plan.items.allSatisfy { $0.exercise.id == "beginner-full" })
    }

    func testHighRanksPreferredFullFallbackBeforeBeginnerSelectedFocus() {
        let catalog = [
            exercise("intermediate-upper", difficulty: .intermediate, zones: [.upper]),
            exercise("beginner-upper", difficulty: .beginner, zones: [.upper]),
            exercise("advanced-full", difficulty: .advanced, zones: [.full])
        ]

        let plan = WorkoutGenerator(catalog: catalog).generate(
            targetDurationMin: 10,
            selectedZones: [.upper],
            intensity: .high
        )

        XCTAssertEqual(
            plan.items.prefix(3).map(\.exercise.id),
            ["intermediate-upper", "advanced-full", "beginner-upper"]
        )
    }

    func testDuplicateCatalogIDsDoNotSuppressFallbackOrCreateAdjacentDuplicates() {
        let duplicate = exercise("duplicate-upper", difficulty: .beginner, zones: [.upper])
        let catalog = [duplicate, duplicate, duplicate, duplicate]
            + [exercise("beginner-full", difficulty: .beginner, zones: [.full])]

        let plan = WorkoutGenerator(catalog: catalog).generate(
            targetDurationMin: 5,
            selectedZones: [.upper],
            intensity: .light
        )

        XCTAssertEqual(Set(plan.items.map(\.exercise.id)), ["duplicate-upper", "beginner-full"])
        for pair in zip(plan.items, plan.items.dropFirst()) {
            XCTAssertNotEqual(pair.0.exercise.id, pair.1.exercise.id)
        }
    }

    func testShortCustomIntervalsCanReachNearestTargetBeyondLegacyIterationLimit() {
        let exercise = Exercise(
            id: "one-second",
            title: "one-second",
            zones: [.full],
            difficulty: .beginner,
            defaultDurationSec: 1,
            restAfterSec: 0,
            mediaName: "placeholder",
            isPlaceholderMedia: true,
            accessLevel: .free
        )

        let plan = WorkoutGenerator(catalog: [exercise]).generate(
            targetDurationMin: 15,
            selectedZones: [.full],
            intensity: .light
        )

        XCTAssertEqual(plan.totalDurationSec, 900)
        XCTAssertEqual(plan.items.count, 900)
    }

    private func exercise(
        _ id: String,
        difficulty: Difficulty,
        zones: [AbsZone]
    ) -> Exercise {
        Exercise(
            id: id,
            title: id,
            zones: zones,
            difficulty: difficulty,
            defaultDurationSec: 40,
            restAfterSec: 10,
            mediaName: "placeholder",
            isPlaceholderMedia: true,
            accessLevel: .free
        )
    }
}