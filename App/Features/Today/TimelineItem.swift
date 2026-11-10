import DayTrackCore
import SwiftUI

/// Блок на шкале времени в готовом для рисования виде. Это копия данных,
/// а не ссылка на запись в базе: шкала не ломается, если запись удалили.
struct TimelineItem: Identifiable {
    let id: UUID
    var title: String
    var start: Date
    var end: Date
    var color: Color
    var badgeSymbol: String?
    var badgeColor: Color = .secondary
    /// Продолжение блока, начатого в предыдущий день. Показывается бледно и не нажимается.
    var isGhost = false
}

extension TimelineItem {
    static func plan(_ block: PlannedBlock, result: BlockResult?, isGhost: Bool = false) -> TimelineItem {
        var item = TimelineItem(
            id: block.uuid,
            title: block.title,
            start: block.start,
            end: block.end,
            color: Color(hex: block.category?.colorHex ?? "7F8C8D"),
            isGhost: isGhost
        )
        guard !isGhost, let result else { return item }
        switch result.status {
        case .done:
            item.badgeSymbol = "checkmark.circle.fill"
            item.badgeColor = .green
        case .partial:
            item.badgeSymbol = "circle.lefthalf.filled"
            item.badgeColor = .orange
        case .missed:
            item.badgeSymbol = "xmark.circle.fill"
            item.badgeColor = .red
        case .pending:
            break
        }
        return item
    }

    static func fact(_ fact: FactEntry, isGhost: Bool = false) -> TimelineItem {
        var item = TimelineItem(
            id: fact.uuid,
            title: fact.title,
            start: fact.start,
            end: fact.end,
            color: Color(hex: fact.category?.colorHex ?? "7F8C8D"),
            isGhost: isGhost
        )
        if !isGhost, fact.isUnplanned {
            item.badgeSymbol = "arrow.triangle.branch"
            item.badgeColor = .orange
        }
        return item
    }
}
