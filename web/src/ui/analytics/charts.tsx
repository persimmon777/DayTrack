// Простые SVG-графики без сторонних библиотек.

export function Bars(props: { items: { label: string; value: number; color: string }[]; max?: number; average?: number | null; percent?: boolean; height?: number }) {
  const h = props.height ?? 160, w = 320, pad = 22
  const max = props.max ?? Math.max(1, ...props.items.map((i) => i.value))
  const n = Math.max(props.items.length, 1)
  const bw = (w - pad) / n
  const y = (v: number) => h - 18 - (v / max) * (h - 30)
  const skip = n > 14 ? Math.ceil(n / 8) : 1
  return (
    <svg viewBox={`0 0 ${w} ${h}`} class="chart">
      {[0, 0.5, 1].map((f) => <g><line x1={pad} x2={w} y1={y(max * f)} y2={y(max * f)} class="grid" /><text x={0} y={y(max * f) + 3} class="axis">{props.percent ? `${Math.round(max * f * 100)}%` : Math.round(max * f)}</text></g>)}
      {props.items.map((i, k) => (
        <g>
          <rect x={pad + k * bw + bw * 0.15} y={y(i.value)} width={bw * 0.7} height={Math.max(0, h - 18 - y(i.value))} rx={2} fill={i.color} />
          {k % skip === 0 && <text x={pad + k * bw + bw / 2} y={h - 4} class="axis" text-anchor="middle">{i.label}</text>}
        </g>
      ))}
      {props.average != null && <g><line x1={pad} x2={w} y1={y(props.average)} y2={y(props.average)} class="avg" /><text x={pad + 2} y={y(props.average) - 3} class="axis">в среднем {props.percent ? `${Math.round(props.average * 100)}%` : Math.round(props.average)}</text></g>}
    </svg>
  )
}

export function StackedBars(props: { days: { label: string; parts: { value: number; color: string }[] }[]; unit?: string }) {
  const h = 180, w = 320, pad = 22
  const max = Math.max(1, ...props.days.map((d) => d.parts.reduce((a, p) => a + p.value, 0)))
  const n = Math.max(props.days.length, 1), bw = (w - pad) / n
  const scale = (v: number) => (v / max) * (h - 30)
  const skip = n > 14 ? Math.ceil(n / 8) : 1
  return (
    <svg viewBox={`0 0 ${w} ${h}`} class="chart">
      {[0, 0.5, 1].map((f) => <g><line x1={pad} x2={w} y1={h - 18 - scale(max * f)} y2={h - 18 - scale(max * f)} class="grid" /><text x={0} y={h - 15 - scale(max * f)} class="axis">{Math.round(max * f)}</text></g>)}
      {props.days.map((d, k) => {
        let acc = 0
        return (
          <g>
            {d.parts.map((p) => { const top = h - 18 - scale(acc + p.value); const r = <rect x={pad + k * bw + bw * 0.15} y={top} width={bw * 0.7} height={scale(p.value)} fill={p.color} />; acc += p.value; return r })}
            {k % skip === 0 && <text x={pad + k * bw + bw / 2} y={h - 4} class="axis" text-anchor="middle">{d.label}</text>}
          </g>
        )
      })}
    </svg>
  )
}

export function Donut(props: { items: { value: number; color: string }[]; size?: number }) {
  const size = props.size ?? 130, r = size / 2 - 8, c = 2 * Math.PI * r
  const total = Math.max(1, props.items.reduce((a, i) => a + i.value, 0))
  let offset = 0
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      <g transform={`rotate(-90 ${size / 2} ${size / 2})`}>
        {props.items.map((i) => {
          const len = (i.value / total) * c
          const el = <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={i.color} stroke-width={16} stroke-dasharray={`${Math.max(len - 1.5, 0)} ${c}`} stroke-dashoffset={-offset} />
          offset += len
          return el
        })}
      </g>
    </svg>
  )
}

export function PlanFactBars(props: { lines: { name: string; planned: number; fact: number }[] }) {
  const max = Math.max(1, ...props.lines.flatMap((l) => [l.planned, l.fact]))
  return (
    <div class="hbars">
      {props.lines.map((l) => (
        <div class="hbar">
          <span class="hbar-label">{l.name}</span>
          <div class="hbar-tracks">
            <div class="track"><i class="plan" style={{ width: `${(l.planned / max) * 100}%` }} /><span>{(l.planned / 60).toFixed(1).replace('.', ',')}</span></div>
            <div class="track"><i class="fact" style={{ width: `${(l.fact / max) * 100}%` }} /><span>{(l.fact / 60).toFixed(1).replace('.', ',')}</span></div>
          </div>
        </div>
      ))}
      <div class="legend"><span><i class="plan" />План</span><span><i class="fact" />Факт</span></div>
    </div>
  )
}

export function HourLines(props: { series: { name: string; color: string; values: Map<number, number> }[] }) {
  const h = 160, w = 320, pad = 18
  const x = (hour: number) => pad + (hour / 23) * (w - pad - 4)
  const y = (v: number) => h - 18 - ((v - 1) / 4) * (h - 30)
  return (
    <svg viewBox={`0 0 ${w} ${h}`} class="chart">
      {[1, 3, 5].map((v) => <g><line x1={pad} x2={w} y1={y(v)} y2={y(v)} class="grid" /><text x={2} y={y(v) + 3} class="axis">{v}</text></g>)}
      {[0, 6, 12, 18, 23].map((hr) => <text x={x(hr)} y={h - 4} class="axis" text-anchor="middle">{hr}</text>)}
      {props.series.map((s) => {
        const pts = [...s.values].sort((a, b) => a[0] - b[0])
        return (
          <g>
            <polyline fill="none" stroke={s.color} stroke-width={2} points={pts.map(([hr, v]) => `${x(hr)},${y(v)}`).join(' ')} />
            {pts.map(([hr, v]) => <circle cx={x(hr)} cy={y(v)} r={3} fill={s.color} />)}
          </g>
        )
      })}
    </svg>
  )
}
