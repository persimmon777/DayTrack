import { describe, expect, it } from 'vitest'
import { addDays, endAfter, keyOf, resolve, windowOf, duration, percent, isValidKey } from './time'
import { evaluate, layout } from './comparison'
import { bestMatch, keywordScore, parseKeywords } from './keywords'
import { occurs, occurrences, periodRange, shiftPeriod, ruleApplies, weekNumber, defaultFirstWeekKey } from './periods'
import { averageByHour, estimateRatios, median, minutesByKind, reasonCounts, softStreak, countLastDays } from './stats'
import { advise, freeSlot, rules, defaultAdvisorSettings, AdvisorBlock, AdvisorInput } from './advisor'

const at = (h: number, m = 0, day = 10) => new Date(2026, 10, day, h, m).getTime()

describe('время', () => {
  it('ключи и окна дня', () => {
    expect(keyOf(at(23, 59))).toBe(20261110)
    expect(addDays(20261231, 1)).toBe(20270101)
    expect(addDays(20260301, -1)).toBe(20260228)
    const w = windowOf(20261110)
    expect(w.start).toBe(at(0))
    expect(w.end).toBe(at(0, 0, 11))
    expect(isValidKey(20260231)).toBe(false)
    expect(resolve(9, 30, 20261110)).toBe(at(9, 30))
  })
  it('конец после начала переходит через полночь', () => {
    expect(endAfter(at(23, 30), 7 * 60 + 30)).toBe(at(7, 30, 11))
    expect(endAfter(at(23, 30), 23 * 60 + 45)).toBe(at(23, 45))
    expect(endAfter(at(23, 30), 23 * 60 + 30)).toBe(at(23, 30, 11))
  })
  it('длительность', () => {
    expect(duration(0)).toBe('0 мин')
    expect(duration(90)).toBe('1 ч 30 мин')
    expect(duration(120)).toBe('2 ч')
    expect(percent(0.584)).toBe('58%')
  })
})

describe('сравнение плана и факта', () => {
  it('выполнено, частично, не выполнено, впереди', () => {
    const r = evaluate(
      [{ id: 'a', start: at(9), end: at(10, 30) }, { id: 'b', start: at(11), end: at(13) }, { id: 'c', start: at(15), end: at(16, 30) }, { id: 'd', start: at(20), end: at(21) }],
      [{ id: '1', planId: 'a', start: at(9), end: at(10, 30) }, { id: '2', planId: 'b', start: at(12, 10), end: at(13) }, { id: '3', planId: null, start: at(14, 10), end: at(16) }],
      at(18),
    )
    expect(r.blocks.map((b) => b.status)).toEqual(['done', 'partial', 'missed', 'pending'])
    expect(r.creditedMinutes).toBe(140)
    expect(r.unplannedMinutes).toBe(110)
    expect(r.completion).toBeCloseTo(140 / 360)
  })
  it('сверх плана не засчитывается, сдвиг отмечается', () => {
    const r = evaluate([{ id: 'a', start: at(9), end: at(10) }], [{ id: '1', planId: 'a', start: at(9, 40), end: at(11) }], at(12))
    expect(r.blocks[0].creditedMinutes).toBe(60)
    expect(r.blocks[0].isShifted).toBe(true)
  })
  it('раскладка колонок', () => {
    expect(layout([{ start: 0, end: 120 }, { start: 10, end: 40 }, { start: 50, end: 100 }]))
      .toEqual([{ column: 0, columnCount: 2 }, { column: 1, columnCount: 2 }, { column: 1, columnCount: 2 }])
  })
})

