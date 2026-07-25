import SwiftUI
import UIKit

struct ExercisePlayerView: View {
    private enum FocusElement: Hashable {
        case stateTitle
        case exitButton
        case pauseButton
        case nextButton
        case pauseDialog
    }

    let plan: WorkoutPlan
    let onRepeat: () -> Void
    let onNewWorkout: () -> Void

    @StateObject private var store: WorkoutSessionStore
    @State private var confirmation: SessionConfirmationVariant?
    @State private var confirmationOpener: FocusElement?
    @State private var confirmationTransitioning = false
    @State private var lastAnnouncedSecond: Int?
    @State private var validationFocusProbe = "none"
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

    init(plan: WorkoutPlan, onRepeat: @escaping () -> Void, onNewWorkout: @escaping () -> Void) {
        self.plan = plan
        self.onRepeat = onRepeat
        self.onNewWorkout = onNewWorkout
        _store = StateObject(wrappedValue: WorkoutSessionStore(plan: plan))
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
        .preferredColorScheme(store.phase == .finished ? .light : .dark)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .animation(
            reduceMotion ? .linear(duration: 0.1) : .easeInOut(duration: 0.36),
            value: store.phase
        )
        .animation(.easeOut(duration: 0.12), value: store.isPaused)
        .onAppear {
            setFocus(.stateTitle)
            announceCurrentPhase()
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { now in
            guard !validationMode else { return }
            store.tick(at: now)
            announceCountdownIfNeeded()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { store.tick() }
        }
        .onChange(of: store.phase) { phase in
            lastAnnouncedSecond = nil
            announceCurrentPhase()
            setFocus(phase == .finished ? nil : .stateTitle)
        }
        .onChange(of: store.isPaused) { isPaused in
            setFocus(isPaused ? .pauseDialog : .pauseButton)
        }
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

                    ExerciseMediaAperture(exercise: store.currentItem.exercise)

                    if validationMode {
                        activeCountdownComposition
                    } else {
                        activeCountdownComposition
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Осталось \(store.remainingSeconds) секунд в этом упражнении")
                            .accessibilityIdentifier("session.active.countdownGroup")
                    }
                }
                .padding(.horizontal, TempoTokens.Space.outer)
                .padding(.vertical, TempoTokens.Space.xl)
                .padding(.bottom, 80)
            }
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

                Button(action: advanceFromExercise) {
                    Text(nextActionTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: TempoTokens.Size.primaryControl)
                        .background(TempoTokens.ColorToken.vermilion)
                        .foregroundStyle(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: TempoTokens.Radius.button, style: .continuous))
                }
                .accessibilityFocused($focusedElement, equals: .nextButton)
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
                accessibilityLabel: "Завершить тренировку"
            ) {
                presentConfirmation(.exitSession, opener: .exitButton)
            }
            .accessibilityIdentifier("session.exit")
            .accessibilityFocused($focusedElement, equals: .exitButton)
            Spacer()
            Text(String(format: "%02d / %02d", store.currentIndex + 1, plan.items.count))
                .font(.subheadline.weight(.semibold).monospacedDigit())
            Spacer()
            Color.clear.frame(width: 48, height: 48)
        }
        .padding(.horizontal, TempoTokens.Space.sm)
    }

    private var restScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TempoTokens.Space.xl) {
                Text("Пауза между упражнениями")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(inverseSecondaryColor)
                Text("Вдох.\nМедленный\nвыдох.")
                    .font(.system(size: restTitleSize, weight: .bold))
                    .foregroundStyle(TempoTokens.SemanticColor.inversePrimary.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityFocused($focusedElement, equals: .stateTitle)
                Text("\(store.remainingSeconds)")
                    .font(.system(size: restTimerSize, weight: .semibold).monospacedDigit())
                    .foregroundStyle(TempoTokens.SemanticColor.inversePrimary.color)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                Capsule()
                    .fill(TempoTokens.SemanticColor.inverseDivider.color)
                    .frame(height: 2)
                    .padding(.vertical, TempoTokens.Space.md)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, TempoTokens.Space.outer)
            .padding(.vertical, TempoTokens.Space.xl)
        }
        .foregroundStyle(.white)
        .tint(.white)
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
            .foregroundStyle(TempoTokens.SemanticColor.inversePrimary.color)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("session.rest.nextTitle")
    }

    private func nextDuration(_ item: WorkoutItem) -> some View {
        Text(WorkoutSessionStore.format(seconds: item.durationSec))
            .font(.headline.monospacedDigit())
            .foregroundStyle(TempoTokens.SemanticColor.inversePrimary.color)
            .fixedSize()
            .accessibilityIdentifier("session.rest.nextDuration")
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

    private var activeCountdownLabel: some View {
        Text("Осталось в этом упражнении")
            .font(.caption.weight(.semibold))
            .foregroundStyle(inverseSecondaryColor)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("session.active.timerContext")
    }

    private var restBottomBlock: some View {
        VStack(alignment: .leading, spacing: TempoTokens.Space.md) {
            if let next = store.nextItem {
                VStack(alignment: .leading, spacing: TempoTokens.Space.xs) {
                    Text("Дальше · \(next.order) из \(plan.items.count)")
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(inverseSecondaryColor)
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
                    Rectangle().fill(TempoTokens.SemanticColor.inverseDivider.color).frame(height: 1)
                        .accessibilityHidden(true)
                }
                .overlay(alignment: .bottom) {
                    Rectangle().fill(TempoTokens.SemanticColor.inverseDivider.color).frame(height: 1)
                        .accessibilityHidden(true)
                }
            }

            Button("Пропустить отдых") { store.skipRest() }
                .font(.headline)
                .foregroundStyle(TempoTokens.SemanticColor.inversePrimary.color)
                .frame(maxWidth: .infinity, minHeight: TempoTokens.Size.primaryControl)
                .contentShape(Rectangle())
                .overlay {
                    RoundedRectangle(cornerRadius: TempoTokens.Radius.button, style: .continuous)
                        .stroke(inverseControlBorderColor, lineWidth: accessibilityContrast == .increased ? 2 : 1)
                }
                .accessibilityIdentifier("session.rest.skip")
        }
        .padding(.horizontal, TempoTokens.Space.outer)
        .padding(.vertical, TempoTokens.Space.sm)
        .background(TempoTokens.ColorToken.ultramarine)
        .tint(.white)
    }

    private var sessionBackground: Color {
        switch store.phase {
        case .exercise: return TempoTokens.ColorToken.carbon
        case .rest: return TempoTokens.ColorToken.ultramarine
        case .finished: return TempoTokens.ColorToken.chalk
        }
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
        if store.nextItem == nil { return "Завершить" }
        return "Далее · отдых \(store.currentItem.restAfterSec) сек"
    }

    private func advanceFromExercise() {
        if store.nextItem == nil, store.remainingSeconds > 0 {
            presentConfirmation(.finishLastExerciseEarly, opener: .nextButton)
        } else {
            store.skipExercise()
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
            store.skipExercise()
            self.confirmation = nil
            confirmationOpener = nil
            confirmationTransitioning = false
        }
    }

    private func announceCountdownIfNeeded() {
        guard [10, 5, 3, 2, 1].contains(store.remainingSeconds),
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
        case .nextButton: validationFocusProbe = "nextButton"
        case .pauseDialog: validationFocusProbe = "pauseDialog"
        case nil: validationFocusProbe = "none"
        }
    }
}

#Preview("Активное упражнение") {
    NavigationStack {
        ExercisePlayerView(plan: .preview, onRepeat: {}, onNewWorkout: {})
    }
}
