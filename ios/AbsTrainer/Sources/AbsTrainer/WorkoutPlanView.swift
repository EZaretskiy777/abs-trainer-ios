import SwiftUI

struct WorkoutPlanView: View {
    let plan: WorkoutPlan
    let onStart: () -> Void
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .largeTitle) private var planTitleSize = 36
    @AccessibilityFocusState private var planTitleFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TempoTokens.Space.xl) {
                topBar
                summary
                LazyVStack(spacing: 0) {
                    ForEach(plan.items) { item in
                        workoutRow(item)
                    }
                }
            }
            .padding(.horizontal, TempoTokens.Space.outer)
            .padding(.top, TempoTokens.Space.xs)
            .padding(.bottom, 88)
        }
        .background(TempoTokens.ColorToken.chalk.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            TempoPrimaryButton(title: "Начать тренировку", action: onStart)
                .padding(.horizontal, TempoTokens.Space.outer)
                .padding(.vertical, TempoTokens.Space.sm)
                .background(TempoTokens.ColorToken.chalk)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.light)
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
        .foregroundStyle(TempoTokens.ColorToken.carbon)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: TempoTokens.Space.md) {
            Text("Сегодня · \(zonesTitle)")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(TempoTokens.ColorToken.vermilion)
            Text("\(plan.targetDurationMin) минут\nбез спешки")
                .font(.system(size: planTitleSize, weight: .bold))
                .foregroundStyle(TempoTokens.ColorToken.carbon)
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
            .background(TempoTokens.ColorToken.chalkSubtle)
            .clipShape(Capsule())
    }

    private func workoutRow(_ item: WorkoutItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: TempoTokens.Space.md) {
            Text(String(format: "%02d", item.order))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(TempoTokens.ColorToken.vermilion)
                .frame(width: 28, alignment: .leading)

            VStack(alignment: .leading, spacing: TempoTokens.Space.xxs) {
                Text(item.exercise.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(TempoTokens.ColorToken.carbon)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(item.exercise.zones.first?.title ?? "Весь пресс") · отдых \(item.restAfterSec) сек")
                    .font(.caption)
                    .foregroundStyle(TempoTokens.ColorToken.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: TempoTokens.Space.xs)
            Text(WorkoutSessionStore.format(seconds: item.durationSec))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(TempoTokens.ColorToken.carbon)
                .fixedSize()
        }
        .padding(.vertical, TempoTokens.Space.md)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(TempoTokens.ColorToken.carbon.opacity(0.16))
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var zonesTitle: String {
        if plan.selectedZones.contains(.full) { return AbsZone.full.title }
        return plan.selectedZones.map(\.title).joined(separator: ", ")
    }
}

#Preview("План") {
    NavigationStack {
        WorkoutPlanView(plan: .preview, onStart: {})
    }
}
