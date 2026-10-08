import { describe, it, expect } from 'vitest'
import { analyze } from '../src/lib/analysis'
import type { Pillars } from '../src/lib/saju'

const P = (y: string, m: string, d: string, t?: string): Pillars => ({
  year: { gan: y[0], zhi: y[1] },
  month: { gan: m[0], zhi: m[1] },
  day: { gan: d[0], zhi: d[1] },
  time: t ? { gan: t[0], zhi: t[1] } : null,
})

describe('analyze', () => {
  it('1990-03-15 10:30 (庚午 己卯 己卯 己巳)', () => {
    const a = analyze(P('庚午', '己卯', '己卯', '己巳'))
    expect(a.dayGan).toBe('己')
    expect(a.dayElement).toBe('土')
    expect(a.elements).toEqual({ 木: 2, 火: 2, 土: 3, 金: 1, 水: 0 })
    expect(a.lacking).toEqual(['水'])
    expect(a.groups).toEqual({ 비겁: 2, 식상: 1, 재성: 0, 관성: 4, 인성: 2 })
    expect(a.dominantGroup).toBe('관성')
    expect(a.strength).toBe('중화')
    expect(a.yongshin).toBe('水')
  })
  it('신강: 용신은 식상·재성·관성 오행 중 가장 적은 것 (동률이면 식상 우선)', () => {
    const a = analyze(P('壬子', '甲寅', '甲寅', '乙亥'))
    expect(a.strength).toBe('신강')
    expect(a.yongshin).toBe('火')
  })
  it('신약: 용신은 인성·비겁 오행 (동률이면 인성 우선)', () => {
    const a = analyze(P('庚申', '辛酉', '甲子', '庚午'))
    expect(a.strength).toBe('신약')
    expect(a.yongshin).toBe('水')
  })
  it('시간 모름이면 6글자만 센다', () => {
    const a = analyze(P('庚午', '己卯', '己卯'))
    expect(Object.values(a.elements).reduce((x, y) => x + y, 0)).toBe(6)
  })
})
