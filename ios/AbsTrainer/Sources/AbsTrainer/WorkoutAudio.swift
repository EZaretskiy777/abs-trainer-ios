import AVFoundation
import Combine
import Foundation
import UIKit

@MainActor
final class WorkoutAudioPreferences: ObservableObject {
    enum Keys {
        static let musicEnabled = "audio.v1.musicEnabled"
        static let musicVolume = "audio.v1.musicVolume"
        static let voiceCoachEnabled = "audio.v1.voiceCoachEnabled"
    }

    @Published var musicEnabled: Bool {
        didSet { store.set(musicEnabled, forKey: Keys.musicEnabled) }
    }

    @Published var musicVolume: Double {
        didSet {
            let validated = Self.clamp(musicVolume)
            if validated != musicVolume {
                musicVolume = validated
                return
            }
            store.set(validated, forKey: Keys.musicVolume)
        }
    }

    @Published var voiceCoachEnabled: Bool {
        didSet { store.set(voiceCoachEnabled, forKey: Keys.voiceCoachEnabled) }
    }

    private let store: UserDefaults

    init(store: UserDefaults = .standard) {
        self.store = store
        musicEnabled = store.object(forKey: Keys.musicEnabled) as? Bool ?? false
        musicVolume = Self.clamp(store.object(forKey: Keys.musicVolume) as? Double ?? 0.50)
        voiceCoachEnabled = store.object(forKey: Keys.voiceCoachEnabled) as? Bool ?? true
        store.set(musicVolume, forKey: Keys.musicVolume)
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value.isFinite ? value : 0.50))
    }
}

enum MusicGainState {
    case normal
    case coachingSpeech
    case voiceOver
    case muted
}

enum MusicGainPolicy {
    static func outputGain(volume: Double, state: MusicGainState) -> Float {
        let value = min(1, max(0, volume.isFinite ? volume : 0.50))
        switch state {
        case .normal: return Float(value)
        case .coachingSpeech: return Float(value * 0.20)
        case .voiceOver: return Float(value * 0.35)
        case .muted: return 0
        }
    }
}

struct CoachingPhrase: Equatable {
    enum Priority: Int {
        case cadence = 1
        case hold = 2
        case countdown = 3
        case transition = 4
        case finish = 5
    }

    let id: String
    let text: String
    let priority: Priority
}

enum CoachingEvent {
    case workoutStarted
    case exerciseStarted(index: Int, total: Int, title: String, prescription: WorkoutPrescription)
    case exerciseTick(
        index: Int,
        elapsedSecond: Int,
        remainingSecond: Int,
        prescription: WorkoutPrescription
    )
    case repetitionCount(index: Int, count: Int, prescription: WorkoutPrescription)
    case restStarted(index: Int, total: Int, nextTitle: String?)
    case workoutFinished
}

struct CoachingScheduler {
    static let russianNumerals = [
        "Один", "Два", "Три", "Четыре", "Пять", "Шесть", "Семь", "Восемь",
        "Девять", "Десять", "Одиннадцать", "Двенадцать", "Тринадцать",
        "Четырнадцать", "Пятнадцать", "Шестнадцать", "Семнадцать",
        "Восемнадцать", "Девятнадцать", "Двадцать", "Двадцать один", "Двадцать два"
    ]

    private var delivered: Set<String> = []

    mutating func phrases(for event: CoachingEvent, voiceOverActive: Bool) -> [CoachingPhrase] {
        let candidates = phraseCandidates(for: event)
        guard !voiceOverActive else {
            delivered.formUnion(candidates.map(\.id))
            return []
        }
        return candidates.filter { delivered.insert($0.id).inserted }
    }

    mutating func resetForNewExercise() {
        delivered = delivered.filter { $0.hasPrefix("session.") }
    }

