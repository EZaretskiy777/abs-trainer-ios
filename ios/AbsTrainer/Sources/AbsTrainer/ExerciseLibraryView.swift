import AVFoundation
import AVKit
import SwiftUI
import UIKit

final class ExerciseVideoPlayback: NSObject, ObservableObject {
    enum State: Equatable {
        case poster
        case loading
        case playing
        case failed
    }

    @Published private(set) var state: State = .poster
    let player = AVQueuePlayer()

    private var looper: AVPlayerLooper?
    private var statusObservation: NSKeyValueObservation?
    private var playbackFailureObserver: NSObjectProtocol?
    private var activeItem: AVPlayerItem?
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
        state = .loading
        let item = AVPlayerItem(url: url)
        activeItem = item
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self, self.activeItem === item else { return }
                switch item.status {
                case .readyToPlay:
                    self.state = .playing
                    if self.isPlaybackAllowed {
                        self.player.play()
                    } else {
                        self.player.pause()
                    }
                case .failed:
                    self.fail()
                default:
                    break
                }
            }
        }
        looper = AVPlayerLooper(player: player, templateItem: item)
        playbackFailureObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.looper != nil else { return }
            self.fail()
        }
    }

    func play() {
        guard state == .playing, isPlaybackAllowed else { return }
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
    }

    func tearDown() {
        isPlaybackAllowed = false
        player.pause()
        statusObservation = nil
        if let playbackFailureObserver {
            NotificationCenter.default.removeObserver(playbackFailureObserver)
            self.playbackFailureObserver = nil
        }
        activeItem = nil
        looper?.disableLooping()
        looper = nil
        player.removeAllItems()
        state = .poster
    }

    func fail() {
        tearDown()
        state = .failed
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
        .accessibilityElement(children: .ignore)
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
        ProcessInfo.processInfo.arguments.contains("-ExerciseMediaFailure")
    }

    private var posterIsAvailable: Bool {
        !ProcessInfo.processInfo.arguments.contains("-ExercisePosterFailure")
            && ExerciseMediaRepository.posterURL(for: exercise) != nil
    }

    private var staticMode: Bool {
        reduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ExercisePoster(exercise: exercise)
            if playback.state == .playing, !staticMode, !forceFailure {
                VideoPlayer(player: playback.player)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            if playback.state == .loading, !staticMode, !forceFailure {
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
        .onAppear(perform: startIfNeeded)
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
}

private struct ExercisePoster: View {
    let exercise: Exercise

    private var forceFailure: Bool {
        ProcessInfo.processInfo.arguments.contains("-ExercisePosterFailure")
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
    }
}
