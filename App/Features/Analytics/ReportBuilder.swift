import DayTrackCore
import Foundation
import SwiftData

/// Текст запроса для нейросети, который копируется вместе с отчётом.
enum ReportSettings {
    private static let promptKey = "report.prompt"

    static let defaultPrompt = """
    Ты профессиональный психолог и специалист по тайм-менеджменту, который работает со студентами. \
    Ниже мой отчёт «план/факт» из приложения для планирования дня. Разбери его: что получилось хорошо, \
    какие закономерности ты видишь (что сбивает меня с плана, как распределены учёба, отдых и сон, \
    насколько точно я оцениваю время, как продвигаются мои фокусы) и дай 3 конкретных совета на следующий период. \
    Будь доброжелательным и без упрёков: мне важно понять причины, а не почувствовать вину. \
    Учитывай, что я склонен откладывать сложное, недооцениваю время на дела и мне трудно отдыхать без чувства вины.
    """

    static var prompt: String {
        get {
            let stored = UserDefaults.standard.string(forKey: promptKey) ?? ""
            return stored.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultPrompt : stored
        }
        set { UserDefaults.standard.set(newValue, forKey: promptKey) }
    }

    static func resetPrompt() {
        UserDefaults.standard.removeObject(forKey: promptKey)
    }
}

/// Собирает текстовый отчёт за день, неделю или месяц.
@MainActor
struct ReportBuilder {
    let context: ModelContext
    private let calendar = Calendar.current

    func build(kind: PeriodKind, anchorKey: Int) -> String {
        let range = Periods.range(kind, containing: anchorKey, calendar: calendar)
        switch kind {
        case .day: return dayReport(key: anchorKey)
        case .week, .month: return periodReport(kind: kind, range: range)
        }
    }

    // MARK: Данные

