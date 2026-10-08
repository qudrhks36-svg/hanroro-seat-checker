import { describe, it, expect } from 'vitest'
import { analyze } from '../src/lib/analysis'
import { recommendPartners, compatibility } from '../src/lib/compat'
import type { Pillars } from '../src/lib/saju'

const P = (y: string, m: string, d: string, t?: string): Pillars => ({
  year: { gan: y[0], zhi: y[1] },
  month: { gan: m[0], zhi: m[1] },
  day: { gan: d[0], zhi: d[1] },
  time: t ? { gan: t[0], zhi: t[1] } : null,
})
const me = P('庚午', '己卯', '己卯', '己巳') // 1990-03-15 10:30
const meA = analyze(me)

describe('recommendPartners', () => {
  const r = recommendPartners(me, meA, { gender: 'female', birthYear: 1990, currentYear: 2026 })
  it('띠 추천: 午·卯 기준 육합·삼합 / 충', () => {
    expect(r.zodiac.good).toEqual(['양', '호랑이', '개', '돼지'])
    expect(r.zodiac.caution).toEqual(['쥐', '닭'])
  })
  it('나이차 상위 3개 (손계산: 1982 6점, 1991 5점, 1994 5점)', () => {
    expect(r.ages.map((x) => x.year)).toEqual([1982, 1991, 1994])
    expect(r.ages[1].label).toBe('1살 연하')
    expect(r.ages[0].label).toBe('8살 연상')
  })
  it('유형 문구에 용신 오행과 배우자성이 들어간다', () => {
    expect(r.type).toContain('대화가 잘 통하는')
    expect(r.type).toContain('관성(官星)')
    expect(r.type).not.toContain('{el}')
  })
  it('성인 기준 연도 상한', () => {
    const young = recommendPartners(me, meA, { gender: 'male', birthYear: 2005, currentYear: 2026 })
    expect(young.ages.every((x) => x.year <= 2007)).toBe(true)
  })
})

describe('compatibility', () => {
  it('일지 육합 + 일간 합 + 띠 삼합이면 매우 좋음', () => {
    const p2 = P('甲戌', '乙亥', '甲戌')
    const c = compatibility(me, meA, p2, analyze(p2))
    expect(c.score).toBeGreaterThanOrEqual(80)
    expect(c.level).toBe('매우 좋음')
    expect(c.reasons.join(' ')).toContain('일간 천간합')
    // 오행 라벨 뒤에 받침 여부에 따라 틀리는 조사(을/를)를 붙이지 않는다
    expect(c.reasons.join(' ')).not.toMatch(/\([木火土金水]\)[을를]/)
    expect(c.reasons.join(' ')).toMatch(/용신 오행은 [목화토금수]\([木火土金水]\)이고/)
  })
  it('일지·띠 충이면 낮다', () => {
    const p3 = P('庚子', '辛酉', '丙酉')
    const c = compatibility(me, meA, p3, analyze(p3))
    expect(c.score).toBeLessThan(40)
    expect(c.cautions.join(' ')).toContain('충')
  })
  it('점수는 0~100', () => {
    const c = compatibility(me, meA, me, meA)
    expect(c.score).toBeGreaterThanOrEqual(0)
    expect(c.score).toBeLessThanOrEqual(100)
  })
})
