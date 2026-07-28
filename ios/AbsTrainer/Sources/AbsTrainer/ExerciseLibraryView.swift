import AVFoundation
import CoreImage
import SwiftUI
import UIKit

struct ExerciseVideoFrameCover: Equatable {
    private(set) var isVisible = true
    private(set) var hasPresentedFrame = false

    mutating func awaitNextFrame() {
        isVisible = true
    }

    mutating func recordPresentedFrame() {
        isVisible = false
        hasPresentedFrame = true
    }
}

final class ExerciseVideoPlayback: NSObject, ObservableObject {
    enum State: Equatable {
        case poster
        case loading
        case ready
        case playing
        case failed
    }

    @Published private(set) var state: State = .poster
    @Published private(set) var frameCover = ExerciseVideoFrameCover()
#if DEBUG
    @Published private(set) var completedLoopCount = 0
    @Published private(set) var currentPositionMilliseconds = 0
    @Published private(set) var posterPresentationMilliseconds: Int?
    @Published private(set) var videoStartMilliseconds: Int?
    @Published private(set) var firstLoopMilliseconds: Int?
    @Published private(set) var interruptionCount = 0
    @Published private(set) var observedStateNames = ["poster"]
    @Published private(set) var observedFrameCoverNames = ["poster"]
#endif
    let player = AVQueuePlayer()

    private var looper: AVPlayerLooper?
    private var timeControlObservation: NSKeyValueObservation?
    private var currentItemObservation: NSKeyValueObservation?
    private var itemStatusObservation: NSKeyValueObservation?
    private var playbackFailureObserver: NSObjectProtocol?
#if DEBUG
    private var playbackCompletionObserver: NSObjectProtocol?
#endif
    private var periodicTimeObserver: Any?
#if DEBUG
    private var presentationStartedAt: TimeInterval?
    private var posterPresentedBeforeOrigin = false
#endif
    private var ownedItems: [AVPlayerItem] = []
    private var isPlaybackAllowed = false

    override init() {
        super.init()
        player.isMuted = true
        player.actionAtItemEnd = .none
    }

    func load(url: URL) {
        guard looper == nil else {
            play()
            return
        }
        awaitNextVideoFrame()
        transition(to: .loading)
        let item = AVPlayerItem(url: url)
        looper = AVPlayerLooper(player: player, templateItem: item)
        currentItemObservation = player.observe(\.currentItem, options: [.initial, .new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                guard let self, self.looper != nil else { return }
                self.observeStatus(of: player.currentItem)
            }
        }
        timeControlObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                guard let self, self.looper != nil else { return }
                switch player.timeControlStatus {
                case .playing:
                    if self.state == .loading, player.currentItem?.status == .readyToPlay {
                        self.transition(to: .ready)
                    }
                    self.recordPlaybackProgress(player.currentTime())
                case .paused, .waitingToPlayAtSpecifiedRate:
                    if self.state == .playing {
                        self.transition(to: .ready)
                    }
                default:
                    break
                }
            }
        }
        playbackFailureObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  self.looper != nil,
                  let failedItem = notification.object as? AVPlayerItem,
                  self.owns(failedItem) else { return }
            self.fail()
        }
#if DEBUG
        playbackCompletionObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  self.looper != nil,
                  let completedItem = notification.object as? AVPlayerItem,
                  self.owns(completedItem) else { return }
            let durationSeconds = CMTimeGetSeconds(completedItem.duration)
            if self.firstLoopMilliseconds == nil, durationSeconds.isFinite, durationSeconds > 0 {
                self.firstLoopMilliseconds = Int((durationSeconds * 1_000).rounded())
            }
            self.completedLoopCount += 1
            self.ownedItems.removeAll { $0 === completedItem }
        }
