import SwiftUI
import UIKit

struct ExercisePlayerView: View {
    private enum FocusElement: Hashable {
        case stateTitle
        case exitButton
        case pauseButton
        case audioButton
        case nextButton
        case pauseDialog
    }

    let plan: WorkoutPlan
    let onRepeat: () -> Void
    let onNewWorkout: () -> Void

    @StateObject private var store: WorkoutSessionStore
    @StateObject private var audioCoordinator: WorkoutAudioCoordinator
    @State private var confirmation: SessionConfirmationVariant?
    @State private var confirmationOpener: FocusElement?
    @State private var confirmationTransitioning = false
    @State private var lastAnnouncedSecond: Int?
    @State private var validationFocusProbe = "none"
    @State private var mediaUnavailable = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var accessibilityContrast
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .largeTitle) private var activeTimerSize = 68
    @ScaledMetric(relativeTo: .largeTitle) private var activeTitleSize = 30
    @ScaledMetric(relativeTo: .largeTitle) private var restTimerSize = 116
    @ScaledMetric(relativeTo: .largeTitle) private var restTitleSize = 48
    @AccessibilityFocusState private var focusedElement: FocusElement?

    private var validationMode: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-ValidationMode")
        #else
        false
        #endif
    }

    private var audioRuntimeProbe: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-AudioRuntimeProbe")
        #else
        false
        #endif
    }

    init(
        plan: WorkoutPlan,
        audioPreferences: WorkoutAudioPreferences,
        onRepeat: @escaping () -> Void,
        onNewWorkout: @escaping () -> Void
    ) {
        self.plan = plan
        self.onRepeat = onRepeat
        self.onNewWorkout = onNewWorkout
        _store = StateObject(wrappedValue: WorkoutSessionStore(plan: plan))
        _audioCoordinator = StateObject(
            wrappedValue: WorkoutAudioCoordinator(preferences: audioPreferences)
        )
    }

    var body: some View {
        ZStack {
            sessionBackground.ignoresSafeArea()
            Group {
                switch store.phase {
                case .exercise:
                    exerciseScreen
                case .rest:
                    restScreen
                case .finished:
                    FinishView(
                        plan: plan,
                        elapsedSeconds: store.elapsedSeconds,
                        completedCount: store.completedExerciseCount,
                        skippedCount: store.outcomes.values.filter { $0 == .skipped }.count,
                        onRepeat: onRepeat,
                        onNewWorkout: onNewWorkout
                    )
                }
            }
            .accessibilityHidden(isModalPresented)
            .allowsHitTesting(!isModalPresented)

            if store.isPaused {
                pauseOverlay
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.96).combined(with: .opacity))
            }

            if let confirmation {
                SessionConfirmationModal(
                    variant: confirmation,
                    isTransitioning: confirmationTransitioning,
                    onCancel: cancelConfirmation,
                    onConfirm: confirmDestructiveAction
                )
                .transition(reduceMotion ? .opacity : .scale(scale: 0.96).combined(with: .opacity))
            }

            if validationMode {
                Text(validationFocusProbe)
                    .font(.system(size: 1))
                    .frame(width: 1, height: 1)
                    .accessibilityIdentifier("validation.ax.focus.\(validationFocusProbe)")
                    .accessibilityLabel("Validation accessibility focus")
                    .accessibilityValue(validationFocusProbe)
            }
        }
        .preferredColorScheme(store.phase == .rest ? .light : .dark)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .animation(
            reduceMotion ? .linear(duration: 0.1) : .easeInOut(duration: 0.36),
            value: store.phase
        )
        .animation(.easeOut(duration: 0.12), value: store.isPaused)
        .onAppear {
            audioCoordinator.onSafetyPause = {
                store.pause()
            }
            if validationMode, !audioRuntimeProbe {
                store.completeFirstExercisePreparation()
            } else {
                audioCoordinator.start(plan: plan) {
                    store.completeFirstExercisePreparation()
                }
            }
            setFocus(.stateTitle)
            announceCurrentPhase()
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { now in
            guard !validationMode else { return }
            store.tick(at: now)
            audioCoordinator.tick(store: store)
            announceCountdownIfNeeded()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                if store.phase != .finished, !store.isPaused {
                    audioCoordinator.sceneDidBecomeInactive()
                }
            } else if store.phase != .finished {
                audioCoordinator.sceneDidBecomeInactive()
            }
        }
        .onChange(of: store.phase) { phase in
            lastAnnouncedSecond = nil
            audioCoordinator.synchronize(store: store)
            announceCurrentPhase()
            setFocus(phase == .finished ? nil : .stateTitle)
        }
        .onChange(of: store.latestVoiceEvent) { _ in
            audioCoordinator.synchronize(store: store)
        }
        .onChange(of: store.isPaused) { isPaused in
            if isPaused { audioCoordinator.pause() }
            else { audioCoordinator.resume() }
            setFocus(isPaused ? .pauseDialog : .pauseButton)
        }
        .onDisappear { audioCoordinator.stop() }
    }

    private var exerciseScreen: some View {
        VStack(spacing: 0) {
            playerTopBar
            TempoRail(total: plan.items.count, current: store.currentIndex)
                .padding(.horizontal, TempoTokens.Space.outer)
            ScrollView {
                VStack(alignment: .leading, spacing: TempoTokens.Space.lg) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .bottom) {
                            exerciseTitle
                            Spacer(minLength: TempoTokens.Space.sm)
                            exerciseZone
                        }
                        VStack(alignment: .leading, spacing: TempoTokens.Space.xs) {
                            exerciseTitle
                            exerciseZone
                        }
                    }

                    ExerciseMotionAperture(
                        exercise: store.currentItem.exercise,
                        isPaused: store.isPaused,
                        onMediaAvailabilityChange: { mediaUnavailable = $0 }
                    )
                        .allowsHitTesting(false)
                        .accessibilityIdentifier("session.active.athleteStage")

                    if mediaUnavailable {
                        Text("Демонстрация недоступна — таймер и управление тренировкой продолжают работать.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(inverseSecondaryColor)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("session.active.mediaError")
                    }

                    if validationMode {
                        activeProgressComposition
                    } else {
                        activeProgressComposition
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(activeProgressAccessibilityLabel)
                            .accessibilityIdentifier("session.active.countdownGroup")
                    }

                    TempoRail(total: plan.items.count, current: store.currentIndex)
                        .accessibilityLabel("\(store.currentIndex + 1) из \(plan.items.count) упражнений")
                        .accessibilityIdentifier("session.active.progress")

                    nextExerciseCard

                    if audioCoordinator.isMusicEnabled {
                        Text("Музыка · \(audioCoordinator.displayedMusicTrack.title)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(inverseSecondaryColor)
                            .accessibilityIdentifier("session.audio.track")
                            .accessibilityValue(
                                audioCoordinator.activeMusicTrack == nil ? "Подготовка" : "Воспроизводится"
                            )
                    }

                    if case .repetitionBased = store.currentItem.prescription {
                        repetitionControls
                    }

                    if let statusText = audioCoordinator.statusText {
                        Text(statusText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(inverseSecondaryColor)
                            .accessibilityIdentifier("session.audio.status")
                            .accessibilityHidden(true)
                    }
                }
                .padding(.horizontal, TempoTokens.Space.outer)
                .padding(.vertical, TempoTokens.Space.xl)
                .padding(.bottom, 80)
            }
            .accessibilityIdentifier("session.active.scroll")
        }
        .foregroundStyle(.white)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: TempoTokens.Space.sm) {
                InverseIconButton(
                    symbol: "pause.fill",
                    size: TempoTokens.Size.pauseControl,
                    accessibilityLabel: "Поставить тренировку на паузу",
                    action: { store.pause() }
                )
                .accessibilityIdentifier("session.pause")
                .accessibilityFocused($focusedElement, equals: .pauseButton)

                InverseIconButton(
                    symbol: "forward.end.fill",
                    size: TempoTokens.Size.pauseControl,
                    accessibilityLabel: "Пропустить упражнение",
                    action: { presentConfirmation(.skipExercise, opener: .nextButton) }
                )
                .accessibilityIdentifier("session.exercise.skip")
                .disabled(store.isPreparingFirstExercise)

                Button(action: advanceFromExercise) {
                    Text(nextActionTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: TempoTokens.Size.primaryControl)
                        .background(TempoTokens.ColorToken.vermilion)
                        .foregroundStyle(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: TempoTokens.Radius.button, style: .continuous))
                }
                .accessibilityFocused($focusedElement, equals: .nextButton)
                .disabled(store.isPreparingFirstExercise)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, TempoTokens.Space.outer)
            .padding(.vertical, TempoTokens.Space.sm)
            .background(TempoTokens.ColorToken.carbon)
        }
    }

    private var playerTopBar: some View {
        HStack {
            InverseIconButton(
                symbol: "xmark",
                size: TempoTokens.Size.iconControl,
                accessibilityLabel: "Завершить тренировку",
                foreground: sessionControlColor
            ) {
                presentConfirmation(.exitSession, opener: .exitButton)
            }
            .accessibilityIdentifier("session.exit")
            .accessibilityFocused($focusedElement, equals: .exitButton)
            Spacer()
            Text(String(format: "%02d / %02d", store.currentIndex + 1, plan.items.count))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(sessionControlColor)
            Spacer()
            InverseIconButton(
                symbol: audioCoordinator.sessionMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                size: TempoTokens.Size.iconControl,
                accessibilityLabel: audioCoordinator.sessionMuted
                    ? "Включить звук этой тренировки"
                    : "Выключить звук этой тренировки",
                foreground: sessionControlColor
            ) {
                audioCoordinator.setSessionMuted(!audioCoordinator.sessionMuted)
            }
            .accessibilityIdentifier("session.audio.toggle")
            .accessibilityValue(audioCoordinator.sessionMuted ? "Звук выключен" : "Звук включён")
            .accessibilityFocused($focusedElement, equals: .audioButton)
        }
        .padding(.horizontal, TempoTokens.Space.sm)
    }

    private var restScreen: some View {
        VStack(spacing: 0) {
            playerTopBar
            ScrollView {
                VStack(alignment: .leading, spacing: TempoTokens.Space.xl) {
                    Text("Пауза между упражнениями")
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(TempoTokens.ColorToken.auditRest)
                    Text("Отдых")
                        .font(.system(size: restTitleSize, weight: .bold))
                        .foregroundStyle(TempoTokens.ColorToken.carbon)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityFocused($focusedElement, equals: .stateTitle)
                    Text("\(store.remainingSeconds)")
                        .font(.system(size: restTimerSize, weight: .semibold).monospacedDigit())
                        .foregroundStyle(TempoTokens.ColorToken.carbon)
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                    Capsule()
                        .fill(TempoTokens.ColorToken.carbon.opacity(0.24))
                        .frame(height: 2)
                        .padding(.vertical, TempoTokens.Space.md)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, TempoTokens.Space.outer)
                .padding(.vertical, TempoTokens.Space.xl)
            }
        }
        .foregroundStyle(TempoTokens.ColorToken.carbon)
        .tint(TempoTokens.ColorToken.carbon)
        .safeAreaInset(edge: .bottom) {
            restBottomBlock
        }
    }

    private var pauseOverlay: some View {
        ZStack {
            Color.black.opacity(0.46)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: TempoTokens.Space.lg) {
                Image(systemName: "pause.fill")
                    .font(.title)
                    .frame(width: 64, height: 64)
                    .background(TempoTokens.ColorToken.chalkSubtle)
                    .clipShape(Circle())
                    .accessibilityHidden(true)
                Text("Пауза")
                    .font(.largeTitle.bold())
                    .accessibilityIdentifier("pause.dialog.title")
                    .accessibilityFocused($focusedElement, equals: .pauseDialog)
                    .accessibilitySortPriority(3)
                Text("Таймер остановлен. Продолжите, когда будете готовы.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(TempoTokens.ColorToken.muted)
                    .accessibilityIdentifier("pause.dialog.message")
                    .accessibilitySortPriority(2)
                TempoPrimaryButton(title: "Продолжить тренировку", symbol: "play.fill") {
                    store.resume()
                }
                .accessibilityIdentifier("pause.resume")
                .accessibilitySortPriority(1)
            }
            .padding(TempoTokens.Space.xl)
            .frame(maxWidth: 360)
            .background(TempoTokens.ColorToken.chalk)
            .foregroundStyle(TempoTokens.ColorToken.carbon)
            .clipShape(RoundedRectangle(cornerRadius: TempoTokens.Radius.media, style: .continuous))
            .padding(TempoTokens.Space.outer)
            .shadow(color: .black.opacity(0.18), radius: 24, y: 16)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityIdentifier("pause.dialog")
        }
    }

    private var exerciseTitle: some View {
        Text(store.currentItem.exercise.title)
            .font(.system(size: activeTitleSize, weight: .bold))
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityFocused($focusedElement, equals: .stateTitle)
    }

    private var exerciseZone: some View {
        Text(store.currentItem.exercise.zones.first?.title ?? AbsZone.full.title)
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(TempoTokens.ColorToken.vermilion)
    }

    private func nextTitle(_ item: WorkoutItem) -> some View {
        Text(item.exercise.title)
            .font(.title3.weight(.semibold))
            .foregroundStyle(TempoTokens.ColorToken.carbon)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("session.rest.nextTitle")
    }

    private func nextDuration(_ item: WorkoutItem) -> some View {
        Text(prescriptionDisplay(item.prescription))
            .font(.headline.monospacedDigit())
            .foregroundStyle(TempoTokens.ColorToken.carbon)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("session.rest.nextDuration")
    }

    private func prescriptionDisplay(_ prescription: WorkoutPrescription) -> String {
        switch prescription {
        case let .timeBased(duration):
            return "\(duration) сек"
        case let .repetitionBased(target, unit, _, _):
            return unit == .perSideAlternating
                ? "\(target) повторов · по \(target / 2)"
                : "\(target) повторов"
        }
    }

    private var activeCountdown: some View {
        Text(store.formattedRemaining)
            .font(.system(size: activeTimerSize, weight: .semibold).monospacedDigit())
            .foregroundStyle(TempoTokens.SemanticColor.inversePrimary.color)
            .minimumScaleFactor(0.75)
            .lineLimit(1)
            .accessibilityIdentifier("session.active.timer")
    }

    private var activeCountdownComposition: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: TempoTokens.Space.md) {
                activeCountdown
                Spacer(minLength: TempoTokens.Space.sm)
                activeCountdownLabel
                    .frame(maxWidth: 116, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: TempoTokens.Space.xxs) {
                activeCountdown
                activeCountdownLabel
            }
        }
    }

    @ViewBuilder
    private var activeProgressComposition: some View {
        switch store.currentItem.prescription {
        case .timeBased:
            activeCountdownComposition
        case let .repetitionBased(target, unit, _, _):
            VStack(alignment: .leading, spacing: TempoTokens.Space.xs) {
                Text(store.isManualCount
                     ? "Подтверждено вручную: \(store.currentCount) из \(target)"
                     : "Плановый счёт: \(store.currentCount) из \(target)")
                    .font(.system(size: activeTimerSize, weight: .semibold).monospacedDigit())
                    .foregroundStyle(TempoTokens.SemanticColor.inversePrimary.color)
                    .minimumScaleFactor(0.72)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("session.active.repetitionCount")
                Text(unit == .perSideAlternating
                     ? "По \(target / 2) на сторону. Каждая смена стороны — следующий номер."
                     : "Каждый полный цикл — один повтор")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(inverseSecondaryColor)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Счёт задаёт темп и не распознаёт движения.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(inverseSecondaryColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("session.active.pacingDisclosure")
            }
        }
    }

    private var activeProgressAccessibilityLabel: String {
        switch store.currentItem.prescription {
        case .timeBased:
            return "Осталось \(store.remainingSeconds) секунд в этом упражнении"
        case let .repetitionBased(target, unit, _, _):
            let meaning = unit == .perSideAlternating
                ? "Каждая смена стороны считается отдельно"
                : "Каждый полный цикл считается одним повтором"
            return "Выполнено \(store.currentCount) из \(target) повторов. \(meaning)"
        }
    }

    private var repetitionControls: some View {
        VStack(alignment: .leading, spacing: TempoTokens.Space.sm) {
            if store.isAwaitingSetConfirmation {
                Text("Цель достигнута. Подтвердите завершение набора.")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(TempoTokens.SemanticColor.inversePrimary.color)
                    .accessibilityIdentifier("session.active.setConfirmation")
            }

            if store.isManualCount {
                HStack(spacing: TempoTokens.Space.sm) {
                    manualCountButton(
                        symbol: "minus",
                        label: "Уменьшить счёт повторов",
                        isDisabled: store.currentCount == 0
                    ) {
                        adjustManualCount(by: -1)
                    }
                    manualCountButton(
                        symbol: "plus",
                        label: "Подтвердить ещё один повтор",
                        isDisabled: store.currentCount == store.currentItem.prescription.targetCount
                    ) {
                        adjustManualCount(by: 1)
                    }
                }
            } else {
                Button(store.isAwaitingSetConfirmation ? "Продолжить вручную" : "Считать вручную") {
                    store.switchToManualCount()
                }
                    .font(.headline)
                    .frame(minHeight: TempoTokens.Size.minimumTap)
                    .foregroundStyle(TempoTokens.SemanticColor.inversePrimary.color)
                    .accessibilityHint("Отключает автоматический темп для текущего упражнения")
                    .accessibilityIdentifier("session.active.manualCount")
            }
        }
        .disabled(store.isPreparingFirstExercise)
    }

    private func manualCountButton(
        symbol: String,
        label: String,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(maxWidth: .infinity, minHeight: TempoTokens.Size.minimumTap)
                .overlay {
                    RoundedRectangle(cornerRadius: TempoTokens.Radius.small)
                        .stroke(
                            inverseControlBorderColor,
                            lineWidth: accessibilityContrast == .increased ? 2 : 1
                        )
                }
        }
        .accessibilityLabel(label)
        .disabled(isDisabled)
    }

    private func adjustManualCount(by delta: Int) {
        store.adjustManualCount(by: delta)
        audioCoordinator.synchronize(store: store)
    }

    private var activeCountdownLabel: some View {
        Text("Осталось в этом упражнении")
            .font(.caption.weight(.semibold))
            .foregroundStyle(inverseSecondaryColor)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("session.active.timerContext")
    }

    private var nextExerciseCard: some View {
        let title = store.nextItem?.exercise.title ?? "Финиш тренировки"
        let context = store.nextItem == nil
            ? "Это последнее упражнение"
            : "После отдыха \(store.currentItem.restAfterSec) секунд"
        return VStack(alignment: .leading, spacing: TempoTokens.Space.xxs) {
            Text("ДАЛЬШЕ")
                .font(.caption.weight(.bold))
                .foregroundStyle(TempoTokens.ColorToken.auditPrimary)
            Text(title)
                .font(.headline)
                .foregroundStyle(TempoTokens.ColorToken.auditText)
                .fixedSize(horizontal: false, vertical: true)
            Text(context)
                .font(.caption)
                .foregroundStyle(TempoTokens.ColorToken.auditMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TempoTokens.Space.md)
        .background(TempoTokens.ColorToken.auditInteractive)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Дальше. \(title). \(context)")
        .accessibilityIdentifier("session.active.nextCard")
    }

    private var restBottomBlock: some View {
        VStack(alignment: .leading, spacing: TempoTokens.Space.md) {
            if let next = store.nextItem {
                VStack(alignment: .leading, spacing: TempoTokens.Space.xs) {
                    Text("Дальше · \(next.order) из \(plan.items.count)")
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(TempoTokens.ColorToken.muted)
                        .accessibilityIdentifier("session.rest.nextEyebrow")
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline) {
                            nextTitle(next)
                            Spacer(minLength: TempoTokens.Space.xs)
                            nextDuration(next)
                        }
                        VStack(alignment: .leading, spacing: TempoTokens.Space.xs) {
                            nextTitle(next)
                            nextDuration(next)
                        }
                    }
                }
                .padding(.vertical, TempoTokens.Space.md)
                .overlay(alignment: .top) {
                    Rectangle().fill(TempoTokens.ColorToken.carbon.opacity(0.18)).frame(height: 1)
                        .accessibilityHidden(true)
                }
                .overlay(alignment: .bottom) {
                    Rectangle().fill(TempoTokens.ColorToken.carbon.opacity(0.18)).frame(height: 1)
                        .accessibilityHidden(true)
                }
            }

            Button("Пропустить отдых") { store.skipRest() }
                .font(.headline)
                .foregroundStyle(TempoTokens.ColorToken.carbon)
                .frame(maxWidth: .infinity, minHeight: TempoTokens.Size.primaryControl)
                .contentShape(Rectangle())
                .overlay {
                    RoundedRectangle(cornerRadius: TempoTokens.Radius.button, style: .continuous)
                        .stroke(TempoTokens.ColorToken.carbon, lineWidth: accessibilityContrast == .increased ? 2 : 1)
                }
                .accessibilityIdentifier("session.rest.skip")
        }
        .padding(.horizontal, TempoTokens.Space.outer)
        .padding(.vertical, TempoTokens.Space.sm)
        .background(TempoTokens.ColorToken.chalk)
        .tint(TempoTokens.ColorToken.carbon)
    }

    private var sessionBackground: Color {
        switch store.phase {
        case .exercise: return TempoTokens.ColorToken.auditCanvas
        case .rest: return TempoTokens.ColorToken.chalk
        case .finished: return TempoTokens.ColorToken.auditCanvas
        }
    }

    private var sessionControlColor: Color {
        store.phase == .rest ? TempoTokens.ColorToken.carbon : .white
    }

    private var isModalPresented: Bool {
        store.isPaused || confirmation != nil
    }

    private var inverseSecondaryColor: Color {
        accessibilityContrast == .increased
            ? Color.white
            : TempoTokens.SemanticColor.inverseSecondary.color
    }

    private var inverseControlBorderColor: Color {
        accessibilityContrast == .increased
            ? Color.white
            : TempoTokens.SemanticColor.inverseControlBorder.color
    }

    private var nextActionTitle: String {
        if case .repetitionBased = store.currentItem.prescription {
            return store.isAwaitingSetConfirmation ? "Подтвердить набор" : "Завершить набор"
        }
        if store.nextItem == nil { return "Завершить" }
        return "Далее · отдых \(store.currentItem.restAfterSec) сек"
    }

    private func advanceFromExercise() {
        if case .repetitionBased = store.currentItem.prescription {
            if store.isAwaitingSetConfirmation {
                store.confirmSet()
            } else {
                presentConfirmation(.finishRepetitionEarly, opener: .nextButton)
            }
            return
        }
        if store.nextItem == nil, store.remainingSeconds > 0 {
            presentConfirmation(.finishLastExerciseEarly, opener: .nextButton)
        } else {
            store.completeCurrentEarly()
        }
    }

    private func presentConfirmation(_ variant: SessionConfirmationVariant, opener: FocusElement) {
        guard confirmation == nil, !store.isPaused else { return }
        confirmationOpener = opener
        confirmationTransitioning = false
        confirmation = variant
        setFocus(nil)
    }

    private func cancelConfirmation() {
        guard !confirmationTransitioning else { return }
        let opener = confirmationOpener
        confirmation = nil
        confirmationOpener = nil
        DispatchQueue.main.async { setFocus(opener) }
    }

    private func confirmDestructiveAction() {
        guard let confirmation, !confirmationTransitioning else { return }
        confirmationTransitioning = true
        switch confirmation {
        case .exitSession:
            onNewWorkout()
        case .finishLastExerciseEarly:
            store.completeCurrentEarly()
            self.confirmation = nil
            confirmationOpener = nil
            confirmationTransitioning = false
        case .finishRepetitionEarly:
            store.completeCurrentEarly()
            self.confirmation = nil
            confirmationOpener = nil
            confirmationTransitioning = false
        case .skipExercise:
            store.skipExercise()
            self.confirmation = nil
            confirmationOpener = nil
            confirmationTransitioning = false
        }
    }

    private func announceCountdownIfNeeded() {
        guard case .timeBased = store.currentItem.prescription,
              [10, 5, 3, 2, 1].contains(store.remainingSeconds),
              lastAnnouncedSecond != store.remainingSeconds else { return }
        lastAnnouncedSecond = store.remainingSeconds
        UIAccessibility.post(
            notification: .announcement,
            argument: "Осталось \(store.remainingSeconds) секунд"
        )
    }

    private func announceCurrentPhase() {
        let message: String
        switch store.phase {
        case .exercise:
            message = "Упражнение \(store.currentIndex + 1) из \(plan.items.count). \(store.currentItem.exercise.title)"
        case .rest:
            message = "Отдых, \(store.remainingSeconds) секунд"
        case .finished:
            message = "Тренировка завершена"
        }
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    private func setFocus(_ element: FocusElement?) {
        focusedElement = element
        guard validationMode else { return }
        switch element {
        case .stateTitle: validationFocusProbe = "stateTitle"
        case .exitButton: validationFocusProbe = "exitButton"
        case .pauseButton: validationFocusProbe = "pauseButton"
        case .audioButton: validationFocusProbe = "audioButton"
        case .nextButton: validationFocusProbe = "nextButton"
        case .pauseDialog: validationFocusProbe = "pauseDialog"
        case nil: validationFocusProbe = "none"
        }
    }
}

#Preview("Активное упражнение") {
    NavigationStack {
        ExercisePlayerView(
            plan: .preview,
            audioPreferences: WorkoutAudioPreferences(),
            onRepeat: {},
            onNewWorkout: {}
        )
    }
}
