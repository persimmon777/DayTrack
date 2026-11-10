import Foundation

/// Причина, по которой день пошёл не по плану.
public enum DeviationReason: String, CaseIterable, Codable, Sendable {
    case suddenTask
    case fatigue
    case phone
    case hardToStart
    case underestimated
    case mood
    case health
    case other

    public var title: String {
        switch self {
        case .suddenTask: return "Внезапное дело"
        case .fatigue: return "Усталость"
        case .phone: return "Телефон и соцсети"
        case .hardToStart: return "Трудно было начать"
        case .underestimated: return "Не рассчитал время"
        case .mood: return "Не было настроения"
        case .health: return "Самочувствие"
        case .other: return "Другое"
        }
    }
}
