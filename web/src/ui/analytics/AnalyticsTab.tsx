import { useEffect, useState } from 'preact/hooks'
import * as S from '../../data/store'
import { periodData, groupMinutes, heat, PeriodData } from '../../data/analytics'
import { Card, Segmented } from '../kit'
import { openSheet } from '../sheets'
import { ReportSheet, ReflectionSheet } from '../sheets/more'
import { BlockDetail, FactEditor } from '../sheets/editors'
import { Timeline, TimelineItem, scrollToHour } from '../Timeline'
import { planItem } from '../plan/PlanTab'
import { Bars, StackedBars, Donut, PlanFactBars, HourLines } from './charts'
import { dayTitle } from '../DayHeader'
import { useNow } from '../hooks'
import { addDays, DayKey, duration, fmtDayShort, fmtMonth, fmtTime, percent, todayKey, windowOf } from '../../core/time'
import { periodKinds, periodRange, PeriodKind, shiftPeriod } from '../../core/periods'
import { balanceGroups, reasonTitle } from '../../core/kinds'
import { focusStatuses } from '../../data/model'

export function AnalyticsTab(props: { dayKey: DayKey; setDayKey: (k: DayKey) => void }) {
  const [kind, setKind] = useState<PeriodKind>('day')
  const { dayKey } = props
  const range = periodRange(kind, dayKey)
  const today = todayKey()
  const title = kind === 'day' ? dayTitle(dayKey) : kind === 'week' ? `${fmtDayShort(range[0])} – ${fmtDayShort(range[1])}` : fmtMonth(dayKey)
  return (
    <div class="tab">
      <header class="topbar">
        <span class="spacer" />
        <span class="day-title">Аналитика</span>
        <div class="topbar-right"><button class="link small" onClick={() => openSheet(() => <ReportSheet kind={kind} anchor={dayKey} />)}>💬 Отчёт</button></div>
      </header>
      <div class="content">
        <Segmented value={kind} onChange={setKind} options={periodKinds.map((p) => ({ value: p.id, title: p.title }))} />
        <div class="period-nav">
          <button class="icon-btn" onClick={() => props.setDayKey(shiftPeriod(dayKey, kind, -1))}>‹</button>
          <b>{title}</b>
          <button class="icon-btn" onClick={() => props.setDayKey(shiftPeriod(dayKey, kind, 1))}>›</button>
        </div>
        {!(today >= range[0] && today <= range[1]) && <button class="link small center" onClick={() => props.setDayKey(today)}>К текущему периоду</button>}
        {kind === 'day' ? <DayAnalytics dayKey={dayKey} /> : <PeriodAnalytics range={range} kind={kind} onDay={(k) => { props.setDayKey(k); setKind('day') }} />}
      </div>
    </div>
  )
}

