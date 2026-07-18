import SwiftUI

enum DesignSystem {
    static let background = Color(red: 0.04, green: 0.05, blue: 0.08)
    static let card = Color(red: 0.10, green: 0.12, blue: 0.17)
    static let accent = Color(red: 0.20, green: 0.86, blue: 0.57)
    static let secondaryAccent = Color(red: 0.29, green: 0.53, blue: 1.00)
    static let mutedText = Color.white.opacity(0.64)
}

struct PremiumCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(DesignSystem.card)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
