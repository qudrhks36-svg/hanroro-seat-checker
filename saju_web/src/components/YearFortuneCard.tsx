import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import type { YearFortune } from '@/lib/interpret'

export function YearFortuneCard({ y }: { y: YearFortune }) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="flex items-center gap-2 text-base">
          {y.year}년 세운 <Badge variant="secondary">{y.ganzhi} · {y.god}</Badge>
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-2 text-sm leading-relaxed">
        {y.body.map((t, i) => <p key={i}>{t}</p>)}
      </CardContent>
    </Card>
  )
}
