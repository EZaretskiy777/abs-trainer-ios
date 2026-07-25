import SwiftUI

enum TempoTokens {
    struct ContrastColor {
        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }

        var color: Color {
            Color(red: red, green: green, blue: blue).opacity(alpha)
        }

        func contrastRatio(over background: ContrastColor) -> Double {
            let foreground = composited(over: background)
            let lighter = max(foreground.relativeLuminance, background.relativeLuminance)
            let darker = min(foreground.relativeLuminance, background.relativeLuminance)
            return (lighter + 0.05) / (darker + 0.05)
        }

        private func composited(over background: ContrastColor) -> ContrastColor {
            ContrastColor(
                red: alpha * red + (1 - alpha) * background.red,
                green: alpha * green + (1 - alpha) * background.green,
                blue: alpha * blue + (1 - alpha) * background.blue
            )
        }

        private var relativeLuminance: Double {
            0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        }

        private func linear(_ component: Double) -> Double {
            component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }
    }

    enum SemanticColor {
        static let activeBackground = ContrastColor(red: 0.090, green: 0.090, blue: 0.078)
        static let restBackground = ContrastColor(red: 0.161, green: 0.275, blue: 0.776)
        static let inversePrimary = ContrastColor(red: 1, green: 1, blue: 1)
        static let inverseSecondary = ContrastColor(red: 1, green: 1, blue: 1, alpha: 0.85)
        static let inverseDivider = ContrastColor(red: 1, green: 1, blue: 1, alpha: 0.55)
        static let inverseControlBorder = ContrastColor(red: 1, green: 1, blue: 1, alpha: 0.85)
    }

    enum ColorToken {
        static let chalk = Color("TempoChalk")
        static let chalkSubtle = Color("TempoChalkSubtle")
        static let carbon = Color("TempoCarbon")
        static let muted = Color("TempoMuted")
        static let vermilion = Color("TempoVermilion")
        static let ultramarine = Color("TempoUltramarine")
        static let moss = Color("TempoMoss")
        static let signal = Color("TempoSignal")
    }

    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let huge: CGFloat = 40
        static let outer: CGFloat = 20
    }

    enum Radius {
        static let small: CGFloat = 12
        static let button: CGFloat = 20
        static let media: CGFloat = 28
    }

    enum Size {
        static let minimumTap: CGFloat = 44
        static let iconControl: CGFloat = 48
        static let primaryControl: CGFloat = 58
        static let pauseControl: CGFloat = 58
        static let durationChoice: CGFloat = 72
        static let zoneChoice: CGFloat = 62
        static let compactMediaHeight: CGFloat = 230
        static let regularMediaHeight: CGFloat = 286
    }
}

struct TempoPrimaryButton: View {
    let title: String
    var symbol: String? = "arrow.right"
    var isLoading = false
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: TempoTokens.Space.sm) {
                if isLoading {
                    ProgressView().tint(.white)
                }
                Text(isLoading ? "Собираем…" : title)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let symbol, !isLoading {
                    Image(systemName: symbol)
                        .font(.headline.weight(.semibold))
                }
            }
            .padding(.horizontal, TempoTokens.Space.lg)
            .frame(maxWidth: .infinity, minHeight: TempoTokens.Size.primaryControl)
            .foregroundStyle(.white)
            .background(TempoTokens.ColorToken.carbon)
            .clipShape(RoundedRectangle(cornerRadius: TempoTokens.Radius.button, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1 : 0.38)
        .accessibilityLabel(isLoading ? "Собираем тренировку" : title)
    }
}

struct TempoChoiceCell: View {
    let title: String
    let isSelected: Bool
    var selectedColor = TempoTokens.ColorToken.carbon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: TempoTokens.Space.xs) {
                VStack(alignment: .leading, spacing: TempoTokens.Space.xxs) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if isSelected {
                        Text("Выбрано")
                            .font(.caption2.weight(.bold))
                            .textCase(.uppercase)
                    }
                }
                Spacer(minLength: TempoTokens.Space.xs)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, TempoTokens.Space.md)
            .frame(maxWidth: .infinity, minHeight: TempoTokens.Size.zoneChoice, alignment: .leading)
            .foregroundStyle(isSelected ? Color.white : TempoTokens.ColorToken.carbon)
            .background(isSelected ? selectedColor : Color.clear)
            .overlay {
                RoundedRectangle(cornerRadius: TempoTokens.Radius.small, style: .continuous)
                    .stroke(isSelected ? selectedColor : TempoTokens.ColorToken.carbon.opacity(0.18), lineWidth: isSelected ? 2 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: TempoTokens.Radius.small, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isSelected ? "Выбрано" : "Не выбрано")
    }
}

struct TempoRail: View {
    let total: Int
    var current: Int?

    var body: some View {
        Group {
            if current == nil {
                planRail
            } else {
                playerRail
            }
        }
        .frame(minHeight: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var playerRail: some View {
        HStack(spacing: TempoTokens.Space.xxs) {
            ForEach(0..<max(total, 1), id: \.self) { index in
                Capsule()
                    .fill(color(for: index))
                    .frame(maxWidth: .infinity)
                    .frame(height: 5)
            }
        }
        .frame(height: 5)
    }

    private var planRail: some View {
        GeometryReader { proxy in
            let count = max(total, 1)
            let workCount = (count + 1) / 2
            let restCount = count / 2
            let gaps = CGFloat(max(count - 1, 0)) * TempoTokens.Space.xxs
            let unit = max(0, proxy.size.width - gaps) / (CGFloat(workCount) + CGFloat(restCount) * 0.35)
            HStack(spacing: TempoTokens.Space.xxs) {
                ForEach(0..<count, id: \.self) { index in
                    Capsule()
                        .fill(color(for: index))
                        .frame(width: unit * (index.isMultiple(of: 2) ? 1 : 0.35), height: 7)
                }
            }
        }
        .frame(height: 8)
    }

    private func color(for index: Int) -> Color {
        guard let current else {
            return index.isMultiple(of: 2)
                ? TempoTokens.ColorToken.carbon
                : TempoTokens.ColorToken.ultramarine
        }
        if index < current { return TempoTokens.ColorToken.vermilion }
        if index == current { return .white }
        return .white.opacity(0.24)
    }

    private var accessibilityText: String {
        guard let current else { return "Последовательность тренировки, \(total) сегментов" }
        return "Шаг \(current + 1) из \(total)"
    }
}

struct ExerciseMediaAperture: View {
    let exercise: Exercise
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack {
            TempoTokens.ColorToken.chalkSubtle

            Image(systemName: "figure.core.training")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(TempoTokens.ColorToken.vermilion)

            Text("Демо движения")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(TempoTokens.ColorToken.carbon)
                .padding(TempoTokens.Space.sm)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Text("Поясница прижата · локоть тянется к колену")
                .font(.caption.weight(.semibold))
                .foregroundStyle(TempoTokens.ColorToken.carbon)
                .fixedSize(horizontal: false, vertical: true)
                .padding(TempoTokens.Space.sm)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .frame(maxWidth: .infinity)
        .frame(height: dynamicTypeSize.isAccessibilitySize ? TempoTokens.Size.compactMediaHeight : TempoTokens.Size.regularMediaHeight)
        .clipShape(RoundedRectangle(cornerRadius: TempoTokens.Radius.media, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Демонстрация упражнения недоступна. \(exercise.title)")
    }
}
