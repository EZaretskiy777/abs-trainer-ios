import SwiftUI
import UIKit

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
        static let inverseSecondary = ContrastColor(red: 1, green: 1, blue: 1, alpha: 0.72)
        static let inverseDivider = ContrastColor(red: 1, green: 1, blue: 1, alpha: 0.30)
        static let inverseControlBorder = ContrastColor(red: 1, green: 1, blue: 1, alpha: 0.50)
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
        static let dialRegular: CGFloat = 216
        static let dialCompact: CGFloat = 184
        static let dialLandscape: CGFloat = 168
        static let dialHandle: CGFloat = 24
    }
}

struct TempoPrimaryButton: View {
    enum Layout {
        case leading
        case balancedTrailingSymbol
    }

    let title: String
    var symbol: String? = "arrow.right"
    var isLoading = false
    var isEnabled = true
    var layout: Layout = .leading
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if layout == .balancedTrailingSymbol {
                    HStack(spacing: 0) {
                        Color.clear.frame(
                            width: TempoTokens.Size.minimumTap,
                            height: TempoTokens.Size.minimumTap
                        )
                        Text(isLoading ? "Собираем…" : title)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .center)
                        Group {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else if let symbol {
                                Image(systemName: symbol)
                                    .font(.system(size: 18, weight: .semibold))
                                    .accessibilityHidden(true)
                            }
                        }
                        .frame(width: TempoTokens.Size.minimumTap, height: TempoTokens.Size.minimumTap)
                    }
                } else {
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
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
            .padding(.horizontal, layout == .balancedTrailingSymbol ? TempoTokens.Space.xs : TempoTokens.Space.lg)
            .padding(.vertical, layout == .balancedTrailingSymbol ? TempoTokens.Space.sm : 0)
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

struct InverseIconButton: View {
    let symbol: String
    let size: CGFloat
    let accessibilityLabel: String
    let action: () -> Void

    @Environment(\.colorSchemeContrast) private var accessibilityContrast

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size >= TempoTokens.Size.pauseControl ? 17 : 16, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: size, height: size)
                .contentShape(Circle())
                .background(Color.white.opacity(0.001))
                .overlay {
                    Circle().stroke(
                        Color.white.opacity(accessibilityContrast == .increased ? 1 : 0.50),
                        lineWidth: accessibilityContrast == .increased ? 2 : 1
                    )
                }
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .tint(.white)
        .accessibilityLabel(accessibilityLabel)
    }
}

enum SessionConfirmationVariant: Equatable {
    case exitSession
    case finishLastExerciseEarly

    var title: String {
        switch self {
        case .exitSession: return "Завершить тренировку?"
        case .finishLastExerciseEarly: return "Завершить последнее упражнение?"
        }
    }

    var message: String {
        switch self {
        case .exitSession: return "Прогресс этой сессии не сохранится."
        case .finishLastExerciseEarly: return "До конца упражнения ещё осталось время."
        }
    }

    var cancelTitle: String {
        switch self {
        case .exitSession: return "Продолжить тренировку"
        case .finishLastExerciseEarly: return "Продолжить упражнение"
        }
    }

    var destructiveTitle: String {
        switch self {
        case .exitSession: return "Завершить тренировку"
        case .finishLastExerciseEarly: return "Завершить сейчас"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .exitSession: return "session.confirmation.exit"
        case .finishLastExerciseEarly: return "session.confirmation.finishEarly"
        }
    }
}

