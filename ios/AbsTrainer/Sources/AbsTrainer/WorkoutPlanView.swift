import SwiftUI

struct WorkoutPlanView: View {
    let plan: WorkoutPlan
    @ObservedObject var audioPreferences: WorkoutAudioPreferences
    let onEditAudio: () -> Void
    let onOpenExercise: (String) -> Void
    let onStart: () -> Void
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .largeTitle) private var planTitleSize = 36
    @AccessibilityFocusState private var planTitleFocused: Bool

    private var validationMode: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-ValidationMode")
        #else
        false
        #endif
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TempoTokens.Space.xl) {
                topBar
                summary
                audioSummary
                LazyVStack(spacing: 0) {
                    ForEach(plan.items) { item in
                        workoutRow(item)
                        if item.order < plan.items.count, item.restAfterSec > 0 {
                            restRow(after: item)
                        }
                    }
                }
            }
            .padding(.horizontal, TempoTokens.Space.outer)
            .padding(.top, TempoTokens.Space.xs)
            .padding(.bottom, 88)
        }
        .accessibilityIdentifier("plan.scroll")
        .background(TempoTokens.ColorToken.auditCanvas.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            TempoPrimaryButton(title: "Начать тренировку", style: .auditPrimary, action: onStart)
                .padding(.horizontal, TempoTokens.Space.outer)
                .padding(.vertical, TempoTokens.Space.sm)
                .background(TempoTokens.ColorToken.auditCanvas)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onAppear { planTitleFocused = true }
    }

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.semibold))
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Назад к настройке")
            Spacer()
            Text("Ваш план")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Color.clear.frame(width: 48, height: 48)
        }
        .foregroundStyle(TempoTokens.ColorToken.auditText)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: TempoTokens.Space.md) {
            Text("Сегодня · \(zonesTitle)")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(TempoTokens.ColorToken.auditPrimary)
            Text("План на \(plan.targetDurationMin) минут")
                .font(.system(size: planTitleSize, weight: .bold))
                .foregroundStyle(TempoTokens.ColorToken.auditText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityFocused($planTitleFocused)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: TempoTokens.Space.xs) {
                    metaChip("\(plan.items.count) упражнений")
                    metaChip("\(max(plan.items.count - 1, 0)) пауз")
                    metaChip(plan.intensity.title)
                }
                VStack(alignment: .leading, spacing: TempoTokens.Space.xs) {
                    metaChip("\(plan.items.count) упражнений")
                    metaChip("\(max(plan.items.count - 1, 0)) пауз")
                    metaChip(plan.intensity.title)
                }
            }
            TempoRail(total: max(plan.items.count * 2 - 1, 1), current: nil)
                .padding(.top, TempoTokens.Space.xs)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(plan.targetDurationMin) минут, \(zonesTitle.lowercased()), \(plan.intensity.planTitle)")
        .accessibilityIdentifier("plan.summary")
    }

    private func metaChip(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, TempoTokens.Space.sm)
            .frame(minHeight: 32)
            .foregroundStyle(TempoTokens.ColorToken.auditText)
            .background(TempoTokens.ColorToken.auditInteractive)
            .clipShape(Capsule())
    }

    private var audioSummary: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: TempoTokens.Space.md) {
                audioSummaryText
                Spacer(minLength: TempoTokens.Space.xs)
                audioEditButton
            }
            VStack(alignment: .leading, spacing: TempoTokens.Space.sm) {
                audioSummaryText
                audioEditButton
            }
        }
        .padding(.vertical, TempoTokens.Space.md)
        .overlay(alignment: .top) {
            Rectangle().fill(TempoTokens.ColorToken.auditMuted.opacity(0.35)).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(TempoTokens.ColorToken.auditMuted.opacity(0.35)).frame(height: 1)
        }
    }

    private var audioSummaryText: some View {
        VStack(alignment: .leading, spacing: TempoTokens.Space.xxs) {
            Text(audioPreferences.musicEnabled
                 ? "Музыка · \(Int((audioPreferences.musicVolume * 100).rounded()))%"
                 : "Музыка выключена")
                .font(.body.weight(.semibold))
            Text(audioPreferences.voiceCoachEnabled
                 ? "Голосовой тренер включён"
                 : "Голосовой тренер выключен")
                .font(.caption)
                .foregroundStyle(TempoTokens.ColorToken.auditMuted)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("plan.audio.summary")
    }

    private var audioEditButton: some View {
        Button("Изменить", action: onEditAudio)
            .font(.body.weight(.semibold))
            .frame(minHeight: TempoTokens.Size.minimumTap)
            .accessibilityLabel("Изменить настройки звука тренировки")
            .accessibilityIdentifier("plan.audio.edit")
    }

    private func workoutRow(_ item: WorkoutItem) -> some View {
        Button { onOpenExercise(item.exercise.id) } label: {
            HStack(alignment: .top, spacing: TempoTokens.Space.md) {
                Text(String(format: "%02d", item.order))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(TempoTokens.ColorToken.auditPrimary)
                    .frame(width: 28, alignment: .leading)
                VStack(alignment: .leading, spacing: TempoTokens.Space.xxs) {
                    Text(item.exercise.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(TempoTokens.ColorToken.auditText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.68)
                        .allowsTightening(true)
                        .layoutPriority(1)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("plan.row.title.\(item.exercise.id)")
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: TempoTokens.Space.xs) {
                            workoutZone(item)
                            Spacer(minLength: TempoTokens.Space.xs)
                            workoutPrescription(item)
                        }
                        VStack(alignment: .leading, spacing: TempoTokens.Space.xxs) {
                            workoutZone(item)
                            workoutPrescription(item)
                        }
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TempoTokens.ColorToken.auditMuted)
                    .accessibilityHidden(true)
            }
            .padding(TempoTokens.Space.md)
            .background(TempoTokens.ColorToken.auditInteractive)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: validationMode ? .contain : .combine)
        .accessibilityLabel(workoutRowAccessibilityLabel(item))
        .accessibilityHint("Открывает технику и упрощённый вариант")
        .accessibilityIdentifier("plan.row.exercise.\(item.exercise.id)")
    }

    private func workoutZone(_ item: WorkoutItem) -> some View {
        Text(item.exercise.zones.first?.title ?? "Весь пресс")
            .font(.caption)
            .foregroundStyle(TempoTokens.ColorToken.auditMuted)
    }

    private func workoutPrescription(_ item: WorkoutItem) -> some View {
        Text(prescriptionTitle(item.prescription))
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .foregroundStyle(TempoTokens.ColorToken.auditPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func restRow(after item: WorkoutItem) -> some View {
        let next = plan.items[item.order]
        return HStack(spacing: TempoTokens.Space.md) {
            Image(systemName: "pause.fill").accessibilityHidden(true)
            VStack(alignment: .leading, spacing: TempoTokens.Space.xxs) {
                Text("ОТДЫХ").font(.caption.weight(.bold))
                Text("Дальше: \(next.exercise.title)")
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: TempoTokens.Space.xs)
            Text("\(item.restAfterSec) сек")
                .font(.subheadline.weight(.semibold).monospacedDigit())
        }
        .foregroundStyle(TempoTokens.ColorToken.auditRest)
        .padding(.horizontal, TempoTokens.Space.md)
        .frame(minHeight: TempoTokens.Size.minimumTap)
        .background(TempoTokens.ColorToken.auditRest.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Отдых \(item.restAfterSec) секунд. Дальше \(next.exercise.title)")
        .accessibilityIdentifier("plan.row.rest.\(item.order)")
    }

    private func prescriptionTitle(_ prescription: WorkoutPrescription) -> String {
        switch prescription {
        case let .timeBased(duration):
            return "\(duration) сек"
        case let .repetitionBased(target, unit, _, _):
            return unit == .perSideAlternating
                ? "\(target) повторов · по \(target / 2)"
                : "\(target) повторов"
        }
    }

    private func workoutRowAccessibilityLabel(_ item: WorkoutItem) -> String {
        let prescription: String
        switch item.prescription {
        case let .timeBased(duration):
            prescription = "Удержание, \(duration) секунд"
        case let .repetitionBased(target, unit, _, _):
            prescription = unit == .perSideAlternating
                ? "\(target) повторов, по \(target / 2) на каждую сторону; каждое движение одной стороны считается следующим повтором"
                : "\(target) повторов, полный цикл движения считается одним повтором"
        }
        return "\(item.order). \(item.exercise.title). \(prescription). Отдых \(item.restAfterSec) секунд"
    }

    private var zonesTitle: String {
        if plan.selectedZones.contains(.full) { return AbsZone.full.title }
        return plan.selectedZones.map(\.title).joined(separator: ", ")
    }
}

#Preview("План") {
    NavigationStack {
        WorkoutPlanView(
            plan: .preview,
            audioPreferences: WorkoutAudioPreferences(),
            onEditAudio: {},
            onOpenExercise: { _ in },
            onStart: {}
        )
    }
}
