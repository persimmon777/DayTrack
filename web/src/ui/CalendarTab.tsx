import { useState } from 'preact/hooks'
import * as S from '../data/store'
import { calendarEntries, dayFill, fillBackground } from '../data/calendar'
import { openSheet, closeSheet, Sheet } from './sheets'
import { BlockEditor, BlockDetail } from './sheets/editors'
import { ReminderEditor } from './sheets/more'
import { DayKey, fmtDayLong, fmtMonth, fmtTime, resolve, todayKey, windowOf } from '../core/time'
import { daysIn, periodRange, shiftPeriod } from '../core/periods'

/** Календарь месяца: день закрашен цветами категорий запланированного, в клетке — время самого раннего дела. */
export function CalendarTab(props: { onOpenDay: (k: DayKey) => void }) {
  const [month, setMonth] = useState(todayKey())
  const range = periodRange('month', month)
  const keys = daysIn(range)
  const today = todayKey()
  const blanks = (new Date(Math.floor(range[0] / 10000), Math.floor(range[0] / 100) % 100 - 1, 1).getDay() + 6) % 7
  const cells = keys.map((k) => {
    const entries = calendarEntries(k)
    const fill = dayFill(entries)
    return { k, entries, fill }
  })
  const isCurrent = today >= range[0] && today <= range[1]
  return (
    <div class="tab">
      <header class="topbar">
        <button class="icon-btn" aria-label="Предыдущий месяц" onClick={() => setMonth(shiftPeriod(month, 'month', -1))}>‹</button>
        <span class="day-title">{fmtMonth(month)}</span>
        <div class="topbar-right">
          {!isCurrent && <button class="link small" onClick={() => setMonth(today)}>Сегодня</button>}
          <button class="icon-btn" aria-label="Следующий месяц" onClick={() => setMonth(shiftPeriod(month, 'month', 1))}>›</button>
        </div>
      </header>
      <div class="content">
        <div class="mcal">
          {['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'].map((w) => <span class="cal-wd">{w}</span>)}
          {Array.from({ length: blanks }, () => <span />)}
          {cells.map(({ k, entries, fill }) => {
            const bg = fillBackground(fill.parts)
            const hasReminder = entries.some((e) => e.source === 'reminder')
            return (
              <button class={`mcal-cell ${bg ? 'filled' : ''} ${k === today ? 'today' : ''} ${k < today ? 'past' : ''}`}
                style={bg ? { background: bg } : undefined}
                aria-label={`${fmtDayLong(k)}: ${entries.length ? entries.map((e) => e.title).join(', ') : 'ничего не запланировано'}`}
                onClick={() => openSheet(() => <DayPopup dayKey={k} onOpenDay={props.onOpenDay} />)}>
                <span class="mcal-num">{k % 100}</span>
                {fill.earliest !== null && <span class="mcal-time">{fmtTime(fill.earliest)}</span>}
                {entries.length > 1 && <span class="mcal-more">+{entries.length - 1}</span>}
                {hasReminder && <span class="mcal-bell">🔔</span>}
              </button>
            )
          })}
        </div>
        <p class="muted small pad">Цвет дня — категории запланированных дел, по доле времени. В клетке — начало самого раннего дела. Сон в заливку не входит.</p>
      </div>
    </div>
  )
}

/** Список дел дня по нажатию на клетку. */
function DayPopup(props: { dayKey: DayKey; onOpenDay: (k: DayKey) => void }) {
  const { dayKey } = props
  const entries = calendarEntries(dayKey)
  const nextStart = () => {
    const last = Math.max(0, ...S.activeBlocks(S.day(dayKey)).map((b) => b.end))
    return last && last < windowOf(dayKey).end ? last : resolve(9, 0, dayKey)
  }
  const time = (e: (typeof entries)[number]) =>
    e.start === null ? 'весь день' : e.end !== null && e.end !== e.start ? `${fmtTime(e.start)}–${fmtTime(e.end)}` : fmtTime(e.start)
  return (
    <Sheet title={fmtDayLong(dayKey)}>
      <div class="group-body">
        {!entries.length && <p class="pad muted">На этот день ничего не запланировано.</p>}
        {entries.map((e) => (
          <div class={`row ${e.source === 'block' || e.source === 'reminder' ? 'tappable' : ''}`} onClick={() => {
            if (e.source === 'block') openSheet(() => <BlockDetail dayKey={dayKey} blockId={e.id} />)
            if (e.source === 'reminder') { const r = S.getState().reminders.find((x) => `rem-${x.id}` === e.id); if (r) openSheet(() => <ReminderEditor reminder={r} dayKey={dayKey} />) }
          }}>
            <span class="popup-mark">{e.source === 'reminder' ? '🔔' : <i class="dot" style={{ background: e.color, marginRight: 0 }} />}</span>
            <span class="mono popup-time">{time(e)}</span>
            <span class="grow">{e.title}{e.source === 'schedule' && <span class="muted small"> · расписание</span>}</span>
          </div>
        ))}
      </div>
      <div class="sheet-actions">
        <button class="primary" onClick={() => openSheet(() => <BlockEditor dayKey={dayKey} start={nextStart()} />)}>＋ Запланировать на этот день</button>
        <div class="two">
          <button class="secondary" onClick={() => openSheet(() => <ReminderEditor dayKey={dayKey} />)}>🔔 Напоминание</button>
          <button class="secondary" onClick={() => { closeSheet(); props.onOpenDay(dayKey) }}>Открыть день</button>
        </div>
      </div>
    </Sheet>
  )
}
