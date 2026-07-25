import SwiftUI

struct FinishView: View {
    let plan: WorkoutPlan
    let elapsedSeconds: Int
    let completedCount: Int
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
                    .foregroundStyle(TempoTokens.ColorToken.vermilion)

                completionSymbol

                Text("Темп\nвыдержан.")
                    .font(.system(size: finishTitleSize, weight: .bold))
                    .foregroundStyle(TempoTokens.ColorToken.carbon)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityFocused($finishTitleFocused)
                Text("Все упражнения выполнены. Результат сохранён только на этом устройстве.")
                    .font(.body)
                    .foregroundStyle(TempoTokens.ColorToken.muted)
                    .fixedSize(horizontal: false, vertical: true)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: TempoTokens.Space.xl) {
                        result(value: WorkoutSessionStore.format(seconds: elapsedSeconds), label: "фактическое время")
                        Divider()
                            .overlay(TempoTokens.ColorToken.carbon.opacity(0.16))
                        result(value: "\(completedCount) / \(plan.items.count)", label: "упражнений")
                    }
                    VStack(alignment: .leading, spacing: TempoTokens.Space.md) {
                        result(value: WorkoutSessionStore.format(seconds: elapsedSeconds), label: "фактическое время")
                        Divider()
                            .overlay(TempoTokens.ColorToken.carbon.opacity(0.16))
                        result(value: "\(completedCount) / \(plan.items.count)", label: "упражнений")
                    }
                }
                .padding(.vertical, TempoTokens.Space.md)
                .overlay(alignment: .top) {
                    Rectangle().fill(TempoTokens.ColorToken.carbon.opacity(0.16)).frame(height: 1)
                }
                .overlay(alignment: .bottom) {
                    Rectangle().fill(TempoTokens.ColorToken.carbon.opacity(0.16)).frame(height: 1)
                }
            }
            .padding(.horizontal, TempoTokens.Space.outer)
            .padding(.top, TempoTokens.Space.huge)
            .padding(.bottom, 148)
        }
        .background(TempoTokens.ColorToken.chalk.ignoresSafeArea())
        .preferredColorScheme(.light)
        .onAppear { finishTitleFocused = true }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: TempoTokens.Space.xs) {
                TempoPrimaryButton(
                    title: "Повторить тренировку",
                    symbol: "arrow.counterclockwise",
                    layout: .balancedTrailingSymbol,
                    action: onRepeat
                )
                .accessibilityIdentifier("finish.repeat")
                Button("Настроить новую", action: onNewWorkout)
                    .font(.headline)
                    .foregroundStyle(TempoTokens.ColorToken.carbon)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .accessibilityIdentifier("finish.newWorkout")
            }
            .padding(.horizontal, TempoTokens.Space.outer)
            .padding(.vertical, TempoTokens.Space.sm)
            .background(TempoTokens.ColorToken.chalk)
        }
    }

    private var completionSymbol: some View {
        ZStack {
            Circle()
                .stroke(TempoTokens.ColorToken.vermilion, lineWidth: 18)
            Image(systemName: "checkmark")
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(TempoTokens.ColorToken.carbon)
        }
        .frame(width: 154, height: 154)
        .accessibilityHidden(true)
    }

    private func result(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: TempoTokens.Space.xxs) {
            Text(value)
                .font(.title2.weight(.semibold).monospacedDigit())
                .foregroundStyle(TempoTokens.ColorToken.carbon)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.caption)
                .foregroundStyle(TempoTokens.ColorToken.muted)
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
        completedCount: WorkoutPlan.preview.items.count,
        onRepeat: {},
        onNewWorkout: {}
    )
}