struct SessionConfirmationModal: View {
    let variant: SessionConfirmationVariant
    let isTransitioning: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @Environment(\.colorSchemeContrast) private var accessibilityContrast
    @AccessibilityFocusState private var titleFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.64)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            ScrollView {
                VStack(spacing: TempoTokens.Space.md) {
                    Image(systemName: "stop.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(TempoTokens.ColorToken.signal)
                        .frame(width: 56, height: 56)
                        .background(TempoTokens.ColorToken.chalkSubtle)
                        .clipShape(Circle())
                        .accessibilityHidden(true)

                    Text(variant.title)
                        .font(.title2.bold())
                        .foregroundStyle(TempoTokens.ColorToken.carbon)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("\(variant.accessibilityIdentifier).title")
                        .accessibilityFocused($titleFocused)
                        .accessibilitySortPriority(4)

                    Text(variant.message)
                        .font(.body)
                        .foregroundStyle(TempoTokens.ColorToken.muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("\(variant.accessibilityIdentifier).message")
                        .accessibilitySortPriority(3)

                    VStack(spacing: TempoTokens.Space.xs) {
                        Button(variant.cancelTitle, action: onCancel)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .padding(.horizontal, TempoTokens.Space.md)
                            .background(TempoTokens.ColorToken.carbon)
                            .clipShape(RoundedRectangle(cornerRadius: TempoTokens.Radius.button, style: .continuous))
                            .accessibilityIdentifier("\(variant.accessibilityIdentifier).cancel")
                            .accessibilitySortPriority(2)

                        Button(role: .destructive, action: onConfirm) {
                            Text(variant.destructiveTitle)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .padding(.horizontal, TempoTokens.Space.md)
                                .foregroundStyle(TempoTokens.ColorToken.signal)
                                .overlay {
                                    RoundedRectangle(cornerRadius: TempoTokens.Radius.button, style: .continuous)
                                        .stroke(
                                            TempoTokens.ColorToken.signal,
                                            lineWidth: accessibilityContrast == .increased ? 2 : 1
                                        )
                                }
                        }
                        .accessibilityIdentifier("\(variant.accessibilityIdentifier).destructive")
                        .accessibilitySortPriority(1)
                    }
                    .buttonStyle(.plain)
                    .disabled(isTransitioning)
                    .opacity(isTransitioning ? 0.38 : 1)
                }
                .padding(TempoTokens.Space.xl)
            }
            .frame(maxWidth: 353, maxHeight: 520)
            .background(TempoTokens.ColorToken.chalk)
            .clipShape(RoundedRectangle(cornerRadius: TempoTokens.Radius.media, style: .continuous))
            .padding(TempoTokens.Space.outer)
            .shadow(color: .black.opacity(0.18), radius: 24, y: 16)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityIdentifier(variant.accessibilityIdentifier)
            .accessibilityAction(.escape, onCancel)
        }
        .onAppear { titleFocused = true }
    }
}

enum DurationDialContract {
    static let allowedValues = [5, 10, 15]

    static func nearestIndex(to value: Int, in values: [Int] = allowedValues) -> Int {
        values.indices.min { lhs, rhs in
            let lhsDistance = distance(from: value, to: values[lhs])
            let rhsDistance = distance(from: value, to: values[rhs])
            return lhsDistance == rhsDistance ? lhs < rhs : lhsDistance < rhsDistance
        } ?? 0
    }

    private static func distance(from value: Int, to candidate: Int) -> UInt {
        if value >= candidate { return UInt(value - candidate) }
        if value >= 0 { return UInt(candidate - value) }
        return value.magnitude + UInt(candidate)
    }

    static func index(for fraction: CGFloat, count: Int) -> Int {
        guard count > 1 else { return 0 }
        let scaled = max(0, min(1, fraction)) * CGFloat(count - 1)
        return Int(floor(scaled + 0.499_999))
    }
}

struct TempoDurationDial: View {
    @Binding var value: Int
    var allowedValues = DurationDialContract.allowedValues
    var isEnabled = true
    var onCommit: ((Int) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var accessibilityContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var dragStartedInArc = false

    private var validationMode: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-ValidationMode")
        #else
        false
        #endif
    }

    private var currentIndex: Int {
        DurationDialContract.nearestIndex(to: value, in: allowedValues)
    }

    private var progress: CGFloat {
        guard allowedValues.count > 1 else { return 0 }
        return CGFloat(currentIndex) / CGFloat(allowedValues.count - 1)
    }

