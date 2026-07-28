import XCTest
@testable import AbsTrainer

@MainActor
final class WorkoutAudioPreferencesTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "WorkoutAudioPreferencesTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultsAndPersistentValuesFollowAudioContract() {
        let preferences = WorkoutAudioPreferences(store: defaults)
        XCTAssertFalse(preferences.musicEnabled)
        XCTAssertEqual(preferences.musicVolume, 0.50, accuracy: 0.001)
        XCTAssertTrue(preferences.voiceCoachEnabled)

        preferences.musicEnabled = true
        preferences.musicVolume = 0.75
        preferences.voiceCoachEnabled = false

        let restored = WorkoutAudioPreferences(store: defaults)
        XCTAssertTrue(restored.musicEnabled)
        XCTAssertEqual(restored.musicVolume, 0.75, accuracy: 0.001)
        XCTAssertFalse(restored.voiceCoachEnabled)
    }

    func testCorruptVolumeIsClampedAtPersistenceBoundary() {
        defaults.set(8.0, forKey: WorkoutAudioPreferences.Keys.musicVolume)
        let preferences = WorkoutAudioPreferences(store: defaults)
        XCTAssertEqual(preferences.musicVolume, 1.0, accuracy: 0.001)

        preferences.musicVolume = -1
        XCTAssertEqual(preferences.musicVolume, 0, accuracy: 0.001)
        XCTAssertEqual(defaults.double(forKey: WorkoutAudioPreferences.Keys.musicVolume), 0, accuracy: 0.001)
    }
}

final class CoachingSchedulerTests: XCTestCase {
    func testDynamicNumeralsAreFiniteCurrentOnlyAndRussian() {
        var scheduler = CoachingScheduler()
        let prescription = WorkoutPrescription.repetitionBased(
            targetCount: 22,
            countingUnit: .perSideAlternating,
            cadenceMillisPerCount: 2_000,
            estimatedDurationSec: 44
        )

        var spoken: [String] = []
        for count in 1...22 {
            spoken += scheduler.phrases(
                for: .repetitionCount(index: 0, count: count, prescription: prescription),
                voiceOverActive: false
            ).map(\.text)
        }
        XCTAssertEqual(spoken, CoachingScheduler.russianNumerals)
        XCTAssertEqual(Set(spoken).count, 22)
        XCTAssertTrue(scheduler.phrases(
            for: .repetitionCount(index: 0, count: 22, prescription: prescription),
            voiceOverActive: false
        ).isEmpty)
    }

    func testStaticHoldEmitsHoldMidpointAndCountdownButNeverRepetitionNumerals() {
        var scheduler = CoachingScheduler()
        let prescription = WorkoutPrescription.timeBased(durationSec: 40)
        let samples = [
            CoachingEvent.exerciseTick(index: 0, elapsedSecond: 4, remainingSecond: 36, prescription: prescription),
            .exerciseTick(index: 0, elapsedSecond: 20, remainingSecond: 20, prescription: prescription),
            .exerciseTick(index: 0, elapsedSecond: 30, remainingSecond: 10, prescription: prescription),
            .exerciseTick(index: 0, elapsedSecond: 35, remainingSecond: 5, prescription: prescription)
        ]
        let spoken = samples.flatMap { scheduler.phrases(for: $0, voiceOverActive: false).map(\.text) }

        XCTAssertEqual(spoken, ["Удерживаем положение.", "Половина.", "Осталось десять секунд.", "Пять."])
        XCTAssertTrue(Set(spoken).isDisjoint(with: Set(CoachingScheduler.russianNumerals)))
    }

    func testVoiceOverSuppressesAndDoesNotReplayMissedEvents() {
        var scheduler = CoachingScheduler()
        XCTAssertTrue(scheduler.phrases(for: .workoutStarted, voiceOverActive: true).isEmpty)
        XCTAssertTrue(scheduler.phrases(for: .workoutStarted, voiceOverActive: false).isEmpty)

        var audibleScheduler = CoachingScheduler()
        XCTAssertEqual(
            audibleScheduler.phrases(for: .workoutStarted, voiceOverActive: false).map(\.text),
            ["Начинаем тренировку."]
        )
        XCTAssertTrue(audibleScheduler.phrases(for: .workoutStarted, voiceOverActive: false).isEmpty)
    }

