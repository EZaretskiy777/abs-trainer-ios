import SwiftUI

struct FinishView: View {
    let plan: WorkoutPlan
    let elapsedSeconds: Int
    let completedCount: Int
    let skippedCount: Int
    let onRepeat: () -> Void
    let onNewWorkout: () -> Void
    @ScaledMetric(relativeTo: .largeTitle) private var finishTitleSize = 42
    @AccessibilityFocusState private var finishTitleFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TempoTokens.Space.xl) {
                Text("Тренировка завершена")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(TempoTokens.ColorToken.auditPrimary)
                    .accessibilityIdentifier("finish.eyebrow")

                completionSymbol

                Text("Отличная работа")
                    .font(.system(size: finishTitleSize, weight: .bold))
                    .foregroundStyle(TempoTokens.ColorToken.auditText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("finish.title")
                    .accessibilityFocused($finishTitleFocused)
                Text(skippedCount == 0
                     ? "Выполнено \(completedCount) из \(plan.items.count) упражнений. Результат сохранён только на этом устройстве."
                     : "Выполнено \(completedCount) из \(plan.items.count), пропущено \(skippedCount). Результат сохранён только на этом устройстве.")
                    .font(.body)
                    .foregroundStyle(TempoTokens.ColorToken.auditMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("finish.body")

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: TempoTokens.Space.xl) {
                        result(value: WorkoutSessionStore.format(seconds: elapsedSeconds), label: "фактическое время")
                            .accessibilityIdentifier("finish.elapsedResult")
                        Divider()
                            .overlay(TempoTokens.ColorToken.auditMuted.opacity(0.35))
                        result(value: "\(completedCount) / \(plan.items.count)", label: "упражнений")
                            .accessibilityIdentifier("finish.completedResult")
                    }
                    VStack(alignment: .leading, spacing: TempoTokens.Space.md) {
                        result(value: WorkoutSessionStore.format(seconds: elapsedSeconds), label: "фактическое время")
                            .accessibilityIdentifier("finish.elapsedResult")
                        Divider()
                            .overlay(TempoTokens.ColorToken.auditMuted.opacity(0.35))
                        result(value: "\(completedCount) / \(plan.items.count)", label: "упражнений")
                            .accessibilityIdentifier("finish.completedResult")
                    }
                }
                .padding(.vertical, TempoTokens.Space.md)
                .overlay(alignment: .top) {
                    Rectangle().fill(TempoTokens.ColorToken.auditMuted.opacity(0.35)).frame(height: 1)
                }
                .overlay(alignment: .bottom) {
                    Rectangle().fill(TempoTokens.ColorToken.auditMuted.opacity(0.35)).frame(height: 1)
                }

                Text("Пропущено: \(skippedCount)")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(TempoTokens.ColorToken.auditMuted)
                    .accessibilityIdentifier("finish.skippedResult")

                Text("Фокус: \(plan.selectedZones.map(\.title).joined(separator: ", "))")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(TempoTokens.ColorToken.auditText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("finish.zonesResult")
            }
            .padding(.horizontal, TempoTokens.Space.outer)
            .padding(.top, TempoTokens.Space.huge)
            .padding(.bottom, 148)
        }
        .background(TempoTokens.ColorToken.auditCanvas.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear { finishTitleFocused = true }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: TempoTokens.Space.xs) {
                TempoPrimaryButton(
                    title: "Повторить тренировку",
                    symbol: "arrow.counterclockwise",
                    layout: .balancedTrailingSymbol,
                    style: .auditPrimary,
                    action: onRepeat
                )
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .accessibilityIdentifier("finish.repeat")
                Button(action: onNewWorkout) {
                    Text("Настроить новую")
                        .font(.headline)
                        .foregroundStyle(TempoTokens.ColorToken.auditText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .contentShape(Rectangle())
                }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("finish.newWorkout")
            }
            .padding(.horizontal, TempoTokens.Space.outer)
            .padding(.vertical, TempoTokens.Space.sm)
            .background(TempoTokens.ColorToken.auditCanvas)
        }
    }

    private var completionSymbol: some View {
        ZStack {
            Circle()
                .stroke(TempoTokens.ColorToken.auditPrimary, lineWidth: 12)
            Image(systemName: "checkmark")
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(TempoTokens.ColorToken.auditText)
        }
        .frame(width: 154, height: 154)
        .accessibilityHidden(true)
    }

    private func result(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: TempoTokens.Space.xxs) {
            Text(value)
                .font(.title2.weight(.semibold).monospacedDigit())
                .foregroundStyle(TempoTokens.ColorToken.auditText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.caption)
                .foregroundStyle(TempoTokens.ColorToken.auditMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Завершение") {
    FinishView(
        plan: .preview,
        elapsedSeconds: 604,
        completedCount: 9,
        skippedCount: 1,
        onRepeat: {},
        onNewWorkout: {}
    )
}