    private func phraseCandidates(for event: CoachingEvent) -> [CoachingPhrase] {
        switch event {
        case .workoutStarted:
            return [phrase("session.start", "Начинаем тренировку.", .transition)]
        case let .exerciseStarted(index, total, title, prescription):
            let intro = index == 0
                ? "Упражнение \(index + 1) из \(total). \(title)."
                : "Дальше — упражнение \(index + 1) из \(total). \(title)."
            var result = [phrase("exercise.\(index).intro", intro, .transition)]
            switch prescription {
            case let .timeBased(duration):
                result.append(phrase(
                    "exercise.\(index).prescription",
                    "Удержание — \(duration) секунд. Приготовились.",
                    .transition
                ))
            case let .repetitionBased(target, unit, _, _):
                let detail = unit == .perSideAlternating
                    ? "Цель — \(target) повторов, по \(target / 2) на каждую сторону. Каждая смена стороны — следующий номер. Счёт задаёт темп."
                    : "Цель — \(target) повторов. Каждый полный цикл — один повтор. Счёт задаёт темп."
                result.append(phrase("exercise.\(index).prescription", detail, .transition))
            }
            return result
        case let .exerciseTick(index, elapsed, remaining, prescription):
            guard case let .timeBased(duration) = prescription else { return [] }
            if remaining == 10 {
                return [phrase("exercise.\(index).time.10", "Осталось десять секунд.", .countdown)]
            }
            if let countdown = [5: "Пять.", 3: "Три.", 2: "Два.", 1: "Один."][remaining] {
                return [phrase("exercise.\(index).time.\(remaining)", countdown, .countdown)]
            }
            let midpoint = elapsed >= Int(ceil(Double(duration) / 2)) && remaining > 12
            if midpoint {
                return [phrase("exercise.\(index).midpoint", "Половина.", .hold)]
            }
            if elapsed >= 4, remaining > 12 {
                return [phrase("exercise.\(index).hold", "Удерживаем положение.", .hold)]
            }
            return []
        case let .repetitionCount(index, count, prescription):
            guard case let .repetitionBased(target, _, _, _) = prescription,
                  (1...min(target, Self.russianNumerals.count)).contains(count) else { return [] }
            return [phrase(
                "exercise.\(index).count.\(count)",
                Self.russianNumerals[count - 1],
                .cadence
            )]
        case let .restStarted(index, total, nextTitle):
            var result = [phrase("rest.\(index).start", "Отдых.", .transition)]
            if let nextTitle {
                result.append(phrase(
                    "rest.\(index).next",
                    "Дальше — упражнение \(index + 2) из \(total). \(nextTitle).",
                    .transition
                ))
            }
            return result
        case .workoutFinished:
            return [phrase("session.finish", "Тренировка завершена.", .finish)]
        }
    }

    private func phrase(_ id: String, _ text: String, _ priority: CoachingPhrase.Priority) -> CoachingPhrase {
        CoachingPhrase(id: id, text: text, priority: priority)
    }
}

