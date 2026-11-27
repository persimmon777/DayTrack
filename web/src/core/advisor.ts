import { CategoryKind } from './kinds'
import { keywordScore } from './keywords'
import { duration, fmtTime, minutesBetween, percent } from './time'

export interface AdvisorBlock { id: string; title: string; start: number; end: number; kind: CategoryKind; categoryId?: string | null; categoryName?: string | null; isFrog?: boolean; hasFact?: boolean }

export type AdviceRule = 'frog' | 'startSmall' | 'estimates' | 'load' | 'oneThreeFive' | 'buffer' | 'breaks' | 'rest' | 'studyCeiling' | 'sleep' | 'minimumDay' | 'energy' | 'weekBalance'

export const adviceRules: { id: AdviceRule; title: string }[] = [
  { id: 'frog', title: 'Лягушка дня' },
  { id: 'startSmall', title: 'Старт на 5 минут' },
  { id: 'estimates', title: 'Поправка оценок времени' },
  { id: 'load', title: 'Лимит загрузки' },
  { id: 'oneThreeFive', title: 'Правило 1-3-5' },
  { id: 'buffer', title: 'Резерв на непредвиденное' },
  { id: 'breaks', title: 'Перерывы в учёбе' },
  { id: 'rest', title: 'Отдых в плане' },
  { id: 'studyCeiling', title: 'Потолок учёбы' },
  { id: 'sleep', title: 'Сон' },
  { id: 'minimumDay', title: 'День-минимум' },
  { id: 'energy', title: 'Продуктивные часы' },
  { id: 'weekBalance', title: 'Баланс недели' },
]
export const ruleTitle = (r: AdviceRule) => adviceRules.find((x) => x.id === r)!.title

export interface AdvisorSettings {
  loadLimit: number; bufferMinutes: number; breakInterval: number; studyCeiling: number
  minSleep: number; studyTarget: number; disabled: AdviceRule[]
}
export const defaultAdvisorSettings: AdvisorSettings = {
  loadLimit: 0.7, bufferMinutes: 60, breakInterval: 90, studyCeiling: 480, minSleep: 420, studyTarget: 360, disabled: [],
}

export interface AdvisorInput {
  blocks: AdvisorBlock[]
  taskEstimates: number[]
  window: { start: number; end: number }
  now: number
  awakeMinutes: number
  estimateHistory: Map<string, { ratio: number; samples: number }>
  daysWithoutPlan: number
  bestEnergyHours: number[]
  weekStudyMinutes: number
  weekDaysElapsed: number
}

export type AdviceAction =
  | { type: 'markFrog'; blockId: string }
  | { type: 'extendCategory'; categoryId: string; ratio: number }
  | { type: 'addBlock'; title: string; kind: CategoryKind; start: number; minutes: number }

export interface Advice { rule: AdviceRule; text: string; why: string; basis: string; action?: AdviceAction; actionTitle?: string }

const practice = 'Практический приём тайм-менеджмента, не научный закон'
const research = (s: string) => `Исследования: ${s}`
const mins = (b: { start: number; end: number }) => minutesBetween(b.start, b.end)
const pct = (r: number) => Math.round((r - 1) * 100)

export function roundUp(time: number, stepMinutes: number): number {
  const s = stepMinutes * 60000
  // Округление в локальном времени: часовые пояса со сдвигом в полчаса тоже работают.
  const offset = new Date(time).getTimezoneOffset() * 60000
  return Math.ceil((time - offset) / s) * s + offset
}

export function freeSlot(input: AdvisorInput, minutes: number, after?: number): number | null {
  const dayStart9 = input.window.start + 9 * 3600000
  const limit = input.window.start + 22 * 3600000
  let cursor = roundUp(Math.max(after ?? dayStart9, dayStart9, input.now), 15)
  const busy = input.blocks.filter((b) => b.kind !== 'sleep').sort((a, b) => a.start - b.start)
  while (cursor + minutes * 60000 <= limit) {
    const end = cursor + minutes * 60000
    const clash = busy.find((b) => b.start < end && b.end > cursor)
    if (clash) cursor = roundUp(clash.end, 15)
    else return cursor
  }
  return null
}