function DayAnalytics(props: { dayKey: DayKey }) {
  const now = useNow()
  const { dayKey } = props
  const st = S.getState()
  const d = S.day(dayKey)
  const sum = S.summary(d, now)
  const win = windowOf(dayKey)
  const prevDay = S.day(addDays(dayKey, -1))
  useEffect(() => {
    const starts = [...S.activeBlocks(d).map((b) => b.start), ...(d?.facts ?? []).map((f) => f.start)]
    scrollToHour(dayKey === todayKey() ? new Date().getHours() - 1 : starts.length ? new Date(Math.min(...starts)).getHours() : 8)
  }, [dayKey])
  const plan: TimelineItem[] = [...S.activeBlocks(prevDay).filter((b) => b.end > win.start).map((b) => planItem(b, undefined, true)), ...S.activeBlocks(d).map((b) => planItem(b, sum.status(b.id)?.status))]
  const factItem = (f: { id: string; title: string; start: number; end: number; categoryId: string | null; blockId: string | null }, ghost = false): TimelineItem =>
    ({ id: f.id, title: f.title, start: f.start, end: f.end, color: S.category(f.categoryId)?.color ?? '#7F8C8D', ghost, badge: !ghost && !f.blockId ? '⑂' : undefined, badgeColor: '#f39c12' })
  const facts = [...(prevDay?.facts ?? []).filter((f) => f.end > win.start).map((f) => factItem(f, true)), ...(d?.facts ?? []).map((f) => factItem(f))]
  const c = sum.current
  const marks = st.energy.filter((m) => m.day === dayKey).sort((a, b) => a.at - b.at)
  const r = st.reflections[dayKey]
  return (
    <>
      <Card>
        {c.completion !== null ? (
          <>
            <div class="big-number">{percent(c.completion)} <span class="muted">плана выполнено</span></div>
            <progress value={Math.min(c.completion, 1)} max={1} />
            <p class="muted small">Сделано {duration(c.creditedMinutes)} из {duration(c.plannedMinutes)}{c.unplannedMinutes ? ` · вне плана ${duration(c.unplannedMinutes)}` : ''}{c.blocks.filter((b) => b.status === 'missed').length ? ` · не сделано блоков: ${c.blocks.filter((b) => b.status === 'missed').length}` : ''}</p>
            {sum.planWasEdited && sum.baseline?.completion != null && <p class="muted small">К исходному плану, без правок: {percent(sum.baseline.completion)}</p>}
          </>
        ) : <p class="muted">{c.unplannedMinutes ? `Плана на этот день не было. Отмечено ${duration(c.unplannedMinutes)}.` : 'На этот день нет ни плана, ни факта.'}</p>}
      </Card>
      <Timeline window={win} titles={['План', 'Факт']} now={dayKey === todayKey() ? now : null} columns={[
        { items: plan, onTapItem: (id) => openSheet(() => <BlockDetail dayKey={dayKey} blockId={id} />) },
        { items: facts, onTapItem: (id) => { const f = d?.facts.find((x) => x.id === id); if (f) openSheet(() => <FactEditor dayKey={dayKey} fact={f} />) } },
      ]} />
      {d?.changes.length ? <Card><b>Правки плана после фиксации</b>{[...d.changes].sort((a, b) => a.at - b.at).map((x) => <div class="small list-row"><span class="muted">{fmtTime(x.at)}</span> {x.text}</div>)}</Card> : null}
      <Card>
        {marks.length > 0 && <><b>Энергия и настроение</b>{marks.map((m) => <div class="list-row small"><span class="muted mono">{fmtTime(m.at)}</span><span class="grow" />⚡ {m.energy} · 🙂 {m.mood}</div>)}</>}
        {r && (r.wentWell || r.hindered || r.changeTomorrow || r.rating) ? (
          <>
            <b class={marks.length ? 'mt' : ''}>Вечерний разбор</b>
            {r.wentWell && <p class="small"><span class="muted">Получилось:</span> {r.wentWell}</p>}
            {r.hindered && <p class="small"><span class="muted">Помешало:</span> {r.hindered}</p>}
            {r.changeTomorrow && <p class="small"><span class="muted">Изменю завтра:</span> {r.changeTomorrow}</p>}
            {r.rating > 0 && <p class="stars-text">{'★'.repeat(r.rating)}{'☆'.repeat(5 - r.rating)}</p>}
            <button class="link small" onClick={() => openSheet(() => <ReflectionSheet dayKey={dayKey} />)}>Изменить разбор</button>
          </>
        ) : <button class="link-row" onClick={() => openSheet(() => <ReflectionSheet dayKey={dayKey} />)}>🌙 Заполнить вечерний разбор</button>}
      </Card>
    </>
  )
}

