import { useEffect, useState } from "react";
import type { Api } from "./api";
import {
  TYPE_LABEL,
  errorMessage,
  formatDays,
  previewDays,
  todayString,
  type Employee,
  type LeaveType,
} from "./lib";

const ME_KEY = "leave_me_id";

function loadMe(): string {
  try {
    return localStorage.getItem(ME_KEY) ?? "";
  } catch {
    return "";
  }
}

export default function RequestForm({
  api,
  employees,
  onChanged,
}: {
  api: Api;
  employees: Employee[];
  onChanged: () => void;
}) {
  const active = employees.filter((e) => e.active);
  const [empId, setEmpId] = useState(loadMe);
  const [type, setType] = useState<LeaveType>("annual");
  const [start, setStart] = useState("");
  const [end, setEnd] = useState("");
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ kind: "ok" | "err"; text: string } | null>(null);

  // 저장된 사원이 더 이상 없으면 선택을 비운다
  useEffect(() => {
    if (empId && !active.some((e) => String(e.id) === empId)) setEmpId("");
  }, [active, empId]);

  const me = active.find((e) => String(e.id) === empId);
  const lastDay = type === "annual" ? end || start : start;
  const days = previewDays(type, start, lastDay);
  const remaining = me?.balance.remaining ?? 0;

  function pick(id: string) {
    setEmpId(id);
    try {
      localStorage.setItem(ME_KEY, id);
    } catch {
      /* 저장 불가여도 동작에는 문제 없음 */
    }
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!me) return;
    setBusy(true);
    setMsg(null);
    try {
      await api.submit(me.id, type, start, type === "annual" ? end || start : null, reason.trim());
      setMsg({ kind: "ok", text: `${me.name}님의 결재를 올렸어요.` });
      setStart("");
      setEnd("");
      setReason("");
      onChanged();
    } catch (err) {
      setMsg({ kind: "err", text: errorMessage(err) });
    } finally {
      setBusy(false);
    }
  }

  return (
    <form className="card" onSubmit={submit}>
      <h2>결재 올리기</h2>

      <label>
        신청자
        <select value={empId} required onChange={(e) => pick(e.target.value)}>
          <option value="">이름을 선택해 주세요</option>
          {active.map((e) => (
            <option key={e.id} value={e.id}>
              {e.name} (남은 {formatDays(e.balance.remaining)}일)
            </option>
          ))}
        </select>
      </label>

      <div className="seg" role="radiogroup" aria-label="휴가 종류">
        {(Object.keys(TYPE_LABEL) as LeaveType[]).map((t) => (
          <button
            key={t}
            type="button"
            role="radio"
            aria-checked={type === t}
            className={type === t ? "on" : ""}
            onClick={() => setType(t)}
          >
            {TYPE_LABEL[t]}
          </button>
        ))}
      </div>

      <div className="row">
        <label>
          {type === "annual" ? "시작일" : "날짜"}
          <input type="date" value={start} min={todayString()} required onChange={(e) => setStart(e.target.value)} />
        </label>
        {type === "annual" && (
          <label>
            종료일
            <input type="date" value={end} min={start || todayString()} onChange={(e) => setEnd(e.target.value)} />
          </label>
        )}
      </div>

      <label>
        사유 (선택)
        <input type="text" value={reason} maxLength={200} onChange={(e) => setReason(e.target.value)} />
      </label>

      {me && start && (
        <p className={days > remaining ? "warn" : "muted"}>
          {days === 0
            ? "주말만 선택되어 있어요."
            : `${formatDays(days)}일 차감 · 신청 후 잔여 ${formatDays(remaining - days)}일`}
        </p>
      )}

      <button className="primary" disabled={busy || !me || !start || days === 0}>
        {busy ? "올리는 중…" : "결재 올리기"}
      </button>
      {msg && <p className={msg.kind === "ok" ? "ok" : "warn"}>{msg.text}</p>}
    </form>
  );
}