const work = (i: AdvisorInput) => i.blocks.filter((b) => b.kind !== 'sleep' && b.kind !== 'rest')
const study = (i: AdvisorInput) => i.blocks.filter((b) => b.kind === 'study').sort((a, b) => a.start - b.start)
const isBuffer = (b: AdvisorBlock) => keywordScore(b.title, ['резерв', 'буфер', 'запас']) !== null

export const rules: Record<AdviceRule, (i: AdvisorInput, s: AdvisorSettings) => Advice | null> = {
  minimumDay(i) {
    if (i.blocks.length || i.daysWithoutPlan < 2) return null
    const start = freeSlot(i, 25) ?? i.now
    return {
      rule: 'minimumDay',
      text: 'Несколько дней без плана — так бывает. Начни с дня-минимума: одно дело по фокусу на 25 минут и вечерний разбор.',
      why: 'После перерыва легче вернуться с маленького шага, чем с полного плана. Маленький обязательный минимум помогает не выпадать надолго после «работы до упора».',
      basis: practice, action: { type: 'addBlock', title: 'Главное дело, 25 минут', kind: 'study', start, minutes: 25 }, actionTitle: 'Добавить 25 минут',
    }
  },
  frog(i) {
    const s = study(i)
    if (!s.length) return null
    const frog = i.blocks.find((b) => b.isFrog)
    if (frog) {
      if (frog.id === s[0].id || frog.start <= s[0].start) return null
      return { rule: 'frog', text: `Лягушка «${frog.title}» стоит после других дел учёбы. Попробуй поставить её первой.`,
        why: 'Сложное дело, отложенное на потом, обычно так и не начинается: к вечеру сил меньше, а поводов отложить больше.', basis: practice }
    }
    const longest = s.reduce((a, b) => (mins(b) > mins(a) ? b : a))
    return { rule: 'frog', text: `Отметь «лягушку» — самое сложное дело дня. Например, «${longest.title}».`,
      why: 'Когда главное дело названо и стоит первым, его труднее отложить до последнего.', basis: practice,
      action: { type: 'markFrog', blockId: longest.id }, actionTitle: 'Сделать лягушкой' }
  },
  startSmall(i) {
    if (i.now < i.window.start || i.now >= i.window.end) return null
    const frog = i.blocks.find((b) => b.isFrog)
    if (!frog || frog.hasFact || frog.start >= i.now) return null
    return { rule: 'startSmall', text: `Лягушка «${frog.title}» ещё не начата. Не надо делать её целиком — начни на 5 минут: открой материалы и сделай первый крошечный шаг.`,
      why: 'Чаще всего мешает не само дело, а момент начала. Конкретный маленький шаг «сейчас открою и сделаю X» запускает работу легче, чем намерение сделать всё.',
      basis: research('намерения реализации, Gollwitzer, 1999') }
  },
  estimates(i) {
    const seen = new Map<string, string>()
    for (const b of i.blocks) if (b.categoryId) seen.set(b.categoryId, b.categoryName ?? 'эта категория')
    const c = [...seen].map(([id, name]) => ({ id, name, h: i.estimateHistory.get(id) }))
      .filter((x) => x.h && x.h.samples >= 3 && x.h.ratio >= 1.2).sort((a, b) => b.h!.ratio - a.h!.ratio)
    if (!c.length) return null
    const ratio = Math.min(c[0].h!.ratio, 2)
    return { rule: 'estimates', text: `Обычно «${c[0].name}» занимает у тебя на ${pct(c[0].h!.ratio)}% больше, чем запланировано. Заложить больше времени?`,
      why: 'Люди систематически недооценивают, сколько займёт дело. Помогает не «стараться точнее», а смотреть на свою прошлую статистику похожих дел.',
      basis: research('ошибка планирования, Kahneman & Tversky, 1979; Buehler и др., 1994'),
      action: { type: 'extendCategory', categoryId: c[0].id, ratio }, actionTitle: `Увеличить на ${pct(ratio)}%` }
  },
  load(i, s) {
    const planned = work(i).reduce((a, b) => a + mins(b), 0)
    if (i.awakeMinutes <= 0 || planned <= i.awakeMinutes * s.loadLimit) return null
    return { rule: 'load', text: `Занято ${percent(planned / i.awakeMinutes)} времени бодрствования (${duration(planned)}). Убери или перенеси что-нибудь, чтобы осталось место на дорогу, еду и неожиданное.`,
      why: 'План без запаса ломается от первой задержки, и к вечеру остаётся ощущение провала. Реалистичный план выполняется чаще и меньше демотивирует.', basis: practice }
  },
  oneThreeFive(i) {
    const sizes = [...work(i).map(mins), ...i.taskEstimates]
    const big = sizes.filter((m) => m >= 90).length, medium = sizes.filter((m) => m >= 30 && m < 90).length, small = sizes.filter((m) => m < 30).length
    if (!(big > 1 || medium > 3 || small > 5)) return null
    return { rule: 'oneThreeFive', text: `В плане ${big} больших, ${medium} средних и ${small} мелких дел. По правилу 1-3-5 реально успеть одно большое, три средних и пять мелких — лишнее лучше перенести.`,
      why: 'Ограничение числа дел заставляет заранее выбрать главное, а не надеяться успеть всё.', basis: practice }
  },
  buffer(i, s) {
    if (work(i).length < 2 || i.blocks.some(isBuffer)) return null
    const start = freeSlot(i, s.bufferMinutes)
    if (start === null) return null
    return { rule: 'buffer', text: `В дне нет резерва на непредвиденное. Внезапные дела случаются почти каждый день — оставь под них ${duration(s.bufferMinutes)}.`,
      why: 'Если под неожиданное нет места, оно вытесняет запланированное. С резервом внезапное дело не ломает весь день.', basis: practice,
      action: { type: 'addBlock', title: 'Резерв на непредвиденное', kind: 'other', start, minutes: s.bufferMinutes }, actionTitle: `Добавить резерв в ${fmtTime(start)}` }
  },
  rest(i) {
    if (!study(i).length || i.blocks.some((b) => b.kind === 'rest')) return null
    const start = freeSlot(i, 30)
    if (start === null) return null
    return { rule: 'rest', text: 'В плане нет отдыха. Запланируй его как полноценный блок — тогда отдыхать можно без чувства вины.',
      why: 'Восстанавливает отдых с переключением, а не отдых с тревогой о делах. Когда отдых стоит в плане, он перестаёт быть «прогулом».',
      basis: research('восстановление после нагрузки, Sonnentag & Fritz, 2007'),
      action: { type: 'addBlock', title: 'Отдых', kind: 'rest', start, minutes: 30 }, actionTitle: `Добавить отдых в ${fmtTime(start)}` }
  },
  breaks(i, s) {
    const runs: { start: number; end: number }[] = []
    for (const b of study(i)) {
      const last = runs[runs.length - 1]
      if (last && b.start - last.end < 10 * 60000) last.end = Math.max(last.end, b.end)
      else runs.push({ start: b.start, end: b.end })
    }
    const run = runs.find((r) => mins(r) > s.breakInterval + 15)
    if (!run) return null
    const breakStart = run.start + s.breakInterval * 60000
    return { rule: 'breaks', text: `Учёба с ${fmtTime(run.start)} до ${fmtTime(run.end)} идёт без паузы. Вставь перерыв на 15 минут около ${fmtTime(breakStart)}.`,
      why: 'Короткие перерывы надёжно снижают усталость, а заранее запланированные перерывы помогают меньше отвлекаться. Интервал можно выбрать под себя.',
      basis: research('метаанализ микроперерывов, Albulescu и др., 2022; Biwer и др., 2023'),
      action: { type: 'addBlock', title: 'Перерыв', kind: 'rest', start: breakStart, minutes: 15 }, actionTitle: 'Добавить перерыв' }
  },
  studyCeiling(i, s) {
    const m = study(i).reduce((a, b) => a + mins(b), 0)
    if (m <= s.studyCeiling) return null
    return { rule: 'studyCeiling', text: `Учёбы запланировано ${duration(m)} — больше твоего потолка ${duration(s.studyCeiling)}. Лучше стабильно, чем до упора.`,
      why: 'Работа до упора часто заканчивается долгим провалом. Ровный темп с потолком в день даёт больше за неделю и месяц.', basis: practice }
  },
  sleep(i, s) {
    const sl = i.blocks.filter((b) => b.kind === 'sleep')
    if (!sl.length) return null
    const m = sl.reduce((a, b) => a + mins(b), 0)
    if (m >= s.minSleep) return null
    return { rule: 'sleep', text: `На сон запланировано ${duration(m)}. Взрослым рекомендуют не меньше 7 часов — сдвинь отбой или подъём.`,
      why: 'Недосып снижает внимание и память: учёба на следующий день идёт медленнее, и сэкономленное время теряется.',
      basis: research('рекомендации AASM и Sleep Research Society, 2015') }
  },
  energy(i) {
    if (!i.bestEnergyHours.length) return null
    const s = study(i)
    const hard = i.blocks.find((b) => b.isFrog) ?? (s.length ? s.reduce((a, b) => (mins(b) > mins(a) ? b : a)) : null)
    if (!hard) return null
    const hour = new Date(hard.start).getHours()
    if (i.bestEnergyHours.some((h) => Math.abs(h - hour) <= 1)) return null
    return { rule: 'energy', text: `По твоим отметкам больше всего сил в ${i.bestEnergyHours.map((h) => `${h}:00`).join(', ')}, а «${hard.title}» стоит на ${hour}:00. Если можно, перенеси сложное на продуктивные часы.`,
      why: 'Сложные задачи даются легче, когда энергия выше. Это наблюдение по твоим собственным данным, а не общее правило.', basis: practice }
  },
  weekBalance(i, s) {
    if (i.weekDaysElapsed < 3 || s.studyTarget <= 0) return null
    const target = s.studyTarget * i.weekDaysElapsed
    const r = i.weekStudyMinutes / target
    if (r < 0.6) return { rule: 'weekBalance', text: `За неделю учёбы ${duration(i.weekStudyMinutes)} при цели ${duration(target)}. Не пытайся догнать за один день — добавь по часу в оставшиеся.`,
      why: 'Попытка наверстать всё сразу часто приводит к перегрузке и новому провалу. Небольшая прибавка каждый день устойчивее.', basis: practice }
    if (r > 1.4) return { rule: 'weekBalance', text: `За неделю учёбы уже ${duration(i.weekStudyMinutes)} — заметно больше цели. Оставь в ближайшие дни больше отдыха, чтобы не выгореть.`,
      why: 'Длинные периоды перегрузки часто сменяются долгим спадом. Отдых сейчас сохраняет темп на будущее.', basis: practice }
    return null
  },
}

const order: AdviceRule[] = ['minimumDay', 'frog', 'startSmall', 'estimates', 'load', 'oneThreeFive', 'buffer', 'rest', 'breaks', 'studyCeiling', 'sleep', 'energy', 'weekBalance']

export function advise(input: AdvisorInput, settings: AdvisorSettings = defaultAdvisorSettings): Advice[] {
  return order.filter((r) => !settings.disabled.includes(r)).map((r) => rules[r](input, settings)).filter((a): a is Advice => a !== null)
}
