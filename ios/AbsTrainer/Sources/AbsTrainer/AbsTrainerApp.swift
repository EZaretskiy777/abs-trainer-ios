import SwiftUI

@main
struct AbsTrainerApp: App {
    private let validationViewport = ValidationViewport.fromLaunchArguments()

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
