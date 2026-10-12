import { describe, it, expect } from 'vitest'
import { buildCharacter } from '../src/lib/character'
import { GAN, ZHI, GROUPS, ELEMENTS } from '../src/lib/tables'

describe('buildCharacter', () => {
  it('샘플: 己 일간, 卯 일지, 관성 우세, 중화', () => {
    const c = buildCharacter({ dayGan: '己', dayZhi: '卯', group: '관성', strength: '중화', dayElement: '土' })
    expect(c.nickname).toBe('듬직한 정원사 너구리')
    expect(c.emoji).toBe('🦝')
    expect(c.propEmoji).toBe('🌸')
    expect(c.propName).toBe('벚꽃')
    expect(c.tone).toBe('균형 잡힌')
    expect(c.accent).toBe('土')
    expect(c.bubbles.map((b) => b.label)).toEqual(['연애할 때', '일할 때', '스트레스 받을 때'])
    expect(c.bubbles[1].text).toBe('규칙과 역할이 분명해야 편하고, 맡은 책임은 끝까지 해내요.')
  })
  it('모든 조합(10 × 12 × 5 × 3)에서 빈 값이 없다', () => {
    for (const dayGan of GAN) for (const dayZhi of ZHI) for (const group of GROUPS) {
      for (const strength of ['신강', '중화', '신약'] as const) {
        const c = buildCharacter({ dayGan, dayZhi, group, strength, dayElement: ELEMENTS[0] })
        const s = JSON.stringify(c)
        expect(s).not.toContain('undefined')
        expect(c.nickname).toBe(`${c.adjective} ${c.job} ${c.animal}`)
        expect(c.bubbles).toHaveLength(3)
        for (const b of c.bubbles) expect(b.text.length).toBeGreaterThan(5)
      }
    }
  })
})
