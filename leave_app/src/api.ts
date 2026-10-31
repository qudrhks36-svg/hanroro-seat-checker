import { createClient } from "@supabase/supabase-js";
import type { EmployeeRow, LeaveRequest, LeaveType, Me, Status } from "./lib";

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

export const api = {
  me: (token: string) => rpc<Me>("leave_me", { p_token: token }),
  myRequests: (token: string) => rpc<LeaveRequest[]>("leave_my_requests", { p_token: token }),
  submit: (
    token: string,
    type: LeaveType,
    start: string,
    end: string | null,
    reason: string,
  ) =>
    rpc<LeaveRequest>("leave_submit", {
      p_token: token,
      p_type: type,
      p_start: start,
      p_end: end,
      p_reason: reason,
    }),
  cancel: (token: string, id: number) => rpc<LeaveRequest>("leave_cancel", { p_token: token, p_id: id }),

  adminOverview: (token: string) =>
    rpc<{ pending_count: number; employees: EmployeeRow[] }>("leave_admin_overview", { p_token: token }),
  adminRequests: (token: string, status: Status | null = null) =>
    rpc<LeaveRequest[]>("leave_admin_requests", { p_token: token, p_status: status }),
  adminDecide: (token: string, id: number, approve: boolean, comment: string) =>
    rpc<LeaveRequest>("leave_admin_decide", {
      p_token: token,
      p_id: id,
      p_approve: approve,
      p_comment: comment,
    }),
  adminCancel: (token: string, id: number, comment: string) =>
    rpc<LeaveRequest>("leave_admin_cancel", { p_token: token, p_id: id, p_comment: comment }),
  adminSaveEmployee: (token: string, id: number | null, name: string, hireDate: string | null) =>
    rpc<EmployeeRow>("leave_admin_save_employee", {
      p_token: token,
      p_id: id,
      p_name: name,
      p_hire_date: hireDate,
    }),
  adminResetToken: (token: string, id: number) =>
    rpc<string>("leave_admin_reset_token", { p_token: token, p_id: id }),
  adminSetActive: (token: string, id: number, active: boolean) =>
    rpc<void>("leave_admin_set_active", { p_token: token, p_id: id, p_active: active }),
};