    func testOutcomePhrasesHaveExactOrderAndOnceSemantics() {
        var scheduler = CoachingScheduler()
        let events: [CoachingEvent] = [
            .manualCountStarted(index: 0),
            .repetitionTargetReached(index: 0),
            .setConfirmed(index: 0),
            .completedEarly(index: 1),
            .exerciseSkipped(index: 2)
        ]
        let expected = [
            "Ручной счёт.",
            "Плановый счёт завершён. Подтвердите набор.",
            "Набор подтверждён.",
            "Набор завершён досрочно.",
            "Упражнение пропущено."
        ]

        XCTAssertEqual(
            events.flatMap { scheduler.phrases(for: $0, voiceOverActive: false).map(\.text) },
            expected
        )
        XCTAssertTrue(events.flatMap {
            scheduler.phrases(for: $0, voiceOverActive: false)
        }.isEmpty)
    }

    func testFirstRepetitionIntroEndsWithRequiredPreparationPhrase() {
        var scheduler = CoachingScheduler()
        let phrases = scheduler.phrases(
            for: .exerciseStarted(
                index: 0,
                total: 1,
                title: "Скручивания",
                prescription: .repetitionBased(
                    targetCount: 6,
                    countingUnit: .fullCycle,
                    cadenceMillisPerCount: 3_000,
                    estimatedDurationSec: 18
                )
            ),
            voiceOverActive: false
        )

        XCTAssertEqual(phrases.last?.text, "Приготовились.")
    }

    func testMusicGainPolicyUsesContractTargets() {
        XCTAssertEqual(MusicGainPolicy.outputGain(volume: 0.8, state: .normal), 0.8, accuracy: 0.001)
        XCTAssertEqual(MusicGainPolicy.outputGain(volume: 0.8, state: .coachingSpeech), 0.16, accuracy: 0.001)
        XCTAssertEqual(MusicGainPolicy.outputGain(volume: 0.8, state: .voiceOver), 0.28, accuracy: 0.001)
        XCTAssertEqual(MusicGainPolicy.outputGain(volume: 0.8, state: .muted), 0, accuracy: 0.001)
    }
}

