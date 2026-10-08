import { useMemo } from 'react'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { recommendPartners } from '@/lib/compat'
import type { Person } from '@/lib/person'

export function PartnerRecommend({ me }: { me: Person }) {
  const r = useMemo(
    () => recommendPartners(me.pillars, me.analysis, {
      gender: me.birth.gender, birthYear: me.solar.y, currentYear: new Date().getFullYear(),
    }),
    [me],
  )
  return (
    <Card>
      <CardHeader className="pb-2"><CardTitle className="text-base">나와 잘 맞는 상대</CardTitle></CardHeader>
      <CardContent className="space-y-4 text-sm leading-relaxed">
        <div className="space-y-1">
          <div className="font-medium">띠</div>
          <div className="flex flex-wrap gap-1">
            {r.zodiac.good.map((z) => <Badge key={z}>{z}띠</Badge>)}
          </div>
          {r.zodiac.caution.length > 0 && (
            <div className="flex flex-wrap items-center gap-1 text-muted-foreground">
              충에 해당해 조율이 필요한 띠:
              {r.zodiac.caution.map((z) => <Badge key={z} variant="outline">{z}띠</Badge>)}
            </div>
          )}
        </div>
        <div className="space-y-1">
          <div className="font-medium">상대 유형</div>
          <p>{r.type}</p>
        </div>
        <div className="space-y-1">
          <div className="font-medium">나이차 (출생연도 기준)</div>
          {r.ages.length === 0 ? <p>추천 조건에 맞는 출생연도가 없습니다.</p> : (
            <ul className="space-y-1">
              {r.ages.map((a) => (
                <li key={a.year}><b>{a.label}</b> · {a.year}년생({a.ganzhi}) <span className="text-muted-foreground">{a.reason}</span></li>
              ))}
            </ul>
          )}
        </div>
      </CardContent>
    </Card>
  )
}