#endif
        periodicTimeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 30),
            queue: .main
        ) { [weak self] time in
            self?.recordPlaybackProgress(time)
        }
        play()
    }

    func play() {
        guard looper != nil, isPlaybackAllowed else { return }
        player.play()
    }

    func setPlaybackAllowed(_ isAllowed: Bool) {
        isPlaybackAllowed = isAllowed
        if isAllowed {
            play()
        } else {
            pause()
        }
    }

    func pause() {
        player.pause()
        if state == .playing {
            transition(to: .ready)
        }
    }

    func awaitNextVideoFrame() {
        guard !frameCover.isVisible else { return }
        frameCover.awaitNextFrame()
#if DEBUG
        observedFrameCoverNames.append("poster")
#endif
    }

    func recordPresentedVideoFrame() {
        guard frameCover.isVisible else { return }
        frameCover.recordPresentedFrame()
#if DEBUG
        observedFrameCoverNames.append("video")
#endif
    }

#if DEBUG
    func beginPresentation() {
        guard presentationStartedAt == nil else { return }
        presentationStartedAt = ProcessInfo.processInfo.systemUptime
        if posterPresentedBeforeOrigin, posterPresentationMilliseconds == nil {
            posterPresentationMilliseconds = 0
        }
    }

    func recordPosterPresentation() {
        guard posterPresentationMilliseconds == nil else { return }
        guard let presentationStartedAt else {
            posterPresentedBeforeOrigin = true
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        posterPresentationMilliseconds = Int(
            ((now - presentationStartedAt) * 1_000).rounded()
        )
    }
#endif

    func tearDown() {
        cleanUp(resetProbe: true)
        state = .poster
    }

    func fail() {
        awaitNextVideoFrame()
        cleanUp(resetProbe: false)
        transition(to: .failed)
    }

    private func cleanUp(resetProbe: Bool) {
        isPlaybackAllowed = false
        player.pause()
        timeControlObservation = nil
        currentItemObservation = nil
        itemStatusObservation = nil
        if let playbackFailureObserver {
            NotificationCenter.default.removeObserver(playbackFailureObserver)
            self.playbackFailureObserver = nil
        }
#if DEBUG
        if let playbackCompletionObserver {
            NotificationCenter.default.removeObserver(playbackCompletionObserver)
            self.playbackCompletionObserver = nil
        }
#endif
        if let periodicTimeObserver {
            player.removeTimeObserver(periodicTimeObserver)
            self.periodicTimeObserver = nil
        }
        looper?.disableLooping()
        looper = nil
        player.removeAllItems()
        ownedItems.removeAll()
#if DEBUG
        if resetProbe {
            presentationStartedAt = nil
            posterPresentedBeforeOrigin = false
            completedLoopCount = 0
            currentPositionMilliseconds = 0
            posterPresentationMilliseconds = nil
            videoStartMilliseconds = nil
            firstLoopMilliseconds = nil
            interruptionCount = 0
            observedStateNames = ["poster"]
            observedFrameCoverNames = ["poster"]
        }
#endif
        if resetProbe {
            frameCover = ExerciseVideoFrameCover()
        }
    }

    private func observeStatus(of item: AVPlayerItem?) {
        itemStatusObservation = nil
        guard let item else { return }
        if !owns(item) {
            ownedItems.append(item)
            if ownedItems.count > 2 {
                ownedItems.removeFirst(ownedItems.count - 2)
            }
        }
        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self,
                      self.looper != nil,
                      self.player.currentItem === item else { return }
                switch item.status {
                case .readyToPlay:
                    if self.state != .playing {
                        self.transition(to: .ready)
                    }
                    self.play()
                case .failed:
                    self.fail()
                default:
                    break
                }
            }
        }
    }

    private func owns(_ item: AVPlayerItem) -> Bool {
        ownedItems.contains { $0 === item }
    }

    private func recordPlaybackProgress(_ time: CMTime) {
        guard looper != nil else { return }
        let seconds = CMTimeGetSeconds(time)
        guard seconds.isFinite, seconds >= 0 else { return }
        let positionMilliseconds = Int((seconds * 1_000).rounded())

#if DEBUG
        currentPositionMilliseconds = positionMilliseconds
#endif

        guard player.timeControlStatus == .playing, positionMilliseconds > 0 else { return }
        if state == .loading {
            guard player.currentItem?.status == .readyToPlay else { return }
            transition(to: .ready)
        }
        transition(to: .playing)
#if DEBUG
        if videoStartMilliseconds == nil, let presentationStartedAt {
            videoStartMilliseconds = Int(
                ((ProcessInfo.processInfo.systemUptime - presentationStartedAt) * 1_000).rounded()
            )
        }
#endif
    }

    private func transition(to newState: State) {
        guard state != newState else { return }
#if DEBUG
        if state == .playing, newState == .loading || newState == .ready || newState == .failed {
            interruptionCount += 1
        }
        let stateName: String
        switch newState {
        case .poster: stateName = "poster"
        case .loading: stateName = "loading"
        case .ready: stateName = "ready"
        case .playing: stateName = "playing"
        case .failed: stateName = "failed"
        }
        if observedStateNames.last != stateName {
            observedStateNames.append(stateName)
        }
#endif
        state = newState
    }
}

