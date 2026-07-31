import SwiftUI
import UIKit

struct ContentView: View {
    private enum Route: Hashable {
        case plan
        case session
        case exerciseLibrary
        case exerciseDetail(String)
    }

    @State private var selectedDuration = 10
    @State private var selectedZones: Set<AbsZone> = [.full]
    @State private var selectedIntensity: WorkoutIntensity = .balanced
    @State private var plan: WorkoutPlan?
    @State private var path: [Route] = []
    @State private var isGenerating = false
    @State private var generationError: String?
    @State private var generationTask: Task<Void, Never>?
    @State private var generationRequestID: UUID?
    @State private var wasExerciseLibraryOpen = false
    @StateObject private var audioPreferences = WorkoutAudioPreferences()
    @ScaledMetric(relativeTo: .largeTitle) private var displayTitleSize = 42
    @AccessibilityFocusState private var setupTitleFocused: Bool
    @AccessibilityFocusState private var exerciseLibraryButtonFocused: Bool
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private let generator = WorkoutGenerator()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                setupContent
                .padding(.horizontal, TempoTokens.Space.outer)
                .padding(.top, TempoTokens.Space.xl)
                .padding(.bottom, 88)
            }
            .accessibilityIdentifier("setup.scroll")
            .background(TempoTokens.ColorToken.auditCanvas.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: TempoTokens.Space.xxs) {
                    TempoPrimaryButton(
                        title: "Собрать тренировку",
                        isLoading: isGenerating,
                        style: .auditPrimary,
                        action: generatePlan
                    )
                    if isGenerating {
                        Button("Отменить сборку", action: cancelGeneration)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: TempoTokens.Size.minimumTap)
                            .foregroundStyle(TempoTokens.ColorToken.auditText)
                            .accessibilityHint("Параметры тренировки останутся выбранными")
                            .accessibilityIdentifier("setup.generation.cancel")
                    }
                }
                .padding(.horizontal, TempoTokens.Space.outer)
                .padding(.vertical, TempoTokens.Space.sm)
                .background(TempoTokens.ColorToken.auditCanvas)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .plan:
                    if let plan {
                        WorkoutPlanView(
                            plan: plan,
                            audioPreferences: audioPreferences,
                            onEditAudio: { path.removeLast() },
                            onOpenExercise: { path.append(.exerciseDetail($0)) },
                            onStart: { path.append(.session) }
                        )
                    } else {
                        Color.clear.onAppear { path.removeAll() }
                    }
                case .session:
                    if let plan {
                        ExercisePlayerView(
                            plan: plan,
                            audioPreferences: audioPreferences,
                            onRepeat: {
                                audioPreferences.prepareMusicForNextWorkout()
                                path = [.plan]
                            },
                            onNewWorkout: {
                                self.plan = nil
                                path.removeAll()
                            }
                        )
                    } else {
                        Color.clear.onAppear { path.removeAll() }
                    }
                case .exerciseLibrary:
                    ExerciseLibraryView { exerciseID in
                        path.append(.exerciseDetail(exerciseID))
                    }
                case let .exerciseDetail(exerciseID):
                    if let exercise = ExerciseCatalog.starter.first(where: { $0.id == exerciseID }) {
                        ExerciseDetailView(exercise: exercise)
                    } else {
                        Color.clear.onAppear { path.removeLast() }
                    }
                }
            }
        }
        .tint(TempoTokens.ColorToken.auditPrimary)
        .preferredColorScheme(.dark)
        .onAppear { setupTitleFocused = true }
        .onChange(of: path) { newPath in
            if newPath.isEmpty, wasExerciseLibraryOpen {
                exerciseLibraryButtonFocused = true
            }
            wasExerciseLibraryOpen = newPath.contains(.exerciseLibrary)
        }
    }

    @ViewBuilder
    private var setupContent: some View {
        if verticalSizeClass == .compact {
            HStack(alignment: .top, spacing: TempoTokens.Space.xxl) {
                VStack(alignment: .leading, spacing: TempoTokens.Space.xl) {
                    header
                    sessionPresetSummary
                }
                    .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: TempoTokens.Space.xxl) {
                    durationPicker
                    zonePicker
                    intensityPicker
                    audioSettings
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            VStack(alignment: .leading, spacing: TempoTokens.Space.xxl) {
                header
                sessionPresetSummary
                durationPicker
                zonePicker
                intensityPicker
                audioSettings
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: TempoTokens.Space.sm) {
            HStack(alignment: .center, spacing: TempoTokens.Space.sm) {
                Text("Локальная тренировка")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(1.4)
                    .foregroundStyle(TempoTokens.ColorToken.auditPrimary)
                Spacer(minLength: TempoTokens.Space.xs)
                Button {
                    guard !isGenerating else { return }
                    path.append(.exerciseLibrary)
                } label: {
                    Label("Упражнения", systemImage: "list.bullet.rectangle")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: TempoTokens.Size.minimumTap)
                }
                .buttonStyle(.plain)
                .disabled(isGenerating)
                .accessibilityLabel("Открыть каталог упражнений")
                .accessibilityIdentifier("setup.openExercises")
                .accessibilityFocused($exerciseLibraryButtonFocused)
            }
            Text("Соберите свой темп")
                .font(.system(size: displayTitleSize, weight: .bold))
                .foregroundStyle(TempoTokens.ColorToken.auditText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("setup.title")
                .accessibilityFocused($setupTitleFocused)
            Text("Выберите длительность и нагрузку. План будет готов без регистрации.")
                .font(.body)
                .foregroundStyle(TempoTokens.ColorToken.auditMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sessionPresetSummary: some View {
        VStack(alignment: .leading, spacing: TempoTokens.Space.sm) {
            Text("\(selectedDuration) минут · \(selectedZones.map(\.setupTitle).sorted().joined(separator: ", "))")
                .font(.headline)
                .foregroundStyle(TempoTokens.ColorToken.auditText)
                .fixedSize(horizontal: false, vertical: true)
            Text("План соберётся локально: работа, отдых и понятный следующий шаг.")
                .font(.subheadline)
                .foregroundStyle(TempoTokens.ColorToken.auditMuted)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .center, spacing: TempoTokens.Space.sm) {
                TempoRail(total: 8, current: 2)
                    .accessibilityHidden(true)
                Text("\(audioPreferences.nextMusicTrackPreview.title) готов")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TempoTokens.ColorToken.auditPrimary)
                    .fixedSize()
            }
        }
        .padding(TempoTokens.Space.md)
        .background(TempoTokens.ColorToken.auditSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("setup.presetSummary")
    }

    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: TempoTokens.Space.md) {
            sectionHeader(title: "Сколько времени?", value: "\(selectedDuration) минут")
            TempoDurationDial(
                value: $selectedDuration,
                allowedValues: DurationDialContract.allowedValues,
                isEnabled: !isGenerating,
                usesDarkCanvas: true
            )
        }
    }

    private var zonePicker: some View {
        VStack(alignment: .leading, spacing: TempoTokens.Space.md) {
            sectionHeader(title: "Куда нагрузка?", value: "Можно несколько")
            VStack(spacing: TempoTokens.Space.xs) {
                HStack(spacing: TempoTokens.Space.xs) {
                    zoneChoice(.upper)
                    zoneChoice(.lower)
                }
                HStack(spacing: TempoTokens.Space.xs) {
                    zoneChoice(.obliques)
                    zoneChoice(.full)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Зона нагрузки")
        .accessibilityHint("Можно выбрать несколько зон. Весь пресс отменяет выбор отдельных зон.")
    }

    private func zoneChoice(_ zone: AbsZone) -> some View {
        TempoChoiceCell(
            title: zone.setupTitle,
            isSelected: selectedZones.contains(zone),
            selectedColor: zone == .full ? TempoTokens.ColorToken.ultramarine : TempoTokens.ColorToken.carbon,
            isEnabled: !isGenerating,
            usesDarkCanvas: true,
            accessibilityIdentifier: "setup.zone.\(zone.rawValue)",
            action: { toggle(zone) }
        )
        .frame(maxWidth: .infinity)
    }

    private var intensityPicker: some View {
        VStack(alignment: .leading, spacing: TempoTokens.Space.md) {
            sectionHeader(title: "Интенсивность упражнений", value: "Один вариант")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: TempoTokens.Space.xs) { intensityChoices }
                VStack(spacing: TempoTokens.Space.xs) { intensityChoices }
            }
            if let generationError {
                Text(generationError)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TempoTokens.ColorToken.auditRest)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("setup.generationError")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Интенсивность упражнений")
        .accessibilityHint("Выберите один вариант. Интенсивность меняет сложность упражнений.")
    }

    private var audioSettings: some View {
        VStack(alignment: .leading, spacing: TempoTokens.Space.md) {
            sectionHeader(title: "Звук тренировки", value: "Локально")
                .accessibilityIdentifier("setup.audio.section")

            Toggle(isOn: $audioPreferences.musicEnabled) {
                VStack(alignment: .leading, spacing: TempoTokens.Space.xxs) {
                    Text("Музыка тренировки").font(.body.weight(.semibold))
                    Text("Оригинальный ритм").font(.caption).foregroundStyle(TempoTokens.ColorToken.auditMuted)
                }
            }
            .frame(minHeight: 64)
            .accessibilityValue(audioPreferences.musicEnabled ? "Включена" : "Выключена")
            .accessibilityIdentifier("setup.audio.musicToggle")

            VStack(alignment: .leading, spacing: TempoTokens.Space.xs) {
                Text("Трек").font(.body.weight(.semibold))
                VStack(spacing: TempoTokens.Space.xs) {
                    HStack(spacing: TempoTokens.Space.xs) {
                        musicTrackChoice(.auto)
                        musicTrackChoice(.pulseGrid)
                    }
                    HStack(spacing: TempoTokens.Space.xs) {
                        musicTrackChoice(.forwardArc)
                        musicTrackChoice(.groundedOrbit)
                    }
                }
                if audioPreferences.musicSelection == .auto {
                    Text("Следующая тренировка · \(audioPreferences.nextMusicTrackPreview.title)")
                        .font(.caption)
                        .foregroundStyle(TempoTokens.ColorToken.auditMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Выбор музыки тренировки")

            VStack(alignment: .leading, spacing: TempoTokens.Space.xs) {
                HStack {
                    Text("Громкость музыки").font(.body.weight(.semibold))
                    Spacer()
                    Text("\(Int((audioPreferences.musicVolume * 100).rounded()))%")
                        .font(.caption.weight(.semibold).monospacedDigit())
                }
                Slider(value: $audioPreferences.musicVolume, in: 0...1, step: 0.05)
                    .disabled(!audioPreferences.musicEnabled || isGenerating)
                    .accessibilityLabel("Громкость музыки")
                    .accessibilityValue("\(Int((audioPreferences.musicVolume * 100).rounded())) процентов")
                    .accessibilityHint("Настройте громкость фоновой музыки")
                    .accessibilityIdentifier("setup.audio.musicVolume")
            }
            .frame(minHeight: 64)

            Toggle(isOn: $audioPreferences.voiceCoachEnabled) {
                VStack(alignment: .leading, spacing: TempoTokens.Space.xxs) {
                    Text("Голосовой тренер").font(.body.weight(.semibold))
                    Text("Переходы и темп").font(.caption).foregroundStyle(TempoTokens.ColorToken.auditMuted)
                }
            }
            .frame(minHeight: 64)
            .accessibilityValue(audioPreferences.voiceCoachEnabled ? "Включён" : "Выключен")
            .accessibilityIdentifier("setup.audio.voiceToggle")

            Text("Музыка и голос работают без сети. Системные подсказки VoiceOver всегда важнее голосового тренера.")
                .font(.caption)
                .foregroundStyle(TempoTokens.ColorToken.auditMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .disabled(isGenerating)
        .opacity(isGenerating ? 0.38 : 1)
    }

    private func musicTrackChoice(_ selection: WorkoutMusicSelection) -> some View {
        TempoChoiceCell(
            title: selection.title,
            isSelected: audioPreferences.musicSelection == selection,
            isEnabled: !isGenerating,
            usesDarkCanvas: true,
            accessibilityIdentifier: "setup.audio.track.\(selection.rawValue)"
        ) {
            audioPreferences.musicSelection = selection
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var intensityChoices: some View {
        ForEach(WorkoutIntensity.allCases) { intensity in
            TempoChoiceCell(
                title: intensity.title,
                isSelected: selectedIntensity == intensity,
                isEnabled: !isGenerating,
                usesDarkCanvas: true,
                accessibilityIdentifier: "setup.intensity.\(intensity.rawValue)"
            ) {
                selectedIntensity = intensity
                generationError = nil
            }
        }
    }

    private func sectionHeader(title: String, value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                sectionTitle(title)
                Spacer(minLength: TempoTokens.Space.xs)
                sectionValue(value, alignment: .trailing)
            }
            VStack(alignment: .leading, spacing: TempoTokens.Space.xxs) {
                sectionTitle(title)
                sectionValue(value, alignment: .leading)
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .foregroundStyle(TempoTokens.ColorToken.auditText)
    }

    private func sectionValue(_ value: String, alignment: TextAlignment) -> some View {
        Text(value)
            .font(.caption.weight(.semibold))
            .foregroundStyle(TempoTokens.ColorToken.auditMuted)
            .multilineTextAlignment(alignment)
    }

    private func toggle(_ zone: AbsZone) {
        if zone == .full {
            selectedZones = [.full]
            return
        }

        selectedZones.remove(.full)
        if selectedZones.contains(zone) {
            selectedZones.remove(zone)
        } else {
            selectedZones.insert(zone)
        }
        if selectedZones.isEmpty {
            selectedZones.insert(.full)
            UIAccessibility.post(
                notification: .announcement,
                argument: "Выбран весь пресс, потому что должна остаться хотя бы одна зона"
            )
        }
    }

    private func generatePlan() {
        guard !isGenerating else { return }
        isGenerating = true
        generationError = nil
        let setup = WorkoutSetup(
            targetDurationMin: selectedDuration,
            selectedZones: selectedZones,
            intensity: selectedIntensity
        ).normalized
        let requestID = UUID()
        generationRequestID = requestID
        generationTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: generationDelayNanoseconds)
            } catch {
                return
            }
            guard generationRequestID == requestID, !Task.isCancelled else { return }
            let generatedPlan = activeGenerator.generate(
                targetDurationMin: setup.targetDurationMin,
                selectedZones: setup.canonicalZones,
                intensity: setup.intensity
            )
            isGenerating = false
            generationTask = nil
            generationRequestID = nil
            guard !generatedPlan.items.isEmpty else {
                generationError = "Не удалось собрать тренировку. Параметры сохранены — попробуйте ещё раз."
                return
            }
            audioPreferences.prepareMusicForNextWorkout()
            plan = generatedPlan
            path.append(.plan)
        }
    }

    private func cancelGeneration() {
        generationRequestID = nil
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
        generationError = "Сборка отменена. Параметры сохранены."
    }

    private var activeGenerator: WorkoutGenerator {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ValidationMode"), arguments.contains("-PlanGenerationFailure") {
            return WorkoutGenerator(catalog: [])
        }
        #endif
        return generator
    }

    private var generationDelayNanoseconds: UInt64 {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ValidationMode"),
           let index = arguments.firstIndex(of: "-PlanGenerationDelayMilliseconds"),
           arguments.indices.contains(index + 1),
           let milliseconds = UInt64(arguments[index + 1]) {
            return milliseconds * 1_000_000
        }
        #endif
        return 350_000_000
    }
}

#Preview("Настройка · 393×852") {
    ContentView()
        .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro"))
}

#Preview("Настройка · compact") {
    ContentView()
        .previewLayout(.fixed(width: 320, height: 568))
}
