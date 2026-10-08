import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { RadioGroup, RadioGroupItem } from '@/components/ui/radio-group'
import { Alert, AlertDescription } from '@/components/ui/alert'
import type { BirthInput } from '@/lib/saju'

type Props = { submitLabel: string; onSubmit: (b: BirthInput) => void; error?: string }

export function InputForm({ submitLabel, onSubmit, error }: Props) {
  const [calendar, setCalendar] = useState<'solar' | 'lunar'>('solar')
  const [leap, setLeap] = useState(false)
  const [gender, setGender] = useState<'male' | 'female'>('female')
  const [y, setY] = useState('')
  const [m, setM] = useState('')
  const [d, setD] = useState('')
  const [time, setTime] = useState('')
  const [unknown, setUnknown] = useState(false)

  const submit = (e: React.FormEvent) => {
    e.preventDefault()
    const [hh, mm] = time.split(':').map(Number)
    const hasTime = !unknown && time !== ''
    onSubmit({
      calendar, year: Number(y), month: Number(m), day: Number(d),
      leap: calendar === 'lunar' && leap,
      hour: hasTime ? hh : undefined,
      minute: hasTime ? mm : undefined,
      gender,
    })
  }

  return (
    <form onSubmit={submit} className="space-y-5">
      <div className="space-y-2">
        <Label id="cal-label">달력</Label>
        <RadioGroup aria-labelledby="cal-label" value={calendar} onValueChange={(v) => setCalendar(v as 'solar' | 'lunar')} className="flex gap-4">
          <div className="flex items-center gap-2"><RadioGroupItem value="solar" id="cal-solar" /><Label htmlFor="cal-solar">양력</Label></div>
          <div className="flex items-center gap-2"><RadioGroupItem value="lunar" id="cal-lunar" /><Label htmlFor="cal-lunar">음력</Label></div>
        </RadioGroup>
        {calendar === 'lunar' && (
          <div className="flex items-center gap-2">
            <Checkbox id="leap" checked={leap} onCheckedChange={(v) => setLeap(v === true)} />
            <Label htmlFor="leap">윤달</Label>
          </div>
        )}
      </div>

      <div className="grid grid-cols-3 gap-3">
        <div className="space-y-1"><Label htmlFor="y">년</Label><Input id="y" inputMode="numeric" placeholder="1990" value={y} onChange={(e) => setY(e.target.value)} required /></div>
        <div className="space-y-1"><Label htmlFor="m">월</Label><Input id="m" inputMode="numeric" placeholder="3" value={m} onChange={(e) => setM(e.target.value)} required /></div>
        <div className="space-y-1"><Label htmlFor="d">일</Label><Input id="d" inputMode="numeric" placeholder="15" value={d} onChange={(e) => setD(e.target.value)} required /></div>
      </div>

      <div className="space-y-2">
        <Label htmlFor="time">태어난 시간</Label>
        <Input id="time" type="time" value={time} onChange={(e) => setTime(e.target.value)} disabled={unknown} required={!unknown} />
        <div className="flex items-center gap-2">
          <Checkbox id="unknown" checked={unknown} onCheckedChange={(v) => setUnknown(v === true)} />
          <Label htmlFor="unknown">시간을 몰라요 (연·월·일 기준으로 풀이)</Label>
        </div>
      </div>

      <div className="space-y-2">
        <Label id="gender-label">성별</Label>
        <RadioGroup aria-labelledby="gender-label" value={gender} onValueChange={(v) => setGender(v as 'male' | 'female')} className="flex gap-4">
          <div className="flex items-center gap-2"><RadioGroupItem value="female" id="g-f" /><Label htmlFor="g-f">여성</Label></div>
          <div className="flex items-center gap-2"><RadioGroupItem value="male" id="g-m" /><Label htmlFor="g-m">남성</Label></div>
        </RadioGroup>
      </div>

      {error && <Alert variant="destructive"><AlertDescription>{error}</AlertDescription></Alert>}
      <Button type="submit" className="w-full">{submitLabel}</Button>
    </form>
  )
}
