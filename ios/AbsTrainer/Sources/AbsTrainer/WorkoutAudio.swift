import AVFoundation
import Combine
import CryptoKit
import Foundation
import UIKit

enum WorkoutMusicTrack: String, CaseIterable, Codable, Identifiable {
    case pulseGrid
    case forwardArc
    case groundedOrbit

    var id: WorkoutMusicTrack { self }
    var fileExtension: String { "m4a" }

    var title: String {
        switch self {
        case .pulseGrid: return "Pulse Grid"
        case .forwardArc: return "Forward Arc"
        case .groundedOrbit: return "Grounded Orbit"
        }
    }

    var resourceName: String {
        switch self {
        case .pulseGrid: return "workout_music_pulse_grid_v3"
        case .forwardArc: return "workout_music_forward_arc_v4"
        case .groundedOrbit: return "workout_music_grounded_orbit_v3"
        }
    }

    var sha256: String {
        switch self {
        case .pulseGrid:
            return "75ce7234b1b1a826dbdb8384eaae8c79a7bf760cea5e27790e26e5134823bb19"
        case .forwardArc:
            return "1023ffe6be67874714cd13e8c51577d4734e0b192215510bdbbacde762ff20cf"
        case .groundedOrbit:
            return "60d8937a9c32b66d419546f1f339397c00c2e9f0ea39269c5710e9b697e42467"
        }
    }
}

enum WorkoutMusicSelection: String, CaseIterable, Codable, Identifiable {
    case auto
    case pulseGrid
    case forwardArc
    case groundedOrbit

    var id: WorkoutMusicSelection { self }

    var title: String {
        switch self {
        case .auto: return "Авто"
        case .pulseGrid: return WorkoutMusicTrack.pulseGrid.title
        case .forwardArc: return WorkoutMusicTrack.forwardArc.title
        case .groundedOrbit: return WorkoutMusicTrack.groundedOrbit.title
        }
    }

    var explicitTrack: WorkoutMusicTrack? {
        switch self {
        case .auto: return nil
        case .pulseGrid: return .pulseGrid
        case .forwardArc: return .forwardArc
        case .groundedOrbit: return .groundedOrbit
        }
    }
}

enum WorkoutMusicRegistry {
    static let canonicalTracks = WorkoutMusicTrack.allCases
}

enum WorkoutMusicResolver {
    static func firstAvailable(
        preferred: WorkoutMusicTrack,
        isAvailable: (WorkoutMusicTrack) -> Bool
    ) -> WorkoutMusicTrack? {
        let candidates = [preferred] + WorkoutMusicRegistry.canonicalTracks.filter { $0 != preferred }
        return candidates.first(where: isAvailable)
    }

    static func next(after previous: WorkoutMusicTrack?) -> WorkoutMusicTrack {
        let tracks = WorkoutMusicRegistry.canonicalTracks
        guard let previous, let index = tracks.firstIndex(of: previous) else {
            return tracks[0]
        }
        return tracks[(index + 1) % tracks.count]
    }
}

enum WorkoutMusicResourceValidator {
    static func isValid(track: WorkoutMusicTrack, at url: URL) throws -> Bool {
        let digest = SHA256.hash(data: try Data(contentsOf: url, options: .mappedIfSafe))
        return digest.map { String(format: "%02x", $0) }.joined() == track.sha256
    }
}

@MainActor
final class WorkoutAudioPreferences: ObservableObject {
    enum Keys {
        static let musicEnabled = "audio.v1.musicEnabled"
        static let musicVolume = "audio.v1.musicVolume"
        static let voiceCoachEnabled = "audio.v1.voiceCoachEnabled"
        static let musicSelection = "audio.v2.musicSelection"
        static let lastAutoTrack = "audio.v2.lastAutoTrack"
        static let currentMusicTrack = "audio.v2.currentMusicTrack"
        static let lastPlayedTrack = "audio.v2.lastPlayedTrack"
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

