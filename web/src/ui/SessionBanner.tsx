import { useState } from 'preact/hooks'
import * as S from '../data/store'
import { useNow } from './hooks'
import { duration, fmtTime } from '../core/time'
import { toast } from './sheets'

const titles = { rest: 'Отдых', focus: 'Фокус', game: 'Игра' }
const icons = { rest: '☕', focus: '🚶', game: '🎮' }
const finish = { rest: 'Я вернулся', focus: 'Закончил', game: 'Выключил' }

/** Полоса идущей сессии: отдых, фокус или игра. */
export function SessionBanner() {
  const now = useNow(1000)
  const [stepPrompt, setStepPrompt] = useState<S.SessionResult | null>(null)
  const s = S.getState().session
  if (stepPrompt) {
    return (
      <div class="banner focus">
        <div class="stack">
          <b>Ты начал — это главное</b>
          <span class="small">{duration(stepPrompt.actual)} на деле записаны в факт. Завтра продолжишь с того же места — главное не пропускать два дня подряд.</span>
          <div class="row-buttons">
            {stepPrompt.projectId && stepPrompt.label && <button class="primary small" onClick={() => {
              const p = S.getState().projects.find((x) => x.id === stepPrompt.projectId)
              const st = p?.steps.find((x) => !x.done && x.title === stepPrompt.label)
              if (st) { st.done = true; S.commit() }
              setStepPrompt(null)
            }}>Шаг сделан</button>}
            <button class="secondary small" onClick={() => setStepPrompt(null)}>Ещё не закончил</button>
          </div>
        </div>
      </div>
    )
  }
  if (!s) return null
  const overdue = now > s.endsAt
  const left = Math.max(0, Math.round((s.endsAt - now) / 1000))
  const mm = String(Math.floor(left / 60)).padStart(2, '0'), ss = String(left % 60).padStart(2, '0')
  const over = Math.max(1, Math.round((now - s.endsAt) / 60000))
  const subtitle = s.mode === 'rest' ? (s.label ? `Потом: ${s.label}` : `С ${fmtTime(s.startedAt)} до ${fmtTime(s.endsAt)}`)
    : s.mode === 'focus' ? (s.label || 'Только эти минуты, потом можно остановиться') : `До ${fmtTime(s.endsAt)}. Сохранись заранее`
  const done = () => {
    const r = S.finishSession()
    if (!r) return
    if (r.mode === 'focus') setStepPrompt(r)
    else if (r.mode === 'rest') toast(r.actual > r.planned + 5 ? `Отдых занял ${duration(r.actual)} вместо ${duration(r.planned)}. Записал как есть: честные данные помогут планировать отдых реалистичнее.` : `Отдых записан в факт: ${duration(r.actual)}.`)
    else toast(r.actual > r.planned + 5 ? `Игра заняла ${duration(r.actual)} вместо ${duration(r.planned)}. Это не провал, а данные: в следующий раз сохранись за 5 минут до конца. На неделе осталось ${duration(S.gameRemaining())}.` : `Ты остановился вовремя — это настоящий навык. На неделе осталось ${duration(S.gameRemaining())} игр.`)
  }
  return (
    <div class={`banner ${s.mode} ${overdue && s.mode !== 'focus' ? 'overdue' : ''}`}>
      <span class="banner-icon">{icons[s.mode]}</span>
      <div class="stack grow">
        <b>{overdue
          ? s.mode === 'rest' ? `Отдых закончился ${duration(over)} назад` : s.mode === 'focus' ? `Сверх плана ${duration(over)} — отлично идёт` : `Игра идёт сверх плана: ${duration(over)}`
          : `${titles[s.mode]} · осталось ${mm}:${ss}`}</b>
        <span class="small muted ellipsis">{subtitle}</span>
      </div>
      <button class="link small muted" onClick={() => { if (confirm('Отменить без записи?')) S.cancelSession() }}>✕</button>
      <button class="primary small" onClick={done}>{finish[s.mode]}</button>
    </div>
  )
}
