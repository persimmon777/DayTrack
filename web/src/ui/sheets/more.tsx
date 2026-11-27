import { useState } from 'preact/hooks'
import { Sheet, closeSheet, openSheet, toast } from '../sheets'
import { Group, Row, TextRow, TimeRow, DateRow, Select, Toggle, ScalePicker, Segmented } from '../kit'
import * as S from '../../data/store'
import type { ID, Reminder } from '../../data/model'
import { uid } from '../../data/model'
import { DayKey, duration, fmtRange, minuteOfDay, percent, resolve, todayKey } from '../../core/time'
import { repeatRules, RepeatRule, PeriodKind } from '../../core/periods'
import { keywordScore } from '../../core/keywords'
import { reasons, Reason } from '../../core/kinds'
import { buildReport, promptText } from '../../data/report'

// MARK: Напоминание

export function ReminderEditor(props: { reminder?: Reminder; dayKey: DayKey }) {
  const r = props.reminder
  const [title, setTitle] = useState(r?.title ?? '')
  const [note, setNote] = useState(r?.note ?? '')
  const [firstDay, setFirstDay] = useState(r?.firstDay ?? props.dayKey)
  const [allDay, setAllDay] = useState(r ? r.minute === null : true)
  const [minute, setMinute] = useState(r?.minute ?? 720)
  const [repeat, setRepeat] = useState<RepeatRule>(r?.repeat ?? 'none')
  const [repeatChosen, setRepeatChosen] = useState(!!r)
  const [notify, setNotify] = useState(r?.notify ?? true)
  const [lead, setLead] = useState(r?.leadDays ?? 1)
  const save = () => {
    const st = S.getState()
    const value: Reminder = { id: r?.id ?? uid(), title: title.trim(), note, firstDay, minute: allDay ? null : minute, repeat, notify, leadDays: notify ? lead : 0, createdAt: r?.createdAt ?? Date.now() }
    st.reminders = r ? st.reminders.map((x) => (x.id === r.id ? value : x)) : [...st.reminders, value]
    S.commit()
    closeSheet()
  }
  return (
    <Sheet title={r ? 'Изменить' : 'Напоминание'} onSave={save} saveDisabled={!title.trim()}>
      <Group>
        <TextRow value={title} onInput={(v) => {
          setTitle(v)
          if (!repeatChosen) setRepeat(keywordScore(v, ['день рожд', 'др', 'годовщин']) !== null ? 'yearly' : 'none')
        }} placeholder="Например: день рождения Маши, врач" autofocus={!r} />
        <DateRow label="Дата" value={firstDay} onChange={setFirstDay} />
        <Toggle label="Весь день" checked={allDay} onChange={setAllDay} />
        {!allDay && <TimeRow label="Время" minute={minute} onChange={setMinute} />}
        <Select label="Повтор" value={repeat} onChange={(v) => { setRepeat(v); setRepeatChosen(true) }} options={repeatRules.map((x) => ({ value: x.id, title: x.title }))} />
      </Group>
      <Group footer={notify ? (allDay ? 'В сам день — в 9:00' : 'В сам день — в указанное время') + (lead > 0 ? ', а заранее — в 20:00.' : '.') : undefined}>
        <Toggle label="Уведомление" checked={notify} onChange={setNotify} />
        {notify && <Select label="Ещё заранее" value={lead} onChange={setLead} options={[{ value: 0, title: 'Не нужно' }, { value: 1, title: 'Накануне' }, { value: 3, title: 'За 3 дня' }, { value: 7, title: 'За неделю' }]} />}
      </Group>
      <Group title="Заметка"><TextRow value={note} onInput={setNote} placeholder="Необязательно" multiline /></Group>
      {r && <Group><button class="danger-row" onClick={() => { if (confirm('Удалить напоминание?')) { S.getState().reminders = S.getState().reminders.filter((x) => x.id !== r.id); S.commit(); closeSheet() } }}>Удалить</button></Group>}
    </Sheet>
  )
}

// MARK: Энергия