    private func days(in range: ClosedRange<Int>) -> [Day] {
        let from = range.lowerBound, to = range.upperBound
        return (try? context.fetch(FetchDescriptor<Day>(predicate: #Predicate { $0.key >= from && $0.key <= to }))) ?? []
    }

    private func marks(in range: ClosedRange<Int>) -> [EnergyMark] {
        let from = range.lowerBound, to = range.upperBound
        let descriptor = FetchDescriptor<EnergyMark>(
            predicate: #Predicate { $0.dayKey >= from && $0.dayKey <= to },
            sortBy: [SortDescriptor(\.at)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func reflections(in range: ClosedRange<Int>) -> [Reflection] {
        let from = range.lowerBound, to = range.upperBound
        let descriptor = FetchDescriptor<Reflection>(
            predicate: #Predicate { $0.dayKey >= from && $0.dayKey <= to },
            sortBy: [SortDescriptor(\.dayKey)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func focuses(overlapping range: ClosedRange<Int>) -> [Focus] {
        ((try? context.fetch(FetchDescriptor<Focus>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? [])
            .filter { $0.range.overlaps(range) && $0.status != .dropped }
    }

    // MARK: Оформление

    private func dateTitle(_ key: Int, weekday: Bool = true) -> String {
        guard let date = Recurrence.date(forKey: key, calendar: calendar) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Format.locale
        formatter.setLocalizedDateFormatFromTemplate(weekday ? "EEEE d MMMM yyyy" : "d MMMM yyyy")
        return formatter.string(from: date)
    }

    private func shortDate(_ key: Int) -> String {
        guard let date = Recurrence.date(forKey: key, calendar: calendar) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Format.locale
        formatter.dateFormat = "EEEEEE dd.MM"
        return formatter.string(from: date)
    }

    private func hours(_ minutes: Int) -> String { DurationText.short(minutes: minutes) }

    private func focusLines(_ focuses: [Focus], days: [Day]) -> [String] {
        let progress = FocusProgress.compute(focuses: focuses, days: days)
        return focuses.map { focus in
            var line = "- \(focus.title) (\(focus.period == .week ? "неделя" : "месяц"))"
            if let parent = focus.parentUUID.flatMap({ id in focuses.first { $0.uuid == id } }) {
                line += ", шаг к «\(parent.title)»"
            }
            line += ": \((progress[focus.uuid] ?? FocusProgress()).text)"
            if focus.status != .active { line += ", итог: \(focus.status.title.lowercased())" }
            if !focus.why.isEmpty { line += ". Зачем: \(focus.why)" }
            if !focus.result.isEmpty { line += ". Итог своими словами: \(focus.result)" }
            return line
        }
    }

    private func balanceLines(planned: [BalanceGroup: Int], fact: [BalanceGroup: Int]) -> [String] {
        BalanceGroup.allCases.compactMap { group in
            let p = planned[group] ?? 0, f = fact[group] ?? 0
            guard p > 0 || f > 0 else { return nil }
            return "\(group.rawValue): план \(hours(p)), факт \(hours(f))"
        }
    }

    // MARK: День

    private func dayReport(key: Int) -> String {
        let day = days(in: key...key).first
        let summary = DaySummary(day: day, now: .now)
        var lines = ["ОТЧЁТ ЗА ДЕНЬ: \(dateTitle(key))", ""]

        let focusList = focuses(overlapping: key...key)
        if !focusList.isEmpty {
            let weekRange = Periods.range(.week, containing: key, calendar: calendar)
            let monthRange = Periods.range(.month, containing: key, calendar: calendar)
            lines.append("ФОКУСЫ")
            lines += focusLines(focusList, days: days(in: min(weekRange.lowerBound, monthRange.lowerBound)...max(weekRange.upperBound, monthRange.upperBound)))
            lines.append("")
        }

        let blocks = (day?.activeBlocks ?? []).sorted { $0.start < $1.start }
        if blocks.isEmpty {
            lines.append("ПЛАНА НА ЭТОТ ДЕНЬ НЕ БЫЛО")
        } else {
            lines.append("ПЛАН → ФАКТ")
            for block in blocks {
                let category = block.category.map { " [\($0.name)]" } ?? ""
                var line = "\(Format.timeRange(block.start, block.end)) \(block.title)\(category) → "
                let facts = block.facts.sorted { $0.start < $1.start }
                let result = summary.status(of: block)
                if !facts.isEmpty {
                    line += facts.map { Format.timeRange($0.start, $0.end) }.joined(separator: ", ")
                }
                switch result?.status {
                case .done: line += facts.isEmpty ? "выполнено" : ", выполнено"
                case .partial:
                    line += ", частично (\(result?.factMinutes ?? 0) из \(result?.plannedMinutes ?? 0) мин)"
                case .missed: line += "не выполнено"
                case .pending, .none: line += "ещё не наступило"
                }
                let reason = block.missReason ?? facts.compactMap(\.reason).first
                if let reason { line += ", причина: \(reason.title.lowercased())" }
                lines.append(line)
            }
        }

        let unplanned = (day?.facts ?? []).filter(\.isUnplanned).sorted { $0.start < $1.start }
        if !unplanned.isEmpty {
            lines.append("")
            lines.append("ВНЕ ПЛАНА")
            for fact in unplanned {
                let category = fact.category.map { " [\($0.name)]" } ?? ""
                lines.append("\(Format.timeRange(fact.start, fact.end)) \(fact.title)\(category), причина: \((fact.reason ?? .other).title.lowercased())")
            }
        }

        if let changes = day?.changes, !changes.isEmpty {
            lines.append("")
            lines.append("ПРАВКИ ПЛАНА ПОСЛЕ ФИКСАЦИИ")
            for change in changes.sorted(by: { $0.at < $1.at }) {
                lines.append("\(Format.time(change.at)) \(change.text)")
            }
        }

        lines.append("")
        lines.append("ИТОГИ")
        if let completion = summary.current.completion {
            var line = "Выполнение плана: \(DurationText.percent(completion))"
            if summary.planWasEdited, let baseline = summary.baseline?.completion {
                line += " (к исходному плану без правок: \(DurationText.percent(baseline)))"
            }
            lines.append(line)
        }
        let plannedByGroup = blocks.reduce(into: [BalanceGroup: Int]()) {
            $0[BalanceGroup.of($1.category?.kind ?? .other), default: 0] += PlanComparison.minutes(from: $1.start, to: $1.end)
        }
        let factByGroup = (day?.facts ?? []).reduce(into: [BalanceGroup: Int]()) {
            $0[BalanceGroup.of($1.category?.kind ?? .other), default: 0] += PlanComparison.minutes(from: $1.start, to: $1.end)
        }
        lines += balanceLines(planned: plannedByGroup, fact: factByGroup)

        let tasks = (day?.tasks ?? []).sorted { $0.sortOrder < $1.sortOrder }
        if !tasks.isEmpty {
            lines.append("Задачи без времени: сделано \(tasks.filter(\.isDone).count) из \(tasks.count): "
                + tasks.map { ($0.isDone ? "✓ " : "✗ ") + $0.title }.joined(separator: "; "))
        }

        let energy = marks(in: key...key)
        if !energy.isEmpty {
            lines.append("Энергия и настроение (из 5): "
                + energy.map { "\(Format.time($0.at)) — энергия \($0.energy), настроение \($0.mood)" }.joined(separator: "; "))
        }

        if let reflection = reflections(in: key...key).first, !reflection.isEmpty {
            lines.append("")
            lines.append("РЕФЛЕКСИЯ")
            if !reflection.wentWell.isEmpty { lines.append("Получилось: \(reflection.wentWell)") }
            if !reflection.hindered.isEmpty { lines.append("Помешало: \(reflection.hindered)") }
            if !reflection.changeTomorrow.isEmpty { lines.append("Завтра изменю: \(reflection.changeTomorrow)") }
            if reflection.rating > 0 { lines.append("Оценка дня: \(reflection.rating) из 5") }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: Неделя и месяц

    private func periodReport(kind: PeriodKind, range: ClosedRange<Int>) -> String {
        let dayModels = days(in: range)
        let data = PeriodAnalytics(range: range, kind: kind, days: dayModels, marks: marks(in: range))
        let title = kind == .week
            ? "ОТЧЁТ ЗА НЕДЕЛЮ: \(dateTitle(range.lowerBound, weekday: false)) – \(dateTitle(range.upperBound, weekday: false))"
            : "ОТЧЁТ ЗА МЕСЯЦ: \(dateTitle(range.lowerBound, weekday: false)) – \(dateTitle(range.upperBound, weekday: false))"
        var lines = [title, ""]

        let focusList = focuses(overlapping: range)
        if !focusList.isEmpty {
            lines.append("ФОКУСЫ")
            lines += focusLines(focusList, days: dayModels)
            lines.append("")
        }

        lines.append("ПО ДНЯМ")
        let today = DayClock.app.key(for: .now)
        for point in data.days where point.key <= today {
            var parts: [String] = []
            if let completion = point.completion {
                parts.append("план \(hours(point.plannedMinutes)), выполнено \(DurationText.percent(completion))")
            } else {
                parts.append("плана не было")
            }
            let groups = BalanceGroup.minutes(point.byKind)
            for group in BalanceGroup.allCases {
                if let minutes = groups[group], minutes > 0 {
                    parts.append("\(group.rawValue.lowercased()) \(hours(minutes))")
                }
            }
            if point.unplannedMinutes > 0 { parts.append("вне плана \(hours(point.unplannedMinutes))") }
            if !point.hasFact { parts.append("факт не внесён") }
            lines.append("\(shortDate(point.key)): \(parts.joined(separator: ", "))")
        }

        lines.append("")
        lines.append("ИТОГИ")
        if let completion = data.completion {
            var line = "Выполнение плана за период: \(DurationText.percent(completion))"
            let previousAnchor = Periods.shift(range.lowerBound, kind: kind, by: -1, calendar: calendar)
            let previousRange = Periods.range(kind, containing: previousAnchor, calendar: calendar)
            let previous = PeriodAnalytics(range: previousRange, kind: kind, days: days(in: previousRange), marks: [])
            if let before = previous.completion {
                line += " (в прошлом периоде: \(DurationText.percent(before)))"
            }
            lines.append(line)
        }
        lines.append("Дней с планом: \(data.daysWithPlan.count) из \(data.days.count)")
        let groups = BalanceGroup.minutes(data.byKind)
        let daysWithFact = max(data.days.filter(\.hasFact).count, 1)
        for group in BalanceGroup.allCases {
            if let minutes = groups[group], minutes > 0 {
                lines.append("\(group.rawValue): всего \(hours(minutes)), в среднем \(hours(minutes / daysWithFact)) в день")
            }
        }

        if !data.reasons.isEmpty {
            lines.append("")
            lines.append("ЧТО СБИВАЛО С ПЛАНА")
            for item in data.reasons { lines.append("\(item.reason.title): \(item.count)") }
        }

        let estimates = data.categories.filter { ($0.estimateRatio ?? 0) > 0 }
        if !estimates.isEmpty {
            lines.append("")
            lines.append("ТОЧНОСТЬ ОЦЕНОК ВРЕМЕНИ (факт к плану по выполненным блокам)")
            for line in estimates {
                let percent = Int((((line.estimateRatio ?? 1) - 1) * 100).rounded())
                lines.append("\(line.name): \(percent == 0 ? "точно" : (percent > 0 ? "дольше на \(percent)%" : "быстрее на \(-percent)%"))")
            }
        }

        if !data.bestEnergyHours.isEmpty {
            lines.append("")
            lines.append("Больше всего энергии в часы: \(data.bestEnergyHours.map { "\($0):00" }.joined(separator: ", "))")
        }

        let reflectionList = reflections(in: range).filter { !$0.isEmpty }
        if !reflectionList.isEmpty {
            lines.append("")
            lines.append("РЕФЛЕКСИЯ ПО ДНЯМ")
            for reflection in reflectionList {
                var parts: [String] = []
                if !reflection.wentWell.isEmpty { parts.append("получилось: \(reflection.wentWell)") }
                if !reflection.hindered.isEmpty { parts.append("помешало: \(reflection.hindered)") }
                if !reflection.changeTomorrow.isEmpty { parts.append("изменю: \(reflection.changeTomorrow)") }
                if reflection.rating > 0 { parts.append("оценка \(reflection.rating)/5") }
                lines.append("\(shortDate(reflection.dayKey)): \(parts.joined(separator: "; "))")
            }
        }
        return lines.joined(separator: "\n")
    }
}
