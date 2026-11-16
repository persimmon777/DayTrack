import Foundation

/// Блок плана для советчика.
public struct AdvisorBlock: Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var start: Date
    public var end: Date
    public var kind: CategoryKind
    public var categoryID: String?
    public var categoryName: String?
    public var isFrog: Bool
    public var hasFact: Bool

    public init(id: UUID, title: String, start: Date, end: Date, kind: CategoryKind,
                categoryID: String? = nil, categoryName: String? = nil, isFrog: Bool = false, hasFact: Bool = false) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.kind = kind
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.isFrog = isFrog
        self.hasFact = hasFact
    }

    public var minutes: Int { PlanComparison.minutes(from: start, to: end) }
}

/// Пороги советчика (меняются в настройках).
public struct AdvisorSettings: Equatable, Sendable {
    public var loadLimit: Double
    public var bufferMinutes: Int
    public var breakIntervalMinutes: Int
    public var studyCeilingMinutes: Int
    public var minSleepMinutes: Int
    public var studyTargetMinutes: Int
    public var disabled: Set<AdviceRule>

    public init(loadLimit: Double = 0.7, bufferMinutes: Int = 60, breakIntervalMinutes: Int = 90,
                studyCeilingMinutes: Int = 8 * 60, minSleepMinutes: Int = 7 * 60,
                studyTargetMinutes: Int = 6 * 60, disabled: Set<AdviceRule> = []) {
        self.loadLimit = loadLimit
        self.bufferMinutes = bufferMinutes
        self.breakIntervalMinutes = breakIntervalMinutes
        self.studyCeilingMinutes = studyCeilingMinutes
        self.minSleepMinutes = minSleepMinutes
        self.studyTargetMinutes = studyTargetMinutes
        self.disabled = disabled
    }
}

/// Всё, на что смотрит советчик.
public struct AdvisorInput: Sendable {
    public var blocks: [AdvisorBlock]
    /// Оценки задач без времени в минутах (0 — без оценки).
    public var taskEstimates: [Int]
    public var dayWindow: DateInterval
    public var now: Date
    /// Минуты бодрствования по настройкам подъёма и отбоя.
    public var awakeMinutes: Int
    /// История оценок по категориям: во сколько раз факт длиннее плана и по скольким блокам.
    public var estimateHistory: [String: (ratio: Double, samples: Int)]
    /// Дней подряд без плана перед этим днём.
    public var daysWithoutPlan: Int
    /// Часы с самой высокой энергией (пусто, если данных мало).
    public var bestEnergyHours: [Int]
    /// Учёба за прошедшие дни недели и сколько дней прошло.
    public var weekStudyMinutes: Int
    public var weekDaysElapsed: Int

    public init(blocks: [AdvisorBlock], taskEstimates: [Int] = [], dayWindow: DateInterval, now: Date,
                awakeMinutes: Int = 16 * 60, estimateHistory: [String: (ratio: Double, samples: Int)] = [:],
                daysWithoutPlan: Int = 0, bestEnergyHours: [Int] = [], weekStudyMinutes: Int = 0, weekDaysElapsed: Int = 0) {
        self.blocks = blocks
        self.taskEstimates = taskEstimates
        self.dayWindow = dayWindow
        self.now = now
        self.awakeMinutes = awakeMinutes
        self.estimateHistory = estimateHistory
        self.daysWithoutPlan = daysWithoutPlan
        self.bestEnergyHours = bestEnergyHours
        self.weekStudyMinutes = weekStudyMinutes
        self.weekDaysElapsed = weekDaysElapsed
    }
}

public enum AdviceRule: String, CaseIterable, Codable, Sendable {
    case frog, startSmall, estimates, load, oneThreeFive, buffer, breaks, rest, studyCeiling, sleep, minimumDay, energy, weekBalance

    public var title: String {
        switch self {
        case .frog: return "Лягушка дня"
        case .startSmall: return "Старт на 5 минут"
        case .estimates: return "Поправка оценок времени"
        case .load: return "Лимит загрузки"
        case .oneThreeFive: return "Правило 1-3-5"
        case .buffer: return "Резерв на непредвиденное"
        case .breaks: return "Перерывы в учёбе"
        case .rest: return "Отдых в плане"
        case .studyCeiling: return "Потолок учёбы"
        case .sleep: return "Сон"
        case .minimumDay: return "День-минимум"
        case .energy: return "Продуктивные часы"
        case .weekBalance: return "Баланс недели"
        }
    }
}

