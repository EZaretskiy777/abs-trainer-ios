import SwiftUI

struct FinishView: View {
    let plan: WorkoutPlan

    var body: some View {
        ZStack {
            DesignSystem.background.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Готово")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                Text("Вы выполнили \(plan.items.count) упражнений")
                    .foregroundStyle(DesignSystem.mutedText)
                Text("~\(plan.totalDurationSec / 60) минут core work")
                    .font(.title2.bold())
                    .padding()
                    .background(DesignSystem.card)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .padding(24)
        }
    }
}