@MainActor
final class WorkoutAudioCoordinatorTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 4_000)

    func testOpeningCompletionStartsCanonicalFirstDeadline() {
        let speech = FakeSpeechController()
        let watchdog = FakePreRollWatchdog()
        let store = WorkoutSessionStore(plan: makePlan(), now: start)
        let coordinator = makeCoordinator(speech: speech, watchdog: watchdog)

        coordinator.start(plan: store.plan) {
            store.completeFirstExercisePreparation(at: self.start.addingTimeInterval(3))
        }
        store.tick(at: start.addingTimeInterval(20))
        XCTAssertTrue(store.isPreparingFirstExercise)
        XCTAssertEqual(store.remainingSeconds, 18)

        speech.completeCurrentBatch()
        XCTAssertFalse(store.isPreparingFirstExercise)
        store.tick(at: start.addingTimeInterval(20))
        XCTAssertEqual(store.remainingSeconds, 1)
    }

    func testTimerTickDuringOpeningDoesNotCancelOrCompletePreRoll() {
        let speech = FakeSpeechController()
        let watchdog = FakePreRollWatchdog()
        let store = WorkoutSessionStore(plan: makePlan(), now: start)
        let coordinator = makeCoordinator(speech: speech, watchdog: watchdog)
        coordinator.start(plan: store.plan) {
            store.completeFirstExercisePreparation(at: self.start.addingTimeInterval(8))
        }

        coordinator.tick(store: store)

        XCTAssertTrue(store.isPreparingFirstExercise)
        XCTAssertTrue(speech.isSpeaking)
        XCTAssertEqual(speech.stopCount, 0)
        XCTAssertNotNil(watchdog.delay)
    }

    func testOpeningCancellationStartsDeadlineExactlyOnce() {
        let speech = FakeSpeechController()
        let watchdog = FakePreRollWatchdog()
        let store = WorkoutSessionStore(plan: makePlan(), now: start)
        let coordinator = makeCoordinator(speech: speech, watchdog: watchdog)
        var completionCount = 0

        coordinator.start(plan: store.plan) {
            completionCount += 1
            store.completeFirstExercisePreparation(at: self.start.addingTimeInterval(2))
        }
        coordinator.pause()
        coordinator.pause()

        XCTAssertEqual(completionCount, 1)
        XCTAssertEqual(speech.stopCount, 2)
        store.tick(at: start.addingTimeInterval(19))
        XCTAssertEqual(store.remainingSeconds, 1)
    }

    func testOpeningWatchdogFiresAtEightSecondsAndStartsDeadline() {
        let speech = FakeSpeechController()
        let watchdog = FakePreRollWatchdog()
        let store = WorkoutSessionStore(plan: makePlan(), now: start)
        let coordinator = makeCoordinator(speech: speech, watchdog: watchdog)

        coordinator.start(plan: store.plan) {
            store.completeFirstExercisePreparation(at: self.start.addingTimeInterval(8))
        }

        XCTAssertEqual(watchdog.delay, WorkoutAudioCoordinator.firstExercisePreRollTimeout)
        XCTAssertEqual(watchdog.delay, 8)
        XCTAssertTrue(store.isPreparingFirstExercise)
        watchdog.fire()
        XCTAssertEqual(speech.stopCount, 1)
        XCTAssertFalse(store.isPreparingFirstExercise)
        store.tick(at: start.addingTimeInterval(25))
        XCTAssertEqual(store.remainingSeconds, 1)
    }

    func testDisabledCoachCompletesOpeningImmediatelyWithoutWatchdog() {
        let speech = FakeSpeechController()
        let watchdog = FakePreRollWatchdog()
        let preferences = makePreferences()
        preferences.voiceCoachEnabled = false
        let store = WorkoutSessionStore(plan: makePlan(), now: start)
        let coordinator = WorkoutAudioCoordinator(
            preferences: preferences,
            voiceOverActive: false,
            speechController: speech,
            schedulePreRollWatchdog: watchdog.schedule
        )

        coordinator.start(plan: store.plan) {
            store.completeFirstExercisePreparation(at: self.start)
        }

        XCTAssertFalse(store.isPreparingFirstExercise)
        XCTAssertNil(watchdog.delay)
        XCTAssertTrue(speech.batches.isEmpty)
    }

    func testTargetNumeralAndConfirmationPromptAreDeliveredInOrderOnce() {
        let speech = FakeSpeechController()
        let watchdog = FakePreRollWatchdog()
        let store = WorkoutSessionStore(plan: makePlan(), now: start)
        let coordinator = makeCoordinator(speech: speech, watchdog: watchdog)
        coordinator.start(plan: store.plan) {
            store.completeFirstExercisePreparation(at: self.start)
        }
        speech.completeCurrentBatch()

        store.tick(at: start.addingTimeInterval(18))
        coordinator.tick(store: store)
        coordinator.synchronize(store: store)

        XCTAssertEqual(
            speech.batches.last,
            ["Шесть", "Плановый счёт завершён. Подтвердите набор."]
        )
        XCTAssertEqual(speech.batches.filter {
            $0.contains("Плановый счёт завершён. Подтвердите набор.")
        }.count, 1)
    }

    func testManualTargetNumeralAndConfirmationPromptAreBatchedInOrder() {
        let speech = FakeSpeechController()
        let watchdog = FakePreRollWatchdog()
        let store = WorkoutSessionStore(plan: makePlan(), now: start)
        let coordinator = makeCoordinator(speech: speech, watchdog: watchdog)
        coordinator.start(plan: store.plan) {
            store.completeFirstExercisePreparation(at: self.start)
        }
        speech.completeCurrentBatch()
        store.switchToManualCount()
        coordinator.synchronize(store: store)
        speech.completeCurrentBatch()

        store.adjustManualCount(by: 6)
        coordinator.synchronize(store: store)

        XCTAssertEqual(
            speech.batches.last,
            ["Шесть", "Плановый счёт завершён. Подтвердите набор."]
        )
    }

    func testRapidManualIncrementsDeliverEveryNumeralInActionOrder() {
        let speech = FakeSpeechController()
        let watchdog = FakePreRollWatchdog()
        let store = WorkoutSessionStore(plan: makePlan(), now: start)
        let coordinator = makeCoordinator(speech: speech, watchdog: watchdog)
        coordinator.start(plan: store.plan) {
            store.completeFirstExercisePreparation(at: self.start)
        }
        speech.completeCurrentBatch()
        store.switchToManualCount()
        coordinator.synchronize(store: store)
        speech.completeCurrentBatch()

        for expected in 1...3 {
            store.adjustManualCount(by: 1)
            coordinator.synchronize(store: store)
            XCTAssertEqual(speech.batches.last, [CoachingScheduler.russianNumerals[expected - 1]])
            speech.completeCurrentBatch()
        }
    }

    func testSafetyEventsPauseAudioWithoutCatchUpOrAutoResume() {
        assertSafetyPause(resetExpected: false) { $0.handleInterruptionBegan() }
        assertSafetyPause(resetExpected: false) { $0.handleOldDeviceUnavailable() }
        assertSafetyPause(resetExpected: true) { $0.handleMediaServicesReset() }
        assertSafetyPause(resetExpected: false) { $0.sceneDidBecomeInactive() }
    }

    private func assertSafetyPause(
        resetExpected: Bool,
        action: (WorkoutAudioCoordinator) -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let speech = FakeSpeechController()
        let music = FakeMusicController()
        let watchdog = FakePreRollWatchdog()
        let store = WorkoutSessionStore(plan: makePlan(), now: start)
        let coordinator = makeCoordinator(speech: speech, music: music, watchdog: watchdog)
        coordinator.onSafetyPause = { store.pause(at: self.start.addingTimeInterval(6)) }
        coordinator.start(plan: store.plan) {
            store.completeFirstExercisePreparation(at: self.start)
        }
        speech.completeCurrentBatch()
        store.tick(at: start.addingTimeInterval(6))
        let countBeforePause = store.currentCount

        action(coordinator)
        store.tick(at: start.addingTimeInterval(60))

        XCTAssertTrue(store.isPaused, file: file, line: line)
        XCTAssertEqual(store.currentCount, countBeforePause, file: file, line: line)
        XCTAssertGreaterThanOrEqual(speech.stopCount, 1, file: file, line: line)
        XCTAssertGreaterThanOrEqual(music.pauseCount, 1, file: file, line: line)
        XCTAssertEqual(music.resetCount, resetExpected ? 1 : 0, file: file, line: line)
    }

    private func makeCoordinator(
        speech: FakeSpeechController,
        music: FakeMusicController? = nil,
        watchdog: FakePreRollWatchdog
    ) -> WorkoutAudioCoordinator {
        WorkoutAudioCoordinator(
            preferences: makePreferences(),
            voiceOverActive: false,
            speechController: speech,
            musicController: music,
            schedulePreRollWatchdog: watchdog.schedule
        )
    }

    private func makePreferences() -> WorkoutAudioPreferences {
        let name = "WorkoutAudioCoordinatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return WorkoutAudioPreferences(store: defaults)
    }

    private func makePlan() -> WorkoutPlan {
        WorkoutPlan(
            id: "audio-coordinator-plan",
            targetDurationMin: 5,
            selectedZones: [.full],
            intensity: .balanced,
            items: [
                WorkoutItem(
                    id: "audio-item",
                    exercise: ExerciseCatalog.starter[0],
                    prescription: .repetitionBased(
                        targetCount: 6,
                        countingUnit: .fullCycle,
                        cadenceMillisPerCount: 3_000,
                        estimatedDurationSec: 18
                    ),
                    restAfterSec: 0,
                    order: 1
                )
            ]
        )
    }
}

