import DayTrackCore
import SwiftUI

/// Две шкалы времени рядом: слева план, справа факт.
struct DualTimelineView: View {
    static let hourHeight: CGFloat = 56
    static let gutter: CGFloat = 40
    static let columnGap: CGFloat = 6

    /// Идентификатор строки часа, к которой можно прокрутить экран.
    static func hourAnchor(_ index: Int) -> String { "hour-\(index)" }

    let window: DateInterval
    let planItems: [TimelineItem]
    let factItems: [TimelineItem]
    /// Текущий момент. Передаётся только для сегодняшнего дня.
    let now: Date?
    let onTapPlanItem: (UUID) -> Void
    let onTapFactItem: (UUID) -> Void
    let onTapPlanSpace: (Date) -> Void
    let onTapFactSpace: (Date) -> Void

    private var hourCount: Int { max(1, Int((window.duration / 3600).rounded())) }
    private var totalHeight: CGFloat { CGFloat(hourCount) * Self.hourHeight }

    var body: some View {
        ZStack(alignment: .topLeading) {
            hourGrid
            GeometryReader { geometry in
                let columnWidth = max(0, (geometry.size.width - Self.gutter - Self.columnGap) / 2)
                column(planItems, width: columnWidth, onTapItem: onTapPlanItem, onTapSpace: onTapPlanSpace)
                    .offset(x: Self.gutter)
                column(factItems, width: columnWidth, onTapItem: onTapFactItem, onTapSpace: onTapFactSpace)
                    .offset(x: Self.gutter + columnWidth + Self.columnGap)
                if let now, window.contains(now) {
                    nowLine
                        .offset(x: Self.gutter - 4, y: y(for: now) - 4)
                }
            }
        }
        .frame(height: totalHeight)
    }

    // MARK: Сетка часов

    private var hourGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<hourCount, id: \.self) { index in
                HStack(alignment: .top, spacing: 4) {
                    Text(Format.time(window.start.addingTimeInterval(Double(index) * 3600)))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: Self.gutter - 4, alignment: .trailing)
                        .offset(y: -6)
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(height: 0.5)
                }
                .frame(height: Self.hourHeight, alignment: .top)
                .id(Self.hourAnchor(index))
            }
        }
    }

    private var nowLine: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
            Rectangle()
                .fill(.red)
                .frame(height: 1.5)
        }
        .allowsHitTesting(false)
    }

    // MARK: Колонка

    private func column(
        _ items: [TimelineItem],
        width: CGFloat,
        onTapItem: @escaping (UUID) -> Void,
        onTapSpace: @escaping (Date) -> Void
    ) -> some View {
        let slots = TimelineLayout.layout(items.map {
            TimelineLayout.Span(
                start: $0.start.timeIntervalSinceReferenceDate,
                end: $0.end.timeIntervalSinceReferenceDate
            )
        })

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6).opacity(0.6))
                .contentShape(Rectangle())
                .onTapGesture { location in
                    onTapSpace(date(atY: location.y))
                }

            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let slot = slots[index]
                let top = y(for: item.start)
                let height = max(y(for: item.end) - top, 22)
                let slotWidth = width / CGFloat(max(slot.columnCount, 1))

                TimelineBlockView(item: item, height: height)
                    .frame(width: max(slotWidth - 2, 0), height: height)
                    .offset(x: CGFloat(slot.column) * slotWidth + 1, y: top)
                    .onTapGesture {
                        if !item.isGhost { onTapItem(item.id) }
                    }
            }
        }
        .frame(width: width, height: totalHeight, alignment: .topLeading)
    }

    // MARK: Время и координаты

    private func y(for date: Date) -> CGFloat {
        let seconds = min(max(date.timeIntervalSince(window.start), 0), window.duration)
        return CGFloat(seconds / 3600) * Self.hourHeight
    }

    /// Время в точке нажатия, округлённое вниз до 15 минут.
    private func date(atY y: CGFloat) -> Date {
        let seconds = Double(min(max(y, 0), totalHeight) / Self.hourHeight) * 3600
        let snapped = (seconds / 900).rounded(.down) * 900
        return window.start.addingTimeInterval(min(snapped, window.duration - 900))
    }
}

/// Один блок на шкале.
private struct TimelineBlockView: View {
    let item: TimelineItem
    let height: CGFloat

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(item.color)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.isGhost ? "↑ \(item.title)" : item.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(height > 52 ? 2 : 1)
                if height >= 36 {
                    Text(Format.timeRange(item.start, item.end))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 3)

            Spacer(minLength: 0)

            if let badge = item.badgeSymbol {
                Image(systemName: badge)
                    .font(.caption)
                    .foregroundStyle(item.badgeColor)
                    .padding(3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            ZStack {
                Color(.systemBackground)
                item.color.opacity(0.24)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .opacity(item.isGhost ? 0.45 : 1)
        .contentShape(Rectangle())
    }
}

/// Подписи колонок, закреплённые над шкалой.
struct TimelineColumnsHeader: View {
    var body: some View {
        HStack(spacing: DualTimelineView.columnGap) {
            Color.clear
                .frame(width: DualTimelineView.gutter - DualTimelineView.columnGap, height: 1)
            Text("План")
                .frame(maxWidth: .infinity)
            Text("Факт")
                .frame(maxWidth: .infinity)
        }
        .font(.subheadline.weight(.semibold))
        .padding(.vertical, 6)
        .background(.bar)
    }
}
