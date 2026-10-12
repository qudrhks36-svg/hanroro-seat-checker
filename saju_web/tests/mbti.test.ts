import { describe, it, expect } from 'vitest'
import { analyze } from '../src/lib/analysis'
import { calcPillars } from '../src/lib/saju'
import { predictMbti, axisText, MBTI_GAIN } from '../src/lib/mbti'
import type { Pillars } from '../src/lib/saju'

const sample: Pillars = {
  year: { gan: '庚', zhi: '午' },
  month: { gan: '己', zhi: '卯' },
  day: { gan: '己', zhi: '卯' },
  time: { gan: '己', zhi: '巳' },
}
const clamp = (n: number) => Math.max(15, Math.min(85, n))

describe('predictMbti 샘플 (庚午 己卯 己卯 己巳)', () => {
  const p = predictMbti(analyze(sample))
  // 손계산 d 값 (스펙 "샘플 손계산"): EI, SN, TF, JP
  const D = [-0.07917, 0.21944, -0.28889, 0.20556]
  const expectPct = D.map((d) => clamp(Math.round(50 + MBTI_GAIN * d)))

  it('4축 순서와 글자', () => {
    expect(p.axes.map((x) => x.axis)).toEqual(['EI', 'SN', 'TF', 'JP'])
    expect(p.axes.map((x) => x.letters.join(''))).toEqual(['EI', 'SN', 'TF', 'JP'])
  })
  it('채택 배율 50 에서 샘플 값을 고정한다', () => {
    expect(MBTI_GAIN).toBe(50)
    expect(p.axes.map((x) => x.pctFirst)).toEqual([46, 61, 36, 60])
    expect(p.axes[0].reasons[1]).toEqual({ label: '인성', points: 6 })
  })
  it('pctFirst는 손계산 d 와 MBTI_GAIN 으로 정해진다', () => {
    expect(p.axes.map((x) => x.pctFirst)).toEqual(expectPct)
  })
  it('우세 글자와 유형 (부호는 GAIN 과 무관)', () => {
    expect(p.axes.map((x) => x.lean)).toEqual(['I', 'S', 'F', 'J'])
    expect(p.type).toBe('ISFJ')
  })
  it('balanced 는 |pctFirst-50| < 10', () => {
    expect(p.axes.map((x) => x.balanced)).toEqual(expectPct.map((v) => Math.abs(v - 50) < 10))
  })
  it('EI 근거 1순위는 관성 (v = -0.2222)', () => {
    const r = p.axes[0].reasons
    expect(r.length).toBeGreaterThanOrEqual(1)
    expect(r.length).toBeLessThanOrEqual(2)
    expect(r[0]).toEqual({ label: '관성', points: Math.round(0.22222 * MBTI_GAIN) })
  })
  it('같은 입력은 같은 결과이고 값은 15~85', () => {
    expect(JSON.stringify(predictMbti(analyze(sample)))).toBe(JSON.stringify(p))
    for (const x of p.axes) {
      expect(x.pctFirst).toBeGreaterThanOrEqual(15)
      expect(x.pctFirst).toBeLessThanOrEqual(85)
    }
  })
})

describe('axisText', () => {
  it('모든 축·글자에 문구가 있다', () => {
    for (const [axis, letters] of [['EI', 'EI'], ['SN', 'SN'], ['TF', 'TF'], ['JP', 'JP']] as const) {
      for (const l of letters) {
        const t = axisText(axis, l)
        expect(t.advice.length).toBeGreaterThan(10)
        expect(t.minor.length).toBeGreaterThan(10)
      }
    }
  })
})

describe('분포 검증 (1930~2029, 13일 간격, 정오)', () => {
  const samples = (() => {
    const out: ReturnType<typeof predictMbti>[] = []
    const t0 = Date.UTC(1930, 0, 1)
    const t1 = Date.UTC(2029, 11, 31)
    for (let t = t0; t <= t1; t += 13 * 86400000) {
      const d = new Date(t)
      const { pillars } = calcPillars({
        calendar: 'solar', year: d.getUTCFullYear(), month: d.getUTCMonth() + 1, day: d.getUTCDate(),
        hour: 12, minute: 0, gender: 'male',
      })
      out.push(predictMbti(analyze(pillars)))
    }
    return out
  })()

  for (let i = 0; i < 4; i++) {
    it(`축 ${i}: 평균 42~58, 15/85 포화 10% 미만, 균형 구간 50% 미만`, () => {
      const v = samples.map((s) => s.axes[i].pctFirst)
      const mean = v.reduce((a, b) => a + b, 0) / v.length
      const sat = v.filter((x) => x <= 15 || x >= 85).length / v.length
      const bal = v.filter((x) => Math.abs(x - 50) < 10).length / v.length
      expect(mean).toBeGreaterThanOrEqual(42)
      expect(mean).toBeLessThanOrEqual(58)
      expect(sat).toBeLessThan(0.1)
      expect(bal).toBeLessThan(0.5)
    })
  }
  it('16유형 중 12가지 이상 등장', () => {
    expect(new Set(samples.map((s) => s.type)).size).toBeGreaterThanOrEqual(12)
  })
})
