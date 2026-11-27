// Уведомления веб-версии. Браузер не умеет ставить уведомление «на потом», как iOS:
// они приходят, пока приложение открыто или только что свёрнуто. Для надёжных напоминаний
// есть экспорт в Календарь iPhone (см. ics ниже).
import { activeBlocks, daysIdle, getState, kindOf, nextStep, commit, workedToday } from './store'
import { addDays, DayKey, duration, fmtTime, keyOf, minutesBetween, resolve, todayKey } from '../core/time'
import { occurrences } from '../core/periods'

export interface Planned { id: string; at: number; title: string; body: string }

export function notificationsSupported() { return typeof Notification !== 'undefined' }
export function permission(): NotificationPermission | 'unsupported' { return notificationsSupported() ? Notification.permission : 'unsupported' }

export async function requestPermission() {
  if (!notificationsSupported()) return 'unsupported'
  return Notification.requestPermission()
}

async function show(n: Planned) {
  if (permission() !== 'granted') return false
  try {
    const reg = await navigator.serviceWorker?.getRegistration()
    if (reg) await reg.showNotification(n.title, { body: n.body, tag: n.id, icon: 'icon-192.png' })
    else new Notification(n.title, { body: n.body, tag: n.id })
    return true
  } catch { return false }
}

const at = (minute: number, key: DayKey) => resolve(Math.floor(minute / 60), minute % 60, key)

/** Все уведомления на ближайшие сутки по тем же правилам, что в iOS-версии. */
export function plannedNotifications(now = Date.now()): Planned[] {
  const st = getState()
  const n = st.settings.notify
  const today = todayKey()
  const out: Planned[] = []
  for (const key of [today, addDays(today, 1)]) {
    if (n.morningOn) out.push({ id: `daily-morning-${key}`, at: at(n.morning, key), title: 'Доброе утро', body: 'Загляни в план на сегодня: что главное и где отдых?' })
    if (n.eveningOn) out.push({ id: `daily-evening-${key}`, at: at(n.evening, key), title: 'Время подвести итоги', body: 'Внеси факт за день и ответь на три вопроса разбора. Это пара минут.' })
    if (n.factOn) {
      const lastEnd = Math.max(0, ...(st.days[key]?.facts ?? []).map((f) => f.end))
      n.factTimes.forEach((m, i) => {
        const t = at(m, key)
        if (lastEnd && t - lastEnd < 2 * 3600000) return
        out.push({ id: `fact-${key}-${i}`, at: t, title: 'Что было за последние часы?', body: 'Отметь факт, пока помнишь: это быстрее, чем вспоминать вечером.' })
      })
    }
    if (n.eveBeforeOn) {
      const tomorrow = addDays(key, 1)
      const blocks = activeBlocks(st.days[tomorrow]).filter((b) => b.source === 'manual').sort((a, b) => a.start - b.start)
      if (blocks.length) out.push({ id: `eve-${tomorrow}`, at: at(n.eveBefore, key), title: 'Завтра запланировано',
        body: blocks.slice(0, 4).map((b) => `${fmtTime(b.start)} ${b.title}`).join(', ') + (blocks.length > 4 ? ` и ещё ${blocks.length - 4}` : '') + '. Проверь, всё ли готово.' })
    }
    if (n.breakOn) {
      const runs: { start: number; end: number }[] = []
      for (const b of activeBlocks(st.days[key]).filter((x) => kindOf(x.categoryId) === 'study').sort((a, b) => a.start - b.start)) {
        const last = runs[runs.length - 1]
        if (last && b.start - last.end < 600000) last.end = Math.max(last.end, b.end)
        else runs.push({ start: b.start, end: b.end })
      }
      for (const r of runs) for (let t = r.start + n.breakInterval * 60000; t < r.end - 600000; t += n.breakInterval * 60000)
        out.push({ id: `break-${t}`, at: t, title: 'Пора сделать перерыв', body: `По плану ты учишься уже ${duration(minutesBetween(r.start, t))}. Встань, пройдись или разомнись 10–15 минут, лучше без телефона.` })
    }
    for (const r of st.reminders.filter((x) => x.notify)) {
      if (occurrences(r.firstDay, r.repeat, key, key).length) out.push({ id: `rem-${r.id}-${key}-0`, at: at(r.minute ?? 540, key), title: r.title, body: `Сегодня${r.minute !== null ? ` в ${fmtTime(at(r.minute, key))}` : ''}${r.note ? `\n${r.note}` : ''}` })
      if (r.leadDays > 0) {
        const target = addDays(key, r.leadDays)
        if (occurrences(r.firstDay, r.repeat, target, target).length) out.push({ id: `rem-${r.id}-${target}-${r.leadDays}`, at: at(1200, key), title: r.title, body: r.leadDays === 1 ? 'Завтра' : `Через ${r.leadDays} дн.` })
      }
    }
    for (const p of st.projects.filter((x) => !x.archived && x.nudgeOn)) {
      if (key === today && workedToday(p)) continue
      const step = nextStep(p)
      out.push({ id: `proj-${p.id}-${key}`, at: at(p.nudgeMinute, key), title: `${p.title}: ${p.minimum} минут?`,
        body: (daysIdle(p) >= 2 ? `${p.minimum} минут, и цепочка снова началась. Не надо наверстывать.` : `Всего ${p.minimum} минут — главное не пропускать два дня подряд.`) + (step ? ` Следующий шаг: ${step.title}.` : '') })
    }
  }
  const s = st.session
  if (s) {
    const d = s.endsAt
    if (s.mode === 'rest') {
      out.push({ id: `session-end-${s.startedAt}`, at: d, title: 'Отдых закончился', body: `Возвращайся ${s.label ? `к «${s.label}»` : 'к делам'}. Начни с самого маленького шага.` })
      out.push({ id: `session-late-${s.startedAt}`, at: d + 600000, title: 'Отдых затянулся на 10 минут', body: 'Ничего страшного. Нажми «Я вернулся», когда приступишь.' })
    } else if (s.mode === 'focus') {
      out.push({ id: `session-end-${s.startedAt}`, at: d, title: `${minutesBetween(s.startedAt, s.endsAt)} минут прошли`, body: 'Ты начал — это самое трудное. Можно остановиться с чистой совестью, а можно продолжить.' })
    } else {
      out.push({ id: `session-end-${s.startedAt}`, at: d, title: 'Игровое время вышло', body: 'Сохранись и выходи: это время ты сам себе выделил, и оно закончилось.' })
      out.push({ id: `session-late-${s.startedAt}`, at: d + 600000, title: 'Уже на 10 минут дольше', body: '«Ещё одна катка» — ловушка. Сохранись прямо сейчас.' })
      out.push({ id: `session-late2-${s.startedAt}`, at: d + 1800000, title: 'Полчаса сверх плана', body: 'Отложи телефон или геймпад в другую комнату и нажми «Выключил».' })
    }
  }
  void now
  return out
}

