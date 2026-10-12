import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'

export function SituationBubbles({ bubbles }: { bubbles: { label: string; text: string }[] }) {
  return (
    <Card>
      <CardHeader className="pb-2"><CardTitle className="text-base">상황별 나</CardTitle></CardHeader>
      <CardContent className="space-y-3">
        {bubbles.map((b) => (
          <div key={b.label} className="space-y-1">
            <div className="text-xs text-muted-foreground">{b.label}</div>
            <div className="w-fit max-w-full rounded-2xl rounded-tl-sm bg-muted px-3 py-2 text-sm leading-relaxed">{b.text}</div>
          </div>
        ))}
      </CardContent>
    </Card>
  )
}
