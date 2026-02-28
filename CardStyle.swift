import SwiftUI

struct CardStyle: ViewModifier {
    
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(Color.cardBackground)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 4)
    }
}

extension View {
    func appCard() -> some View {
        self.modifier(CardStyle())
    }
}
