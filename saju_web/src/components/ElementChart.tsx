import { Progress } from '@/components/ui/progress'
import { ELEMENTS, ELEMENT_KO, type Element } from '@/lib/tables'

export function ElementChart({ elements }: { elements: Record<Element, number> }) {
  const total = ELEMENTS.reduce((s, e) => s + elements[e], 0) || 1
  return (
    <div className="space-y-2">
      {ELEMENTS.map((e) => (
        <div key={e} className="flex items-center gap-3">
          <span className="w-12 text-sm">{ELEMENT_KO[e]}({e})</span>
          <Progress value={(elements[e] / total) * 100} className="h-2 flex-1" />
          <span className="w-6 text-right text-sm tabular-nums">{elements[e]}</span>
        </div>
      ))}
    </div>
  )
}