    @Published var musicSelection: WorkoutMusicSelection {
        didSet {
            store.set(musicSelection.rawValue, forKey: Keys.musicSelection)
            if let explicitTrack = musicSelection.explicitTrack {
                currentMusicTrack = explicitTrack
            } else {
                currentMusicTrack = WorkoutMusicResolver.next(after: persistedLastAutoTrack)
            }
        }
    }

    @Published private(set) var currentMusicTrack: WorkoutMusicTrack {
        didSet { store.set(currentMusicTrack.rawValue, forKey: Keys.currentMusicTrack) }
    }

    private let store: UserDefaults

    init(store: UserDefaults = .standard) {
        self.store = store
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ResetAudioPreferences") {
            [
                Keys.musicEnabled,
                Keys.musicVolume,
                Keys.voiceCoachEnabled,
                Keys.musicSelection,
                Keys.lastAutoTrack,
                Keys.currentMusicTrack,
                Keys.lastPlayedTrack
            ].forEach { store.removeObject(forKey: $0) }
        }
        #endif
        musicEnabled = store.object(forKey: Keys.musicEnabled) as? Bool ?? false
        musicVolume = Self.clamp(store.object(forKey: Keys.musicVolume) as? Double ?? 0.50)
        voiceCoachEnabled = store.object(forKey: Keys.voiceCoachEnabled) as? Bool ?? true
        let selection = store.string(forKey: Keys.musicSelection)
            .flatMap(WorkoutMusicSelection.init(rawValue:)) ?? .pulseGrid
        musicSelection = selection
        currentMusicTrack = selection.explicitTrack
            ?? WorkoutMusicResolver.next(after: store.string(forKey: Keys.lastAutoTrack)
                .flatMap(WorkoutMusicTrack.init(rawValue:)))
        store.set(musicVolume, forKey: Keys.musicVolume)
        store.set(selection.rawValue, forKey: Keys.musicSelection)
        store.set(currentMusicTrack.rawValue, forKey: Keys.currentMusicTrack)
    }

    @discardableResult
    func prepareMusicForNextWorkout() -> WorkoutMusicTrack {
        if let explicitTrack = musicSelection.explicitTrack {
            currentMusicTrack = explicitTrack
            return explicitTrack
        }
        let next = WorkoutMusicResolver.next(after: persistedLastAutoTrack)
        store.set(next.rawValue, forKey: Keys.lastAutoTrack)
        currentMusicTrack = next
        return next
    }

    func recordPlayedMusicTrack(_ track: WorkoutMusicTrack) {
        currentMusicTrack = track
        store.set(track.rawValue, forKey: Keys.lastPlayedTrack)
        if musicSelection == .auto {
            store.set(track.rawValue, forKey: Keys.lastAutoTrack)
        }
    }

    var nextMusicTrackPreview: WorkoutMusicTrack {
        musicSelection.explicitTrack ?? WorkoutMusicResolver.next(after: persistedLastAutoTrack)
    }

