import SwiftUI

struct ContentView: View {
    @State private var selectedDuration = 10
    @State private var selectedZones: Set<AbsZone> = [.full]
    @State private var plan: WorkoutPlan?

    private let durations = [5, 10, 15]
    private let generator = WorkoutGenerator()

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        durationPicker
                        zonePicker
                        generateButton
                        if let plan {
                            NavigationLink {
                                WorkoutPlanView(plan: plan)
                            } label: {
                                Text("Открыть план")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(DesignSystem.accent)
                                    .foregroundStyle(.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("ABS Trainer")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Core workout")
                .font(.system(size: 42, weight: .bold, design: .rounded))
            Text("Выберите время и зоны пресса — мы соберём тренировку под вас.")
                .foregroundStyle(DesignSystem.mutedText)
        }
    }

    private var durationPicker: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Время").font(.title2.bold())
                HStack {
                    ForEach(durations, id: \.self) { minutes in
                        Button("\(minutes) мин") { selectedDuration = minutes }
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(selectedDuration == minutes ? DesignSystem.secondaryAccent : Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
    }

    private var zonePicker: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Зоны пресса").font(.title2.bold())
                ForEach(AbsZone.allCases) { zone in
                    Button {
                        toggle(zone)
                    } label: {
                        HStack {
                            Text(zone.title)
                            Spacer()
                            Image(systemName: selectedZones.contains(zone) ? "checkmark.circle.fill" : "circle")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    private var generateButton: some View {
        Button {
            plan = generator.generate(targetDurationMin: selectedDuration, selectedZones: Array(selectedZones))
        } label: {
            Text("Generate workout")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(DesignSystem.accent)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func toggle(_ zone: AbsZone) {
        if selectedZones.contains(zone) {
            selectedZones.remove(zone)
        } else {
            selectedZones.insert(zone)
        }
        if selectedZones.isEmpty { selectedZones.insert(.full) }
    }
}
