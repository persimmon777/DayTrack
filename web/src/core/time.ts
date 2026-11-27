// Дни обозначаются ключами вида 20261127. День начинается в 00:00 по времени устройства.

export type DayKey = number

export function keyOf(date: Date | number): DayKey {
  const d = new Date(date)
  return d.getFullYear() * 10000 + (d.getMonth() + 1) * 100 + d.getDate()
}

export function partsOf(key: DayKey) {
  return { year: Math.floor(key / 10000), month: Math.floor(key / 100) % 100, day: key % 100 }
}

/** Полночь дня. */
export function dateOfKey(key: DayKey): Date {
  const { year, month, day } = partsOf(key)
  return new Date(year, month - 1, day)
}

/** Полдень дня: не страдает от перевода часов. */
export function noonOfKey(key: DayKey): Date {
  const { year, month, day } = partsOf(key)
  return new Date(year, month - 1, day, 12)
}

export function isValidKey(key: DayKey): boolean {
  return keyOf(dateOfKey(key)) === key
}

export function addDays(key: DayKey, days: number): DayKey {
  const d = noonOfKey(key)
  d.setDate(d.getDate() + days)
  return keyOf(d)
}

/** Начало и конец дня в миллисекундах. */
export function windowOf(key: DayKey): { start: number; end: number } {
  const start = dateOfKey(key).getTime()
  const next = dateOfKey(addDays(key, 1)).getTime()
  return { start, end: next }
}

/** Момент внутри дня с данным временем на часах. */
export function resolve(hour: number, minute: number, key: DayKey): number {
  const { year, month, day } = partsOf(key)
  return new Date(year, month - 1, day, hour, minute).getTime()
}

export function minuteOfDay(time: number): number {
  const d = new Date(time)
  return d.getHours() * 60 + d.getMinutes()
}

/** Ближайший момент строго после `start` с данным временем на часах: «23:30–07:30» — до утра. */
export function endAfter(start: number, minute: number): number {
  const d = new Date(start)
  const candidate = new Date(d.getFullYear(), d.getMonth(), d.getDate(), Math.floor(minute / 60), minute % 60).getTime()
  if (candidate > start) return candidate
  const next = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1, Math.floor(minute / 60), minute % 60)
  return next.getTime()
}

export function weekday(key: DayKey): number {
  // 1 — воскресенье, 2 — понедельник, … 7 — суббота (как в Calendar Apple).
  return noonOfKey(key).getDay() + 1
}

export function daysInMonth(year: number, month: number): number {
  return new Date(year, month, 0).getDate()
}

export function todayKey(): DayKey {
  return keyOf(Date.now())
}

// MARK: Оформление по-русски

const monthsGen = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря']
const monthsNom = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь']
const monthsShort = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек']
const weekdaysShort = ['вс', 'пн', 'вт', 'ср', 'чт', 'пт', 'сб']
const weekdaysLong = ['воскресенье', 'понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота']

const pad = (n: number) => String(n).padStart(2, '0')

export function fmtTime(time: number): string {
  const d = new Date(time)
  return `${pad(d.getHours())}:${pad(d.getMinutes())}`
}

export function fmtMinute(minute: number): string {
  return `${pad(Math.floor(minute / 60) % 24)}:${pad(minute % 60)}`
}

export function fmtRange(start: number, end: number): string {
  return `${fmtTime(start)}–${fmtTime(end)}`
}

/** «вт, 10 ноября» */
export function fmtDay(key: DayKey): string {
  const { month, day } = partsOf(key)
  return `${weekdaysShort[noonOfKey(key).getDay()]}, ${day} ${monthsGen[month - 1]}`
}

/** «вторник, 10 ноября 2026» */
export function fmtDayLong(key: DayKey, withWeekday = true): string {
  const { year, month, day } = partsOf(key)
  const base = `${day} ${monthsGen[month - 1]} ${year}`
  return withWeekday ? `${weekdaysLong[noonOfKey(key).getDay()]}, ${base}` : base
}

/** «16 ноя» */
export function fmtDayShort(key: DayKey): string {
  const { month, day } = partsOf(key)
  return `${day} ${monthsShort[month - 1]}`
}

/** «пн 16.11» */
export function fmtDayTiny(key: DayKey): string {
  const { month, day } = partsOf(key)
  return `${weekdaysShort[noonOfKey(key).getDay()]} ${pad(day)}.${pad(month)}`
}

export function fmtWeekdayShort(key: DayKey): string {
  return weekdaysShort[noonOfKey(key).getDay()]
}

/** «Ноябрь 2026» */
export function fmtMonth(key: DayKey): string {
  const { year, month } = partsOf(key)
  return `${monthsNom[month - 1]} ${year}`
}

/** «45 мин», «2 ч», «1 ч 30 мин» */
export function duration(minutes: number): string {
  const total = Math.max(0, Math.round(minutes))
  const h = Math.floor(total / 60)
  const m = total % 60
  if (h === 0) return `${m} мин`
  if (m === 0) return `${h} ч`
  return `${h} ч ${m} мин`
}

export function percent(fraction: number): string {
  return `${Math.round(fraction * 100)}%`
}

export function minutesBetween(start: number, end: number): number {
  return Math.max(0, Math.round((end - start) / 60000))
}

export function timeInputValue(time: number): string {
  return fmtTime(time)
}

export function parseTimeInput(value: string): number {
  const [h, m] = value.split(':').map(Number)
  return (h || 0) * 60 + (m || 0)
}

export function dateInputValue(key: DayKey): string {
  const { year, month, day } = partsOf(key)
  return `${year}-${pad(month)}-${pad(day)}`
}

export function parseDateInput(value: string): DayKey {
  const [y, m, d] = value.split('-').map(Number)
  return y * 10000 + m * 100 + d
}

export function pluralDays(count: number): string {
  const mod10 = count % 10, mod100 = count % 100
  if (mod10 === 1 && mod100 !== 11) return `${count} день`
  if (mod10 >= 2 && mod10 <= 4 && !(mod100 >= 12 && mod100 <= 14)) return `${count} дня`
  return `${count} дней`
}
