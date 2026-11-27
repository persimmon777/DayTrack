import { describe, expect, it } from 'vitest'
import { emptyState } from './defaults'
import { exportSnapshot, importSnapshot } from './backup'

describe('резервная копия', () => {
  it('переживает экспорт и импорт без потерь', () => {
    const s = emptyState()
    const cat = s.categories[0]
    s.days[20261127] = {
      key: 20261127, lockedAt: 1000, planEditedAt: null, scheduleApplied: true,
      blocks: [{ id: 'B', title: 'Матан', start: 2000, end: 5000, note: '', categoryId: cat.id, baselineStart: 2000, baselineEnd: 5000, addedAfterLock: false, removedAt: null, missReason: 'phone', source: 'manual', focusId: null, isFrog: true }],
      tasks: [], facts: [{ id: 'F', title: 'Матан', start: 2000, end: 4000, note: '', reason: null, categoryId: cat.id, blockId: 'B', focusId: null, projectId: null }], changes: [],
    }
    s.projects.push({ id: 'P', title: 'Swift', why: '', categoryId: null, minimum: 5, ifThen: '', steps: [{ id: 'S', title: 'Открыть', minutes: 5, done: false }], createdAt: 1, lastWorkedAt: null, archived: false, nudgeOn: true, nudgeMinute: 1140, order: 0 })
    const json = JSON.parse(JSON.stringify(exportSnapshot(s)))
    expect(json.categories[0].colorHex).toBe(cat.color.replace('#', '').toUpperCase())
    const back = importSnapshot(json, s)
    expect(back.days[20261127]).toEqual(s.days[20261127])
    expect(back.categories[0]).toEqual({ ...cat, color: cat.color.toUpperCase() })
    expect(back.projects[0].steps[0].title).toBe('Открыть')
  })

  it('читает копию из iOS-версии', () => {
    const ios = {
      formatVersion: 1, exportedAt: '2026-11-20T10:00:00Z', appVersion: '0.1.0',
      categories: [{ uuid: 'C', name: 'Учёба', colorHex: '6C5CE7', symbol: 'book.fill', kindRaw: 'study', sortOrder: 0, isArchived: false }],
      days: [{ key: 20261120, blocks: [], tasks: [], facts: [{ uuid: 'F', title: 'Курсовая', start: '2026-11-20T07:00:00Z', end: '2026-11-20T08:00:00Z', note: '', categoryUUID: 'C' }], changes: [] }],
      reminders: [], scheduleRules: [], templates: [],
    }
    const s = importSnapshot(ios, emptyState())
    expect(s.categories[0].symbol).toBe('📘')
    expect(s.days[20261120].facts[0].end - s.days[20261120].facts[0].start).toBe(3600000)
  })
})
