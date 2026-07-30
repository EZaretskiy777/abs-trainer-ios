import XCTest
@testable import AbsTrainer

@MainActor
final class WorkoutSessionStoreTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000)

    func testSessionStartsWithFirstExerciseDuration() {
        let store = makeStartedStore()

        XCTAssertEqual(store.phase, .exercise)
        XCTAssertEqual(store.currentIndex, 0)
        XCTAssertEqual(store.remainingSeconds, 10)
        XCTAssertEqual(store.completedExerciseCount, 0)
    }

    func testExerciseDeadlineMovesSessionIntoRest() {
        let store = makeStartedStore()

        store.tick(at: start.addingTimeInterval(10))

        XCTAssertEqual(store.phase, .rest)
        XCTAssertEqual(store.remainingSeconds, 5)
        XCTAssertEqual(store.completedExerciseCount, 1)
        XCTAssertEqual(store.nextItem?.order, 2)
    }

    func testSkippingRestStartsNextExercise() {
        let store = makeStartedStore()
        store.tick(at: start.addingTimeInterval(10))

        store.skipRest(at: start.addingTimeInterval(11))

        XCTAssertEqual(store.phase, .exercise)
        XCTAssertEqual(store.currentIndex, 1)
        XCTAssertEqual(store.remainingSeconds, 8)
    }

    func testCompletingLastExerciseFinishesSession() {
        let store = makeStartedStore()
        store.tick(at: start.addingTimeInterval(10))
        store.skipRest(at: start.addingTimeInterval(10))

        store.tick(at: start.addingTimeInterval(18))

        XCTAssertEqual(store.phase, .finished)
        XCTAssertEqual(store.completedExerciseCount, 2)
    }

    func testPausePreservesRemainingTimeUntilResume() {
        let store = makeStartedStore()
        store.tick(at: start.addingTimeInterval(3))

        store.pause(at: start.addingTimeInterval(3))
        store.tick(at: start.addingTimeInterval(20))
        store.resume(at: start.addingTimeInterval(20))
        store.tick(at: start.addingTimeInterval(22))

        XCTAssertEqual(store.phase, .exercise)
        XCTAssertEqual(store.remainingSeconds, 5)
    }

    func testRepeatedFractionalPauseDoesNotExtendDeadline() {
        let store = makeStartedStore()

        store.pause(at: start.addingTimeInterval(0.25))
        store.resume(at: start.addingTimeInterval(5))
        store.pause(at: start.addingTimeInterval(5.25))
        store.resume(at: start.addingTimeInterval(10))
        store.tick(at: start.addingTimeInterval(19.5))

        XCTAssertEqual(store.phase, .rest)
        XCTAssertEqual(store.completedExerciseCount, 1)
    }

    func testLateTickReconcilesAcrossExerciseAndRestDeadlines() {
        let store = makeStartedStore()

        store.tick(at: start.addingTimeInterval(16))

        XCTAssertEqual(store.phase, .exercise)
        XCTAssertEqual(store.currentIndex, 1)
        XCTAssertEqual(store.remainingSeconds, 7)
    }

    func testFirstDeadlineDoesNotAdvanceDuringPreparationAndStartsAtCompletion() {
        let store = WorkoutSessionStore(plan: makePlan(), now: start)

        store.tick(at: start.addingTimeInterval(30))

        XCTAssertTrue(store.isPreparingFirstExercise)
        XCTAssertEqual(store.phase, .exercise)
        XCTAssertEqual(store.remainingSeconds, 10)

        store.completeFirstExercisePreparation(at: start.addingTimeInterval(30))
        store.tick(at: start.addingTimeInterval(39))
        XCTAssertEqual(store.remainingSeconds, 1)
        XCTAssertEqual(store.phase, .exercise)

        store.tick(at: start.addingTimeInterval(40))
        XCTAssertEqual(store.phase, .rest)
    }

    func testPreparationCompletionIsIdempotentAndPauseRequiresExplicitResume() {
        let store = WorkoutSessionStore(plan: makePlan(), now: start)
        store.pause(at: start.addingTimeInterval(1))
        store.completeFirstExercisePreparation(at: start.addingTimeInterval(2))
        store.completeFirstExercisePreparation(at: start.addingTimeInterval(8))

        store.tick(at: start.addingTimeInterval(20))
        XCTAssertTrue(store.isPaused)
        XCTAssertEqual(store.remainingSeconds, 10)

        store.resume(at: start.addingTimeInterval(20))
        store.tick(at: start.addingTimeInterval(29))
        XCTAssertEqual(store.remainingSeconds, 1)
    }

    private func makeStartedStore() -> WorkoutSessionStore {
        let store = WorkoutSessionStore(plan: makePlan(), now: start)
        store.completeFirstExercisePreparation(at: start)
        return store
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
        XCTAssertEqual(DurationDialContract.allowedValues, Array(5...15))
    }

    func testNearestIndexNormalizesInvalidValuesAndBreaksTiesDown() {
        XCTAssertEqual(DurationDialContract.nearestIndex(to: 7), 2)
        XCTAssertEqual(DurationDialContract.nearestIndex(to: 8), 3)
        XCTAssertEqual(DurationDialContract.nearestIndex(to: 12), 7)
        XCTAssertEqual(DurationDialContract.nearestIndex(to: 13), 8)
        XCTAssertEqual(DurationDialContract.nearestIndex(to: Int.min), 0)
        XCTAssertEqual(DurationDialContract.nearestIndex(to: Int.max), 10)
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

    func testArcFractionIncludesBothEndpointHitCorridors() throws {
        let diameter: CGFloat = 216
        let radius = diameter / 2 - 16
        let center = CGPoint(x: diameter / 2, y: diameter / 2)
        let endpoint = { (degrees: CGFloat) -> CGPoint in
            let radians = degrees * .pi / 180
            return CGPoint(
                x: center.x + radius * cos(radians),
                y: center.y + radius * sin(radians)
            )
        }

        XCTAssertEqual(
            try XCTUnwrap(DurationDialContract.arcFraction(at: endpoint(135), diameter: diameter, clampGap: false)),
            0,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            try XCTUnwrap(DurationDialContract.arcFraction(at: endpoint(45), diameter: diameter, clampGap: false)),
            1,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            try XCTUnwrap(DurationDialContract.arcFraction(at: endpoint(134.9), diameter: diameter, clampGap: false)),
            0,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            try XCTUnwrap(DurationDialContract.arcFraction(at: endpoint(45.1), diameter: diameter, clampGap: false)),
            1,
            accuracy: 0.000_001
        )
    }
}

