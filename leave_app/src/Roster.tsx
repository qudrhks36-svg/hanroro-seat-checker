import { formatDays, type Employee } from "./lib";

/** 사원 전체의 남은 연차 현황 */
export default function Roster({ employees }: { employees: Employee[] }) {
  const active = employees.filter((e) => e.active);
  return (
    <section className="card">
      <h2>사원 현황</h2>
      {active.length === 0 && <p className="muted">아직 등록된 사원이 없어요. 아래 “사원 관리”에서 추가해 주세요.</p>}
      {active.length > 0 && (
        <table className="roster">
          <thead>
            <tr>
              <th>이름</th>
              <th>남은</th>
              <th>발생</th>
              <th>사용</th>
              <th>대기</th>
            </tr>
          </thead>
          <tbody>
            {active.map((e) => (
              <tr key={e.id}>
                <td>{e.name}</td>
                <td className="num strong">{formatDays(e.balance.remaining)}</td>
                <td className="num">{formatDays(e.balance.granted)}</td>
                <td className="num">{formatDays(e.balance.used)}</td>
                <td className="num">{formatDays(e.balance.pending)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
      <p className="muted small">입사일 기준으로 계산해요. 입사 기념일이 지나면 안 쓴 연차는 소멸돼요.</p>
    </section>
  );
}
