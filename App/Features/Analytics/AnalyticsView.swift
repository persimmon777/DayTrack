import DayTrackCore
import SwiftUI

/// Вкладка «Аналитика»: день, неделя или месяц, отчёт для нейросети.
struct AnalyticsView: View {
    @Binding var dayKey: Int

    @State private var kind: PeriodKind = .day
    @State private var path: [Int] = []
    @State private var isShowingReport = false

    private let calendar = Calendar.current
    private var todayKey: Int { DayClock.app.key(for: .now) }
    private var range: ClosedRange<Int> { Periods.range(kind, containing: dayKey, calendar: calendar) }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Picker("Период", selection: $kind) {
                        ForEach(PeriodKind.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Button {
                            dayKey = Periods.shift(dayKey, kind: kind, by: -1, calendar: calendar)
                        } label: {
                            Image(systemName: "chevron.left").padding(6)
                        }
                        Spacer()
                        Text(title)
                            .font(.headline)
                        Spacer()
                        Button {
                            dayKey = Periods.shift(dayKey, kind: kind, by: 1, calendar: calendar)
                        } label: {
                            Image(systemName: "chevron.right").padding(6)
                        }
                    }
                    if !range.contains(todayKey) {
                        Button("К текущему периоду") { dayKey = todayKey }
                            .font(.footnote)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

                switch kind {
                case .day:
                    AnalyticsDayView(dayKey: dayKey)
                        .id(dayKey)
                case .week, .month:
                    PeriodAnalyticsView(range: range, kind: kind) { path.append($0) }
                        .id("\(kind.rawValue)-\(range.lowerBound)")
                }
            }
            .navigationTitle("Аналитика")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingReport = true
                    } label: {
                        Label("Отчёт для нейросети", systemImage: "text.bubble")
                    }
                }
            }
            .navigationDestination(for: Int.self) { key in
                AnalyticsDayView(dayKey: key)
                    .navigationTitle(Self.dayTitle(key))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("План") {
                                dayKey = key
                                kind = .day
                                path.removeAll()
                            }
                        }
                    }
            }
            .sheet(isPresented: $isShowingReport) {
                ReportSheet(kind: kind, anchorKey: dayKey)
            }
        }
    }

    private var title: String {
        switch kind {
        case .day:
            let date = Recurrence.date(forKey: dayKey, calendar: calendar) ?? .now
            return dayKey == todayKey ? "Сегодня, \(Format.day(date))" : Format.day(date)
        case .week:
            let formatter = DateFormatter()
            formatter.locale = Format.locale
            formatter.setLocalizedDateFormatFromTemplate("d MMM")
            let start = Recurrence.date(forKey: range.lowerBound, calendar: calendar) ?? .now
            let end = Recurrence.date(forKey: range.upperBound, calendar: calendar) ?? .now
            return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
        case .month:
            let formatter = DateFormatter()
            formatter.locale = Format.locale
            formatter.dateFormat = "LLLL yyyy"
            return formatter.string(from: Recurrence.date(forKey: dayKey, calendar: calendar) ?? .now).capitalized
        }
    }

    static func dayTitle(_ key: Int) -> String {
        Recurrence.date(forKey: key, calendar: .current).map(Format.day) ?? ""
    }
}
