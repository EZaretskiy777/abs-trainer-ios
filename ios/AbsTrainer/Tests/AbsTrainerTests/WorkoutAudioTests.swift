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

    func testVoiceOverSuppressesAllCoachingAndDoesNotReplayMissedEvents() {
        var scheduler = CoachingScheduler()
        XCTAssertTrue(scheduler.phrases(for: .workoutStarted, voiceOverActive: true).isEmpty)
        XCTAssertEqual(
            scheduler.phrases(for: .workoutStarted, voiceOverActive: false).map(\.text),
            ["Начинаем тренировку."]
        )
        XCTAssertTrue(scheduler.phrases(for: .workoutStarted, voiceOverActive: false).isEmpty)
    }

    func testMusicGainPolicyUsesContractTargets() {
        XCTAssertEqual(MusicGainPolicy.outputGain(volume: 0.8, state: .normal), 0.8, accuracy: 0.001)
        XCTAssertEqual(MusicGainPolicy.outputGain(volume: 0.8, state: .coachingSpeech), 0.16, accuracy: 0.001)
        XCTAssertEqual(MusicGainPolicy.outputGain(volume: 0.8, state: .voiceOver), 0.28, accuracy: 0.001)
        XCTAssertEqual(MusicGainPolicy.outputGain(volume: 0.8, state: .muted), 0, accuracy: 0.001)
    }
}
