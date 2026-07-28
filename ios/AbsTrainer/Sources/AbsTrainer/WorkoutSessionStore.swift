import Combine
import Foundation

@MainActor
final class WorkoutSessionStore: ObservableObject {
    enum Phase: Equatable {
        case exercise
        case rest
        case finished
    }

    struct VoiceEvent: Equatable {
        enum Kind: Equatable {
            case manualCountStarted
            case repetitionTargetReached
            case setConfirmed
            case completedEarly
            case skipped
        }

        let sequence: Int
        let exerciseIndex: Int
        let kind: Kind
    }

    let plan: WorkoutPlan

    @Published private(set) var phase: Phase = .exercise
    @Published private(set) var currentIndex = 0
    @Published private(set) var remainingSeconds: Int
    @Published private(set) var completedExerciseCount = 0
    @Published private(set) var isPaused = false
    @Published private(set) var currentCount = 0
    @Published private(set) var isManualCount = false
    @Published private(set) var isAwaitingSetConfirmation = false
    @Published private(set) var outcomes: [String: WorkoutOutcome] = [:]
    @Published private(set) var isPreparingFirstExercise = true
    @Published private(set) var latestVoiceEvent: VoiceEvent?

    private let sessionStartedAt: Date
    private var deadline: Date
    private var pausedRemaining: TimeInterval?
    private var exerciseStartedAt: Date
    private var pausedActiveElapsed: TimeInterval?
    private var finishedAt: Date?
    private var voiceEventSequence = 0
    private var hasStartedFirstExercise = false

    init(plan: WorkoutPlan, now: Date = Date()) {
        precondition(!plan.items.isEmpty, "WorkoutSessionStore requires a non-empty plan")
        self.plan = plan
        sessionStartedAt = now
        exerciseStartedAt = now
        remainingSeconds = plan.items[0].durationSec
        deadline = now
    }

    var currentItem: WorkoutItem { plan.items[currentIndex] }

    var nextItem: WorkoutItem? {
        guard currentIndex + 1 < plan.items.count else { return nil }
        return plan.items[currentIndex + 1]
    }

    var formattedRemaining: String {
        Self.format(seconds: remainingSeconds)
    }

    var elapsedSeconds: Int {
        let end = finishedAt ?? Date()
        return max(0, Int(end.timeIntervalSince(sessionStartedAt)))
    }

    func tick(at now: Date = Date()) {
        guard phase != .finished,
              !isPaused,
              !isPreparingFirstExercise else { return }
        if phase == .exercise, case .repetitionBased = currentItem.prescription {
            tickRepetition(at: now)
            return
        }
        while phase != .finished, now >= deadline {
            let transitionDate = deadline
            switch phase {
            case .exercise:
                completeExercise(at: transitionDate, outcome: .completed)
            case .rest:
                startNextExercise(at: transitionDate)
            case .finished:
                break
            }
        }
        if phase != .finished {
            remainingSeconds = max(0, Int(ceil(deadline.timeIntervalSince(now))))
        }
    }

    func pause(at now: Date = Date()) {
        guard phase != .finished, !isPaused else { return }
        if isPreparingFirstExercise {
            isPaused = true
            return
        }
        tick(at: now)
        guard phase != .finished else { return }
        pausedRemaining = max(0, deadline.timeIntervalSince(now))
        if phase == .exercise, case .repetitionBased = currentItem.prescription {
            pausedActiveElapsed = max(0, now.timeIntervalSince(exerciseStartedAt))
        }
        isPaused = true
    }

    func resume(at now: Date = Date()) {
        guard isPaused else { return }
        if !hasStartedFirstExercise {
            isPaused = false
            if !isPreparingFirstExercise {
                startFirstExercise(at: now)
            }
            return
        }
        let interval = pausedRemaining ?? TimeInterval(remainingSeconds)
        remainingSeconds = Int(ceil(interval))
        deadline = now.addingTimeInterval(interval)
        if let activeElapsed = pausedActiveElapsed {
            exerciseStartedAt = now.addingTimeInterval(-activeElapsed)
        }
        pausedRemaining = nil
        pausedActiveElapsed = nil
        isPaused = false
    }

    func completeFirstExercisePreparation(at now: Date = Date()) {
        guard isPreparingFirstExercise else { return }
        isPreparingFirstExercise = false
        guard !isPaused else { return }
        startFirstExercise(at: now)
    }

    func skipExercise(at now: Date = Date()) {
        guard phase == .exercise,
              !isPreparingFirstExercise,
              outcomes[currentItem.id] == nil else { return }
        emitVoiceEvent(.skipped)
        completeExercise(at: now, outcome: .skipped)
    }