/// Насколько надёжно основание подсказки.
public enum AdviceBasis: Sendable {
    case research(String)
    case practice

    public var text: String {
        switch self {
        case .research(let source): return "Исследования: \(source)"
        case .practice: return "Практический приём тайм-менеджмента, не научный закон"
        }
    }
}

/// Действие в одно нажатие.
public enum AdviceAction: Equatable, Sendable {
    case markFrog(UUID)
    /// Удлинить блоки категории в `ratio` раз.
    case extendCategory(String, ratio: Double)
    case addBlock(title: String, kind: CategoryKind, start: Date, minutes: Int)
}

public struct Advice: Identifiable, Equatable, Sendable {
    public var rule: AdviceRule
    public var text: String
    public var why: String
    public var basis: AdviceBasis
    public var action: AdviceAction?
    public var actionTitle: String?

    public var id: String { rule.rawValue }

    public static func == (lhs: Advice, rhs: Advice) -> Bool {
        lhs.rule == rhs.rule && lhs.text == rhs.text && lhs.action == rhs.action
    }
}

/// Набор независимых правил. Каждое смотрит на план и историю и даёт не больше одной подсказки.
public enum Advisor {
    public static func advise(_ input: AdvisorInput, settings: AdvisorSettings = AdvisorSettings(), calendar: Calendar) -> [Advice] {
        let rules: [(AdviceRule, () -> Advice?)] = [
            (.minimumDay, { minimumDay(input) }),
            (.frog, { frog(input) }),
            (.startSmall, { startSmall(input, calendar: calendar) }),
            (.estimates, { estimates(input) }),
            (.load, { load(input, settings) }),
            (.oneThreeFive, { oneThreeFive(input) }),
            (.buffer, { buffer(input, settings) }),
            (.rest, { rest(input) }),
            (.breaks, { breaks(input, settings) }),
            (.studyCeiling, { studyCeiling(input, settings) }),
            (.sleep, { sleep(input, settings) }),
            (.energy, { energy(input, calendar: calendar) }),
            (.weekBalance, { weekBalance(input, settings) }),
        ]
        return rules.compactMap { rule, check in settings.disabled.contains(rule) ? nil : check() }
    }

    // MARK: Вспомогательное

    private static func work(_ input: AdvisorInput) -> [AdvisorBlock] {
        input.blocks.filter { $0.kind != .sleep && $0.kind != .rest }
    }

    private static func study(_ input: AdvisorInput) -> [AdvisorBlock] {
        input.blocks.filter { $0.kind == .study }.sorted { $0.start < $1.start }
    }

    private static func isBuffer(_ block: AdvisorBlock) -> Bool {
        KeywordMatcher.score(title: block.title, keywords: ["резерв", "буфер", "запас"]) != nil
    }

    /// Первый свободный промежуток нужной длины между 9:00 и 22:00 (и не раньше текущего момента).
    static func freeSlot(_ input: AdvisorInput, minutes: Int, after: Date? = nil) -> Date? {
        let from = max(after ?? input.dayWindow.start.addingTimeInterval(9 * 3600), input.dayWindow.start.addingTimeInterval(9 * 3600))
        let limit = input.dayWindow.start.addingTimeInterval(22 * 3600)
        var cursor = roundUp(max(from, input.now), toMinutes: 15)
        let busy = input.blocks.filter { $0.kind != .sleep }.sorted { $0.start < $1.start }
        while cursor.addingTimeInterval(TimeInterval(minutes * 60)) <= limit {
            let end = cursor.addingTimeInterval(TimeInterval(minutes * 60))
            if let clash = busy.first(where: { $0.start < end && $0.end > cursor }) {
                cursor = roundUp(clash.end, toMinutes: 15)
            } else {
                return cursor
            }
        }
        return nil
    }

