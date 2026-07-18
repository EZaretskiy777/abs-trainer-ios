import SwiftUI

struct WorkoutPlanView: View {
    let plan: WorkoutPlan

    var body: some View {
        ZStack {
            DesignSystem.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {
                Text("Ваш план")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                Text("\(plan.items.count) упражнений · ~\(plan.totalDurationSec / 60) мин")
                    .foregroundStyle(DesignSystem.mutedText)

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(plan.items) { item in
                            PremiumCard {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("\(item.order). \(item.exercise.title)")
                                            .font(.headline)
                                        Text("\(item.durationSec) сек · отдых \(item.restAfterSec) сек")
                                            .foregroundStyle(DesignSystem.mutedText)
                                    }
                                    Spacer()
                                    if item.exercise.isPlaceholderMedia {
                                        Text("3D soon")
                                            .font(.caption.bold())
                                            .padding(8)
                                            .background(Color.orange.opacity(0.25))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                }

                NavigationLink {
                    ExercisePlayerView(plan: plan, index: 0)
                } label: {
                    Text("Start")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(DesignSystem.accent)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .padding(24)
        }
    }
}
