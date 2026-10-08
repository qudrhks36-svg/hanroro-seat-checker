import { PillarsTable } from '@/components/PillarsTable'
import { ElementChart } from '@/components/ElementChart'
import { headline, type YearFortune } from '@/lib/interpret'
import type { Person } from '@/lib/person'

type Props = { innerRef: React.RefObject<HTMLDivElement | null>; person: Person; year: YearFortune }

export function ShareCard({ innerRef, person, year }: Props) {
  const { pillars, analysis: a, solar } = person
  return (
    <div ref={innerRef} className="space-y-4 rounded-2xl border bg-background p-5">
      <div>
        <div className="text-xs text-muted-foreground">{solar.y}.{solar.m}.{solar.d} (양력 기준)</div>
        <div className="text-lg font-semibold">{headline(a)}</div>
      </div>
      <PillarsTable pillars={pillars} />
      <ElementChart elements={a.elements} />
      <div className="text-sm text-muted-foreground">{year.year}년 {year.ganzhi} · {year.god} · {year.summary}</div>
    </div>
  )
}
