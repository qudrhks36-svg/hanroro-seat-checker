import type { Pillars } from '@/lib/saju'
import { GAN, GAN_KO, ZHI, ZHI_KO, ganEl, zhiEl, ELEMENT_KO, type Element } from '@/lib/tables'

const COLOR: Record<Element, string> = {
  木: 'text-emerald-600', 火: 'text-red-500', 土: 'text-amber-600', 金: 'text-slate-500', 水: 'text-sky-600',
}

function Cell({ ch, ko, el }: { ch: string; ko: string; el: Element }) {
  return (
    <div className="py-2">
      <div className={`text-4xl font-semibold ${COLOR[el]}`}>{ch}</div>
      <div className="text-xs text-muted-foreground">{ko}{ELEMENT_KO[el]}</div>
    </div>
  )
}

export function PillarsTable({ pillars }: { pillars: Pillars }) {
  const cols = [['시주', pillars.time], ['일주', pillars.day], ['월주', pillars.month], ['연주', pillars.year]] as const
  return (
    <div className="grid grid-cols-4 gap-2 text-center">
      {cols.map(([label, pl]) => (
        <div key={label} className="rounded-lg border bg-card p-2">
          <div className="text-xs text-muted-foreground">{label}</div>
          {pl ? (
            <>
              <Cell ch={pl.gan} ko={GAN_KO[GAN.indexOf(pl.gan)]} el={ganEl(pl.gan)} />
              <Cell ch={pl.zhi} ko={ZHI_KO[ZHI.indexOf(pl.zhi)]} el={zhiEl(pl.zhi)} />
            </>
          ) : (
            <div className="py-10 text-sm text-muted-foreground">미상</div>
          )}
        </div>
      ))}
    </div>
  )
}