@MainActor
private final class FakeSpeechController: WorkoutSpeechControlling {
    var isAvailable = true
    private(set) var isSpeaking = false
    private(set) var batches: [[String]] = []
    private(set) var stopCount = 0
    private var completion: (() -> Void)?

    func speak(_ phrases: [String], completion: @escaping () -> Void) {
        batches.append(phrases)
        isSpeaking = true
        self.completion = completion
    }

    func stop() {
        stopCount += 1
        isSpeaking = false
        completion = nil
    }

    func completeCurrentBatch() {
        isSpeaking = false
        let completion = completion
        self.completion = nil
        completion?()
    }
}

@MainActor
private final class FakeMusicController: WorkoutMusicControlling {
    private(set) var pauseCount = 0
    private(set) var resetCount = 0

    func play() {}
    func pause() { pauseCount += 1 }
    func stop() {}
    func reset() { resetCount += 1 }
}

@MainActor
private final class FakePreRollWatchdog {
    private(set) var delay: TimeInterval?
    private var action: (() -> Void)?

    func schedule(delay: TimeInterval, action: @escaping @MainActor () -> Void) -> () -> Void {
        self.delay = delay
        self.action = action
        return { [weak self] in self?.action = nil }
    }

    func fire() {
        let action = action
        self.action = nil
        action?()
    }
}
