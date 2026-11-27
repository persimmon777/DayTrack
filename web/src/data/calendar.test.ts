import { describe, expect, it } from 'vitest'
import { dayFill, fillBackground, CalendarEntry } from './calendar'

const at = (h: number, m = 0) => new Date(2026, 11, 3, h, m).getTime()
const e = (title: string, s: number, end: number, color: string, kind: CalendarEntry['kind'] = 'study', source: CalendarEntry['source'] = 'block'): CalendarEntry =>
  ({ id: title, title, start: s, end, color, kind, source })

describe('заливка дня в календаре', () => {
  it('доли по времени категорий и самое раннее начало', () => {
    const f = dayFill([e('Зачёт', at(8), at(10, 30), '#111'), e('УЗИ', at(11, 5), at(12), '#222', 'other'), e('Сон', at(0), at(7), '#333', 'sleep')])
    expect(f.parts).toEqual([{ color: '#111', minutes: 150 }, { color: '#222', minutes: 55 }])
    expect(f.earliest).toBe(at(8))
    expect(fillBackground(f.parts)).toBe('linear-gradient(to right, #111 0.00% 73.17%, #222 73.17% 100.00%)')
  })
  it('напоминание с временем учитывается во времени, но не в заливке', () => {
    const f = dayFill([e('Позвонить', at(7, 30), at(7, 30), '#F0932B', null, 'reminder'), e('Пары', at(9), at(12), '#111')])
    expect(f.earliest).toBe(at(7, 30))
    expect(f.parts).toEqual([{ color: '#111', minutes: 180 }])
  })
  it('пустой день', () => {
    expect(dayFill([]).earliest).toBeNull()
    expect(fillBackground([])).toBeUndefined()
  })
})
