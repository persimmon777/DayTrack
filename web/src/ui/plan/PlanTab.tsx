import { useEffect, useState } from 'preact/hooks'
import * as S from '../../data/store'
import { DayHeader } from '../DayHeader'
import { Timeline, TimelineItem, scrollToHour } from '../Timeline'
import { Fab } from '../kit'
import { openSheet, toast } from '../sheets'
import { BlockEditor, BlockDetail } from '../sheets/editors'
import { ReminderEditor } from '../sheets/more'
import { SessionBanner } from '../SessionBanner'
import { PlanStatusCard, FocusStrip, StreakLine, AdviceCard, ProjectNudge, RemindersCard, TasksCard, ChangesCard } from './PlanCards'
import { PlanCalendar } from './PlanCalendar'
import { useNow } from '../hooks'
import { addDays, DayKey, todayKey, windowOf } from '../../core/time'
import type { Block } from '../../data/model'

export function planItem(b: Block, status?: string, ghost = false): TimelineItem {
  const c = S.category(b.categoryId)
  const badge = ghost ? undefined : status === 'done' ? '✓' : status === 'partial' ? '◐' : status === 'missed' ? '✕' : undefined
  const color = status === 'done' ? '#2ecc71' : status === 'partial' ? '#f39c12' : '#e74c3c'
  return { id: b.id, title: (b.isFrog && !ghost ? '🐸 ' : '') + b.title, start: b.start, end: b.end, color: c?.color ?? '#7F8C8D', badge, badgeColor: color, ghost }
}

export function PlanTab(props: { dayKey: DayKey; setDayKey: (k: DayKey) => void }) {
  const { dayKey } = props
  const now = useNow()
  const [calendar, setCalendar] = useState(false)
  const d = S.day(dayKey)
  const isToday = dayKey === todayKey()
  const sum = S.summary(d, now)
  const win = windowOf(dayKey)

  useEffect(() => {
    S.autoApplySchedule(dayKey)
    S.autoLock(todayKey())
    if (dayKey < todayKey()) S.autoLock(dayKey)
    const starts = S.activeBlocks(S.day(dayKey)).map((b) => b.start)
    scrollToHour(isToday ? new Date().getHours() - 1 : starts.length ? new Date(Math.min(...starts)).getHours() : 8)
  }, [dayKey])

  if (calendar) return <PlanCalendar dayKey={dayKey} onOpenDay={(k) => { props.setDayKey(k); setCalendar(false) }} onClose={() => setCalendar(false)} />

  const prev = S.activeBlocks(S.day(addDays(dayKey, -1))).filter((b) => b.end > win.start).map((b) => planItem(b, undefined, true))
  const items = [...prev, ...S.activeBlocks(d).map((b) => planItem(b, sum.status(b.id)?.status))]
  const defaultStart = () => {
    const last = Math.max(0, ...S.activeBlocks(d).map((b) => b.end))
    if (last && last < win.end) return last
    if (isToday) { const h = new Date(Date.now() + 3600000).getHours(); return win.start + h * 3600000 }
    return win.start + 9 * 3600000
  }
  return (
    <div class="tab">
      <DayHeader dayKey={dayKey} onChange={props.setDayKey} onCalendar={() => setCalendar(true)} />
      <div class="content">
        <SessionBanner />
        {isToday && <StreakLine />}
        <FocusStrip dayKey={dayKey} />
        {isToday && <ProjectNudge />}
        {dayKey >= todayKey() && <AdviceCard dayKey={dayKey} now={now} />}
        <PlanStatusCard day={d} planned={sum.current.plannedMinutes} />
        <RemindersCard dayKey={dayKey} showUpcoming={isToday} />
        <TasksCard dayKey={dayKey} day={d} />
        <Timeline window={win} titles={['План']} hourHeight={30} now={isToday ? now : null}
          columns={[{ items, onTapItem: (id) => openSheet(() => <BlockDetail dayKey={dayKey} blockId={id} />), onTapSpace: (t) => openSheet(() => <BlockEditor dayKey={dayKey} start={t} />) }]} />
        <ChangesCard day={d} />
      </div>
      <Fab items={[
        { title: 'Блок плана', icon: '➕', onClick: () => openSheet(() => <BlockEditor dayKey={dayKey} start={defaultStart()} />) },
        { title: 'Напоминание или событие', icon: '🔔', onClick: () => openSheet(() => <ReminderEditor dayKey={dayKey} />) },
        { title: 'Подставить расписание', icon: '🗓️', divider: true, onClick: () => { const n = S.applySchedule(dayKey); toast(n ? `Добавлено занятий из расписания: ${n}.` : 'В расписании нет занятий на этот день, которых ещё нет в плане.') } },
        ...S.getState().templates.map((t) => ({ title: `Шаблон: ${t.name}`, icon: '📋', onClick: () => S.applyTemplate(t.id, dayKey) })),
        ...(S.activeBlocks(d).length ? [{ title: 'Сохранить день как шаблон', icon: '💾', onClick: () => { const name = prompt('Название шаблона', 'Учебный день'); if (name?.trim() && d) { S.saveTemplate(name.trim(), d); toast('Шаблон сохранён') } } }] : []),
      ]} />
    </div>
  )
}
