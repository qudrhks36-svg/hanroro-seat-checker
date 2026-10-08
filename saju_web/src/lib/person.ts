import { calcPillars, type BirthInput, type Pillars, type SolarDate } from './saju'
import { analyze, type Analysis } from './analysis'

export type Person = { birth: BirthInput; solar: SolarDate; pillars: Pillars; analysis: Analysis }

export function buildPerson(birth: BirthInput): Person {
  const { solar, pillars } = calcPillars(birth)
  return { birth, solar, pillars, analysis: analyze(pillars) }
}