    func playbackCandidates() -> [WorkoutMusicTrack] {
        let preferred = currentMusicTrack
        guard musicSelection == .auto, let lastPlayedTrack else {
            return [preferred] + WorkoutMusicRegistry.canonicalTracks.filter { $0 != preferred }
        }
        let nonRepeating = WorkoutMusicRegistry.canonicalTracks.filter {
            $0 != preferred && $0 != lastPlayedTrack
        }
        let emergencyRepeat = lastPlayedTrack == preferred ? [] : [lastPlayedTrack]
        return [preferred] + nonRepeating + emergencyRepeat
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value.isFinite ? value : 0.50))
    }

    private var persistedLastAutoTrack: WorkoutMusicTrack? {
        store.string(forKey: Keys.lastAutoTrack).flatMap(WorkoutMusicTrack.init(rawValue:))
    }

    private var lastPlayedTrack: WorkoutMusicTrack? {
        store.string(forKey: Keys.lastPlayedTrack).flatMap(WorkoutMusicTrack.init(rawValue:))
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
    case manualCountStarted(index: Int)
    case repetitionTargetReached(index: Int)
    case setConfirmed(index: Int)
    case completedEarly(index: Int)
    case exerciseSkipped(index: Int)
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
                result.append(phrase("exercise.\(index).prepare", "Приготовились.", .transition))
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
        case let .manualCountStarted(index):
            return [phrase("exercise.\(index).manual", "Ручной счёт.", .transition)]
        case let .repetitionTargetReached(index):
            return [phrase(
                "exercise.\(index).target",
                "Плановый счёт завершён. Подтвердите набор.",
                .transition
            )]
        case let .setConfirmed(index):
            return [phrase("exercise.\(index).confirmed", "Набор подтверждён.", .transition)]
        case let .completedEarly(index):
            return [phrase("exercise.\(index).early", "Набор завершён досрочно.", .transition)]
        case let .exerciseSkipped(index):
            return [phrase("exercise.\(index).skipped", "Упражнение пропущено.", .transition)]
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
protocol WorkoutSpeechControlling: AnyObject {
    var isAvailable: Bool { get }
    var isSpeaking: Bool { get }
    func speak(_ phrases: [String], completion: @escaping () -> Void)
    func stop()
}

@MainActor
protocol WorkoutMusicControlling: AnyObject {
    func play()
    func pause()
    func stop()
    func reset()
}

typealias PreRollWatchdogScheduler = (
    _ delay: TimeInterval,
    _ action: @escaping @MainActor () -> Void
) -> () -> Void

@MainActor
final class WorkoutAudioCoordinator: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let firstExercisePreRollTimeout: TimeInterval = 8

    @Published private(set) var sessionMuted = false
    @Published private(set) var statusText: String?
    @Published private(set) var activeMusicTrack: WorkoutMusicTrack?

    var displayedMusicTrack: WorkoutMusicTrack { activeMusicTrack ?? preferences.currentMusicTrack }
    var isMusicEnabled: Bool { preferences.musicEnabled }

    var onSafetyPause: (() -> Void)?

    private let preferences: WorkoutAudioPreferences
    private let notificationCenter: NotificationCenter
    private let speechController: WorkoutSpeechControlling?
    private let musicController: WorkoutMusicControlling?
    private let schedulePreRollWatchdog: PreRollWatchdogScheduler
    private let speechSynthesizer = AVSpeechSynthesizer()
    private let audioSession = AVAudioSession.sharedInstance()
    private var musicPlayer: AVAudioPlayer?
    private var scheduler = CoachingScheduler()
    private var voiceOverActive: Bool
    private var lastCount = 0
    private var speechOnlySessionActive = false
    private var observerTokens: [NSObjectProtocol] = []
    private var openingCompletion: (() -> Void)?
    private var cancelOpeningWatchdog: (() -> Void)?
    private var pendingOpeningUtterances = 0
    private var observedPhase: WorkoutSessionStore.Phase?
    private var observedIndex = 0
    private var deliveredVoiceEventSequence = 0
    private var speechActivitySequence = 0
    private var hasStartedSession = false
    private var activeSpeechPriority: CoachingPhrase.Priority?
    private var deferredSpeechPhrases: [CoachingPhrase] = []

    init(
        preferences: WorkoutAudioPreferences,
        notificationCenter: NotificationCenter = .default,
        voiceOverActive: Bool? = nil,
        speechController: WorkoutSpeechControlling? = nil,
        musicController: WorkoutMusicControlling? = nil,
        schedulePreRollWatchdog: @escaping PreRollWatchdogScheduler = WorkoutAudioCoordinator.liveWatchdog
    ) {
        self.preferences = preferences
        self.notificationCenter = notificationCenter
        self.speechController = speechController
        self.musicController = musicController
        self.schedulePreRollWatchdog = schedulePreRollWatchdog
        self.voiceOverActive = voiceOverActive ?? UIAccessibility.isVoiceOverRunning
        super.init()
        speechSynthesizer.delegate = self
        installObservers()
    }

    deinit {
        observerTokens.forEach(notificationCenter.removeObserver)
    }

    func start(plan: WorkoutPlan, onOpeningComplete: @escaping () -> Void) {
        if hasStartedSession {
            if openingCompletion == nil {
                onOpeningComplete()
            }
            return
        }
        hasStartedSession = true
        sessionMuted = false
        scheduler = CoachingScheduler()
        lastCount = 0
        observedPhase = .exercise
        observedIndex = 0
        deliveredVoiceEventSequence = 0
        prepareMusicIfNeeded()
        guard let first = plan.items.first else {
            onOpeningComplete()
            return
        }
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
        guard canSpeak(opening) else {
            onOpeningComplete()
            return
        }
        openingCompletion = onOpeningComplete
        cancelOpeningWatchdog = schedulePreRollWatchdog(Self.firstExercisePreRollTimeout) { [weak self] in
            self?.finishOpeningPreRoll(cancelSpeech: true)
        }
        speak(opening) { [weak self] in
            self?.finishOpeningPreRoll(cancelSpeech: false)
        }
    }

    func tick(store: WorkoutSessionStore) {
        guard !store.isPreparingFirstExercise else { return }
        guard store.phase == .exercise, !store.isPaused else {
            synchronize(store: store)
            return
        }
        let item = store.currentItem
        switch item.prescription {
        case .timeBased:
            synchronize(store: store)
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
            guard store.currentCount > lastCount else {
                synchronize(store: store)
                return
            }
            lastCount = store.currentCount
            var phrases = scheduler.phrases(
                for: .repetitionCount(
                    index: store.currentIndex,
                    count: store.currentCount,
                    prescription: item.prescription
                ),
                voiceOverActive: voiceOverActive
            )
            phrases += consumeVoiceEventPhrases(from: store)
            speak(phrases)
        }
    }

    func synchronize(store: WorkoutSessionStore) {
        let hasPendingTargetEvent = store.latestVoiceEvent.map {
            $0.sequence > deliveredVoiceEventSequence && $0.kind == .repetitionTargetReached
        } ?? false
        if store.phase == .exercise,
           !store.isPreparingFirstExercise,
           !store.isPaused,
           store.currentCount > lastCount,
           store.isManualCount || hasPendingTargetEvent,
           case .repetitionBased = store.currentItem.prescription {
            lastCount = store.currentCount
            var targetPhrases = scheduler.phrases(
                for: .repetitionCount(
                    index: store.currentIndex,
                    count: store.currentCount,
                    prescription: store.currentItem.prescription
                ),
                voiceOverActive: voiceOverActive
            )
            targetPhrases += consumeVoiceEventPhrases(from: store)
            speak(targetPhrases)
            return
        }
        var phrases = consumeVoiceEventPhrases(from: store)

        let phaseChanged = observedPhase != store.phase || observedIndex != store.currentIndex
        guard phaseChanged || !phrases.isEmpty else { return }
        if phaseChanged {
            cancelSpeech()
            observedPhase = store.phase
            observedIndex = store.currentIndex
        }

        switch store.phase {
        case .exercise:
            if phaseChanged {
                scheduler.resetForNewExercise()
                lastCount = 0
                phrases += scheduler.phrases(
                    for: .exerciseStarted(
                        index: store.currentIndex,
                        total: store.plan.items.count,
                        title: store.currentItem.exercise.title,
                        prescription: store.currentItem.prescription
                    ),
                    voiceOverActive: voiceOverActive
                )
            }
        case .rest:
            if phaseChanged {
                phrases += scheduler.phrases(
                    for: .restStarted(
                        index: store.currentIndex,
                        total: store.plan.items.count,
                        nextTitle: store.nextItem?.exercise.title
                    ),
                    voiceOverActive: voiceOverActive
                )
            }
        case .finished:
            if phaseChanged {
                stopMusic()
                phrases += scheduler.phrases(for: .workoutFinished, voiceOverActive: voiceOverActive)
            }
        }
        speak(phrases)
    }

    private func consumeVoiceEventPhrases(from store: WorkoutSessionStore) -> [CoachingPhrase] {
        guard let event = store.latestVoiceEvent,
              event.sequence > deliveredVoiceEventSequence else { return [] }
        deliveredVoiceEventSequence = event.sequence
        return scheduler.phrases(
            for: coachingEvent(for: event),
            voiceOverActive: voiceOverActive
        )
    }

    func setSessionMuted(_ muted: Bool) {
        sessionMuted = muted
        if muted {
            cancelSpeech()
            musicPlayer?.setVolume(0, fadeDuration: 0.15)
            musicController?.pause()
        } else {
            applyIdleMusicGain()
            musicPlayer?.play()
            musicController?.play()
        }
    }

    func pause() {
        cancelSpeech()
        pauseMusic()
    }

    func resume() {
        guard !sessionMuted else { return }
        if preferences.musicEnabled, musicPlayer == nil {
            prepareMusicIfNeeded()
        }
        applyIdleMusicGain()
        musicPlayer?.play()
        musicController?.play()
    }

    func stop() {
        cancelSpeech()
        stopMusic()
        musicPlayer = nil
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }

    func sceneDidBecomeInactive() {
        handleSafetyPause()
    }

    func handleInterruptionBegan() {
        handleSafetyPause()
    }

    func handleOldDeviceUnavailable() {
        handleSafetyPause()
    }

    func handleMediaServicesReset() {
        handleSafetyPause(resetMusic: true)
    }

    private func prepareMusicIfNeeded() {
        guard preferences.musicEnabled, !sessionMuted else { return }
        let preferred = preferences.currentMusicTrack
        let candidates = preferences.playbackCandidates()
        for track in candidates {
            guard let url = Bundle.main.url(
                forResource: track.resourceName,
                withExtension: track.fileExtension,
                subdirectory: "Audio"
            ), (try? WorkoutMusicResourceValidator.isValid(track: track, at: url)) == true else {
                continue
            }
            do {
                try audioSession.setCategory(.playback, mode: .default)
                try audioSession.setActive(true)
                let player = try AVAudioPlayer(contentsOf: url)
                player.numberOfLoops = -1
                player.prepareToPlay()
                musicPlayer = player
                applyIdleMusicGain()
                guard player.play() else {
                    musicPlayer = nil
                    continue
                }
                preferences.recordPlayedMusicTrack(track)
                activeMusicTrack = track
                statusText = track == preferred
                    ? nil
                    : "\(preferred.title) недоступен — играет \(track.title)"
                return
            } catch {
                musicPlayer = nil
            }
        }
        activeMusicTrack = nil
        statusText = "Звук тренировки недоступен"
    }

    private func canSpeak(_ phrases: [CoachingPhrase]) -> Bool {
        guard preferences.voiceCoachEnabled,
              !sessionMuted,
              !voiceOverActive,
              !phrases.isEmpty else { return false }
        if let speechController {
            return speechController.isAvailable
        }
        return AVSpeechSynthesisVoice(language: "ru-RU") != nil
    }

    private func speak(_ phrases: [CoachingPhrase], completion: (() -> Void)? = nil) {
        guard canSpeak(phrases) else {
            completion?()
            return
        }
        guard let incomingPriority = phrases.map(\.priority).max(by: { $0.rawValue < $1.rawValue }) else {
            completion?()
            return
        }
        let isSpeaking = speechController?.isSpeaking ?? speechSynthesizer.isSpeaking
        if isSpeaking, let activeSpeechPriority {
            if incomingPriority.rawValue < activeSpeechPriority.rawValue {
                deferredSpeechPhrases = phrases
                return
            }
            deferredSpeechPhrases.removeAll()
            stopSpeech()
        }
        speechActivitySequence += 1
        let activitySequence = speechActivitySequence
        activeSpeechPriority = incomingPriority
        if let speechController {
            speechController.speak(phrases.map(\.text)) { [weak self] in
                self?.speechControllerDidFinish(
                    activitySequence: activitySequence,
                    completion: completion
                )
            }
            return
        }
        guard let voice = AVSpeechSynthesisVoice(language: "ru-RU") else {
            statusText = "Звук тренировки недоступен"
            completion?()
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
            completion?()
            return
        }
        musicPlayer?.setVolume(
            MusicGainPolicy.outputGain(volume: preferences.musicVolume, state: .coachingSpeech),
            fadeDuration: 0.15
        )
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .word)
        }
        if completion != nil {
            pendingOpeningUtterances = phrases.count
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
        speechActivitySequence += 1
        deferredSpeechPhrases.removeAll()
        stopSpeech()
        finishOpeningPreRoll(cancelSpeech: false)
        deactivateSpeechOnlySessionIfNeeded()
        applyIdleMusicGain()
    }

    private func stopSpeech() {
        if let speechController {
            speechController.stop()
        } else if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        pendingOpeningUtterances = 0
        activeSpeechPriority = nil
    }

    private func speechControllerDidFinish(
        activitySequence: Int,
        completion: (() -> Void)?
    ) {
        guard activitySequence == speechActivitySequence else { return }
        activeSpeechPriority = nil
        completion?()
        speakDeferredPhrasesIfNeeded()
    }

    private func speakDeferredPhrasesIfNeeded() {
        guard !deferredSpeechPhrases.isEmpty else { return }
        let phrases = deferredSpeechPhrases
        deferredSpeechPhrases.removeAll()
        speak(phrases)
    }

    private func finishOpeningPreRoll(cancelSpeech: Bool) {
        guard let completion = openingCompletion else { return }
        openingCompletion = nil
        cancelOpeningWatchdog?()
        cancelOpeningWatchdog = nil
        if cancelSpeech { stopSpeech() }
        completion()
    }

    private func deactivateSpeechOnlySessionIfNeeded() {
        let isSpeaking = speechController?.isSpeaking ?? speechSynthesizer.isSpeaking
        guard speechOnlySessionActive, !isSpeaking else { return }
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

    private func coachingEvent(for event: WorkoutSessionStore.VoiceEvent) -> CoachingEvent {
        switch event.kind {
        case .manualCountStarted:
            return .manualCountStarted(index: event.exerciseIndex)
        case .repetitionTargetReached:
            return .repetitionTargetReached(index: event.exerciseIndex)
        case .setConfirmed:
            return .setConfirmed(index: event.exerciseIndex)
        case .completedEarly:
            return .completedEarly(index: event.exerciseIndex)
        case .skipped:
            return .exerciseSkipped(index: event.exerciseIndex)
        }
    }

    private func pauseMusic() {
        musicPlayer?.pause()
        musicController?.pause()
    }

    private func stopMusic() {
        musicPlayer?.stop()
        musicController?.stop()
        activeMusicTrack = nil
    }

    static func liveWatchdog(
        delay: TimeInterval,
        action: @escaping @MainActor () -> Void
    ) -> () -> Void {
        let task = Task { @MainActor in
            let nanoseconds = UInt64(max(0, delay) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            action()
        }
        return { task.cancel() }
    }

    private func installObservers() {
        let center = notificationCenter
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
            Task { @MainActor in self?.handleInterruptionBegan() }
        })
        observerTokens.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] notification in
            guard let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
            Task { @MainActor in self?.handleOldDeviceUnavailable() }
        })
        observerTokens.append(center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleMediaServicesReset() }
        })
    }

    private func voiceOverChanged() {
        voiceOverActive = UIAccessibility.isVoiceOverRunning
        if voiceOverActive { cancelSpeech() }
        applyIdleMusicGain()
    }

    private func handleSafetyPause(resetMusic: Bool = false) {
        onSafetyPause?()
        cancelSpeech()
        pauseMusic()
        if resetMusic {
            musicPlayer = nil
            activeMusicTrack = nil
            musicController?.reset()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let completedActivitySequence = speechActivitySequence
            if pendingOpeningUtterances > 0 {
                pendingOpeningUtterances -= 1
                if pendingOpeningUtterances == 0 {
                    finishOpeningPreRoll(cancelSpeech: false)
                }
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard completedActivitySequence == speechActivitySequence,
                  !speechSynthesizer.isSpeaking else { return }
            activeSpeechPriority = nil
            deactivateSpeechOnlySessionIfNeeded()
            applyIdleMusicGain()
            speakDeferredPhrasesIfNeeded()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            self?.finishOpeningPreRoll(cancelSpeech: false)
        }
    }
}
