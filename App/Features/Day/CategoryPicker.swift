import SwiftUI

/// Значок категории в цветном квадрате.
struct CategoryBadge: View {
    let colorHex: String
    let symbol: String
    var size: CGFloat = 28

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.25)
            .fill(Color(hex: colorHex))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }
}

/// Выбор категории в форме. Архивные категории не предлагаются,
/// кроме той, что уже выбрана у записи.
struct CategoryPicker: View {
    let categories: [ActivityCategory]
    @Binding var selection: UUID?

    private var options: [ActivityCategory] {
        categories.filter { !$0.isArchived || $0.uuid == selection }
    }

    var body: some View {
        Picker("Категория", selection: $selection) {
            Text("Без категории").tag(UUID?.none)
            ForEach(options) { category in
                Label(category.name, systemImage: category.symbol)
                    .tag(UUID?.some(category.uuid))
            }
        }
    }
}

/// Быстрый выбор длительности: кнопки под полями времени.
struct DurationChips: View {
    let onPick: (Int) -> Void

    private let options = [15, 30, 45, 60, 90, 120]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(options, id: \.self) { minutes in
                    Button(label(minutes)) { onPick(minutes) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
    }

    private func label(_ minutes: Int) -> String {
        switch minutes {
        case 60: return "1 ч"
        case 90: return "1,5 ч"
        case 120: return "2 ч"
        default: return "\(minutes) мин"
        }
    }
}
