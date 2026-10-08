import { describe, it, expect } from 'vitest'
import { tenGod, groupBetween, groupElement, zhiRelation, ganHe, ganEl } from '../src/lib/tables'

describe('십성', () => {
  it('일간 己 기준', () => {
    expect(tenGod('己', '己')).toBe('비견')
    expect(tenGod('己', '庚')).toBe('상관')
    expect(tenGod('己', '乙')).toBe('편관')
    expect(tenGod('己', '丁')).toBe('편인')
    expect(tenGod('己', '丙')).toBe('정인')
  })
  it('그룹과 그룹 오행', () => {
    expect(groupBetween('甲', '壬')).toBe('인성')
    expect(groupElement('木', '인성')).toBe('水')
    expect(groupElement('木', '재성')).toBe('土')
    expect(groupElement('木', '관성')).toBe('金')
    expect(groupElement('木', '식상')).toBe('火')
  })
})

describe('합충', () => {
  it('지지 관계', () => {
    expect(zhiRelation('午', '未')).toBe('육합')
    expect(zhiRelation('寅', '午')).toBe('삼합')
    expect(zhiRelation('子', '午')).toBe('충')
    expect(zhiRelation('子', '寅')).toBeNull()
    expect(zhiRelation('子', '子')).toBeNull()
  })
  it('천간합', () => {
    expect(ganHe('甲', '己')).toBe(true)
    expect(ganHe('己', '甲')).toBe(true)
    expect(ganHe('甲', '乙')).toBe(false)
    expect(ganEl('己')).toBe('土')
  })
})
