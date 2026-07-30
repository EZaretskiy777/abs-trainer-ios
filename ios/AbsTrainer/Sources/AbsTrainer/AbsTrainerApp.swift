import SwiftUI

@main
struct AbsTrainerApp: App {
    private let validationViewport = ValidationViewport.fromLaunchArguments()
    private let validationDynamicTypeSize = ValidationDynamicTypeSize.fromLaunchArguments()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(
                    width: validationViewport?.width,
                    height: validationViewport?.height
                )
                .background {
                    if let validationViewport {
                        Rectangle()
                            .fill(Color.black.opacity(0.001))
                            .frame(width: validationViewport.width, height: validationViewport.height)
                            .allowsHitTesting(false)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Validation viewport")
                            .accessibilityIdentifier("validation.viewport")
                    }
                }
                .validationDynamicTypeSize(validationDynamicTypeSize)
                .overlay(alignment: .topLeading) {
                    if let validationDynamicTypeSize {
                        Text(validationDynamicTypeSize.validationDescription)
                            .font(.system(size: 1))
                            .frame(width: 1, height: 1)
                            .accessibilityIdentifier("validation.dynamicType")
                            .accessibilityLabel("Validation Dynamic Type")
                            .accessibilityValue(validationDynamicTypeSize.validationDescription)
                    }
                }
        }
    }
}

private extension View {
    @ViewBuilder
    func validationDynamicTypeSize(_ size: DynamicTypeSize?) -> some View {
        if let size {
            environment(\.dynamicTypeSize, size)
        } else {
            self
        }
    }
}

private enum ValidationDynamicTypeSize {
    static func fromLaunchArguments(
        _ arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> DynamicTypeSize? {
        #if DEBUG
        guard arguments.contains("-ValidationMode"),
              value(after: "-UIPreferredContentSizeCategoryName", in: arguments)
                == "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge" else { return nil }
        return .accessibility3
        #else
        return nil
        #endif
    }

    private static func value(after key: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: key), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}

private extension DynamicTypeSize {
    var validationDescription: String {
        switch self {
        case .accessibility3: return "accessibility3"
        default: return String(describing: self)
        }
    }
}

private struct ValidationViewport {
    let width: CGFloat
    let height: CGFloat

    static func fromLaunchArguments(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> ValidationViewport? {
        #if DEBUG
        guard arguments.contains("-ValidationMode"),
              let width = value(after: "-ValidationViewportWidth", in: arguments),
              let height = value(after: "-ValidationViewportHeight", in: arguments),
              width > 0,
              height > 0 else { return nil }
        return ValidationViewport(width: width, height: height)
        #else
        return nil
        #endif
    }

    private static func value(after key: String, in arguments: [String]) -> CGFloat? {
        guard let index = arguments.firstIndex(of: key), arguments.indices.contains(index + 1) else {
            return nil
        }
        guard let parsed = Double(arguments[index + 1]) else { return nil }
        return CGFloat(parsed)
    }
}