    func completeCurrentEarly(at now: Date = Date()) {
        guard phase == .exercise,
              !isPreparingFirstExercise,
              outcomes[currentItem.id] == nil else { return }
        if case .repetitionBased = currentItem.prescription {
            emitVoiceEvent(.completedEarly)
        }
        completeExercise(at: now, outcome: .completedEarly(actualDisplayedCount: currentCount))
    }

    func confirmSet(at now: Date = Date()) {
        guard phase == .exercise,
              case .repetitionBased = currentItem.prescription,
              isAwaitingSetConfirmation,
              outcomes[currentItem.id] == nil else { return }
        emitVoiceEvent(.setConfirmed)
        completeExercise(at: now, outcome: .completed)
    }

    func switchToManualCount() {
        guard phase == .exercise,
              !isPreparingFirstExercise,
              !isManualCount,
              case .repetitionBased = currentItem.prescription else { return }
        isManualCount = true
        isAwaitingSetConfirmation = currentCount >= (currentItem.prescription.targetCount ?? .max)
        emitVoiceEvent(.manualCountStarted)
    }

    func adjustManualCount(by delta: Int) {
        guard isManualCount,
              let target = currentItem.prescription.targetCount else { return }
        let wasAwaitingConfirmation = isAwaitingSetConfirmation
        currentCount = min(target, max(0, currentCount + delta))
        isAwaitingSetConfirmation = currentCount == target
        if isAwaitingSetConfirmation, !wasAwaitingConfirmation {
            emitVoiceEvent(.repetitionTargetReached)
        }
    }

    func skipRest(at now: Date = Date()) {
        guard phase == .rest else { return }
        startNextExercise(at: now)
    }

    private func completeExercise(at now: Date, outcome: WorkoutOutcome) {
        guard outcomes[currentItem.id] == nil else { return }
        outcomes[currentItem.id] = outcome
        if outcome != .skipped {
            completedExerciseCount = min(completedExerciseCount + 1, plan.items.count)
        }
        isPaused = false
        pausedRemaining = nil
        pausedActiveElapsed = nil

        guard nextItem != nil else {
            remainingSeconds = 0
            phase = .finished
            finishedAt = now
            return
        }

        let restSeconds = currentItem.restAfterSec
        guard restSeconds > 0 else {
            startNextExercise(at: now)
            return
        }

        phase = .rest
        remainingSeconds = restSeconds
        deadline = now.addingTimeInterval(TimeInterval(restSeconds))
    }

    private func startNextExercise(at now: Date) {
        guard currentIndex + 1 < plan.items.count else {
            phase = .finished
            remainingSeconds = 0
            finishedAt = now
            return
        }

        currentIndex += 1
        phase = .exercise
        currentCount = 0
        isManualCount = false
        isAwaitingSetConfirmation = false
        exerciseStartedAt = now
        remainingSeconds = currentItem.durationSec
        deadline = now.addingTimeInterval(TimeInterval(currentItem.durationSec))
    }

    private func tickRepetition(at now: Date) {
        guard !isManualCount,
              !isAwaitingSetConfirmation,
              let target = currentItem.prescription.targetCount,
              let cadence = currentItem.prescription.cadenceMillisPerCount else { return }
        let elapsed = max(0, now.timeIntervalSince(exerciseStartedAt))
        let wasAwaitingConfirmation = isAwaitingSetConfirmation
        let plannedCount = min(target, Int(floor(elapsed * 1_000 / Double(cadence))))
        currentCount = max(currentCount, plannedCount)
        remainingSeconds = max(0, currentItem.durationSec - Int(floor(elapsed)))
        if currentCount == target {
            isAwaitingSetConfirmation = true
            remainingSeconds = 0
            if !wasAwaitingConfirmation {
                emitVoiceEvent(.repetitionTargetReached)
            }
        }
    }

    private func startFirstExercise(at now: Date) {
        guard !hasStartedFirstExercise else { return }
        hasStartedFirstExercise = true
        exerciseStartedAt = now
        remainingSeconds = currentItem.durationSec
        deadline = now.addingTimeInterval(TimeInterval(currentItem.durationSec))
    }

    private func emitVoiceEvent(_ kind: VoiceEvent.Kind) {
        voiceEventSequence += 1
        latestVoiceEvent = VoiceEvent(
            sequence: voiceEventSequence,
            exerciseIndex: currentIndex,
            kind: kind
        )
    }

    nonisolated static func format(seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
