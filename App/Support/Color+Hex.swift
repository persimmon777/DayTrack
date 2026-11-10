import SwiftUI

extension Color {
    /// Цвет из записи вида «5B8DEF». Нечитаемая запись даёт серый.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else {
            self = .gray
            return
        }
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Цвета и значки, из которых выбирается оформление категории.
enum CategoryPalette {
    static let colors: [String] = [
        "4F7BE8", "6C5CE7", "A55EEA", "E056A0",
        "EB4D4B", "F0932B", "E1B12C", "6AB04C",
        "22A6B3", "3C6382", "8D6E63", "7F8C8D",
    ]

    static let symbols: [String] = [
        "book.fill", "graduationcap.fill", "lightbulb.fill", "pencil.and.ruler.fill",
        "laptopcomputer", "function", "character.book.closed.fill", "brain.head.profile",
        "leaf.fill", "gamecontroller.fill", "headphones", "tv.fill",
        "person.2.fill", "moon.fill", "bed.double.fill", "figure.run",
        "dumbbell.fill", "fork.knife", "cup.and.saucer.fill", "house.fill",
        "cart.fill", "tram.fill", "car.fill", "briefcase.fill",
        "phone.fill", "heart.fill", "cross.case.fill", "circle.grid.2x2.fill",
    ]
}
