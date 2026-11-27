import { useState } from 'preact/hooks'
import * as S from '../../data/store'
import type { Focus, FocusPeriod, Project, ProjectStep } from '../../data/model'
import { focusStatuses, uid } from '../../data/model'
import { Card, Group, TextRow, Select, Stepper, Toggle, TimeRow, CategorySelect } from '../kit'
import { openSheet, closeSheet, Sheet } from '../sheets'
import { FocusStart, EscapeHelp } from '../sheets/more'
import { SessionBanner } from '../SessionBanner'
import { DayKey, duration, fmtDayShort, fmtMonth, todayKey } from '../../core/time'
import { periodRange, shiftPeriod } from '../../core/periods'

export function FocusTab() {
  const [anchor, setAnchor] = useState(todayKey())
  const [showArchive, setShowArchive] = useState(false)
  const st = S.getState()
  const week = periodRange('week', anchor), month = periodRange('month', anchor)
  const weekFocuses = st.focuses.filter((f) => f.period === 'week' && f.periodStart === week[0]).sort((a, b) => a.order - b.order)
  const monthFocuses = st.focuses.filter((f) => f.period === 'month' && f.periodStart === month[0]).sort((a, b) => a.order - b.order)
  const weekProgress = S.focusProgress(weekFocuses, S.daysInRange(week[0], week[1]))
  const monthProgress = S.focusProgress(st.focuses.filter((f) => f.periodStart >= month[0] && f.periodStart <= month[1]), S.daysInRange(month[0], month[1]))
  const projects = st.projects.filter((p) => !p.archived).sort((a, b) => a.order - b.order)
  const archived = st.projects.filter((p) => p.archived)
  const isCurrent = anchor >= week[0] && anchor <= week[1] && todayKey() >= week[0] && todayKey() <= week[1]

  const section = (title: string, list: Focus[], progress: Map<string, S.FocusProgress>, period: FocusPeriod) => (
    <Card>
      <b>{title}</b>
      {list.map((f) => {
        const p = progress.get(f.id) ?? { minutes: 0, done: 0, total: 0 }
        const parent = st.focuses.find((x) => x.id === f.parentId)
        return (
          <div class="focus-row tappable" onClick={() => openSheet(() => <FocusEditor focus={f} period={period} start={f.periodStart} monthFocuses={monthFocuses} count={list.length} />)}>
            <div class="card-head"><span class={f.status === 'dropped' ? 'strike' : 'strong'}>{f.title}</span>
              {f.status !== 'active' && <span class={`tag ${f.status}`}>{focusStatuses.find((s) => s.id === f.status)!.title}</span>}</div>
            {f.why && <span class="muted small">Зачем: {f.why}</span>}
            {parent && <span class="muted small">↳ {parent.title}</span>}
            {p.total > 0 && <progress value={p.done} max={p.total} />}
            <span class="muted small">{p.minutes ? duration(p.minutes) : 'пока 0 ч'}{p.total ? ` · дел: ${p.done} из ${p.total}` : ''}</span>
          </div>
        )
      })}
      <button class="link-row" onClick={() => openSheet(() => <FocusEditor period={period} start={period === 'week' ? week[0] : month[0]} monthFocuses={monthFocuses} count={list.filter((f) => f.status !== 'dropped').length} />)}>＋ {period === 'week' ? 'Фокус недели' : 'Фокус месяца'}</button>
    </Card>
  )

  return (
    <div class="tab">
      <header class="topbar">
        <button class="icon-btn" onClick={() => setAnchor(shiftPeriod(anchor, 'week', -1))}>‹</button>
        <span class="day-title">Фокусы</span>
        <div class="topbar-right">
          {!isCurrent && <button class="link small" onClick={() => setAnchor(todayKey())}>Сейчас</button>}
          <button class="icon-btn" onClick={() => setAnchor(shiftPeriod(anchor, 'week', 1))}>›</button>
        </div>
      </header>
      <div class="content">
        <SessionBanner />
        <Card>
          <b>Большие дела</b>
          <p class="muted small">Курс, проект или объёмное задание, которое легко забросить. Дело разбивается на шаги по 5–25 минут, а минимум в несколько минут в день не даёт цепочке оборваться.</p>
          {projects.map((p) => <ProjectRow p={p} />)}
          <button class="link-row" onClick={() => openSheet(() => <ProjectEditor />)}>＋ Большое дело</button>
          <button class="link-row" onClick={() => openSheet(() => <EscapeHelp />)}>🛟 Хочу сбежать — помоги</button>
          {archived.length > 0 && <button class="link-row muted" onClick={() => setShowArchive(!showArchive)}>Завершённые: {archived.length} {showArchive ? '▴' : '▾'}</button>}
          {showArchive && archived.map((p) => <div class="list-row tappable muted" onClick={() => openSheet(() => <ProjectEditor project={p} />)}>{p.title}</div>)}
        </Card>
        {section(`Неделя ${fmtDayShort(week[0])} – ${fmtDayShort(week[1])}`, weekFocuses, weekProgress, 'week')}
        {section(fmtMonth(month[0]), monthFocuses, monthProgress, 'month')}
        <p class="muted small pad">Фокус — то главное, ради чего этот период. Привязывай к нему блоки плана, задачи и записи факта: время посчитается само. Лучше не больше трёх фокусов на период.</p>
      </div>
    </div>
  )
}

