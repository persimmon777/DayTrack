import { useEffect, useState } from 'preact/hooks'
import { getVersion, subscribe } from '../data/store'

/** Перерисовывает компонент при любом изменении данных. */
export function useStore() {
  const [, set] = useState(getVersion())
  useEffect(() => subscribe(() => set(getVersion())), [])
}

/** Текущее время, обновляемое с заданным шагом. */
export function useNow(stepMs = 30000) {
  const [now, setNow] = useState(Date.now())
  useEffect(() => {
    const id = window.setInterval(() => setNow(Date.now()), stepMs)
    return () => window.clearInterval(id)
  }, [stepMs])
  return now
}
