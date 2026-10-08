import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import type { Section } from '@/lib/interpret'

export function ReadingSections({ sections }: { sections: Section[] }) {
  return (
    <div className="space-y-3">
      {sections.map((s) => (
        <Card key={s.title}>
          <CardHeader className="pb-2"><CardTitle className="text-base">{s.title}</CardTitle></CardHeader>
          <CardContent className="space-y-2 text-sm leading-relaxed">
            {s.body.map((t, i) => <p key={i}>{t}</p>)}
          </CardContent>
        </Card>
      ))}
    </div>
  )
}