@MainActor
final class WorkoutAudioCoordinator: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var sessionMuted = false
    @Published private(set) var statusText: String?

    var onSafetyPause: (() -> Void)?

    private let preferences: WorkoutAudioPreferences
    private let speechSynthesizer = AVSpeechSynthesizer()
    private let audioSession = AVAudioSession.sharedInstance()
    private var musicPlayer: AVAudioPlayer?
    private var scheduler = CoachingScheduler()
    private var voiceOverActive: Bool
    private var lastCount = 0
    private var speechOnlySessionActive = false
    private var observerTokens: [NSObjectProtocol] = []

    init(preferences: WorkoutAudioPreferences) {
        self.preferences = preferences
        voiceOverActive = UIAccessibility.isVoiceOverRunning
        super.init()
        speechSynthesizer.delegate = self
        installObservers()
    }

    deinit {
        observerTokens.forEach(NotificationCenter.default.removeObserver)
    }

    func start(plan: WorkoutPlan) {
        sessionMuted = false
        scheduler = CoachingScheduler()
        lastCount = 0
        prepareMusicIfNeeded()
        guard let first = plan.items.first else { return }
        var opening = scheduler.phrases(for: .workoutStarted, voiceOverActive: voiceOverActive)
        opening.append(contentsOf: scheduler.phrases(
            for: .exerciseStarted(
                index: 0,
                total: plan.items.count,
                title: first.exercise.title,
                prescription: first.prescription
            ),
            voiceOverActive: voiceOverActive
        ))
        speak(opening)
    }

    func tick(store: WorkoutSessionStore) {
        guard store.phase == .exercise, !store.isPaused else { return }
        let item = store.currentItem
        switch item.prescription {
        case .timeBased:
            let elapsed = max(0, item.durationSec - store.remainingSeconds)
            speak(scheduler.phrases(
                for: .exerciseTick(
                    index: store.currentIndex,
                    elapsedSecond: elapsed,
                    remainingSecond: store.remainingSeconds,
                    prescription: item.prescription
                ),
                voiceOverActive: voiceOverActive
            ))
        case .repetitionBased:
            guard store.currentCount > lastCount else { return }
            lastCount = store.currentCount
            speak(scheduler.phrases(
                for: .repetitionCount(
                    index: store.currentIndex,
                    count: store.currentCount,
                    prescription: item.prescription
                ),
                voiceOverActive: voiceOverActive
            ))
        }
    }

    func transition(to phase: WorkoutSessionStore.Phase, store: WorkoutSessionStore) {
        cancelSpeech()
        switch phase {
        case .exercise:
            scheduler.resetForNewExercise()
            lastCount = 0
            speak(scheduler.phrases(
                for: .exerciseStarted(
                    index: store.currentIndex,
                    total: store.plan.items.count,
                    title: store.currentItem.exercise.title,
                    prescription: store.currentItem.prescription
                ),
                voiceOverActive: voiceOverActive
            ))
        case .rest:
            speak(scheduler.phrases(
                for: .restStarted(
                    index: store.currentIndex,
                    total: store.plan.items.count,
                    nextTitle: store.nextItem?.exercise.title
                ),
                voiceOverActive: voiceOverActive
            ))
        case .finished:
            musicPlayer?.stop()
            speak(scheduler.phrases(for: .workoutFinished, voiceOverActive: voiceOverActive))
        }
    }

    func setSessionMuted(_ muted: Bool) {
        sessionMuted = muted
        if muted {
            cancelSpeech()
            musicPlayer?.setVolume(0, fadeDuration: 0.15)
        } else {
            applyIdleMusicGain()
            musicPlayer?.play()
        }
    }

    func pause() {
        cancelSpeech()
        musicPlayer?.pause()
    }

    func resume() {
        guard !sessionMuted else { return }
        if preferences.musicEnabled, musicPlayer == nil {
            prepareMusicIfNeeded()
        }
        applyIdleMusicGain()
        musicPlayer?.play()
    }

    func stop() {
        cancelSpeech()
        musicPlayer?.stop()
        musicPlayer = nil
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func prepareMusicIfNeeded() {
        guard preferences.musicEnabled, !sessionMuted else { return }
        guard let url = Bundle.main.url(
            forResource: "workout_music_pulse_grid_v1",
            withExtension: "m4a",
            subdirectory: "Audio"
        ) else {
            statusText = "Звук тренировки недоступен"
            return
        }
        do {
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.prepareToPlay()
            musicPlayer = player
            applyIdleMusicGain()
            player.play()
        } catch {
            statusText = "Звук тренировки недоступен"
            musicPlayer = nil
        }
    }

    private func speak(_ phrases: [CoachingPhrase]) {
        guard preferences.voiceCoachEnabled,
              !sessionMuted,
              !voiceOverActive,
              !phrases.isEmpty else { return }
        guard let voice = AVSpeechSynthesisVoice(language: "ru-RU") else {
            statusText = "Звук тренировки недоступен"
            return
        }
        do {
            if musicPlayer == nil {
                try audioSession.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
                try audioSession.setActive(true)
                speechOnlySessionActive = true
            }
        } catch {
            statusText = "Звук тренировки недоступен"
            return
        }
        musicPlayer?.setVolume(
            MusicGainPolicy.outputGain(volume: preferences.musicVolume, state: .coachingSpeech),
            fadeDuration: 0.15
        )
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .word)
        }
        for phrase in phrases {
            let utterance = AVSpeechUtterance(string: phrase.text)
            utterance.voice = voice
            utterance.rate = 0.48
            utterance.pitchMultiplier = 1.0
            speechSynthesizer.speak(utterance)
        }
    }

    private func cancelSpeech() {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        deactivateSpeechOnlySessionIfNeeded()
        applyIdleMusicGain()
    }

    private func deactivateSpeechOnlySessionIfNeeded() {
        guard speechOnlySessionActive, !speechSynthesizer.isSpeaking else { return }
        speechOnlySessionActive = false
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func applyIdleMusicGain() {
        let state: MusicGainState = sessionMuted ? .muted : (voiceOverActive ? .voiceOver : .normal)
        musicPlayer?.setVolume(
            MusicGainPolicy.outputGain(volume: preferences.musicVolume, state: state),
            fadeDuration: 0.30
        )
    }

    private func installObservers() {
        let center = NotificationCenter.default
        observerTokens.append(center.addObserver(
            forName: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.voiceOverChanged() }
        })
        observerTokens.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] notification in
            guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
            Task { @MainActor in self?.handleSafetyPause() }
        })
        observerTokens.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] notification in
            guard let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
            Task { @MainActor in self?.handleSafetyPause() }
        })
        observerTokens.append(center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleSafetyPause(resetMusic: true) }
        })
    }

    private func voiceOverChanged() {
        voiceOverActive = UIAccessibility.isVoiceOverRunning
        if voiceOverActive { cancelSpeech() }
        applyIdleMusicGain()
    }

    private func handleSafetyPause(resetMusic: Bool = false) {
        cancelSpeech()
        musicPlayer?.pause()
        if resetMusic { musicPlayer = nil }
        onSafetyPause?()
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            self?.deactivateSpeechOnlySessionIfNeeded()
            self?.applyIdleMusicGain()
        }
    }
}
