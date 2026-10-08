import { describe, it, expect } from 'vitest'
import { calcPillars, BirthInputError, type BirthInput } from '../src/lib/saju'

const solar = (year: number, month: number, day: number, hour?: number, minute?: number): BirthInput => ({
  calendar: 'solar', year, month, day, hour, minute, gender: 'male',
})
const str = (b: BirthInput) => {
  const { pillars: p } = calcPillars(b)
  return [p.year, p.month, p.day, p.time].map((x) => (x ? x.gan + x.zhi : '--')).join(' ')
}

describe('사주 4주', () => {
  it('일반 사례', () => {
    expect(str(solar(1990, 3, 15, 10, 30))).toBe('庚午 己卯 己卯 己巳')
  })
  it('입춘 경계 (2024-02-04 입춘 17:27 KST)', () => {
    expect(str(solar(2024, 2, 4, 17, 0))).toBe('癸卯 乙丑 戊戌 辛酉')
    expect(str(solar(2024, 2, 4, 17, 40))).toBe('甲辰 丙寅 戊戌 辛酉')
  })
  it('자시(야자시): 일주는 당일 유지', () => {
    expect(str(solar(1990, 3, 15, 23, 30))).toBe('庚午 己卯 己卯 丙子')
  })
  it('시간 모름이면 시주 없음', () => {
    expect(str(solar(1990, 3, 15))).toBe('庚午 己卯 己卯 --')
  })
  it('음력 윤달 변환', () => {
    const r = calcPillars({ calendar: 'lunar', year: 2020, month: 4, day: 15, leap: true, gender: 'female' })
    expect(r.solar).toEqual({ y: 2020, m: 6, d: 6 })
  })
})

describe('입력 검증', () => {
  const bad = (b: BirthInput) => expect(() => calcPillars(b)).toThrow(BirthInputError)
  it('없는 양력 날짜', () => bad(solar(2023, 2, 29)))
  it('범위 밖 연도', () => bad(solar(1899, 1, 1)))
  it('없는 윤달', () => bad({ calendar: 'lunar', year: 2021, month: 4, day: 1, leap: true, gender: 'male' }))
  it('윤4월 30일은 없음(29일까지)', () =>
    bad({ calendar: 'lunar', year: 2020, month: 4, day: 30, leap: true, gender: 'male' }))
  it('시만 있고 분이 없음', () => bad(solar(1990, 3, 15, 10, undefined)))
})
