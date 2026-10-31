import { useCallback, useEffect, useState } from "react";
import { api } from "./api";
import {
  STATUS_LABEL,
  TYPE_LABEL,
  errorMessage,
  formatDays,
  formatRange,
  type EmployeeRow,
  type LeaveRequest,
  type Me,
} from "./lib";

type Tab = "pending" | "history" | "employees";

export default function Admin({ token, me }: { token: string; me: Me }) {
  const [tab, setTab] = useState<Tab>("pending");
  const [requests, setRequests] = useState<LeaveRequest[]>([]);
  const [employees, setEmployees] = useState<EmployeeRow[]>([]);
  const [pendingCount, setPendingCount] = useState(0);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      const [ov, rq] = await Promise.all([api.adminOverview(token), api.adminRequests(token)]);
      setEmployees(ov.employees);
      setPendingCount(ov.pending_count);
      setRequests(rq);
      setError(null);
    } catch (e) {
      setError(errorMessage(e));
    }
  }, [token]);

  useEffect(() => {
    void load();
  }, [load]);

  const pending = requests.filter((r) => r.status === "pending");
  const history = requests.filter((r) => r.status !== "pending");

  return (
    <main className="wrap">
      <header className="top">
        <h1>{me.name} · 결재함</h1>
      </header>

      <nav className="tabs">
        <button className={tab === "pending" ? "on" : ""} onClick={() => setTab("pending")}>
          승인 대기 {pendingCount > 0 && <span className="count">{pendingCount}</span>}
        </button>
        <button className={tab === "history" ? "on" : ""} onClick={() => setTab("history")}>
          처리 내역
        </button>
        <button className={tab === "employees" ? "on" : ""} onClick={() => setTab("employees")}>
          직원 · 잔여
        </button>
      </nav>

      {error && <p className="warn">{error}</p>}

      {tab === "pending" && <PendingList token={token} items={pending} employees={employees} onChanged={load} />}
      {tab === "history" && <History token={token} items={history} onChanged={load} />}
      {tab === "employees" && <Employees token={token} me={me} rows={employees} onChanged={load} />}
    </main>
  );
}

function PendingList({
  token,
  items,
  employees,
  onChanged,
}: {
  token: string;
  items: LeaveRequest[];
  employees: EmployeeRow[];
  onChanged: () => void;
}) {
  const [comment, setComment] = useState<Record<number, string>>({});
  const [err, setErr] = useState<string | null>(null);

  async function decide(r: LeaveRequest, approve: boolean) {
    try {
      await api.adminDecide(token, r.id, approve, comment[r.id] ?? "");
      setErr(null);
      onChanged();
    } catch (e) {
      setErr(errorMessage(e));
    }
  }

  if (items.length === 0) return <div className="card muted">승인 대기 중인 결재가 없어요.</div>;

  return (
    <>
      {err && <p className="warn">{err}</p>}
      {items.map((r) => {
        const bal = employees.find((e) => e.id === r.employee_id)?.balance;
        return (
          <section className="card" key={r.id}>
            <div className="between">
              <strong>{r.employee_name}</strong>
              <span className="badge pending">{TYPE_LABEL[r.leave_type]} {formatDays(r.days)}일</span>
            </div>
            <p>{formatRange(r)}</p>
            {r.reason && <p className="muted">{r.reason}</p>}
            {bal && (
              <p className="muted small">
                현재 잔여 {formatDays(bal.remaining)}일 (대기 중인 신청 차감 후) · 발생 {formatDays(bal.granted)} / 사용{" "}
                {formatDays(bal.used)}
              </p>
            )}
            <input
              type="text"
              placeholder="코멘트 (선택)"
              value={comment[r.id] ?? ""}
              onChange={(e) => setComment({ ...comment, [r.id]: e.target.value })}
            />
            <div className="actions">
              <button className="primary" onClick={() => decide(r, true)}>
                승인
              </button>
              <button className="danger" onClick={() => decide(r, false)}>
                반려
              </button>
            </div>
          </section>
        );
      })}
    </>
  );
}

