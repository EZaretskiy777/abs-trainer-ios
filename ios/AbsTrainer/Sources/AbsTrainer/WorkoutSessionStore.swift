import Combine
import Foundation

@MainActor
final class WorkoutSessionStore: ObservableObject {
    enum Phase: Equatable {
        case exercise
        case rest
        case finished
    }

    let plan: WorkoutPlan

    @Published private(set) var phase: Phase = .exercise
    @Published private(set) var currentIndex = 0
    @Published private(set) var remainingSeconds: Int
    @Published private(set) var completedExerciseCount = 0
    @Published private(set) var isPaused = false

    private let sessionStartedAt: Date
    private var deadline: Date
    private var pausedRemaining: TimeInterval?
    private var finishedAt: Date?

    init(plan: WorkoutPlan, now: Date = Date()) {
        precondition(!plan.items.isEmpty, "WorkoutSessionStore requires a non-empty plan")
        self.plan = plan
        sessionStartedAt = now
        remainingSeconds = plan.items[0].durationSec
        deadline = now.addingTimeInterval(TimeInterval(plan.items[0].durationSec))
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
        guard phase != .finished, !isPaused else { return }
        while phase != .finished, now >= deadline {
            let transitionDate = deadline
            switch phase {
            case .exercise:
                completeExercise(at: transitionDate)
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
        guard phase == .exercise, !isPaused else { return }
        tick(at: now)
        guard phase == .exercise else { return }
        pausedRemaining = max(0, deadline.timeIntervalSince(now))
        isPaused = true
    }

    func resume(at now: Date = Date()) {
        guard isPaused else { return }
        let interval = pausedRemaining ?? TimeInterval(remainingSeconds)
        remainingSeconds = Int(ceil(interval))
        deadline = now.addingTimeInterval(interval)
        pausedRemaining = nil
        isPaused = false
    }

    func skipExercise(at now: Date = Date()) {
        guard phase == .exercise else { return }
        completeExercise(at: now)
    }

    func skipRest(at now: Date = Date()) {
        guard phase == .rest else { return }
        startNextExercise(at: now)
    }

    private func completeExercise(at now: Date) {
        completedExerciseCount = min(completedExerciseCount + 1, plan.items.count)
        isPaused = false
        pausedRemaining = nil

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
        remainingSeconds = currentItem.durationSec
        deadline = now.addingTimeInterval(TimeInterval(currentItem.durationSec))
    }

    nonisolated static func format(seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
