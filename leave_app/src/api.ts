import { createClient } from "@supabase/supabase-js";
import type { Employee, LeaveRequest, LeaveType, Overview } from "./lib";

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const key = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;

export const configured = Boolean(url && key);
const supabase = configured
  ? createClient(url!, key!, { auth: { persistSession: false, autoRefreshToken: false } })
  : null;

async function rpc<T>(fn: string, args: Record<string, unknown>): Promise<T> {
  if (!supabase) throw new Error("Supabase 환경변수가 설정되지 않았어요.");
  const { data, error } = await supabase.rpc(fn, args);
  if (error) throw error;
  return data as T;
}

/** 모든 호출에 회사 공용 토큰(p_token)이 들어간다. */
export function createApi(token: string) {
  return {
    overview: () => rpc<Overview>("leave_overview", { p_token: token }),
    requests: () => rpc<LeaveRequest[]>("leave_list_requests", { p_token: token }),
    submit: (employeeId: number, type: LeaveType, start: string, end: string | null, reason: string) =>
      rpc<LeaveRequest>("leave_submit", {
        p_token: token,
        p_employee_id: employeeId,
        p_type: type,
        p_start: start,
        p_end: end,
        p_reason: reason,
      }),
    decide: (id: number, approve: boolean, comment: string) =>
      rpc<LeaveRequest>("leave_decide", { p_token: token, p_id: id, p_approve: approve, p_comment: comment }),
    cancel: (id: number, comment = "") =>
      rpc<LeaveRequest>("leave_cancel", { p_token: token, p_id: id, p_comment: comment }),
    saveEmployee: (id: number | null, name: string, hireDate: string) =>
      rpc<Employee>("leave_save_employee", {
        p_token: token,
        p_id: id,
        p_name: name,
        p_hire_date: hireDate,
      }),
    setActive: (id: number, active: boolean) =>
      rpc<void>("leave_set_active", { p_token: token, p_id: id, p_active: active }),
    resetAccessToken: () => rpc<string>("leave_reset_access_token", { p_token: token }),
  };
}

export type Api = ReturnType<typeof createApi>;
