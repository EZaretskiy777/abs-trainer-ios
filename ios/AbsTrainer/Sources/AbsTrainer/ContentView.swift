import SwiftUI
import UIKit

struct ContentView: View {
    private enum Route: Hashable {
        case plan
        case session
    }

    @State private var selectedDuration = 10
    @State private var selectedZones: Set<AbsZone> = [.full]
    @State private var plan: WorkoutPlan?
    @State private var path: [Route] = []
    @State private var isGenerating = false
    @ScaledMetric(relativeTo: .largeTitle) private var displayTitleSize = 42
    @AccessibilityFocusState private var setupTitleFocused: Bool

    private let durations = [5, 10, 15]
    private let generator = WorkoutGenerator()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: TempoTokens.Space.xxl) {
                    header
                    durationPicker
                    zonePicker
                }
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
            HStack(spacing: TempoTokens.Space.xs) {
                ForEach(durations, id: \.self) { minutes in
                    Button {
                        selectedDuration = minutes
                    } label: {
                        VStack(spacing: TempoTokens.Space.xxs) {
                            Text(String(format: "%02d", minutes))
                                .font(.title2.weight(.semibold).monospacedDigit())
                            Text("минут")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity, minHeight: TempoTokens.Size.durationChoice)
                        .foregroundStyle(selectedDuration == minutes ? Color.white : TempoTokens.ColorToken.carbon)
                        .background(selectedDuration == minutes ? TempoTokens.ColorToken.carbon : Color.clear)
                        .overlay {
                            RoundedRectangle(cornerRadius: TempoTokens.Radius.small, style: .continuous)
                                .stroke(TempoTokens.ColorToken.carbon.opacity(0.18))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: TempoTokens.Radius.small, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(minutes) минут")
                    .accessibilityAddTraits(selectedDuration == minutes ? .isSelected : [])
                }
            }
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
                        action: { toggle(zone) }
                    )
                }
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
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            plan = generator.generate(
                targetDurationMin: selectedDuration,
                selectedZones: Array(selectedZones)
            )
            isGenerating = false
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