function ProjectRow(props: { p: Project }) {
  const p = props.p
  const idle = S.daysIdle(p)
  const step = S.nextStep(p)
  const done = p.steps.filter((s) => s.done).length
  return (
    <div class="project">
      <div class="card-head tappable" onClick={() => openSheet(() => <ProjectEditor project={p} />)}>
        <span class="strong">{p.title}</span>
        {S.workedToday(p) ? <span class="tag done">сегодня было</span> : idle >= 2 ? <span class="tag warn">{idle} дн. без движения</span> : null}
      </div>
      <span class={`small ${step ? 'muted' : 'warn'}`}>{step ? `Следующий шаг: ${step.title}` : 'Шаги не заданы — разбей дело на маленькие части'}</span>
      {p.steps.length > 0 && <progress value={done} max={p.steps.length} />}
      <button class="primary small" onClick={() => openSheet(() => <FocusStart projectId={p.id} minutes={p.minimum} />)}>▶ {p.minimum} минут сейчас</button>
    </div>
  )
}

function FocusEditor(props: { focus?: Focus; period: FocusPeriod; start: DayKey; monthFocuses: Focus[]; count: number }) {
  const f = props.focus
  const [title, setTitle] = useState(f?.title ?? '')
  const [why, setWhy] = useState(f?.why ?? '')
  const [parentId, setParentId] = useState(f?.parentId ?? null)
  const [status, setStatus] = useState(f?.status ?? 'active')
  const [result, setResult] = useState(f?.result ?? '')
  const save = () => {
    if (!f && props.count >= 3 && !confirm(`Это будет ${props.count + 1}-й фокус. Когда фокусов много, внимание распыляется и ни один не получает достаточно времени. Точно всё это главное?`)) return
    const st = S.getState()
    if (f) Object.assign(f, { title: title.trim(), why: why.trim(), parentId: props.period === 'week' ? parentId : null, status, result })
    else st.focuses.push({ id: uid(), title: title.trim(), why: why.trim(), period: props.period, periodStart: props.start, parentId: props.period === 'week' ? parentId : null, status: 'active', result: '', order: props.count, createdAt: Date.now() })
    S.commit()
    closeSheet()
  }
  return (
    <Sheet title={f ? 'Фокус' : props.period === 'week' ? 'Фокус недели' : 'Фокус месяца'} onSave={save} saveDisabled={!title.trim()}>
      <Group footer="Ответ на «зачем» помогает не бросать, когда трудно: он будет виден рядом с фокусом.">
        <TextRow value={title} onInput={setTitle} placeholder={props.period === 'week' ? 'Например: дописать главу курсовой' : 'Например: сдать сессию без долгов'} autofocus={!f} />
        <TextRow value={why} onInput={setWhy} placeholder="Зачем это мне" multiline />
      </Group>
      {props.period === 'week' && props.monthFocuses.length > 0 && (
        <Group><Select label="Шаг к фокусу месяца" value={parentId} onChange={setParentId} options={[{ value: null, title: 'Не связан' }, ...props.monthFocuses.map((m) => ({ value: m.id as string | null, title: m.title }))]} /></Group>
      )}
      {f && (
        <>
          <Group title="Итог">
            <Select label="Статус" value={status} onChange={setStatus} options={focusStatuses.map((s) => ({ value: s.id, title: s.title }))} />
            <TextRow value={result} onInput={setResult} placeholder="Что получилось, чему научился" multiline />
          </Group>
          <Group><button class="danger-row" onClick={() => { if (confirm('Удалить фокус? Привязанные дела останутся без привязки.')) { const st = S.getState(); st.focuses = st.focuses.filter((x) => x.id !== f.id); S.commit(); closeSheet() } }}>Удалить фокус</button></Group>
        </>
      )}
    </Sheet>
  )
}