export function EnergySheet(props: { dayKey: DayKey }) {
  const [energy, setEnergy] = useState(3)
  const [mood, setMood] = useState(3)
  const [minute, setMinute] = useState(props.dayKey === todayKey() ? minuteOfDay(Date.now()) : 720)
  const save = () => {
    S.getState().energy.push({ id: uid(), at: resolve(Math.floor(minute / 60), minute % 60, props.dayKey), day: props.dayKey, energy, mood })
    S.commit()
    closeSheet()
  }
  return (
    <Sheet title="Как ты сейчас" onSave={save}>
      <Group title="Энергия"><ScalePicker value={energy} onChange={setEnergy} low="нет сил" high="полон сил" /></Group>
      <Group title="Настроение"><ScalePicker value={mood} onChange={setMood} low="плохое" high="отличное" /></Group>
      <Group footer="Отмечай пару раз в день. Через две недели станет видно, в какие часы у тебя больше всего сил, и сложное можно будет ставить на них.">
        <TimeRow label="Время" minute={minute} onChange={setMinute} />
      </Group>
    </Sheet>
  )
}

// MARK: Вечерний разбор

export function ReflectionSheet(props: { dayKey: DayKey }) {
  const st = S.getState()
  const existing = st.reflections[props.dayKey]
  const [wentWell, setWentWell] = useState(existing?.wentWell ?? '')
  const [hindered, setHindered] = useState(existing?.hindered ?? '')
  const [change, setChange] = useState(existing?.changeTomorrow ?? '')
  const [rating, setRating] = useState(existing?.rating ?? 0)
  const d = S.day(props.dayKey)
  const sum = S.summary(d)
  const missed = S.activeBlocks(d).filter((b) => sum.status(b.id)?.status === 'missed').sort((a, b) => a.start - b.start)
  const save = () => {
    st.reflections[props.dayKey] = { day: props.dayKey, wentWell: wentWell.trim(), hindered: hindered.trim(), changeTomorrow: change.trim(), rating, updatedAt: Date.now() }
    S.commit()
    closeSheet()
  }
  return (
    <Sheet title="Вечерний разбор" onSave={save}>
      {sum.current.completion !== null && (
        <Group><p class="pad">Выполнено {percent(sum.current.completion)} плана: {duration(sum.current.creditedMinutes)} из {duration(sum.current.plannedMinutes)}.<br /><span class="muted small">Любой процент — это данные, а не оценка тебя. Главное — понять, что помогло и что мешало.</span></p></Group>
      )}
      {missed.length > 0 && (
        <Group title="Что не получилось" footer="Выбери причину для каждого блока. В аналитике станет видно, что мешает чаще всего.">
          {missed.map((b) => (
            <Select label={<span>{b.title}<br /><span class="muted small">{fmtRange(b.start, b.end)}</span></span>} value={b.missReason}
              onChange={(v) => S.markMissed(b, v)} options={[{ value: null, title: 'Не указана' }, ...reasons.map((r) => ({ value: r.id as Reason | null, title: r.title }))]} />
          ))}
        </Group>
      )}
      <Group title="Что получилось"><TextRow value={wentWell} onInput={setWentWell} placeholder="Даже маленькое считается" multiline /></Group>
      <Group title="Что помешало"><TextRow value={hindered} onInput={setHindered} placeholder="Без самокритики, просто факты" multiline /></Group>
      <Group title="Что изменю завтра"><TextRow value={change} onInput={setChange} placeholder="Одно конкретное действие" multiline /></Group>
      <Group title="Оценка дня">
        <div class="stars">{[1, 2, 3, 4, 5].map((l) => <button class={l <= rating ? 'on' : ''} onClick={() => setRating(l === rating ? 0 : l)}>{l <= rating ? '★' : '☆'}</button>)}</div>
      </Group>
    </Sheet>
  )
}

// MARK: Сессии

export function RestStart(props: { dayKey: DayKey }) {
  const [minutes, setMinutes] = useState(15)
  const next = S.activeBlocks(S.day(props.dayKey)).filter((b) => b.end > Date.now() + minutes * 60000 && !['rest', 'sleep'].includes(S.kindOf(b.categoryId))).sort((a, b) => a.start - b.start)[0]
  const [label, setLabel] = useState(next?.title ?? '')
  return (
    <Sheet title="Отдых" onSave={() => { S.startSession('rest', minutes, label.trim()); closeSheet() }} saveTitle="Начать">
      <Group footer="Отдых с понятным концом проще начать без чувства вины и проще закончить.">
        <Select label="Длительность" value={minutes} onChange={setMinutes} options={[5, 10, 15, 20, 30, 45, 60].map((m) => ({ value: m, title: duration(m) }))} />
      </Group>
      <Group title="К чему вернусь"><TextRow value={label} onInput={setLabel} placeholder="Например: курсовая" /></Group>
    </Sheet>
  )
}