/** Показывает уведомления, время которых наступило за последние 15 минут. */
export async function tick(now = Date.now()) {
  const st = getState()
  const fired = new Set(st.firedNotifications)
  let changed = false
  for (const n of plannedNotifications(now)) {
    if (fired.has(n.id) || n.at > now || now - n.at > 15 * 60000) continue
    fired.add(n.id)
    changed = true
    await show(n)
    onInApp?.(n)
  }
  if (changed) {
    st.firedNotifications = [...fired].slice(-400)
    commit()
  }
}

let onInApp: ((n: Planned) => void) | null = null
export function setInAppHandler(handler: (n: Planned) => void) { onInApp = handler }

export function startScheduler() {
  tick()
  window.setInterval(() => tick(), 20000)
  document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'visible') tick() })
}

// MARK: Экспорт в Календарь iPhone

const pad = (x: number) => String(x).padStart(2, '0')
const icsDate = (t: number) => { const d = new Date(t); return `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}T${pad(d.getHours())}${pad(d.getMinutes())}00` }
const icsDay = (k: DayKey) => String(k)
const esc = (s: string) => s.replace(/\\/g, '\\\\').replace(/\n/g, '\\n').replace(/,/g, '\\,').replace(/;/g, '\;')

/** Файл .ics с напоминаниями и заранее запланированными делами: Календарь сам пришлёт уведомления. */
export function buildIcs(): string {
  const st = getState()
  const lines = ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//DayTrack//RU', 'CALSCALE:GREGORIAN']
  const stamp = icsDate(Date.now())
  for (const r of st.reminders) {
    lines.push('BEGIN:VEVENT', `UID:dt-rem-${r.id}`, `DTSTAMP:${stamp}`, `SUMMARY:${esc(r.title)}`)
    if (r.minute === null) lines.push(`DTSTART;VALUE=DATE:${icsDay(r.firstDay)}`)
    else { const s = at(r.minute, r.firstDay); lines.push(`DTSTART:${icsDate(s)}`, `DTEND:${icsDate(s + 1800000)}`) }
    const rr = { weekly: 'WEEKLY', monthly: 'MONTHLY', yearly: 'YEARLY', none: '' }[r.repeat]
    if (rr) lines.push(`RRULE:FREQ=${rr}`)
    if (r.note) lines.push(`DESCRIPTION:${esc(r.note)}`)
    lines.push('BEGIN:VALARM', 'ACTION:DISPLAY', `DESCRIPTION:${esc(r.title)}`, r.minute === null ? 'TRIGGER:PT9H' : 'TRIGGER:PT0M', 'END:VALARM')
    if (r.leadDays > 0) lines.push('BEGIN:VALARM', 'ACTION:DISPLAY', `DESCRIPTION:${esc(r.title)}`, `TRIGGER:-P${r.leadDays}D`, 'END:VALARM')
    lines.push('END:VEVENT')
  }
  const today = todayKey()
  for (const d of Object.values(st.days)) {
    if (d.key <= today || d.key > addDays(today, 60)) continue
    for (const b of activeBlocks(d).filter((x) => x.source === 'manual')) {
      lines.push('BEGIN:VEVENT', `UID:dt-block-${b.id}`, `DTSTAMP:${stamp}`, `SUMMARY:${esc(b.title)}`, `DTSTART:${icsDate(b.start)}`, `DTEND:${icsDate(b.end)}`,
        'BEGIN:VALARM', 'ACTION:DISPLAY', `DESCRIPTION:${esc(b.title)}`, 'TRIGGER:-PT15M', 'END:VALARM',
        'BEGIN:VALARM', 'ACTION:DISPLAY', `DESCRIPTION:Завтра: ${esc(b.title)}`, 'TRIGGER:-P1D', 'END:VALARM', 'END:VEVENT')
    }
  }
  lines.push('END:VCALENDAR')
  void keyOf
  return lines.join('\r\n')
}