export function ProjectEditor(props: { project?: Project }) {
  const p = props.project
  const [title, setTitle] = useState(p?.title ?? '')
  const [why, setWhy] = useState(p?.why ?? '')
  const [categoryId, setCategoryId] = useState(p?.categoryId ?? null)
  const [minimum, setMinimum] = useState(p?.minimum ?? 5)
  const [ifThen, setIfThen] = useState(p?.ifThen ?? '')
  const [steps, setSteps] = useState<ProjectStep[]>(p?.steps.map((s) => ({ ...s })) ?? [])
  const [newStep, setNewStep] = useState('')
  const [newMinutes, setNewMinutes] = useState(15)
  const [nudgeOn, setNudgeOn] = useState(p?.nudgeOn ?? true)
  const [nudge, setNudge] = useState(p?.nudgeMinute ?? 1140)
  const add = () => { const t = newStep.trim(); if (t) { setSteps([...steps, { id: uid(), title: t, minutes: newMinutes, done: false }]); setNewStep('') } }
  const save = () => {
    const st = S.getState()
    const value: Project = { id: p?.id ?? uid(), title: title.trim(), why, categoryId, minimum, ifThen, steps, createdAt: p?.createdAt ?? Date.now(), lastWorkedAt: p?.lastWorkedAt ?? null, archived: p?.archived ?? false, nudgeOn, nudgeMinute: nudge, order: p?.order ?? st.projects.length }
    st.projects = p ? st.projects.map((x) => (x.id === p.id ? value : x)) : [...st.projects, value]
    S.commit()
    closeSheet()
  }
  return (
    <Sheet title={p ? 'Изменить' : 'Большое дело'} onSave={save} saveDisabled={!title.trim()}>
      <Group>
        <TextRow value={title} onInput={setTitle} placeholder="Например: выучить Swift" autofocus={!p} />
        <TextRow value={why} onInput={setWhy} placeholder="Зачем это мне" />
        <CategorySelect value={categoryId} onChange={setCategoryId} />
      </Group>
      <Group title="Шаги" footer="Большое задание пугает, а пугающее мы избегаем. Разбей его на шаги по 5–25 минут. Первый шаг должен быть смешно маленьким: «открыть задание и прочитать условие».">
        {steps.map((s, i) => (
          <div class="task">
            <button class={`check ${s.done ? 'on' : ''}`} onClick={() => setSteps(steps.map((x, j) => (j === i ? { ...x, done: !x.done } : x)))}>{s.done ? '✓' : ''}</button>
            <input class={`inline-input ${s.done ? 'done' : ''}`} value={s.title} onInput={(e) => setSteps(steps.map((x, j) => (j === i ? { ...x, title: (e.target as HTMLInputElement).value } : x)))} />
            <span class={`small ${s.minutes > 25 ? 'warn' : 'muted'}`}>{s.minutes} мин</span>
            <button class="link small muted" onClick={() => setSteps(steps.filter((_, j) => j !== i))}>✕</button>
          </div>
        ))}
        <div class="task">
          <span class="check ghost">+</span>
          <input class="inline-input" value={newStep} placeholder="Новый шаг" onInput={(e) => setNewStep((e.target as HTMLInputElement).value)} onKeyDown={(e) => { if (e.key === 'Enter') add() }} />
          <select class="mini-select" value={newMinutes} onChange={(e) => setNewMinutes(Number((e.target as HTMLSelectElement).value))}>{[5, 10, 15, 25].map((m) => <option value={m}>{m} мин</option>)}</select>
          <button class="link small" onClick={add}>Добавить</button>
        </div>
        {!steps.length && <button class="link-row" onClick={() => setSteps([
          { id: uid(), title: 'Открыть задание и прочитать условие', minutes: 5, done: false },
          { id: uid(), title: 'Выписать, что непонятно, отдельными вопросами', minutes: 10, done: false },
          { id: uid(), title: 'Найти разобранный пример похожей задачи', minutes: 15, done: false },
          { id: uid(), title: 'Сделать самую простую часть, пусть криво', minutes: 25, done: false },
          { id: uid(), title: 'Сделать следующую часть', minutes: 25, done: false },
        ])}>Подставить шаги для объёмного задания</button>}
      </Group>
      <Group title="Минимум и план «если — то»" footer={`Минимум засчитывается как «не бросил». План «если — то» привязывает старт к ситуации: «Если поел после пар, то открываю курс на ${minimum} минут». Такие планы заметно повышают шанс начать.`}>
        <Stepper label="Минимум" value={minimum} step={1} min={2} max={30} onChange={setMinimum} format={(v) => `${v} мин`} />
        <TextRow value={ifThen} onInput={setIfThen} placeholder={`Если …, то открываю на ${minimum} минут`} multiline />
      </Group>
      <Group>
        <Toggle label="Напоминать, если сегодня не занимался" checked={nudgeOn} onChange={setNudgeOn} />
        {nudgeOn && <TimeRow label="Время" minute={nudge} onChange={setNudge} />}
      </Group>
      {p && (
        <Group>
          <button class="link-row" onClick={() => { p.archived = !p.archived; S.commit(); closeSheet() }}>{p.archived ? 'Вернуть из архива' : 'Готово, убрать в архив'}</button>
          <button class="danger-row" onClick={() => { if (confirm('Удалить дело?')) { const st = S.getState(); st.projects = st.projects.filter((x) => x.id !== p.id); S.commit(); closeSheet() } }}>Удалить</button>
        </Group>
      )}
    </Sheet>
  )
}