    var body: some View {
        Group {
            if verticalSizeClass == .compact {
                HStack(spacing: TempoTokens.Space.md) {
                    dialViewport
                    stepControls(axis: .vertical)
                }
            } else {
                VStack(spacing: TempoTokens.Space.xs) {
                    dialViewport
                    stepControls(axis: .horizontal)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topLeading) {
            if validationMode {
                validationAdjustmentControls
            }
        }
        .onAppear { normalizeValueIfNeeded() }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
    }

    private var dialViewport: some View {
        GeometryReader { proxy in
            let diameter = dialDiameter(for: proxy.size.width)
            dialCanvas(diameter: diameter)
                .frame(width: diameter, height: diameter)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: preferredDiameter)
    }

    @ViewBuilder
    private func stepControls(axis: Axis) -> some View {
        let spacing: CGFloat = axis == .vertical
            ? TempoTokens.Space.sm
            : (dynamicTypeSize.isAccessibilitySize ? 24 : 72)

        if axis == .vertical {
            VStack(spacing: spacing) { stepButtons }
        } else {
            HStack(spacing: spacing) { stepButtons }
        }
    }

    @ViewBuilder
    private var stepButtons: some View {
        stepButton(
            symbol: "minus",
            label: "Уменьшить длительность на 5 минут",
            identifier: "setup.durationDial.decrement",
            isAvailable: currentIndex > 0
        ) { select(index: currentIndex - 1) }

        stepButton(
            symbol: "plus",
            label: "Увеличить длительность на 5 минут",
            identifier: "setup.durationDial.increment",
            isAvailable: currentIndex < allowedValues.count - 1
        ) { select(index: currentIndex + 1) }
    }

    private var preferredDiameter: CGFloat {
        if verticalSizeClass == .compact { return TempoTokens.Size.dialLandscape }
        if dynamicTypeSize.isAccessibilitySize { return TempoTokens.Size.dialCompact }
        return TempoTokens.Size.dialRegular
    }

    private func dialDiameter(for availableWidth: CGFloat) -> CGFloat {
        min(preferredDiameter, max(TempoTokens.Size.dialLandscape, availableWidth - 96))
    }

    private func dialCanvas(diameter: CGFloat) -> some View {
        let lineWidth: CGFloat = diameter >= TempoTokens.Size.dialRegular ? 10 : 9
        let radius = diameter / 2 - 16
        return ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(
                    TempoTokens.ColorToken.carbon.opacity(accessibilityContrast == .increased ? 0.32 : 0.12),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(135))

            Circle()
                .trim(from: 0, to: 0.75 * progress)
                .stroke(
                    accessibilityContrast == .increased
                        ? TempoTokens.ColorToken.carbon
                        : TempoTokens.ColorToken.vermilion,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(135))

            ForEach(allowedValues.indices, id: \.self) { index in
                Rectangle()
                    .fill(index <= currentIndex ? TempoTokens.ColorToken.carbon : TempoTokens.ColorToken.muted)
                    .frame(width: accessibilityContrast == .increased ? 3 : 2, height: 12)
                    .offset(y: -radius)
                    .rotationEffect(.degrees(-135 + 270 * fraction(for: index)))
                    .accessibilityHidden(true)
            }

            Circle()
                .fill(TempoTokens.ColorToken.carbon)
                .overlay(
                    Circle().stroke(
                        TempoTokens.ColorToken.chalk,
                        lineWidth: accessibilityContrast == .increased ? 4 : 3
                    )
                )
                .frame(width: TempoTokens.Size.dialHandle, height: TempoTokens.Size.dialHandle)
                .offset(handleOffset(radius: radius))
                .accessibilityHidden(true)

            VStack(spacing: TempoTokens.Space.xxs) {
                Text("\(value)")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold).monospacedDigit())
                    .minimumScaleFactor(0.82)
                    .lineLimit(1)
                Text("минут")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(TempoTokens.ColorToken.muted)
            }
            .foregroundStyle(TempoTokens.ColorToken.carbon)
            .frame(width: 104, height: 104)
            .accessibilityHidden(true)
        }
        .contentShape(Circle())
        .gesture(dialGesture(diameter: diameter))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Длительность тренировки")
        .accessibilityValue("\(value) минут")
        .accessibilityHint("Смахните вверх или вниз, чтобы изменить на 5 минут. Также доступны кнопки уменьшения и увеличения.")
        .accessibilityIdentifier("setup.durationDial")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: adjust(.increment)
            case .decrement: adjust(.decrement)
            @unknown default: break
            }
        }
    }

    private enum Adjustment {
        case decrement
        case increment
    }

    private var validationAdjustmentControls: some View {
        HStack(spacing: 0) {
            validationAdjustmentButton(
                .decrement,
                identifier: "validation.durationDial.adjustable.decrement"
            )
            validationAdjustmentButton(
                .increment,
                identifier: "validation.durationDial.adjustable.increment"
            )
        }
    }

    private func validationAdjustmentButton(
        _ adjustment: Adjustment,
        identifier: String
    ) -> some View {
        Button { adjust(adjustment) } label: {
            Color.black.opacity(0.001)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Validation adjustable action")
        .accessibilityIdentifier(identifier)
    }

    private func stepButton(
        symbol: String,
        label: String,
        identifier: String,
        isAvailable: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .frame(width: 52, height: 52)
                .foregroundStyle(TempoTokens.ColorToken.carbon)
                .background(TempoTokens.ColorToken.carbon.opacity(0.001))
                .overlay {
                    Circle().stroke(
                        TempoTokens.ColorToken.carbon.opacity(accessibilityContrast == .increased ? 0.32 : 0.16),
                        lineWidth: accessibilityContrast == .increased ? 2 : 1
                    )
                }
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || !isAvailable)
        .opacity(isAvailable ? 1 : 0.38)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private func dialGesture(diameter: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                if !dragStartedInArc {
                    guard fraction(at: gesture.startLocation, diameter: diameter, clampGap: false) != nil else { return }
                    dragStartedInArc = true
                    UISelectionFeedbackGenerator().prepare()
                }
                guard let fraction = fraction(at: gesture.location, diameter: diameter, clampGap: true) else { return }
                select(index: DurationDialContract.index(for: fraction, count: allowedValues.count))
            }
            .onEnded { _ in dragStartedInArc = false }
    }

    private func fraction(at point: CGPoint, diameter: CGFloat, clampGap: Bool) -> CGFloat? {
        let center = CGPoint(x: diameter / 2, y: diameter / 2)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let radius = diameter / 2 - 16
        guard abs(hypot(dx, dy) - radius) <= 24 else { return nil }

        var angle = atan2(dy, dx) * 180 / .pi
        if angle < 0 { angle += 360 }
        if angle >= 135 { return min(1, (angle - 135) / 270) }
        if angle <= 45 { return min(1, (angle + 225) / 270) }
        guard clampGap else { return nil }
        return angle < 90 ? 1 : 0
    }

    private func fraction(for index: Int) -> Double {
        guard allowedValues.count > 1 else { return 0 }
        return Double(index) / Double(allowedValues.count - 1)
    }

    private func handleOffset(radius: CGFloat) -> CGSize {
        let angle = (135 + 270 * progress) * .pi / 180
        return CGSize(width: radius * cos(angle), height: radius * sin(angle))
    }

    private func select(index: Int) {
        guard isEnabled, allowedValues.indices.contains(index), value != allowedValues[index] else { return }
        let newValue = allowedValues[index]
        let update = {
            value = newValue
            onCommit?(newValue)
        }
        if reduceMotion {
            update()
        } else {
            withAnimation(.easeOut(duration: 0.12), update)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func adjust(_ adjustment: Adjustment) {
        switch adjustment {
        case .decrement: select(index: currentIndex - 1)
        case .increment: select(index: currentIndex + 1)
        }
    }

    private func normalizeValueIfNeeded() {
        assert(!allowedValues.isEmpty && allowedValues == Array(Set(allowedValues)).sorted())
        guard !allowedValues.isEmpty, !allowedValues.contains(value) else { return }
        value = allowedValues[DurationDialContract.nearestIndex(to: value, in: allowedValues)]
    }
}

struct TempoChoiceCell: View {
    let title: String
    let isSelected: Bool
    var selectedColor = TempoTokens.ColorToken.carbon
    var isEnabled = true
    var accessibilityIdentifier: String?
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
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isSelected ? "Выбрано" : "Не выбрано")
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
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
