import XCTest
@testable import AbsTrainer

final class WorkoutGeneratorTests: XCTestCase {
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
            selectedZones: [.full]
        )

        XCTAssertFalse(plan.items.isEmpty)
        XCTAssertTrue(plan.items.allSatisfy { $0.exercise.id == exercise.id })
    }

    func testPlanDurationDoesNotIncludeUnusedFinalRest() {
        let plan = WorkoutGenerator().generate(targetDurationMin: 5, selectedZones: [.full])
        let expected = plan.items.enumerated().reduce(0) { total, entry in
            total + entry.element.durationSec + (entry.offset == plan.items.count - 1 ? 0 : entry.element.restAfterSec)
        }

        XCTAssertEqual(plan.totalDurationSec, expected)
    }

    func testEmptySelectionFallsBackToFullZone() {
        let plan = WorkoutGenerator().generate(targetDurationMin: 5, selectedZones: [])

        XCTAssertEqual(plan.selectedZones, [.full])
    }
}