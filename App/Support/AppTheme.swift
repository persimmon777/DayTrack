import SwiftUI

/// Тема оформления: акцентный цвет и светлая или тёмная схема.
enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case calm
    case bright
    case night

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "Системная"
        case .calm: return "Спокойная"
        case .bright: return "Яркая"
        case .night: return "Ночная"
        }
    }

    var subtitle: String {
        switch self {
        case .system: return "Как приложения Apple, светлая и тёмная по настройке iPhone"
        case .calm: return "Приглушённый зелёный акцент, ничего не давит"
        case .bright: return "Насыщенный акцент, крупные цифры заметнее"
        case .night: return "Всегда тёмная, мягкий фиолетовый акцент"
        }
    }

    var accent: Color {
        switch self {
        case .system: return Color("AccentColor")
        case .calm: return Color(hex: "5E8C74")
        case .bright: return Color(hex: "E8455B")
        case .night: return Color(hex: "8C7BFF")
        }
    }

    var colorScheme: ColorScheme? {
        self == .night ? .dark : nil
    }
}

/// Выбор темы.
struct ThemeSettingsView: View {
    @AppStorage("theme") private var themeRaw = AppTheme.system.rawValue

    var body: some View {
        List {
            ForEach(AppTheme.allCases) { theme in
                Button {
                    themeRaw = theme.rawValue
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(theme.accent)
                            .frame(width: 28, height: 28)
                            .overlay {
                                if theme == .night {
                                    Circle().stroke(Color.primary.opacity(0.3), lineWidth: 1)
                                }
                            }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(theme.title)
                            Text(theme.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if themeRaw == theme.rawValue {
                            Image(systemName: "checkmark").foregroundStyle(.tint)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
        }
        .navigationTitle("Оформление")
    }
}
