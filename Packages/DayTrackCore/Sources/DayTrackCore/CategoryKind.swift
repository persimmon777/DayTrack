import Foundation

/// Тип категории. По нему считается баланс учёбы, отдыха и сна,
/// как бы ни назывались сами категории.
public enum CategoryKind: String, CaseIterable, Codable, Sendable {
    case study
    case rest
    case sleep
    case sport
    case routine
    case transit
    case work
    case other

    public var title: String {
        switch self {
        case .study: return "Учёба"
        case .rest: return "Отдых"
        case .sleep: return "Сон"
        case .sport: return "Спорт"
        case .routine: return "Быт"
        case .transit: return "Дорога"
        case .work: return "Работа"
        case .other: return "Другое"
        }
    }
}