function PeriodAnalytics(props: { range: [DayKey, DayKey]; kind: PeriodKind; onDay: (k: DayKey) => void }) {
  const data: PeriodData = periodData(props.range, props.kind)
  const groups = groupMinutes(data.byKind)
  const st = S.getState()
  const focuses = st.focuses.filter((f) => { const [a, b] = S.focusRange(f); return a <= props.range[1] && b >= props.range[0] })
  const progress = S.focusProgress(focuses, S.daysInRange(props.range[0], props.range[1]))
  const planned = data.days.filter((d) => d.planned > 0)
  const withFact = data.categories.filter((c) => c.fact > 0)
  const totalFact = Math.max(1, withFact.reduce((a, c) => a + c.fact, 0))
  const est = data.categories.filter((c) => c.ratio && c.ratio > 0)
  const today = todayKey()
  const blanks = (new Date(Math.floor(props.range[0] / 10000), Math.floor(props.range[0] / 100) % 100 - 1, props.range[0] % 100).getDay() + 6) % 7
  return (
    <>
      <Card>
        <div class="big-number">{data.completion !== null ? percent(data.completion) : '—'} <span class="muted">плана выполнено</span></div>
        <p class="muted small">Дней с планом: {planned.length} из {data.days.length} · отмечено {duration(data.totalFact)}</p>
        <div class="kpis">{balanceGroups.map((g) => <div><span class="muted small">{g.title}</span><b style={{ color: g.color }}>{duration(groups[g.id])}</b></div>)}</div>
      </Card>
      <Card>
        <b>{props.kind === 'month' ? 'Календарь' : 'Дни недели'}</b>
        <div class="heat-grid">
          {['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'].map((w) => <span class="cal-wd">{w}</span>)}
          {Array.from({ length: blanks }, () => <span />)}
          {data.days.map((p) => (
            <button class={`heat-cell ${p.key === today ? 'today' : ''}`} style={{ background: p.completion !== null && p.key <= today ? heat(p.completion) : p.fact ? 'var(--fill2)' : 'var(--fill1)' }} onClick={() => props.onDay(p.key)}>
              <span>{p.key % 100}</span>
              {p.completion !== null && p.key <= today && <small>{percent(p.completion)}</small>}
              {p.planned > 0 && !p.fact && p.key < today && <i class="no-fact" />}
            </button>
          ))}
        </div>
        <div class="legend small"><span><i style={{ background: heat(0.2) }} />до 40%</span><span><i style={{ background: heat(0.55) }} />40–70%</span><span><i style={{ background: heat(0.9) }} />от 70%</span><span><i class="no-fact-legend" />нет факта</span></div>
      </Card>
      {planned.length > 0 && <Card><b>Выполнение плана по дням</b><Bars percent max={1} average={data.completion} items={data.days.filter((d) => d.planned > 0).map((d) => ({ label: d.label, value: d.completion ?? 0, color: heat(d.completion ?? 0) }))} /></Card>}
      {data.totalFact > 0 && (
        <>
          <Card><b>Баланс по дням, часы</b>
            <StackedBars days={data.days.map((d) => { const g = groupMinutes(d.byKind); return { label: d.label, parts: balanceGroups.map((b) => ({ value: g[b.id] / 60, color: b.color })) } })} />
            <div class="legend small">{balanceGroups.map((g) => <span><i style={{ background: g.color }} />{g.title}</span>)}</div>
          </Card>
          <Card><b>Куда ушло время</b>
            <div class="donut-row"><Donut items={withFact.map((c) => ({ value: c.fact, color: c.color }))} />
              <div class="stack grow">{withFact.slice(0, 7).map((c) => <div class="list-row small"><i class="dot" style={{ background: c.color }} /><span class="grow">{c.name}</span><span class="muted">{percent(c.fact / totalFact)}</span></div>)}</div>
            </div>
          </Card>
        </>
      )}
      {data.categories.some((c) => c.planned > 0) && <Card><b>План и факт по категориям, часы</b><PlanFactBars lines={data.categories.slice(0, 8)} /></Card>}
      {focuses.length > 0 && (
        <Card><b>Фокусы</b>
          {focuses.map((f) => { const p = progress.get(f.id) ?? { minutes: 0, done: 0, total: 0 }; return <div class="list-row small"><span class="grow">{f.title}{f.status !== 'active' ? ` · ${focusStatuses.find((s) => s.id === f.status)!.title}` : ''}</span><span class="muted">{p.minutes ? duration(p.minutes) : '0 ч'}{p.total ? ` · ${p.done}/${p.total}` : ''}</span></div> })}
        </Card>
      )}
      {data.reasons.length > 0 && (
        <Card><b>Что сбивало с плана</b>
          {data.reasons.map((r) => <div class="reason-row"><span>{reasonTitle(r.reason)}</span><i style={{ width: `${(r.count / data.reasons[0].count) * 100}%` }} /><b>{r.count}</b></div>)}
        </Card>
      )}
      {est.length > 0 && (
        <Card><b>Точность оценок времени</b>
          {est.map((c) => { const p = Math.round((c.ratio! - 1) * 100); return <div class="list-row small"><i class="dot" style={{ background: c.color }} /><span class="grow">{c.name}</span><span class={p > 20 ? 'warn' : 'muted'}>{p === 0 ? 'точно' : p > 0 ? `дольше на ${p}%` : `быстрее на ${-p}%`}</span></div> })}
          <p class="muted small">Сравнение факта с планом по выполненным блокам. Если дела стабильно занимают больше, закладывай на них больше времени.</p>
        </Card>
      )}
      {data.energyByHour.size > 0 && (
        <Card><b>Энергия и настроение по часам</b>
          <HourLines series={[{ name: 'Энергия', color: '#F0932B', values: data.energyByHour }, { name: 'Настроение', color: '#22A6B3', values: data.moodByHour }]} />
          <div class="legend small"><span><i style={{ background: '#F0932B' }} />Энергия</span><span><i style={{ background: '#22A6B3' }} />Настроение</span></div>
          {data.bestEnergyHours.length > 0 && <p class="muted small">Больше всего сил: {data.bestEnergyHours.map((h) => `${h}:00`).join(', ')}. Сложные дела лучше ставить на эти часы.</p>}
        </Card>
      )}
      {!data.totalFact && !planned.length && <p class="empty">За этот период пока нет ни плана, ни факта.</p>}
    </>
  )
}
