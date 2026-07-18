import SwiftUI

struct ExercisePlayerView: View {
    let plan: WorkoutPlan
    let index: Int

    @State private var remaining: Int
    @State private var isRunning = true

    init(plan: WorkoutPlan, index: Int) {
        self.plan = plan
        self.index = index
        _remaining = State(initialValue: plan.items[index].durationSec)
    }

    var body: some View {
        let item = plan.items[index]

        ZStack {
            DesignSystem.background.ignoresSafeArea()
            VStack(spacing: 24) {
                Text(item.exercise.title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))

                placeholderMedia(title: item.exercise.mediaName)

                Text("\(remaining)")
                    .font(.system(size: 76, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Button(isRunning ? "Pause" : "Resume") {
                    isRunning.toggle()
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(DesignSystem.secondaryAccent)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                if index + 1 < plan.items.count {
                    NavigationLink("Next") {
                        ExercisePlayerView(plan: plan, index: index + 1)
                    }
                    .foregroundStyle(DesignSystem.accent)
                } else {
                    NavigationLink("Finish") {
                        FinishView(plan: plan)
                    }
                    .foregroundStyle(DesignSystem.accent)
                }
            }
            .padding(24)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard isRunning, remaining > 0 else { return }
            remaining -= 1
        }
    }

    private func placeholderMedia(title: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(DesignSystem.card)
                .frame(height: 300)
            VStack(spacing: 16) {
                Image(systemName: "figure.core.training")
                    .font(.system(size: 72))
                    .foregroundStyle(DesignSystem.accent)
                Text("3D placeholder")
                    .font(.headline)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.mutedText)
            }
        }
    }
}
