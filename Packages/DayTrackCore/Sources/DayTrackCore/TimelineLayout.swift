import Foundation

/// Раскладка блоков на шкале времени: пересекающиеся блоки встают рядом в колонки.
public enum TimelineLayout {
    public struct Span: Equatable, Sendable {
        public var start: Double
        public var end: Double

        public init(start: Double, end: Double) {
            self.start = start
            self.end = max(end, start)
        }
    }

    public struct Slot: Equatable, Sendable {
        /// Номер колонки, начиная с нуля.
        public var column: Int
        /// Сколько колонок в группе пересекающихся блоков.
        public var columnCount: Int
    }

    /// Возвращает место для каждого блока в том же порядке, в каком они переданы.
    public static func layout(_ spans: [Span]) -> [Slot] {
        var slots = [Slot](repeating: Slot(column: 0, columnCount: 1), count: spans.count)
        let order = spans.indices.sorted { a, b in
            if spans[a].start != spans[b].start { return spans[a].start < spans[b].start }
            if spans[a].end != spans[b].end { return spans[a].end > spans[b].end }
            return a < b
        }

        var group: [Int] = []
        var columnEnds: [Double] = []
        var groupEnd = -Double.infinity

        func closeGroup() {
            for index in group { slots[index].columnCount = max(columnEnds.count, 1) }
            group.removeAll()
            columnEnds.removeAll()
        }

        for index in order {
            let span = spans[index]
            if !group.isEmpty, span.start >= groupEnd {
                closeGroup()
                groupEnd = -Double.infinity
            }

            if let free = columnEnds.firstIndex(where: { $0 <= span.start }) {
                columnEnds[free] = span.end
                slots[index].column = free
            } else {
                columnEnds.append(span.end)
                slots[index].column = columnEnds.count - 1
            }
            group.append(index)
            groupEnd = max(groupEnd, span.end)
        }
        closeGroup()
        return slots
    }
}