function History({ token, items, onChanged }: { token: string; items: LeaveRequest[]; onChanged: () => void }) {
  const [err, setErr] = useState<string | null>(null);

  async function cancel(r: LeaveRequest) {
    if (!window.confirm(`${r.employee_name}님의 ${formatRange(r)} 승인을 취소하고 연차를 되돌릴까요?`)) return;
    try {
      await api.adminCancel(token, r.id, "대표 취소");
      setErr(null);
      onChanged();
    } catch (e) {
      setErr(errorMessage(e));
    }
  }

  if (items.length === 0) return <div className="card muted">처리한 내역이 없어요.</div>;
  return (
    <section className="card">
      {err && <p className="warn">{err}</p>}
      <ul className="list">
        {items.map((r) => (
          <li key={r.id}>
            <div>
              <strong>{r.employee_name}</strong> · {formatRange(r)}
              <div className="muted">
                {TYPE_LABEL[r.leave_type]} {formatDays(r.days)}일
                {r.decision_comment && ` · ${r.decision_comment}`}
              </div>
            </div>
            <div className="right">
              <span className={`badge ${r.status}`}>{STATUS_LABEL[r.status]}</span>
              {r.status === "approved" && (
                <button className="link" onClick={() => cancel(r)}>
                  승인 취소
                </button>
              )}
            </div>
          </li>
        ))}
      </ul>
    </section>
  );
}

function Employees({
  token,
  me,
  rows,
  onChanged,
}: {
  token: string;
  me: Me;
  rows: EmployeeRow[];
  onChanged: () => void;
}) {
  const [name, setName] = useState("");
  const [hire, setHire] = useState("");
  const [err, setErr] = useState<string | null>(null);
  const [copied, setCopied] = useState<number | null>(null);

  const link = (t: string) => `${window.location.origin}/?t=${t}`;

  async function wrap(fn: () => Promise<unknown>) {
    try {
      await fn();
      setErr(null);
      onChanged();
    } catch (e) {
      setErr(errorMessage(e));
    }
  }

  async function copy(r: EmployeeRow) {
    await navigator.clipboard.writeText(link(r.token));
    setCopied(r.id);
    setTimeout(() => setCopied(null), 1500);
  }

  return (
    <>
      {err && <p className="warn">{err}</p>}
      <section className="card">
        <h2>직원 추가</h2>
        <form
          className="row"
          onSubmit={(e) => {
            e.preventDefault();
            void wrap(async () => {
              await api.adminSaveEmployee(token, null, name, hire);
              setName("");
              setHire("");
            });
          }}
        >
          <label>
            이름
            <input value={name} required onChange={(e) => setName(e.target.value)} />
          </label>
          <label>
            입사일
            <input type="date" value={hire} required onChange={(e) => setHire(e.target.value)} />
          </label>
          <button className="primary">추가</button>
        </form>
        <p className="muted small">추가하면 개인 링크가 만들어져요. 링크를 복사해서 직원에게 전달해 주세요.</p>
      </section>

      {rows
        .filter((r) => r.role === "staff")
        .map((r) => (
          <section className={`card ${r.active ? "" : "inactive"}`} key={r.id}>
            <div className="between">
              <strong>
                {r.name} {!r.active && <span className="muted">(비활성)</span>}
              </strong>
              <span className="muted small">입사 {r.hire_date}</span>
            </div>
            {r.balance && (
              <p>
                남은 <strong>{formatDays(r.balance.remaining)}</strong>일
                <span className="muted">
                  {" "}
                  · 발생 {formatDays(r.balance.granted)} / 사용 {formatDays(r.balance.used)} / 대기 {formatDays(r.balance.pending)}
                </span>
              </p>
            )}
            <div className="actions">
              <button onClick={() => copy(r)}>{copied === r.id ? "복사됨 ✓" : "링크 복사"}</button>
              <button
                onClick={() => {
                  const v = window.prompt("입사일(YYYY-MM-DD)", r.hire_date ?? "");
                  if (v) void wrap(() => api.adminSaveEmployee(token, r.id, r.name, v));
                }}
              >
                입사일 수정
              </button>
              <button
                onClick={() => {
                  if (window.confirm(`${r.name}님의 링크를 재발급할까요? 기존 링크는 바로 사용할 수 없게 돼요.`))
                    void wrap(() => api.adminResetToken(token, r.id));
                }}
              >
                링크 재발급
              </button>
              {r.id !== me.id && (
                <button onClick={() => wrap(() => api.adminSetActive(token, r.id, !r.active))}>
                  {r.active ? "비활성화" : "활성화"}
                </button>
              )}
            </div>
          </section>
        ))}
    </>
  );
}