@MainActor
final class RepetitionWorkoutSessionStoreTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 2_000)

    func testPacedCountReachesTargetButWaitsForExplicitConfirmation() {
        let store = startedStore(plan: repetitionPlan())
        store.tick(at: start.addingTimeInterval(12))

        XCTAssertEqual(store.currentCount, 4)
        XCTAssertTrue(store.isAwaitingSetConfirmation)
        XCTAssertEqual(store.phase, .exercise)
        XCTAssertEqual(store.completedExerciseCount, 0)

        store.confirmSet(at: start.addingTimeInterval(12))
        store.confirmSet(at: start.addingTimeInterval(12))

        XCTAssertEqual(store.phase, .finished)
        XCTAssertEqual(store.completedExerciseCount, 1)
        XCTAssertEqual(store.outcomes["paced"], .completed)
    }

    func testPauseAndLateTickDoNotCatchUpRepetitionCount() {
        let store = startedStore(plan: repetitionPlan(target: 6))
        store.tick(at: start.addingTimeInterval(6))
        XCTAssertEqual(store.currentCount, 2)

        store.pause(at: start.addingTimeInterval(6))
        store.tick(at: start.addingTimeInterval(30))
        store.resume(at: start.addingTimeInterval(30))
        store.tick(at: start.addingTimeInterval(32))

        XCTAssertEqual(store.currentCount, 2)
        store.tick(at: start.addingTimeInterval(33))
        XCTAssertEqual(store.currentCount, 3)
    }

    func testManualCountIsBoundedAndSkipDoesNotIncrementCompletedCount() {
        let store = startedStore(plan: repetitionPlan(target: 4))
        store.switchToManualCount()
        store.adjustManualCount(by: -1)
        XCTAssertEqual(store.currentCount, 0)
        for _ in 0..<8 { store.adjustManualCount(by: 1) }
        XCTAssertEqual(store.currentCount, 4)

        store.skipExercise(at: start)

        XCTAssertEqual(store.phase, .finished)
        XCTAssertEqual(store.completedExerciseCount, 0)
        XCTAssertEqual(store.outcomes["paced"], .skipped)
    }

    func testVoiceEventsAreOrderedAndDuplicateActionsDoNotEmitAgain() {
        let store = startedStore(plan: repetitionPlan(target: 2))

        store.switchToManualCount()
        XCTAssertEqual(store.latestVoiceEvent?.kind, .manualCountStarted)
        XCTAssertEqual(store.latestVoiceEvent?.sequence, 1)
        store.switchToManualCount()
        XCTAssertEqual(store.latestVoiceEvent?.sequence, 1)

        store.adjustManualCount(by: 2)
        XCTAssertEqual(store.latestVoiceEvent?.kind, .repetitionTargetReached)
        XCTAssertEqual(store.latestVoiceEvent?.sequence, 2)
        store.confirmSet(at: start)
        XCTAssertEqual(store.latestVoiceEvent?.kind, .setConfirmed)
        XCTAssertEqual(store.latestVoiceEvent?.sequence, 3)
        store.confirmSet(at: start)
        XCTAssertEqual(store.latestVoiceEvent?.sequence, 3)
    }

    private func startedStore(plan: WorkoutPlan) -> WorkoutSessionStore {
        let store = WorkoutSessionStore(plan: plan, now: start)
        store.completeFirstExercisePreparation(at: start)
        return store
    }

    private func repetitionPlan(target: Int = 4) -> WorkoutPlan {
        let exercise = ExerciseCatalog.starter[0]
        return WorkoutPlan(
            id: "repetition-plan",
            targetDurationMin: 5,
            selectedZones: [.full],
            intensity: .balanced,
            items: [
                WorkoutItem(
                    id: "paced",
                    exercise: exercise,
                    prescription: .repetitionBased(
                        targetCount: target,
                        countingUnit: .fullCycle,
                        cadenceMillisPerCount: 3_000,
                        estimatedDurationSec: target * 3
                    ),
                    restAfterSec: 0,
                    order: 1
                )
            ]
        )
    }
}