export function FocusStart(props: { projectId?: ID | null; minutes?: number }) {
  const projects = S.getState().projects.filter((p) => !p.archived)
  const [projectId, setProjectId] = useState<ID | null>(props.projectId ?? null)
  const [minutes, setMinutes] = useState(props.minutes ?? 5)
  const project = projects.find((p) => p.id === projectId)
  const [step, setStep] = useState(project ? S.nextStep(project)?.title ?? '' : '')
  return (
    <Sheet title="Только начать" onSave={() => { S.startSession('focus', minutes, step.trim(), projectId); closeSheet() }} saveTitle="Поехали">
      {projects.length > 0 && <Group><Select label="Дело" value={projectId} onChange={(v) => { setProjectId(v); const p = projects.find((x) => x.id === v); setStep(p ? S.nextStep(p)?.title ?? '' : '') }}
        options={[{ value: null, title: 'Другое' }, ...projects.map((p) => ({ value: p.id as ID | null, title: p.title }))]} /></Group>}
      <Group title="Один маленький шаг" footer="Чем конкретнее, тем легче начать: не «учить Swift», а «открыть урок 4 и прочитать первый раздел».">
        <TextRow value={step} onInput={setStep} placeholder="Что именно сделаю" multiline />
      </Group>
      <Group footer="Договор с собой: только эти минуты. Потом можно честно остановиться. Обычно трудно лишь начать — дальше идёт легче.">
        <div class="pad"><Segmented value={minutes} onChange={setMinutes} options={[2, 5, 10, 15, 25, 45].map((m) => ({ value: m, title: `${m}` }))} /></div>
      </Group>
    </Sheet>
  )
}

export function GameStart() {
  const stats = S.gameWeekStats()
  const remaining = S.gameRemaining()
  const g = S.getState().settings.games
  const [minutes, setMinutes] = useState(45)
  return (
    <Sheet title="Игра по таймеру" onSave={() => { S.startSession('game', minutes, ''); closeSheet() }} saveTitle="Начать">
      <Group>
        <Row label="Сыграно за неделю">{duration(stats.played)}</Row>
        {g.earnByStudy ? <Row label="Заработано учёбой">{duration(Math.min(stats.studied, g.budget))}</Row> : <Row label="Бюджет на неделю">{duration(g.budget)}</Row>}
        <Row label="Осталось"><span class={remaining === 0 ? 'warn' : ''}>{duration(remaining)}</span></Row>
      </Group>
      <Group footer={minutes > remaining ? 'Это больше, чем осталось в бюджете. Можно и так — запишется честно, но подумай о меньшем времени.' : 'Игры — нормальный отдых, если у них есть конец. Приложение напомнит, когда пора выходить, и ещё раз, если затянется.'}>
        <Select label="Сколько играю" value={minutes} onChange={setMinutes} options={[15, 30, 45, 60, 90, 120].map((m) => ({ value: m, title: duration(m) }))} />
      </Group>
    </Sheet>
  )
}

// MARK: Хочу сбежать

type Feeling = 'hard' | 'unclear' | 'boring' | 'scared' | 'tired' | 'games'
const feelings: { id: Feeling; title: string; icon: string }[] = [
  { id: 'hard', title: 'Слишком сложно', icon: '⛰️' },
  { id: 'unclear', title: 'Непонятно, с чего начать', icon: '❓' },
  { id: 'boring', title: 'Скучно', icon: '😴' },
  { id: 'scared', title: 'Боюсь, что не получится', icon: '⚠️' },
  { id: 'tired', title: 'Нет сил', icon: '🪫' },
  { id: 'games', title: 'Тянет поиграть', icon: '🎮' },
]

