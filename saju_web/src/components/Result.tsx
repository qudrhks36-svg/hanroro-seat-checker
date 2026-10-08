import { Button } from '@/components/ui/button'
import type { Person } from '@/lib/person'

export function Result({ me, onReset }: { me: Person; onReset: () => void }) {
  return (
    <div className="space-y-4">
      <pre className="text-xs">{JSON.stringify(me.pillars)}</pre>
      <Button variant="outline" onClick={onReset}>다시 입력</Button>
    </div>
  )
}
