export type LeaveType = "annual" | "half_am" | "half_pm";
export type Status = "pending" | "approved" | "rejected" | "cancelled";

export interface Balance {
  period_start: string;
  period_end: string;
  granted: number;
  used: number;
  pending: number;
  remaining: number;
}

export interface LeaveRequest {
  id: number;
  employee_id: number;
  employee_name?: string;
  leave_type: LeaveType;
  start_date: string;
  end_date: string;
  days: number;
  reason: string;
  status: Status;
  decision_comment: string;
  decided_at: string | null;
  created_at: string;
}

export interface Employee {
  id: number;
  name: string;
  hire_date: string;
  active: boolean;
  balance: Balance;
}

export interface Overview {
  pending_count: number;
  employees: Employee[];
}

export const TYPE_LABEL: Record<LeaveType, string> = {
  annual: "연차",
  half_am: "오전 반차",
  half_pm: "오후 반차",
};

export const STATUS_LABEL: Record<Status, string> = {
  pending: "승인 대기",
  approved: "승인",
  rejected: "반려",
  cancelled: "취소",
};

/** 서버(RPC)가 던지는 에러 코드를 사용자용 문장으로 바꾼다. */
const ERROR_MESSAGE: Record<string, string> = {
  invalid_token: "링크가 올바르지 않거나 만료되었어요. 새 링크를 받아서 다시 접속해 주세요.",
  bad_type: "휴가 종류가 올바르지 않아요.",
  bad_date: "날짜를 확인해 주세요.",
  past_date: "지난 날짜는 신청할 수 없어요.",
  before_hire: "입사일 이전 날짜는 신청할 수 없어요.",
  weekend_only: "주말만 선택되어 있어요. 평일을 포함해 주세요.",
  crosses_period: "연차 기간(입사 기념일)을 넘어가는 신청은 나눠서 올려 주세요.",
  overlap: "이미 신청한 날짜와 겹쳐요.",
  insufficient_balance: "남은 연차가 부족해요.",
  not_pending: "이미 처리된 신청이에요.",
  cannot_cancel: "취소할 수 없는 신청이에요.",
  not_found: "대상을 찾을 수 없어요.",
  bad_employee: "이름과 입사일을 입력해 주세요.",
};

export function errorMessage(err: unknown): string {
  const raw =
    typeof err === "object" && err && "message" in err
      ? String((err as { message: unknown }).message)
      : String(err);
  return ERROR_MESSAGE[raw] ?? `오류가 발생했어요: ${raw}`;
}

/** "2026-11-09" → Date (로컬 자정). 타임존 때문에 하루 밀리지 않도록 직접 파싱한다. */
export function parseDate(s: string): Date {
  const [y, m, d] = s.split("-").map(Number);
  return new Date(y, m - 1, d);
}

export function formatDate(s: string): string {
  const d = parseDate(s);
  const dow = "일월화수목금토"[d.getDay()];
  return `${d.getMonth() + 1}/${d.getDate()}(${dow})`;
}

export function formatRange(r: Pick<LeaveRequest, "start_date" | "end_date">): string {
  return r.start_date === r.end_date
    ? formatDate(r.start_date)
    : `${formatDate(r.start_date)} ~ ${formatDate(r.end_date)}`;
}

/** 소수점 .0 은 숨긴다: 3 → "3", 0.5 → "0.5" */
export function formatDays(n: number): string {
  return Number.isInteger(n) ? String(n) : n.toFixed(1);
}

/** 신청 화면의 미리보기용 일수 계산. 서버(leave_weekdays)와 같은 규칙: 주말 제외. */
export function previewDays(type: LeaveType, start: string, end: string): number {
  if (!start) return 0;
  const s = parseDate(start);
  if (type !== "annual") {
    const dow = s.getDay();
    return dow === 0 || dow === 6 ? 0 : 0.5;
  }
  const e = parseDate(end || start);
  if (e < s) return 0;
  let n = 0;
  for (const d = new Date(s); d <= e; d.setDate(d.getDate() + 1)) {
    const dow = d.getDay();
    if (dow !== 0 && dow !== 6) n++;
  }
  return n;
}

export function todayString(): string {
  const d = new Date();
  const mm = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  return `${d.getFullYear()}-${mm}-${dd}`;
}