export function EscapeHelp(props: { projectId?: ID | null }) {
  const projects = S.getState().projects.filter((p) => !p.archived)
  const [projectId, setProjectId] = useState<ID | null>(props.projectId ?? null)
  const [feeling, setFeeling] = useState<Feeling | null>(null)
  const [question, setQuestion] = useState('')
  const project = projects.find((p) => p.id === projectId)
  const step = project ? S.nextStep(project)?.title ?? '' : ''
  const start = (title: string, minutes: number, label = step) => (
    <button class="link-row" onClick={() => { S.startSession('focus', minutes, label, projectId); closeSheet() }}>▶ {title}</button>
  )
  return (
    <Sheet title="Хочу сбежать">
      <Group><p class="pad">Желание сбежать — это не лень, а способ уйти от неприятного чувства. Назови его — так с ним легче справиться.</p></Group>
      {projects.length > 0 && <Group><Select label="От какого дела" value={projectId} onChange={setProjectId} options={[{ value: null, title: 'Не выбрано' }, ...projects.map((p) => ({ value: p.id as ID | null, title: p.title }))]} /></Group>}
      <Group title="Что сейчас чувствуешь?">
        {feelings.map((f) => <Row onClick={() => setFeeling(f.id)} label={`${f.icon} ${f.title}`}>{feeling === f.id ? '✓' : ''}</Row>)}
      </Group>
      {feeling && (
        <Group title="Что можно сделать">
          {feeling === 'hard' && <><p class="pad">Сделай дело меньше, а не себя сильнее. Возьми самый крошечный кусок и только 5 минут.</p>{start('Начать на 5 минут', 5)}</>}
          {feeling === 'unclear' && <><p class="pad">Запиши один вопрос, который мешает начать. Найти ответ на него и есть первый шаг.</p>
            <TextRow value={question} onInput={setQuestion} placeholder="Например: как устроен цикл for?" />{start('Искать ответ 10 минут', 10, question ? `Найти ответ: ${question}` : step)}</>}
          {feeling === 'boring' && <><p class="pad">Скучное проще сделать коротким рывком с наградой: 15 минут дела, потом то, что нравится. Можно включить фоновую музыку.</p>{start('15 минут, потом награда', 15)}</>}
          {feeling === 'scared' && <><p class="pad">Первая попытка имеет право быть плохой. Задача сейчас — не сделать хорошо, а сделать черновик. Никто не справляется сразу.</p>{start('Плохой черновик за 10 минут', 10)}</>}
          {feeling === 'tired' && <><p class="pad">Если сил правда нет, честный отдых лучше, чем час прокрастинации с чувством вины. Отдохни по таймеру, а потом — 5 минут дела.</p>
            <button class="link-row" onClick={() => { closeSheet(); openSheet(() => <RestStart dayKey={todayKey()} />) }}>☕ Отдых по таймеру</button>{start('Всё-таки 5 минут', 5)}</>}
          {feeling === 'games' && <><p class="pad">Игры не враг — враг игры без конца. Сначала 25 минут дела, потом игра по таймеру: так игра становится наградой, а не побегом.</p>
            {start('25 минут дела', 25)}<button class="link-row" onClick={() => { closeSheet(); openSheet(() => <GameStart />) }}>🎮 Игра по таймеру</button></>}
        </Group>
      )}
    </Sheet>
  )
}

// MARK: Отчёт для нейросети

export function ReportSheet(props: { kind: PeriodKind; anchor: DayKey }) {
  const report = buildReport(props.kind, props.anchor)
  const full = `${promptText()}\n\n${report}`
  const copy = async (text: string, msg: string) => {
    try { await navigator.clipboard.writeText(text); toast(msg) } catch { toast('Не удалось скопировать: выдели текст и скопируй вручную') }
  }
  return (
    <Sheet title={`Отчёт: ${props.kind === 'day' ? 'день' : props.kind === 'week' ? 'неделя' : 'месяц'}`}>
      <p class="muted small pad">Нажми «Скопировать с запросом» и вставь текст в любую нейросеть. Запрос можно изменить в настройках.</p>
      <pre class="report">{report}</pre>
      <div class="sheet-actions">
        <button class="primary" onClick={() => copy(full, 'Скопировано вместе с запросом')}>Скопировать с запросом</button>
        <div class="two">
          <button class="secondary" onClick={() => copy(report, 'Скопирован только отчёт')}>Только отчёт</button>
          {'share' in navigator && <button class="secondary" onClick={() => navigator.share({ text: full }).catch(() => {})}>Поделиться</button>}
        </div>
      </div>
    </Sheet>
  )
}