describe('ключевые слова', () => {
  it('разбор и совпадения', () => {
    expect(parseKeywords('Тренировка, ЗАЛ;  бег\nзал, а, День  рождения')).toEqual(['тренировка', 'зал', 'бег', 'день рождения'])
    expect(keywordScore('Тренировка в зале', ['трениров'])).not.toBeNull()
    expect(keywordScore('Подготовка к экзамену', ['готов'])).toBeNull()
    expect(keywordScore('У Маши день рождения', ['день рожд'])).not.toBeNull()
    expect(keywordScore('ЁЖИК в тумане', ['ежик'])).not.toBeNull()
    expect(bestMatch('Пишу курсовую', [['курс'], ['курсов']])).toBe(1)
  })
})

describe('повторы и периоды', () => {
  it('повторы', () => {
    expect(occurs(20261127, 20261120, 'weekly')).toBe(true)
    expect(occurs(20270228, 20270131, 'monthly')).toBe(true)
    expect(occurs(20270228, 20000229, 'yearly')).toBe(true)
    expect(occurs(20280229, 20000229, 'yearly')).toBe(true)
    expect(occurrences(20261120, 'weekly', 20261116, 20261210)).toEqual([20261120, 20261127, 20261204])
  })
  it('периоды', () => {
    expect(periodRange('week', 20261118)).toEqual([20261116, 20261122])
    expect(periodRange('month', 20260215)).toEqual([20260201, 20260228])
    expect(shiftPeriod(20260131, 'month', 1)).toBe(20260228)
    expect(shiftPeriod(20261215, 'month', 13)).toBe(20280115)
  })
  it('чётность недель', () => {
    expect(weekNumber(20261116, 20260901)).toBe(12)
    expect(weekNumber(20260830, 20260901)).toBe(0)
    expect(ruleApplies({ weekday: 2, parity: 'odd', enabled: true }, 20261109, 20260901)).toBe(true)
    expect(ruleApplies({ weekday: 2, parity: 'odd', enabled: true }, 20261116, 20260901)).toBe(false)
    expect(defaultFirstWeekKey(20270310)).toBe(20260901)
  })
})

describe('статистика и серии', () => {
  it('статистика', () => {
    expect(minutesByKind([{ start: at(9), end: at(10, 30), categoryId: 'm', kind: 'study' }, { start: at(12), end: at(13), categoryId: null, kind: 'rest' }]))
      .toEqual({ study: 90, rest: 60 })
    const counts = reasonCounts(
      [{ start: at(9), end: at(10), categoryId: null, kind: 'rest', reason: 'phone' }, { start: at(10), end: at(11), categoryId: null, kind: 'rest', reason: 'phone' }, { start: at(11), end: at(12), categoryId: null, kind: 'rest' }],
      [{ id: 'x', start: at(15), end: at(16), categoryId: null, kind: 'study', missReason: 'suddenTask' }],
    )
    expect(counts.map((c) => c.reason)).toEqual(['phone', 'suddenTask', 'other'])
    expect([...averageByHour([{ at: at(10), value: 4 }, { at: at(10, 40), value: 2 }])]).toEqual([[10, 3]])
    expect(median([1, 3])).toBe(2)
    const r = estimateRatios(
      [{ id: 'a', start: at(9), end: at(10), categoryId: 'm', kind: 'study' }, { id: 'b', start: at(11), end: at(12), categoryId: 'm', kind: 'study' }, { id: 'c', start: at(13), end: at(14), categoryId: 'm', kind: 'study' }],
      [{ start: at(9), end: at(10, 30), categoryId: 'm', kind: 'study', planId: 'a' }, { start: at(11), end: at(13), categoryId: 'm', kind: 'study', planId: 'b' }, { start: at(13), end: at(14), categoryId: 'm', kind: 'study', planId: 'c' }],
    )
    expect(r.get('m')!.ratio).toBeCloseTo(1.5)
  })
  it('мягкие серии', () => {
    const s = (keys: number[]) => softStreak(new Set(keys), 20261119)
    expect(s([20261117, 20261118, 20261119])).toBe(3)
    expect(s([20261117, 20261118])).toBe(2)
    expect(s([20261116, 20261118, 20261119])).toBe(4)
    expect(s([20261116, 20261119])).toBe(1)
    expect(s([])).toBe(0)
    expect(s([20261111, 20261112, 20261114, 20261115, 20261116, 20261118, 20261119])).toBe(9)
    expect(countLastDays(new Set([20261119, 20261101, 20261020]), 30, 20261119)).toBe(2)
  })
})

