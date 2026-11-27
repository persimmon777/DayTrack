import { layout } from '../core/comparison'
import { fmtMinute, fmtRange } from '../core/time'

export interface TimelineItem { id: string; title: string; start: number; end: number; color: string; badge?: string; badgeColor?: string; ghost?: boolean }
export interface TimelineColumn { items: TimelineItem[]; onTapItem?: (id: string) => void; onTapSpace?: (time: number) => void }

/** Шкала дня с одной или несколькими колонками рядом. */
export function Timeline(props: { window: { start: number; end: number }; columns: TimelineColumn[]; titles: string[]; now?: number | null; hourHeight?: number }) {
  const hh = props.hourHeight ?? 56
  const compact = hh < 40
  const hours = Math.max(1, Math.round((props.window.end - props.window.start) / 3600000))
  const total = hours * hh
  const y = (t: number) => (Math.min(Math.max(t - props.window.start, 0), props.window.end - props.window.start) / 3600000) * hh
  const timeAt = (offsetY: number) => {
    const sec = (Math.min(Math.max(offsetY, 0), total) / hh) * 3600
    const snapped = Math.floor(sec / 900) * 900
    return props.window.start + Math.min(snapped * 1000, props.window.end - props.window.start - 900000)
  }
  return (
    <div class="timeline-wrap">
      <div class="timeline-header">
        <span class="gutter" />
        {props.titles.map((t) => <span class="col-title">{t}</span>)}
      </div>
      <div class="timeline" style={{ height: total }}>
        {Array.from({ length: hours }, (_, i) => (
          <div class="hour" id={`hour-${i}`} style={{ top: i * hh, height: hh }}>
            <span class="hour-label">{fmtMinute(i * 60)}</span>
          </div>
        ))}
        <div class="columns">
          {props.columns.map((col) => {
            const slots = layout(col.items.map((i) => ({ start: i.start, end: i.end })))
            return (
              <div class="tl-column" onClick={(e) => {
                if (!col.onTapSpace || e.target !== e.currentTarget) return
                const rect = (e.currentTarget as HTMLElement).getBoundingClientRect()
                col.onTapSpace(timeAt(e.clientY - rect.top))
              }}>
                {col.items.map((item, idx) => {
                  const top = y(item.start)
                  const height = Math.max(y(item.end) - top, compact ? 14 : 22)
                  const s = slots[idx]
                  const width = 100 / s.columnCount
                  return (
                    <div class={`tl-block ${item.ghost ? 'ghost' : ''} ${compact ? 'compact' : ''}`}
                      style={{ top, height, left: `calc(${s.column * width}% + 1px)`, width: `calc(${width}% - 2px)`, '--c': item.color } as never}
                      onClick={(e) => { e.stopPropagation(); if (!item.ghost) col.onTapItem?.(item.id) }}>
                      {compact
                        ? <span class="tl-line"><span class="tl-time">{fmtRange(item.start, item.end)}</span> <b>{item.ghost ? '↑ ' : ''}{item.title}</b></span>
                        : <>
                          <b class="tl-title" style={{ WebkitLineClamp: height > 52 ? 2 : 1 }}>{item.ghost ? '↑ ' : ''}{item.title}</b>
                          {height >= 36 && <span class="tl-time">{fmtRange(item.start, item.end)}</span>}
                        </>}
                      {item.badge && <span class="tl-badge" style={{ color: item.badgeColor }}>{item.badge}</span>}
                    </div>
                  )
                })}
              </div>
            )
          })}
        </div>
        {props.now && props.now >= props.window.start && props.now < props.window.end && <div class="now-line" style={{ top: y(props.now) }} />}
      </div>
    </div>
  )
}

/** Прокрутить шкалу к нужному часу. */
export function scrollToHour(hour: number) {
  requestAnimationFrame(() => {
    const el = document.getElementById(`hour-${Math.min(Math.max(hour, 0), 23)}`)
    if (el) window.scrollTo({ top: el.getBoundingClientRect().top + window.scrollY - 120 })
  })
}
