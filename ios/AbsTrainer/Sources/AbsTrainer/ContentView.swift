import SwiftUI
import UIKit

struct ContentView: View {
    private enum Route: Hashable {
        case plan
        case session
    }

    @State private var selectedDuration = WorkoutSetup.default.targetDurationMin
    @State private var selectedZones: Set<AbsZone> = [.full]
    @State private var selectedIntensity: WorkoutIntensity = .balanced
    @State private var plan: WorkoutPlan?
    @State private var path: [Route] = []
    @State private var isGenerating = false
    @State private var generationError: String?
    @ScaledMetric(relativeTo: .largeTitle) private var displayTitleSize = 42
    @AccessibilityFocusState private var setupTitleFocused: Bool
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
            .background(TempoTokens.ColorToken.chalk.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                TempoPrimaryButton(
                    title: "Собрать тренировку",
                    isLoading: isGenerating,
                    action: generatePlan
                )
                .padding(.horizontal, TempoTokens.Space.outer)
                .padding(.vertical, TempoTokens.Space.sm)
                .background(TempoTokens.ColorToken.chalk)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .plan:
                    if let plan {
                        WorkoutPlanView(plan: plan) {
                            path.append(.session)
                        }
                    } else {
                        Color.clear.onAppear { path.removeAll() }
                    }
                case .session:
                    if let plan {
                        ExercisePlayerView(
                            plan: plan,
                            onRepeat: { path = [.plan] },
                            onNewWorkout: {
                                self.plan = nil
                                path.removeAll()
                            }
                        )
                    } else {
                        Color.clear.onAppear { path.removeAll() }
                    }
                }
            }
        }
        .tint(TempoTokens.ColorToken.carbon)
        .preferredColorScheme(.light)
        .onAppear { setupTitleFocused = true }
    }

    @ViewBuilder
    private var setupContent: some View {
        if verticalSizeClass == .compact {
            HStack(alignment: .top, spacing: TempoTokens.Space.xxl) {
                header
                    .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: TempoTokens.Space.xxl) {
                    durationPicker
                    zonePicker
                    intensityPicker
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            VStack(alignment: .leading, spacing: TempoTokens.Space.xl) {
                header
                durationPicker
                zonePicker
                intensityPicker
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: TempoTokens.Space.sm) {
            Text("Локальная тренировка")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .tracking(1.4)
                .foregroundStyle(TempoTokens.ColorToken.vermilion)
            Text("Соберите свой темп")
                .font(.system(size: displayTitleSize, weight: .bold))
                .foregroundStyle(TempoTokens.ColorToken.carbon)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityFocused($setupTitleFocused)
            Text("Выберите длительность и нагрузку. План будет готов без регистрации.")
                .font(.body)
                .foregroundStyle(TempoTokens.ColorToken.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: TempoTokens.Space.md) {
            sectionHeader(title: "Сколько времени?", value: "\(selectedDuration) минут")
            TempoDurationDial(
                value: $selectedDuration,
                allowedValues: DurationDialContract.allowedValues,
                isEnabled: !isGenerating
            )
        }
    }

    private var zonePicker: some View {
        VStack(alignment: .leading, spacing: TempoTokens.Space.md) {
            sectionHeader(title: "Куда нагрузка?", value: "Можно несколько")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: TempoTokens.Space.xs) {
                ForEach(AbsZone.allCases) { zone in
                    TempoChoiceCell(
                        title: zone.setupTitle,
                        isSelected: selectedZones.contains(zone),
                        selectedColor: zone == .full ? TempoTokens.ColorToken.ultramarine : TempoTokens.ColorToken.carbon,
                        isEnabled: !isGenerating,
                        accessibilityIdentifier: "setup.zone.\(zone.rawValue)",
                        action: { toggle(zone) }
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Зона нагрузки")
        .accessibilityHint("Можно выбрать несколько зон. Весь пресс отменяет выбор отдельных зон.")
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
                    .foregroundStyle(TempoTokens.ColorToken.signal)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("setup.generationError")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Интенсивность упражнений")
        .accessibilityHint("Выберите один вариант. Интенсивность меняет сложность упражнений.")
    }

    @ViewBuilder
    private var intensityChoices: some View {
        ForEach(WorkoutIntensity.allCases) { intensity in
            TempoChoiceCell(
                title: intensity.title,
                isSelected: selectedIntensity == intensity,
                isEnabled: !isGenerating,
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
            .foregroundStyle(TempoTokens.ColorToken.carbon)
    }

    private func sectionValue(_ value: String, alignment: TextAlignment) -> some View {
        Text(value)
            .font(.caption.weight(.semibold))
            .foregroundStyle(TempoTokens.ColorToken.muted)
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
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            let generatedPlan = generator.generate(
                targetDurationMin: setup.targetDurationMin,
                selectedZones: setup.canonicalZones,
                intensity: setup.intensity
            )
            isGenerating = false
            guard !generatedPlan.items.isEmpty else {
                generationError = "Не удалось собрать тренировку. Попробуйте другой вариант."
                return
            }
            plan = generatedPlan
            path.append(.plan)
        }
    }
}

#Preview("Настройка · 393×852") {
    ContentView()
        .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro"))
}

#Preview("Настройка · compact") {
    ContentView()
        .previewLayout(.fixed(width: 320, height: 700))
}