describe('советчик', () => {
  const day = 16
  const t = (h: number, m = 0) => at(h, m, day)
  const win = { start: t(0), end: at(0, 0, 17) }
  const block = (title: string, from: number, to: number, kind: AdvisorBlock['kind'], extra: Partial<AdvisorBlock> = {}): AdvisorBlock =>
    ({ id: title + from, title, start: t(from), end: t(to), kind, ...extra })
  const input = (blocks: AdvisorBlock[], extra: Partial<AdvisorInput> = {}): AdvisorInput => ({
    blocks, taskEstimates: [], window: win, now: t(7), awakeMinutes: 960, estimateHistory: new Map(),
    daysWithoutPlan: 0, bestEnergyHours: [], weekStudyMinutes: 0, weekDaysElapsed: 0, ...extra,
  })
  const s = defaultAdvisorSettings

  it('лягушка и старт', () => {
    const long = block('Курсовая', 11, 14, 'study')
    expect(rules.frog(input([block('Матан', 9, 10, 'study'), long]), s)?.action).toEqual({ type: 'markFrog', blockId: long.id })
    expect(rules.startSmall(input([block('К', 9, 11, 'study', { isFrog: true })], { now: t(12) }), s)).not.toBeNull()
    expect(rules.startSmall(input([block('К', 9, 11, 'study', { isFrog: true, hasFact: true })], { now: t(12) }), s)).toBeNull()
  })
  it('резерв ищет свободное время', () => {
    const a = rules.buffer(input([block('Пары', 9, 13, 'study'), block('Курсовая', 14, 16, 'study')]), s)
    expect(a?.action).toMatchObject({ type: 'addBlock', start: t(13), minutes: 60 })
    expect(rules.buffer(input([block('Пары', 9, 13, 'study'), block('К', 14, 16, 'study'), block('Резерв', 17, 18, 'other')]), s)).toBeNull()
    expect(freeSlot(input([], { now: t(15, 10) }), 30)).toBe(t(15, 15))
  })
  it('отдых, перерывы, сон, потолок', () => {
    const found = advise(input([block('Пары', 9, 13, 'study'), block('Сон', 0, 6, 'sleep')]), { ...s, studyCeiling: 180 }).map((a) => a.rule)
    expect(found).toEqual(expect.arrayContaining(['rest', 'breaks', 'sleep', 'studyCeiling']))
    expect(advise(input([block('Пары', 9, 13, 'study')]), { ...s, disabled: ['rest'] }).map((a) => a.rule)).not.toContain('rest')
  })
  it('поправка оценок, день-минимум, неделя', () => {
    const b = [block('Матан', 9, 10, 'study', { categoryId: 'math', categoryName: 'Матан' })]
    expect(rules.estimates(input(b, { estimateHistory: new Map([['math', { ratio: 1.5, samples: 2 }]]) }), s)).toBeNull()
    expect(rules.estimates(input(b, { estimateHistory: new Map([['math', { ratio: 1.3, samples: 5 }]]) }), s)?.action)
      .toEqual({ type: 'extendCategory', categoryId: 'math', ratio: 1.3 })
    expect(rules.minimumDay(input([], { daysWithoutPlan: 2, now: t(10) }), s)).not.toBeNull()
    expect(rules.weekBalance(input([], { weekStudyMinutes: 300, weekDaysElapsed: 4 }), s)).not.toBeNull()
    expect(rules.weekBalance(input([], { weekStudyMinutes: 1400, weekDaysElapsed: 4 }), s)).toBeNull()
  })
})
