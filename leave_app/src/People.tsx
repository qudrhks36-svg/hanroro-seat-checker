import { useState } from "react";
import type { Api } from "./api";
import { errorMessage, formatDate, type Employee } from "./lib";

/** 사원 추가/수정, 공용 링크 복사·재발급 */
export default function People({
  api,
  employees,
  onChanged,
  onTokenChanged,
}: {
  api: Api;
  employees: Employee[];
  onChanged: () => void;
  onTokenChanged: (token: string) => void;
}) {
  const [open, setOpen] = useState(false);
  const [name, setName] = useState("");
  const [hire, setHire] = useState("");
  const [err, setErr] = useState<string | null>(null);
  const [note, setNote] = useState<string | null>(null);

  async function run(fn: () => Promise<unknown>) {
    try {
      await fn();
      setErr(null);
      onChanged();
    } catch (e) {
      setErr(errorMessage(e));
    }
  }

  async function copyLink() {
    let token: string | null = null;
    try {
      token = localStorage.getItem("leave_token");
    } catch {
      /* 아래에서 안내 */
    }
    if (!token) {
      setNote("이 브라우저에서는 링크를 만들 수 없어요. 받은 링크를 그대로 공유해 주세요.");
      return;
    }
    await navigator.clipboard.writeText(`${window.location.origin}/?t=${token}`);
    setNote("공용 링크를 복사했어요.");
  }

  async function resetLink() {
    if (
      !window.confirm(
        "공용 링크를 재발급할까요?\n기존 링크는 바로 사용할 수 없게 되고, 이 화면은 새 링크로 바뀌어요. 새 링크를 모든 사원에게 다시 전달해야 해요.",
      )
    )
      return;
    try {
      const next = await api.resetAccessToken();
      onTokenChanged(next);
      await navigator.clipboard.writeText(`${window.location.origin}/?t=${next}`).catch(() => undefined);
      setNote("새 링크를 만들어 복사했어요. 사원들에게 전달해 주세요.");
      setErr(null);
    } catch (e) {
      setErr(errorMessage(e));
    }
  }

  return (
    <section className="card">
      <div className="between">
        <h2>사원 관리</h2>
        <button className="link" onClick={() => setOpen(!open)}>
          {open ? "접기" : "열기"}
        </button>
      </div>

      {open && (
        <>
          {err && <p className="warn">{err}</p>}
          {note && <p className="ok">{note}</p>}

          <form
            className="row"
            onSubmit={(e) => {
              e.preventDefault();
              void run(async () => {
                await api.saveEmployee(null, name, hire);
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
            <button className="primary">사원 추가</button>
          </form>

          <ul className="list">
            {employees.map((e) => (
              <li key={e.id} className={e.active ? "" : "inactive"}>
                <div>
                  <strong>{e.name}</strong> {!e.active && <span className="muted">(비활성)</span>}
                  <div className="muted small">입사 {e.hire_date} ({formatDate(e.hire_date)})</div>
                </div>
                <div className="actions">
                  <button
                    onClick={() => {
                      const v = window.prompt("입사일(YYYY-MM-DD)", e.hire_date);
                      if (v && /^\d{4}-\d{2}-\d{2}$/.test(v)) void run(() => api.saveEmployee(e.id, e.name, v));
                      else if (v) setErr("입사일은 YYYY-MM-DD 형식으로 입력해 주세요.");
                    }}
                  >
                    입사일 수정
                  </button>
                  <button onClick={() => run(() => api.setActive(e.id, !e.active))}>
                    {e.active ? "비활성화" : "활성화"}
                  </button>
                </div>
              </li>
            ))}
          </ul>

          <div className="actions">
            <button onClick={copyLink}>공용 링크 복사</button>
            <button className="danger" onClick={resetLink}>
              공용 링크 재발급
            </button>
          </div>
          <p className="muted small">
            링크를 아는 사람은 누구나 사원 정보를 보고 신청·승인할 수 있어요. 퇴사자가 생기거나 링크가 밖으로 나갔다면 재발급해 주세요.
          </p>
        </>
      )}
    </section>
  );
}
