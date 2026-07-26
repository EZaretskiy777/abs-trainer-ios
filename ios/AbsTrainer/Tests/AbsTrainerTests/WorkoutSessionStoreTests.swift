import XCTest
@testable import AbsTrainer

@MainActor
final class WorkoutSessionStoreTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000)

    func testSessionStartsWithFirstExerciseDuration() {
        let store = WorkoutSessionStore(plan: makePlan(), now: start)

        XCTAssertEqual(store.phase, .exercise)
        XCTAssertEqual(store.currentIndex, 0)
        XCTAssertEqual(store.remainingSeconds, 10)
        XCTAssertEqual(store.completedExerciseCount, 0)
    }

    func testExerciseDeadlineMovesSessionIntoRest() {
        let store = WorkoutSessionStore(plan: makePlan(), now: start)

        store.tick(at: start.addingTimeInterval(10))

        XCTAssertEqual(store.phase, .rest)
        XCTAssertEqual(store.remainingSeconds, 5)
        XCTAssertEqual(store.completedExerciseCount, 1)
        XCTAssertEqual(store.nextItem?.order, 2)
    }

    func testSkippingRestStartsNextExercise() {
        let store = WorkoutSessionStore(plan: makePlan(), now: start)
        store.tick(at: start.addingTimeInterval(10))

        store.skipRest(at: start.addingTimeInterval(11))

        XCTAssertEqual(store.phase, .exercise)
        XCTAssertEqual(store.currentIndex, 1)
        XCTAssertEqual(store.remainingSeconds, 8)
    }

    func testCompletingLastExerciseFinishesSession() {
        let store = WorkoutSessionStore(plan: makePlan(), now: start)
        store.tick(at: start.addingTimeInterval(10))
        store.skipRest(at: start.addingTimeInterval(10))

        store.tick(at: start.addingTimeInterval(18))

        XCTAssertEqual(store.phase, .finished)
        XCTAssertEqual(store.completedExerciseCount, 2)
    }

    func testPausePreservesRemainingTimeUntilResume() {
        let store = WorkoutSessionStore(plan: makePlan(), now: start)
        store.tick(at: start.addingTimeInterval(3))

        store.pause(at: start.addingTimeInterval(3))
        store.tick(at: start.addingTimeInterval(20))
        store.resume(at: start.addingTimeInterval(20))
        store.tick(at: start.addingTimeInterval(22))

        XCTAssertEqual(store.phase, .exercise)
        XCTAssertEqual(store.remainingSeconds, 5)
    }

    func testRepeatedFractionalPauseDoesNotExtendDeadline() {
        let store = WorkoutSessionStore(plan: makePlan(), now: start)

        store.pause(at: start.addingTimeInterval(0.25))
        store.resume(at: start.addingTimeInterval(5))
        store.pause(at: start.addingTimeInterval(5.25))
        store.resume(at: start.addingTimeInterval(10))
        store.tick(at: start.addingTimeInterval(19.5))

        XCTAssertEqual(store.phase, .rest)
        XCTAssertEqual(store.completedExerciseCount, 1)
    }

    func testLateTickReconcilesAcrossExerciseAndRestDeadlines() {
        let store = WorkoutSessionStore(plan: makePlan(), now: start)

        store.tick(at: start.addingTimeInterval(16))

        XCTAssertEqual(store.phase, .exercise)
        XCTAssertEqual(store.currentIndex, 1)
        XCTAssertEqual(store.remainingSeconds, 7)
    }

    private func makePlan() -> WorkoutPlan {
        WorkoutPlan(
            id: "test-plan",
            targetDurationMin: 5,
            selectedZones: [.full],
            intensity: .balanced,
            items: [
                WorkoutItem(
                    id: "first",
                    exercise: Exercise(
                        id: "crunch",
                        title: "Скручивания",
                        zones: [.upper],
                        difficulty: .beginner,
                        defaultDurationSec: 10,
                        restAfterSec: 5,
                        mediaName: "placeholder_crunch",
                        isPlaceholderMedia: true,
                        accessLevel: .free
                    ),
                    durationSec: 10,
                    restAfterSec: 5,
                    order: 1
                ),
                WorkoutItem(
                    id: "second",
                    exercise: Exercise(
                        id: "plank",
                        title: "Планка",
                        zones: [.full],
                        difficulty: .beginner,
                        defaultDurationSec: 8,
                        restAfterSec: 0,
                        mediaName: "placeholder_plank",
                        isPlaceholderMedia: true,
                        accessLevel: .free
                    ),
                    durationSec: 8,
                    restAfterSec: 0,
                    order: 2
                )
            ]
        )
    }
}

final class TempoContrastTests: XCTestCase {
    func testRestTextAndControlTokensMeetWCAGContrast() {
        let background = TempoTokens.SemanticColor.restBackground

        XCTAssertGreaterThanOrEqual(
            TempoTokens.SemanticColor.inversePrimary.contrastRatio(over: background),
            4.5
        )
        XCTAssertGreaterThanOrEqual(
            TempoTokens.SemanticColor.inverseSecondary.contrastRatio(over: background),
            4.5
        )
        XCTAssertGreaterThanOrEqual(
            TempoTokens.SemanticColor.inverseControlBorder.contrastRatio(over: background),
            3.0
        )
    }

    func testActivePauseTokensMeetWCAGControlContrast() {
        let background = TempoTokens.SemanticColor.activeBackground

        XCTAssertGreaterThanOrEqual(
            TempoTokens.SemanticColor.inversePrimary.contrastRatio(over: background),
            3.0
        )
        XCTAssertGreaterThanOrEqual(
            TempoTokens.SemanticColor.inverseControlBorder.contrastRatio(over: background),
            3.0
        )
    }
}

final class DurationDialContractTests: XCTestCase {
    func testAllowedValuesPreserveProductDurationContract() {
        XCTAssertEqual(DurationDialContract.allowedValues, [5, 10, 15])
    }

    func testNearestIndexNormalizesInvalidValuesAndBreaksTiesDown() {
        XCTAssertEqual(DurationDialContract.nearestIndex(to: 7), 0)
        XCTAssertEqual(DurationDialContract.nearestIndex(to: 8), 1)
        XCTAssertEqual(DurationDialContract.nearestIndex(to: 12), 1)
        XCTAssertEqual(DurationDialContract.nearestIndex(to: 13), 2)
        XCTAssertEqual(DurationDialContract.nearestIndex(to: Int.min), 0)
        XCTAssertEqual(DurationDialContract.nearestIndex(to: Int.max), 2)
    }

    func testSnapFractionsStayWithinThreeStops() {
        XCTAssertEqual(DurationDialContract.index(for: -1, count: 3), 0)
        XCTAssertEqual(DurationDialContract.index(for: 0.24, count: 3), 0)
        XCTAssertEqual(DurationDialContract.index(for: 0.25, count: 3), 0)
        XCTAssertEqual(DurationDialContract.index(for: 0.26, count: 3), 1)
        XCTAssertEqual(DurationDialContract.index(for: 0.74, count: 3), 1)
        XCTAssertEqual(DurationDialContract.index(for: 0.75, count: 3), 1)
        XCTAssertEqual(DurationDialContract.index(for: 0.76, count: 3), 2)
        XCTAssertEqual(DurationDialContract.index(for: 2, count: 3), 2)
    }
}