struct ExerciseLibraryView: View {
    let onSelect: (String) -> Void

    @State private var filter = ExerciseLibraryFilter.default
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var contrast

    private var exercises: [Exercise] {
        filter.apply(to: ExerciseMediaRepository.availableExercises())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TempoTokens.Space.lg) {
                filterControls

                HStack(alignment: .firstTextBaseline) {
                    Text(resultCountTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TempoTokens.ColorToken.carbon)
                        .accessibilityIdentifier("exerciseLibrary.resultCount")
                    Spacer()
                    if filter != .default {
                        Button("Сбросить") { resetFilters() }
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: TempoTokens.Size.minimumTap)
                            .accessibilityIdentifier("exerciseLibrary.reset")
                    }
                }

                if ExerciseMediaRepository.availableExercises().isEmpty {
                    catalogUnavailable
                } else if exercises.isEmpty {
                    noResults
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(exercises) { exercise in
                            ExerciseLibraryRow(exercise: exercise) {
                                onSelect(exercise.id)
                            }
                            Divider()
                                .overlay(TempoTokens.ColorToken.carbon.opacity(contrast == .increased ? 0.42 : 0.16))
                        }
                    }
                }
            }
            .padding(.horizontal, TempoTokens.Space.outer)
            .padding(.vertical, TempoTokens.Space.lg)
        }
        .background(TempoTokens.ColorToken.chalk.ignoresSafeArea())
        .navigationTitle("Упражнения")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $filter.query, prompt: "Найти упражнение")
        .accessibilityIdentifier("exerciseLibrary.screen")
    }

    private var filterControls: some View {
        VStack(alignment: .leading, spacing: TempoTokens.Space.md) {
            filterGroup(title: "Фильтр по зоне") {
                FilterChip(title: "Все зоны", isSelected: filter.zone == nil, identifier: "exerciseLibrary.zone.all") {
                    selectZone(nil)
                }
                ForEach(AbsZone.allCases) { zone in
                    FilterChip(
                        title: zone.title,
                        isSelected: filter.zone == zone,
                        identifier: "exerciseLibrary.zone.\(zone.rawValue)"
                    ) {
                        selectZone(zone)
                    }
                }
            }

            filterGroup(title: "Фильтр по сложности") {
                FilterChip(
                    title: "Любая сложность",
                    isSelected: filter.difficulty == nil,
                    identifier: "exerciseLibrary.difficulty.any"
                ) {
                    selectDifficulty(nil)
                }
                ForEach([Difficulty.beginner, .intermediate]) { difficulty in
                    FilterChip(
                        title: difficulty.title,
                        isSelected: filter.difficulty == difficulty,
                        identifier: "exerciseLibrary.difficulty.\(difficulty.rawValue)"
                    ) {
                        selectDifficulty(difficulty)
                    }
                }
            }
        }
    }

    private func filterGroup<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: TempoTokens.Space.xs) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(TempoTokens.ColorToken.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TempoTokens.Space.xs) { content() }
                    .padding(.vertical, 1)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private var noResults: some View {
        ExerciseLibraryEmptyState(
            symbol: "magnifyingglass",
            title: "Ничего не найдено",
            message: "Попробуйте изменить поиск или фильтры.",
            buttonTitle: "Сбросить фильтры",
            identifier: "exerciseLibrary.noResults",
            action: resetFilters
        )
    }

    private var catalogUnavailable: some View {
        ExerciseLibraryEmptyState(
            symbol: "exclamationmark.circle",
            title: "Каталог пока недоступен",
            message: "Локальные материалы не прошли проверку.",
            buttonTitle: "Назад к настройке",
            identifier: "exerciseLibrary.catalogUnavailable",
            action: { dismiss() }
        )
    }

    private var resultCountTitle: String {
        let count = exercises.count
        let remainder10 = count % 10
        let remainder100 = count % 100
        let noun: String
        if remainder10 == 1, remainder100 != 11 {
            noun = "упражнение"
        } else if (2...4).contains(remainder10), !(12...14).contains(remainder100) {
            noun = "упражнения"
        } else {
            noun = "упражнений"
        }
        return "\(count) \(noun)"
    }

    private func resetFilters() {
        filter.reset()
        UIAccessibility.post(notification: .announcement, argument: "Фильтры сброшены. \(resultCountTitle)")
    }

    private func selectZone(_ zone: AbsZone?) {
        filter.zone = zone
        announceFilterResult()
    }

    private func selectDifficulty(_ difficulty: Difficulty?) {
        filter.difficulty = difficulty
        announceFilterResult()
    }

    private func announceFilterResult() {
        UIAccessibility.post(notification: .announcement, argument: resultCountTitle)
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let identifier: String
    let action: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? TempoTokens.ColorToken.chalk : TempoTokens.ColorToken.carbon)
                .padding(.horizontal, TempoTokens.Space.md)
                .frame(minHeight: TempoTokens.Size.minimumTap)
                .background(isSelected ? TempoTokens.ColorToken.carbon : TempoTokens.ColorToken.chalkSubtle)
                .overlay {
                    Capsule().stroke(
                        TempoTokens.ColorToken.carbon.opacity(contrast == .increased ? 0.9 : 0.22),
                        lineWidth: contrast == .increased ? 2 : 1
                    )
                }
                .clipShape(Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ExerciseLibraryRow: View {
    let exercise: Exercise
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: TempoTokens.Space.md) {
                ExercisePoster(exercise: exercise)
                    .frame(width: dynamicTypeSize.isAccessibilitySize ? 96 : 84)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: TempoTokens.Space.xs) {
                    Text(exercise.title)
                        .font(.headline)
                        .foregroundStyle(TempoTokens.ColorToken.carbon)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(metadata)
                        .font(dynamicTypeSize.isAccessibilitySize ? .body : .caption.weight(.semibold))
                        .foregroundStyle(TempoTokens.ColorToken.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TempoTokens.ColorToken.muted)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, TempoTokens.Space.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Открывает описание и демонстрацию")
        .accessibilityIdentifier("exerciseLibrary.row.\(exercise.id)")
    }

    private var metadata: String {
        "\(exercise.zones.map(\.title).joined(separator: " · ")) · \(exercise.difficulty.title) · \(exercise.defaultDurationSec) сек"
    }

    private var accessibilityLabel: String {
        "\(exercise.title), \(exercise.zones.map(\.title).joined(separator: ", ")), \(exercise.difficulty.title.lowercased()) уровень, \(exercise.defaultDurationSec) секунд"
    }
}

