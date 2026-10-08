import { describe, it, expect } from 'vitest'
import { analyze } from '../src/lib/analysis'
import { interpret, headline, yearFortune } from '../src/lib/interpret'
import type { Pillars } from '../src/lib/saju'

const sample: Pillars = {
  year: { gan: '庚', zhi: '午' },
  month: { gan: '己', zhi: '卯' },
  day: { gan: '己', zhi: '卯' },
  time: { gan: '己', zhi: '巳' },
}
const a = analyze(sample)

describe('interpret', () => {
  it('섹션 제목 순서가 고정이다', () => {
    expect(interpret(sample, a).map((s) => s.title)).toEqual([
      '기본 성향', '사주 구조', '오행 균형', '직업·활동 경향', '조언',
    ])
  })
  it('같은 입력은 같은 결과이고 undefined가 없다', () => {
    const x = JSON.stringify(interpret(sample, a))
    expect(x).toBe(JSON.stringify(interpret(sample, analyze(sample))))
    expect(x).not.toContain('undefined')
    expect(x).not.toContain('{el}')
  })
  it('기본 성향에 일간 풀이가 들어간다', () => {
    expect(interpret(sample, a)[0].body[0]).toContain('기토(己土)')
  })
  it('헤드라인', () => {
    expect(headline(a)).toBe('기토(己土) 일간 · 중화 · 용신 수(水)')
  })
})

describe('yearFortune', () => {
  it('2026 丙午 vs 己 일간', () => {
    const y = yearFortune(a, 2026)
    expect(y.ganzhi).toBe('丙午')
    expect(y.god).toBe('정인')
    expect(y.group).toBe('인성')
    expect(y.matchesYongshin).toBe(false)
    expect(y.summary).toBe('배움과 준비, 주변의 도움이 힘이 되는 안정적인 정비의 흐름입니다.')
    expect(JSON.stringify(y.body)).not.toContain('{el}')
  })
})
