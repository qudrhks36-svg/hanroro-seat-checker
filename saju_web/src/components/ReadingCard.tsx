import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Progress } from '@/components/ui/progress'
import type { Section } from '@/lib/interpret'

export function ReadingCard({ section: s }: { section: Section }) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-xs font-normal text-muted-foreground">{s.title}</CardTitle>
        <p className="text-base font-semibold leading-snug">{s.summary}</p>
      </CardHeader>
      <CardContent className="space-y-3 text-sm">
        <div className="flex flex-wrap gap-1.5">
          {s.chips.map((c) => <Badge key={c} variant="secondary">{c}</Badge>)}
        </div>
        <ul className="list-disc space-y-1 pl-5">
          {s.bullets.map((b, i) => <li key={i}>{b}</li>)}
        </ul>
        {s.meter && (
          <div className="space-y-1.5">
            {s.meter.map((m) => (
              <div key={m.label} className="flex items-center gap-3">
                <span className="w-16 shrink-0 text-xs">{m.label}</span>
                <Progress value={m.value} aria-label={m.label} className="h-2 flex-1" />
                <span className="w-10 text-right text-xs tabular-nums">{m.value}%</span>
              </div>
            ))}
          </div>
        )}
        <details>
          <summary className="cursor-pointer text-xs text-muted-foreground">더 보기</summary>
          <div className="mt-2 space-y-2 leading-relaxed">
            {s.more.map((t, i) => <p key={i}>{t}</p>)}
          </div>
        </details>
      </CardContent>
    </Card>
  )
}