private struct ExerciseLibraryEmptyState: View {
    let symbol: String
    let title: String
    let message: String
    let buttonTitle: String?
    let identifier: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: TempoTokens.Space.md) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .semibold))
                .accessibilityHidden(true)
            Text(title)
                .font(.title3.weight(.bold))
            Text(message)
                .font(.body)
                .foregroundStyle(TempoTokens.ColorToken.muted)
                .multilineTextAlignment(.center)
            if let buttonTitle {
                Button(buttonTitle, action: action)
                    .font(.headline)
                    .frame(minHeight: TempoTokens.Size.minimumTap)
            }
        }
        .foregroundStyle(TempoTokens.ColorToken.carbon)
        .frame(maxWidth: .infinity)
        .padding(.vertical, TempoTokens.Space.huge)
        .accessibilityIdentifier(identifier)
    }
}

struct ExerciseDetailView: View {
    let exercise: Exercise

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var content: ExerciseLibraryContent? {
        ExerciseLibraryContentCatalog.byID[exercise.id]
    }

    var body: some View {
        ScrollView {
            Group {
                if let content {
                    if verticalSizeClass == .compact, !dynamicTypeSize.isAccessibilitySize {
                        HStack(alignment: .top, spacing: TempoTokens.Space.xl) {
                            ExerciseMotionAperture(exercise: exercise)
                                .frame(maxWidth: 330)
                            detailText(content)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: TempoTokens.Space.xl) {
                            ExerciseMotionAperture(exercise: exercise)
                            detailText(content)
                        }
                    }
                } else {
                    ExerciseLibraryEmptyState(
                        symbol: "exclamationmark.circle",
                        title: "Описание недоступно",
                        message: "Вернитесь в каталог и выберите другое упражнение.",
                        buttonTitle: nil,
                        identifier: "exerciseDetail.contentUnavailable",
                        action: {}
                    )
                }
            }
            .padding(TempoTokens.Space.outer)
        }
        .background(TempoTokens.ColorToken.chalk.ignoresSafeArea())
        .navigationTitle(exercise.title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("exerciseDetail.screen.\(exercise.id)")
    }

    private func detailText(_ content: ExerciseLibraryContent) -> some View {
        VStack(alignment: .leading, spacing: TempoTokens.Space.xl) {
            VStack(alignment: .leading, spacing: TempoTokens.Space.sm) {
                Text(exercise.title)
                    .font(.title.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("exerciseDetail.title")
                Text("\(exercise.zones.map(\.title).joined(separator: " · ")) · \(exercise.difficulty.title)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TempoTokens.ColorToken.muted)
                    .accessibilityIdentifier("exerciseDetail.metadata")
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: TempoTokens.Space.xs) { timingLabels }
                    VStack(alignment: .leading, spacing: TempoTokens.Space.xs) { timingLabels }
                }
            }

            orderedSection(title: "Как выполнять", items: content.phases, identifier: "exerciseDetail.phases")
            orderedSection(title: "Обратите внимание", items: content.cues, identifier: "exerciseDetail.cues")

            Text(ExerciseLibraryContentCatalog.disclaimer)
                .font(.footnote)
                .foregroundStyle(TempoTokens.ColorToken.muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("exerciseDetail.disclaimer")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var timingLabels: some View {
        metadataPill("Работа · \(exercise.defaultDurationSec) сек", color: TempoTokens.ColorToken.vermilion)
        metadataPill("Отдых · \(exercise.restAfterSec) сек", color: TempoTokens.ColorToken.ultramarine)
    }

    private func metadataPill(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(TempoTokens.ColorToken.carbon)
            .padding(.horizontal, TempoTokens.Space.sm)
            .frame(minHeight: TempoTokens.Size.minimumTap)
            .overlay(alignment: .leading) {
                Rectangle().fill(color).frame(width: 4)
            }
            .background(TempoTokens.ColorToken.chalkSubtle)
    }

    private func orderedSection(title: String, items: [String], identifier: String) -> some View {
        VStack(alignment: .leading, spacing: TempoTokens.Space.md) {
            Text(title)
                .font(.title3.bold())
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: TempoTokens.Space.sm) {
                    Text("\(index + 1)")
                        .font(.headline)
                        .frame(width: 28, height: 28)
                        .background(TempoTokens.ColorToken.carbon)
                        .foregroundStyle(TempoTokens.ColorToken.chalk)
                        .clipShape(Circle())
                        .accessibilityHidden(true)
                    Text(item)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Шаг \(index + 1). \(item)")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}

private struct ExerciseMotionAperture: View {
    let exercise: Exercise

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var playback = ExerciseVideoPlayback()

    private var forceFailure: Bool {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-ValidationMode") && arguments.contains("-ExerciseMediaFailure")
#else
        return false
#endif
    }

    private var posterIsAvailable: Bool {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let forcePosterFailure = arguments.contains("-ValidationMode")
            && arguments.contains("-ExercisePosterFailure")
        return !forcePosterFailure && ExerciseMediaRepository.posterURL(for: exercise) != nil
#else
        return ExerciseMediaRepository.posterURL(for: exercise) != nil
#endif
    }

    private var posterImage: UIImage? {
        guard posterIsAvailable, let url = ExerciseMediaRepository.posterURL(for: exercise) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    private var validationReduceMotion: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-ValidationMode"),
              let index = arguments.firstIndex(of: "-ValidationReduceMotion"),
              arguments.indices.contains(index + 1) else { return false }
        return arguments[index + 1].caseInsensitiveCompare("YES") == .orderedSame
        #else
        return false
        #endif
    }

    private var validationMode: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-ValidationMode")
        #else
        false
        #endif
    }

    private var staticMode: Bool {
        reduceMotion || validationReduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if playback.state != .poster, playback.state != .failed, !staticMode, !forceFailure {
                ExercisePlayerSurface(
                    player: playback.player,
                    posterImage: posterImage,
                    onAwaitingFrame: playback.awaitNextVideoFrame,
                    onPresentedFrame: playback.recordPresentedVideoFrame
                )
                .allowsHitTesting(false)
            }

            if staticMode
                || forceFailure
                || playback.state == .failed
                || playback.state == .poster
                || (!posterIsAvailable && !playback.frameCover.hasPresentedFrame) {
#if DEBUG
                ExercisePoster(exercise: exercise, onPresented: playback.recordPosterPresentation)
#else
                ExercisePoster(exercise: exercise)
#endif
            }

            if (playback.state == .loading || playback.state == .ready), !staticMode, !forceFailure {
                ProgressView()
                    .padding(TempoTokens.Space.sm)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(TempoTokens.Space.md)
                    .accessibilityLabel("Загрузка демонстрации")
            }

            if staticMode || forceFailure || playback.state == .failed {
                Text(staticMode ? "Статичная демонстрация" : "Анимация недоступна")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, TempoTokens.Space.sm)
                    .frame(minHeight: TempoTokens.Size.minimumTap)
                    .background(TempoTokens.ColorToken.chalk.opacity(0.94), in: Capsule())
                    .padding(TempoTokens.Space.md)
                    .accessibilityIdentifier(staticMode ? "exerciseDetail.staticPoster" : "exerciseDetail.videoFallback")
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .background(TempoTokens.ColorToken.chalkSubtle)
        .clipShape(RoundedRectangle(cornerRadius: TempoTokens.Radius.media, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Демонстрация упражнения «\(exercise.title)»")
        .accessibilityValue(motionAccessibilityValue)
        .accessibilityIdentifier("exerciseDetail.motion")
        .overlay(alignment: .topLeading) {
            validationPlaybackProbe
        }
        .onAppear {
#if DEBUG
            playback.beginPresentation()
#endif
            startIfNeeded()
        }
        .onDisappear { playback.tearDown() }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                startIfNeeded()
            } else {
                playback.setPlaybackAllowed(false)
            }
        }
        .onChange(of: reduceMotion) { _ in startIfNeeded() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            playback.tearDown()
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in
            playback.setPlaybackAllowed(false)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.NSProcessInfoPowerStateDidChange)) { _ in
            startIfNeeded()
        }
    }

    private func startIfNeeded() {
        guard !staticMode, scenePhase == .active else {
            playback.setPlaybackAllowed(false)
            return
        }
        guard !forceFailure, let url = ExerciseMediaRepository.videoURL(for: exercise) else {
            playback.fail()
            return
        }
        playback.setPlaybackAllowed(true)
        playback.load(url: url)
    }

    private var motionAccessibilityValue: String {
        if staticMode { return "Статичная демонстрация" }
        if forceFailure || playback.state == .failed {
            return posterIsAvailable
                ? "Анимация недоступна"
                : "Анимация недоступна, показана резервная иллюстрация"
        }
        return "Анимация"
    }

#if DEBUG
    @ViewBuilder
    private var validationPlaybackProbe: some View {
        if validationMode {
            Text(validationPlaybackValue)
                .font(.system(size: 1))
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("validation.exercisePlayback")
                .accessibilityLabel("Validation exercise playback")
                .accessibilityValue(validationPlaybackValue)
        }
    }

    private var validationPlaybackValue: String {
        let stateName: String
        switch playback.state {
        case .poster: stateName = "poster"
        case .loading: stateName = "loading"
        case .ready: stateName = "ready"
        case .playing: stateName = "playing"
        case .failed: stateName = "failed"
        }
        let coverName = playback.frameCover.isVisible ? "poster" : "video"
        return "state=\(stateName);states=\(playback.observedStateNames.joined(separator: ","));cover=\(coverName);covers=\(playback.observedFrameCoverNames.joined(separator: ","));loops=\(playback.completedLoopCount);posterMs=\(playback.posterPresentationMilliseconds ?? -1);videoMs=\(playback.videoStartMilliseconds ?? -1);firstLoopMs=\(playback.firstLoopMilliseconds ?? -1);interruptions=\(playback.interruptionCount);positionMs=\(playback.currentPositionMilliseconds);"
    }
#else
    @ViewBuilder
    private var validationPlaybackProbe: some View { EmptyView() }
#endif
}

private struct ExercisePlayerSurface: UIViewRepresentable {
    let player: AVQueuePlayer
    let posterImage: UIImage?
    let onAwaitingFrame: () -> Void
    let onPresentedFrame: () -> Void

    func makeUIView(context: Context) -> ExercisePlayerSurfaceView {
        let view = ExercisePlayerSurfaceView()
        view.configure(
            player: player,
            posterImage: posterImage,
            onAwaitingFrame: onAwaitingFrame,
            onPresentedFrame: onPresentedFrame
        )
        return view
    }

    func updateUIView(_ view: ExercisePlayerSurfaceView, context: Context) {
        view.configure(
            player: player,
            posterImage: posterImage,
            onAwaitingFrame: onAwaitingFrame,
            onPresentedFrame: onPresentedFrame
        )
    }

    static func dismantleUIView(_ view: ExercisePlayerSurfaceView, coordinator: ()) {
        view.stopObserving()
    }
}

private final class ExercisePlayerSurfaceView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    private weak var configuredPlayer: AVQueuePlayer?
    private weak var observedItem: AVPlayerItem?
    private var currentItemObservation: NSKeyValueObservation?
    private var periodicTimeObserver: Any?
    private var videoOutput: AVPlayerItemVideoOutput?
    private let coverImageView = UIImageView()
    private let imageContext = CIContext(options: [.cacheIntermediates: false])
    private var observationGeneration = 0
    private var onAwaitingFrame: (() -> Void)?
    private var onPresentedFrame: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        playerLayer.backgroundColor = UIColor.clear.cgColor
        playerLayer.isOpaque = false
        playerLayer.videoGravity = .resizeAspect
        coverImageView.contentMode = .scaleAspectFit
        coverImageView.isUserInteractionEnabled = false
        addSubview(coverImageView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        coverImageView.frame = bounds
    }

    func configure(
        player: AVQueuePlayer,
        posterImage: UIImage?,
        onAwaitingFrame: @escaping () -> Void,
        onPresentedFrame: @escaping () -> Void
    ) {
        self.onAwaitingFrame = onAwaitingFrame
        self.onPresentedFrame = onPresentedFrame
        if coverImageView.image == nil {
            coverImageView.image = posterImage
        }
        guard configuredPlayer !== player else { return }

        stopObserving()
        configuredPlayer = player
        playerLayer.player = player
        showFrameCover()
        let generation = observationGeneration
        currentItemObservation = player.observe(\.currentItem, options: [.initial, .new]) { [weak self] player, _ in
            let update = { [weak self, weak player] in
                guard let self,
                      let player,
                      self.observationGeneration == generation,
                      self.configuredPlayer === player else { return }
                self.observeFrames(from: player.currentItem)
            }
            if Thread.isMainThread {
                update()
            } else {
                DispatchQueue.main.async(execute: update)
            }
        }
        periodicTimeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 60),
            queue: .main
        ) { [weak self] time in
            self?.recordFrameIfAvailable(at: time)
        }
    }

    func stopObserving() {
        observationGeneration += 1
        currentItemObservation = nil
        if let periodicTimeObserver, let configuredPlayer {
            configuredPlayer.removeTimeObserver(periodicTimeObserver)
        }
        periodicTimeObserver = nil
        detachVideoOutput()
        configuredPlayer = nil
        playerLayer.player = nil
    }

    private func observeFrames(from item: AVPlayerItem?) {
        detachVideoOutput()
        showFrameCover()
        guard let item else { return }

        let output = AVPlayerItemVideoOutput(
            pixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
        )
        item.add(output)
        observedItem = item
        videoOutput = output
        recordFrameIfAvailable(at: item.currentTime())
    }

    private func recordFrameIfAvailable(at currentTime: CMTime) {
        guard let videoOutput, let observedItem else { return }
        guard observedItem === configuredPlayer?.currentItem else {
            showFrameCover()
            return
        }
        let durationSeconds = CMTimeGetSeconds(observedItem.duration)
        let currentSeconds = CMTimeGetSeconds(currentTime)
        let remainingSeconds = durationSeconds - currentSeconds
        let shouldCoverSeam = durationSeconds.isFinite
            && currentSeconds.isFinite
            && remainingSeconds > 0
            && remainingSeconds <= 0.1
        if shouldCoverSeam {
            showFrameCover()
        }
        let itemTime = videoOutput.itemTime(forHostTime: CACurrentMediaTime())
        guard itemTime.isValid else { return }
        var displayTime = CMTime.invalid
        guard let pixelBuffer = videoOutput.copyPixelBuffer(
            forItemTime: itemTime,
            itemTimeForDisplay: &displayTime
        ) else { return }

        if durationSeconds.isFinite,
           currentSeconds.isFinite,
           remainingSeconds > 0,
           remainingSeconds <= 0.25 {
            let image = CIImage(cvPixelBuffer: pixelBuffer)
            if let cgImage = imageContext.createCGImage(image, from: image.extent) {
                coverImageView.image = UIImage(cgImage: cgImage)
            }
        }
        if shouldCoverSeam {
            return
        }
        coverImageView.isHidden = true
        onPresentedFrame?()
    }

    private func showFrameCover() {
        coverImageView.isHidden = false
        onAwaitingFrame?()
    }

    private func detachVideoOutput() {
        if let observedItem, let videoOutput {
            observedItem.remove(videoOutput)
        }
        observedItem = nil
        videoOutput = nil
    }
}

private struct ExercisePoster: View {
    let exercise: Exercise
#if DEBUG
    var onPresented: (() -> Void)? = nil
#endif

    private var forceFailure: Bool {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-ValidationMode") && arguments.contains("-ExercisePosterFailure")
#else
        return false
#endif
    }

    private var image: UIImage? {
        guard !forceFailure, let url = ExerciseMediaRepository.posterURL(for: exercise) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                VStack(spacing: TempoTokens.Space.xs) {
                    Image(systemName: "figure.core.training")
                        .font(.system(size: 30, weight: .semibold))
                    Text(exercise.title)
                        .font(.caption.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    if let cue = ExerciseLibraryContentCatalog.byID[exercise.id]?.cues.first {
                        Text(cue)
                            .font(.caption2)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                }
                .foregroundStyle(TempoTokens.ColorToken.carbon)
                .padding(TempoTokens.Space.xs)
                .accessibilityIdentifier("exercisePoster.fallback.\(exercise.id)")
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .background(TempoTokens.ColorToken.chalkSubtle)
        .clipShape(RoundedRectangle(cornerRadius: TempoTokens.Radius.small, style: .continuous))
        .onAppear {
#if DEBUG
            onPresented?()
#endif
        }
    }
}