    static func roundUp(_ date: Date, toMinutes step: Int) -> Date {
        let seconds = TimeInterval(step * 60)
        return Date(timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / seconds).rounded(.up) * seconds)
    }

    private static func percent(_ ratio: Double) -> Int { Int(((ratio - 1) * 100).rounded()) }

    // MARK: Правила

    static func minimumDay(_ input: AdvisorInput) -> Advice? {
        guard input.blocks.isEmpty, input.daysWithoutPlan >= 2 else { return nil }
        let start = freeSlot(input, minutes: 25) ?? input.now
        return Advice(
            rule: .minimumDay,
            text: "Несколько дней без плана — так бывает. Начни с дня-минимума: одно дело по фокусу на 25 минут и вечерний разбор.",
            why: "После перерыва легче вернуться с маленького шага, чем с полного плана. Маленький обязательный минимум помогает не выпадать надолго после «работы до упора».",
            basis: .practice,
            action: .addBlock(title: "Главное дело, 25 минут", kind: .study, start: start, minutes: 25),
            actionTitle: "Добавить 25 минут"
        )
    }

    static func frog(_ input: AdvisorInput) -> Advice? {
        let studyBlocks = study(input)
        guard !studyBlocks.isEmpty else { return nil }
        if let frog = input.blocks.first(where: \.isFrog) {
            guard let firstStudy = studyBlocks.first, frog.id != firstStudy.id, frog.start > firstStudy.start else { return nil }
            return Advice(
                rule: .frog,
                text: "Лягушка «\(frog.title)» стоит после других дел учёбы. Попробуй поставить её первой.",
                why: "Сложное дело, отложенное на потом, обычно так и не начинается: к вечеру сил меньше, а поводов отложить больше.",
                basis: .practice, action: nil, actionTitle: nil
            )
        }
        guard let longest = studyBlocks.max(by: { $0.minutes < $1.minutes }) else { return nil }
        return Advice(
            rule: .frog,
            text: "Отметь «лягушку» — самое сложное дело дня. Например, «\(longest.title)».",
            why: "Когда главное дело названо и стоит первым, его труднее отложить до последнего.",
            basis: .practice,
            action: .markFrog(longest.id),
            actionTitle: "Сделать лягушкой"
        )
    }

    static func startSmall(_ input: AdvisorInput, calendar: Calendar) -> Advice? {
        guard input.dayWindow.contains(input.now),
              let frog = input.blocks.first(where: \.isFrog),
              !frog.hasFact, frog.start < input.now else { return nil }
        return Advice(
            rule: .startSmall,
            text: "Лягушка «\(frog.title)» ещё не начата. Не надо делать её целиком — начни на 5 минут: открой материалы и сделай первый крошечный шаг.",
            why: "Чаще всего мешает не само дело, а момент начала. Конкретный маленький шаг «сейчас открою и сделаю X» запускает работу легче, чем намерение сделать всё.",
            basis: .research("намерения реализации, Gollwitzer, 1999"),
            action: nil, actionTitle: nil
        )
    }

    static func estimates(_ input: AdvisorInput) -> Advice? {
        let candidates = Dictionary(grouping: input.blocks.filter { $0.categoryID != nil }, by: { $0.categoryID! })
            .compactMap { id, blocks -> (String, String, Double)? in
                guard let history = input.estimateHistory[id], history.samples >= 3, history.ratio >= 1.2 else { return nil }
                return (id, blocks.first?.categoryName ?? "эта категория", history.ratio)
            }
            .sorted { $0.2 > $1.2 }
        guard let best = candidates.first else { return nil }
        let (id, name, ratio) = best
        return Advice(
            rule: .estimates,
            text: "Обычно «\(name)» занимает у тебя на \(percent(ratio))% больше, чем запланировано. Заложить больше времени?",
            why: "Люди систематически недооценивают, сколько займёт дело. Помогает не «стараться точнее», а смотреть на свою прошлую статистику похожих дел.",
            basis: .research("ошибка планирования, Kahneman & Tversky, 1979; Buehler и др., 1994"),
            action: .extendCategory(id, ratio: min(ratio, 2)),
            actionTitle: "Увеличить на \(percent(min(ratio, 2)))%"
        )
    }

    static func load(_ input: AdvisorInput, _ settings: AdvisorSettings) -> Advice? {
        let planned = work(input).reduce(0) { $0 + $1.minutes }
        let limit = Int(Double(input.awakeMinutes) * settings.loadLimit)
        guard input.awakeMinutes > 0, planned > limit else { return nil }
        return Advice(
            rule: .load,
            text: "Занято \(DurationText.percent(Double(planned) / Double(input.awakeMinutes))) времени бодрствования (\(DurationText.short(minutes: planned))). Убери или перенеси что-нибудь, чтобы осталось место на дорогу, еду и неожиданное.",
            why: "План без запаса ломается от первой задержки, и к вечеру остаётся ощущение провала. Реалистичный план выполняется чаще и меньше демотивирует.",
            basis: .practice, action: nil, actionTitle: nil
        )
    }

    static func oneThreeFive(_ input: AdvisorInput) -> Advice? {
        let sizes = work(input).map(\.minutes) + input.taskEstimates
        let big = sizes.filter { $0 >= 90 }.count
        let medium = sizes.filter { $0 >= 30 && $0 < 90 }.count
        let small = sizes.filter { $0 < 30 }.count
        guard big > 1 || medium > 3 || small > 5 else { return nil }
        return Advice(
            rule: .oneThreeFive,
            text: "В плане \(big) больших, \(medium) средних и \(small) мелких дел. По правилу 1-3-5 реально успеть одно большое, три средних и пять мелких — лишнее лучше перенести.",
            why: "Ограничение числа дел заставляет заранее выбрать главное, а не надеяться успеть всё.",
            basis: .practice, action: nil, actionTitle: nil
        )
    }

    static func buffer(_ input: AdvisorInput, _ settings: AdvisorSettings) -> Advice? {
        guard work(input).count >= 2, !input.blocks.contains(where: isBuffer),
              let start = freeSlot(input, minutes: settings.bufferMinutes) else { return nil }
        return Advice(
            rule: .buffer,
            text: "В дне нет резерва на непредвиденное. Внезапные дела случаются почти каждый день — оставь под них \(DurationText.short(minutes: settings.bufferMinutes)).",
            why: "Если под неожиданное нет места, оно вытесняет запланированное. С резервом внезапное дело не ломает весь день.",
            basis: .practice,
            action: .addBlock(title: "Резерв на непредвиденное", kind: .other, start: start, minutes: settings.bufferMinutes),
            actionTitle: "Добавить резерв в \(Self.time(start))"
        )
    }

    static func rest(_ input: AdvisorInput) -> Advice? {
        guard !study(input).isEmpty, !input.blocks.contains(where: { $0.kind == .rest }),
              let start = freeSlot(input, minutes: 30) else { return nil }
        return Advice(
            rule: .rest,
            text: "В плане нет отдыха. Запланируй его как полноценный блок — тогда отдыхать можно без чувства вины.",
            why: "Восстанавливает отдых с переключением, а не отдых с тревогой о делах. Когда отдых стоит в плане, он перестаёт быть «прогулом».",
            basis: .research("восстановление после нагрузки, Sonnentag & Fritz, 2007"),
            action: .addBlock(title: "Отдых", kind: .rest, start: start, minutes: 30),
            actionTitle: "Добавить отдых в \(Self.time(start))"
        )
    }

    static func breaks(_ input: AdvisorInput, _ settings: AdvisorSettings) -> Advice? {
        var runs: [(start: Date, end: Date)] = []
        for block in study(input) {
            if let last = runs.last, block.start.timeIntervalSince(last.end) < 10 * 60 {
                runs[runs.count - 1].end = max(last.end, block.end)
            } else {
                runs.append((block.start, block.end))
            }
        }
        guard let run = runs.first(where: { PlanComparison.minutes(from: $0.start, to: $0.end) > settings.breakIntervalMinutes + 15 }) else {
            return nil
        }
        let breakStart = run.start.addingTimeInterval(TimeInterval(settings.breakIntervalMinutes * 60))
        return Advice(
            rule: .breaks,
            text: "Учёба с \(Self.time(run.start)) до \(Self.time(run.end)) идёт без паузы. Вставь перерыв на 15 минут около \(Self.time(breakStart)).",
            why: "Короткие перерывы надёжно снижают усталость, а заранее запланированные перерывы помогают меньше отвлекаться. Интервал можно выбрать под себя.",
            basis: .research("метаанализ микроперерывов, Albulescu и др., 2022; Biwer и др., 2023"),
            action: .addBlock(title: "Перерыв", kind: .rest, start: breakStart, minutes: 15),
            actionTitle: "Добавить перерыв"
        )
    }

    static func studyCeiling(_ input: AdvisorInput, _ settings: AdvisorSettings) -> Advice? {
        let minutes = study(input).reduce(0) { $0 + $1.minutes }
        guard minutes > settings.studyCeilingMinutes else { return nil }
        return Advice(
            rule: .studyCeiling,
            text: "Учёбы запланировано \(DurationText.short(minutes: minutes)) — больше твоего потолка \(DurationText.short(minutes: settings.studyCeilingMinutes)). Лучше стабильно, чем до упора.",
            why: "Работа до упора часто заканчивается долгим провалом. Ровный темп с потолком в день даёт больше за неделю и месяц.",
            basis: .practice, action: nil, actionTitle: nil
        )
    }

    static func sleep(_ input: AdvisorInput, _ settings: AdvisorSettings) -> Advice? {
        let sleepBlocks = input.blocks.filter { $0.kind == .sleep }
        guard !sleepBlocks.isEmpty else { return nil }
        let minutes = sleepBlocks.reduce(0) { $0 + $1.minutes }
        guard minutes < settings.minSleepMinutes else { return nil }
        return Advice(
            rule: .sleep,
            text: "На сон запланировано \(DurationText.short(minutes: minutes)). Взрослым рекомендуют не меньше 7 часов — сдвинь отбой или подъём.",
            why: "Недосып снижает внимание и память: учёба на следующий день идёт медленнее, и сэкономленное время теряется.",
            basis: .research("рекомендации AASM и Sleep Research Society, 2015"),
            action: nil, actionTitle: nil
        )
    }

    static func energy(_ input: AdvisorInput, calendar: Calendar) -> Advice? {
        guard !input.bestEnergyHours.isEmpty else { return nil }
        let hard = input.blocks.first(where: \.isFrog) ?? study(input).max(by: { $0.minutes < $1.minutes })
        guard let hard else { return nil }
        let hour = calendar.component(.hour, from: hard.start)
        guard !input.bestEnergyHours.contains(where: { abs($0 - hour) <= 1 }) else { return nil }
        let hours = input.bestEnergyHours.map { "\($0):00" }.joined(separator: ", ")
        return Advice(
            rule: .energy,
            text: "По твоим отметкам больше всего сил в \(hours), а «\(hard.title)» стоит на \(hour):00. Если можно, перенеси сложное на продуктивные часы.",
            why: "Сложные задачи даются легче, когда энергия выше. Это наблюдение по твоим собственным данным, а не общее правило.",
            basis: .practice, action: nil, actionTitle: nil
        )
    }

    static func weekBalance(_ input: AdvisorInput, _ settings: AdvisorSettings) -> Advice? {
        guard input.weekDaysElapsed >= 3, settings.studyTargetMinutes > 0 else { return nil }
        let target = settings.studyTargetMinutes * input.weekDaysElapsed
        let ratio = Double(input.weekStudyMinutes) / Double(target)
        if ratio < 0.6 {
            return Advice(
                rule: .weekBalance,
                text: "За неделю учёбы \(DurationText.short(minutes: input.weekStudyMinutes)) при цели \(DurationText.short(minutes: target)). Не пытайся догнать за один день — добавь по часу в оставшиеся.",
                why: "Попытка наверстать всё сразу часто приводит к перегрузке и новому провалу. Небольшая прибавка каждый день устойчивее.",
                basis: .practice, action: nil, actionTitle: nil
            )
        }
        if ratio > 1.4 {
            return Advice(
                rule: .weekBalance,
                text: "За неделю учёбы уже \(DurationText.short(minutes: input.weekStudyMinutes)) — заметно больше цели. Оставь в ближайшие дни больше отдыха, чтобы не выгореть.",
                why: "Длинные периоды перегрузки часто сменяются долгим спадом. Отдых сейчас сохраняет темп на будущее.",
                basis: .practice, action: nil, actionTitle: nil
            )
        }
        return nil
    }

    private static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
