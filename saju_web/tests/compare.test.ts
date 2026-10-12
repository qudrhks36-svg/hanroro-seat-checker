import { describe, it, expect } from 'vitest'
import { compareMbti } from '../src/lib/compare'
import type { MbtiPrediction, AxisResult } from '../src/lib/mbti'

// GAIN 과 무관하게 고정한 예측 (ISFJ)
const ax = (axis: AxisResult['axis'], letters: [string, string], pctFirst: number): AxisResult => ({
  axis, letters, pctFirst, lean: pctFirst >= 50 ? letters[0] : letters[1], balanced: Math.abs(pctFirst - 50) < 10, reasons: [],
})
const pred: MbtiPrediction = {
  axes: [ax('EI', ['E', 'I'], 47), ax('SN', ['S', 'N'], 59), ax('TF', ['T', 'F'], 38), ax('JP', ['J', 'P'], 58)],
  type: 'ISFJ',
}

describe('compareMbti', () => {
  it('전부 일치', () => {
    const c = compareMbti(pred, 'ISFJ')
    expect(c.matched).toEqual(['I', 'S', 'F', 'J'])
    expect(c.onlySaju).toEqual([])
    expect(c.onlyMbti).toEqual([])
    expect(c.score).toBe(1)
    expect(c.notes).toEqual([])
  })
  it('일부 일치 + 불일치 축 설명 (실제 글자 쪽 비율 35% 이상)', () => {
    const c = compareMbti(pred, 'ESTP')
    expect(c.matched).toEqual(['S'])
    expect(c.onlySaju).toEqual(['I', 'F', 'J'])
    expect(c.onlyMbti).toEqual(['E', 'T', 'P'])
    expect(c.score).toBe(0.25)
    expect(c.notes).toEqual([
      '사주에서도 E 쪽이 47%로 꽤 있는 편입니다',
      '사주에서도 T 쪽이 38%로 꽤 있는 편입니다',
      '사주에서도 P 쪽이 42%로 꽤 있는 편입니다',
    ])
  })
  it('35% 미만이면 다른 축이라고 말한다', () => {
    // EI 축을 E 20% / I 80% 로 바꾼 예측에서 실제가 E 이면 E 비율 20% < 35%
    const p2: MbtiPrediction = { ...pred, axes: [ax('EI', ['E', 'I'], 20), ...pred.axes.slice(1)] }
    const c = compareMbti(p2, 'ESFJ')
    expect(c.matched).toEqual(['S', 'F', 'J'])
    expect(c.notes).toEqual(['E 쪽은 사주 경향과 다른 축입니다'])
  })
  it('35% 경계: 정확히 35 는 꽤 있는 편, 34 는 다른 축', () => {
    const at = (pct: number, actual: string) =>
      compareMbti({ ...pred, axes: [ax('EI', ['E', 'I'], pct), ...pred.axes.slice(1)] }, `${actual}SFJ`).notes
    expect(at(35, 'E')).toEqual(['사주에서도 E 쪽이 35%로 꽤 있는 편입니다'])
    expect(at(34, 'E')).toEqual(['E 쪽은 사주 경향과 다른 축입니다'])
    expect(at(65, 'I')).toEqual(['사주에서도 I 쪽이 35%로 꽤 있는 편입니다'])
    expect(at(66, 'I')).toEqual(['I 쪽은 사주 경향과 다른 축입니다'])
  })
  it('형식이 틀리면 Error', () => {
    expect(() => compareMbti(pred, 'XXXX')).toThrow()
    expect(() => compareMbti(pred, 'ISF')).toThrow()
  })
})
