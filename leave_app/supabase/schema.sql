-- 연차/반차 결재 시스템 스키마 (v2: 관리자 계정 없음, 한 페이지에서 모두 보고 승인)
--
-- 규칙
--  * 입사일 기준. 입사 1년 미만: 개근한 달마다 1개씩 발생(최대 11개).
--  * 입사 1년부터: 입사 기념일마다 15개 발생. 미사용 연차 이월 없음(기간이 지나면 소멸).
--  * 연차 1일 = 1.0, 반차(오전/오후) = 0.5. 주말은 연차 일수에서 제외.
--  * 잔여 = 발생 - 승인된 사용분 - 승인 대기 중인 신청분
--
-- 접근 방식
--  * 로그인 없이 회사 공용 링크(토큰 1개)로 접속한다. 링크를 아는 사람은 누구나
--    사원 목록 조회, 신청, 승인/반려, 사원 추가를 할 수 있다(신뢰 기반).
--  * 테이블은 RLS를 켜고 정책을 두지 않아 anon 키로 직접 읽거나 쓸 수 없다.
--    모든 접근은 아래 SECURITY DEFINER 함수(RPC)가 공용 토큰을 검증한 뒤에만 가능하다.
--
-- 이 파일은 빈 DB에도, v1(관리자/개인 링크 방식)이 적용된 DB에도 그대로 실행할 수 있다.

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------- v1 → v2 정리

drop function if exists
  leave_me(text), leave_my_requests(text),
  leave_submit(text, text, date, date, text), leave_cancel(text, bigint),
  leave_admin_overview(text), leave_admin_requests(text, text),
  leave_admin_decide(text, bigint, boolean, text), leave_admin_cancel(text, bigint, text),
  leave_admin_save_employee(text, bigint, text, date),
  leave_admin_reset_token(text, bigint), leave_admin_set_active(text, bigint, boolean),
  leave_auth(text, boolean);

do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'employees' and column_name = 'role') then
    -- 관리자 행은 더 이상 필요 없다 (신청 내역이 있다면 같이 지워지지 않도록 직원 행만 대상)
    delete from employees where role = 'admin' and hire_date is null;
  end if;
end $$;

alter table if exists employees drop constraint if exists staff_needs_hire_date;
alter table if exists employees drop column if exists role;
alter table if exists employees drop column if exists token;

-- ---------------------------------------------------------------- tables

create table if not exists employees (
  id          bigint generated always as identity primary key,
  name        text    not null check (length(btrim(name)) > 0),
  hire_date   date    not null,
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

create table if not exists leave_requests (
  id               bigint generated always as identity primary key,
  employee_id      bigint  not null references employees(id) on delete cascade,
  leave_type       text    not null check (leave_type in ('annual', 'half_am', 'half_pm')),
  start_date       date    not null,
  end_date         date    not null,
  days             numeric(4,1) not null check (days > 0),
  reason           text    not null default '',
  status           text    not null default 'pending'
                   check (status in ('pending', 'approved', 'rejected', 'cancelled')),
  decision_comment text    not null default '',
  decided_at       timestamptz,
  created_at       timestamptz not null default now(),
  check (end_date >= start_date),
  -- 반차는 하루짜리
  check (leave_type = 'annual' or start_date = end_date)
);

-- 회사 공용 접속 토큰 (key = 'access_token')
create table if not exists app_settings (
  key   text primary key,
  value text not null
);

insert into app_settings (key, value)
values ('access_token', encode(extensions.gen_random_bytes(24), 'hex'))
on conflict (key) do nothing;

create index if not exists leave_requests_emp_idx on leave_requests (employee_id, start_date);
create index if not exists leave_requests_status_idx on leave_requests (status);

alter table employees      enable row level security;
alter table leave_requests enable row level security;
alter table app_settings   enable row level security;
revoke all on employees, leave_requests, app_settings from anon, authenticated;

-- ---------------------------------------------------------------- pure helpers

-- 기준일(p_on)이 속한 연차 기간 [period_start, period_end) 과 그 시점까지 발생한 연차 수
create or replace function leave_entitlement(p_hire date, p_on date)
returns table (period_start date, period_end date, granted numeric)
language plpgsql immutable
set search_path = public
as $$
declare
  yrs    int;
  mons   int;
begin
  if p_on < p_hire then
    return query select p_hire, (p_hire + interval '1 year')::date, 0::numeric;
    return;
  end if;

  yrs := extract(year from age(p_on, p_hire))::int;
  if yrs >= 1 then
    return query select
      (p_hire + make_interval(years => yrs))::date,
      (p_hire + make_interval(years => yrs + 1))::date,
      15::numeric;
  else
    mons := extract(month from age(p_on, p_hire))::int;
    return query select
      p_hire,
      (p_hire + interval '1 year')::date,
      least(11, mons)::numeric;
  end if;
end;
$$;

-- 주말을 뺀 일수 (공휴일은 반영하지 않음 — 공휴일에 연차를 올리지 않는다고 가정)
create or replace function leave_weekdays(p_start date, p_end date)
returns int
language sql immutable
set search_path = public
as $$
  select count(*)::int
  from generate_series(p_start, p_end, interval '1 day') g
  where extract(isodow from g) < 6;
$$;

-- ---------------------------------------------------------------- internal helpers

create or replace function leave_balance_json(p_emp employees, p_on date)
returns jsonb
language sql stable
set search_path = public
as $$
  select jsonb_build_object(
    'period_start', e.period_start,
    'period_end',   e.period_end,
    'granted',      e.granted,
    'used',         coalesce(sum(r.days) filter (where r.status = 'approved'), 0),
    'pending',      coalesce(sum(r.days) filter (where r.status = 'pending'), 0),
    'remaining',    e.granted
                    - coalesce(sum(r.days) filter (where r.status in ('approved', 'pending')), 0)
  )
  from leave_entitlement(p_emp.hire_date, p_on) e
  left join leave_requests r
    on r.employee_id = p_emp.id
   and r.status in ('approved', 'pending')
   and r.start_date >= e.period_start
   and r.start_date <  e.period_end
  group by e.period_start, e.period_end, e.granted;
$$;

create or replace function leave_check(p_token text)
returns void
language plpgsql stable security definer
set search_path = public
as $$
begin
  if p_token is null
     or not exists (select 1 from app_settings where key = 'access_token' and value = p_token) then
    raise exception 'invalid_token' using errcode = 'P0001';
  end if;
end;
$$;

-- ---------------------------------------------------------------- RPC

-- 사원 목록 + 잔여, 승인 대기 건수
create or replace function leave_overview(p_token text)
returns jsonb
language plpgsql stable security definer
set search_path = public
as $$
begin
  perform leave_check(p_token);
  return jsonb_build_object(
    'pending_count', (select count(*) from leave_requests where status = 'pending'),
    'employees', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', e.id, 'name', e.name, 'hire_date', e.hire_date, 'active', e.active,
        'balance', leave_balance_json(e, current_date)
      ) order by e.active desc, e.name)
      from employees e
    ), '[]'::jsonb)
  );
end;
$$;

-- 전체 신청 목록 (대기 건이 위로)
create or replace function leave_list_requests(p_token text)
returns table (
  id bigint, employee_id bigint, employee_name text, leave_type text,
  start_date date, end_date date, days numeric, reason text, status text,
  decision_comment text, decided_at timestamptz, created_at timestamptz
)
language plpgsql stable security definer
set search_path = public
as $$
begin
  perform leave_check(p_token);
  return query
    select r.id, r.employee_id, e.name, r.leave_type, r.start_date, r.end_date,
           r.days, r.reason, r.status, r.decision_comment, r.decided_at, r.created_at
    from leave_requests r
    join employees e on e.id = r.employee_id
    order by (r.status = 'pending') desc, r.start_date desc, r.id desc;
end;
$$;

create or replace function leave_submit(
  p_token text, p_employee_id bigint, p_type text, p_start date, p_end date, p_reason text
) returns leave_requests
language plpgsql security definer
set search_path = public
as $$
declare
  emp      employees;
  v_end    date := coalesce(p_end, p_start);
  v_days   numeric;
  e        record;
  v_active numeric;
  v_row    leave_requests;
begin
  perform leave_check(p_token);

  -- 같은 직원의 동시 신청을 직렬화해서 잔여 초과 신청을 막는다
  select * into emp from employees where id = p_employee_id and active for update;
  if not found then
    raise exception 'not_found';
  end if;

  if p_type not in ('annual', 'half_am', 'half_pm') then
    raise exception 'bad_type';
  end if;
  if p_start is null then
    raise exception 'bad_date';
  end if;
  if p_type <> 'annual' then
    v_end := p_start;
  end if;
  if v_end < p_start then
    raise exception 'bad_date';
  end if;
  if p_start < current_date then
    raise exception 'past_date';
  end if;
  if p_start < emp.hire_date then
    raise exception 'before_hire';
  end if;

  if p_type = 'annual' then
    v_days := leave_weekdays(p_start, v_end);
  elsif extract(isodow from p_start) < 6 then
    v_days := 0.5;
  else
    v_days := 0;
  end if;
  if v_days <= 0 then
    raise exception 'weekend_only';
  end if;

  -- 한 번의 신청은 하나의 연차 기간 안에 있어야 한다
  select * into e from leave_entitlement(emp.hire_date, p_start);
  if v_end >= e.period_end then
    raise exception 'crosses_period';
  end if;

  -- 겹치는 신청 방지 (반차 오전/오후는 같은 날 공존 가능)
  if exists (
    select 1 from leave_requests r
    where r.employee_id = emp.id
      and r.status in ('pending', 'approved')
      and r.start_date <= v_end and r.end_date >= p_start
      and not (
        r.leave_type in ('half_am', 'half_pm') and p_type in ('half_am', 'half_pm')
        and r.leave_type <> p_type
      )
  ) then
    raise exception 'overlap';
  end if;

  select coalesce(sum(r.days), 0) into v_active
  from leave_requests r
  where r.employee_id = emp.id
    and r.status in ('pending', 'approved')
    and r.start_date >= e.period_start and r.start_date < e.period_end;

  if v_active + v_days > e.granted then
    raise exception 'insufficient_balance';
  end if;

  insert into leave_requests (employee_id, leave_type, start_date, end_date, days, reason)
  values (emp.id, p_type, p_start, v_end, v_days, coalesce(p_reason, ''))
  returning * into v_row;
  return v_row;
end;
$$;

-- 승인/반려
create or replace function leave_decide(
  p_token text, p_id bigint, p_approve boolean, p_comment text default ''
) returns leave_requests
language plpgsql security definer
set search_path = public
as $$
declare
  v_req   leave_requests;
  emp     employees;
  e       record;
  v_other numeric;
begin
  perform leave_check(p_token);

  select * into v_req from leave_requests where id = p_id for update;
  if not found or v_req.status <> 'pending' then
    raise exception 'not_pending';
  end if;

  if p_approve then
    -- 승인 시점에도 잔여를 한 번 더 검증한다 (입사일 수정 등으로 달라졌을 수 있음)
    select * into emp from employees where id = v_req.employee_id for update;
    select * into e from leave_entitlement(emp.hire_date, v_req.start_date);
    select coalesce(sum(r.days), 0) into v_other
    from leave_requests r
    where r.employee_id = emp.id
      and r.id <> v_req.id
      and r.status in ('pending', 'approved')
      and r.start_date >= e.period_start and r.start_date < e.period_end;
    if v_other + v_req.days > e.granted then
      raise exception 'insufficient_balance';
    end if;
  end if;

  update leave_requests
     set status = case when p_approve then 'approved' else 'rejected' end,
         decision_comment = coalesce(p_comment, ''),
         decided_at = now()
   where id = p_id
  returning * into v_req;
  return v_req;
end;
$$;

-- 취소: 대기 중인 건, 또는 아직 끝나지 않은 승인 건 → 잔여 즉시 복구
create or replace function leave_cancel(p_token text, p_id bigint, p_comment text default '')
returns leave_requests
language plpgsql security definer
set search_path = public
as $$
declare
  v_row leave_requests;
begin
  perform leave_check(p_token);
  update leave_requests
     set status = 'cancelled', decision_comment = coalesce(p_comment, ''), decided_at = now()
   where id = p_id
     and (status = 'pending' or (status = 'approved' and end_date >= current_date))
  returning * into v_row;
  if not found then
    raise exception 'cannot_cancel';
  end if;
  return v_row;
end;
$$;

create or replace function leave_save_employee(
  p_token text, p_id bigint, p_name text, p_hire_date date
) returns employees
language plpgsql security definer
set search_path = public
as $$
declare
  v_row employees;
begin
  perform leave_check(p_token);
  if p_name is null or length(btrim(p_name)) = 0 or p_hire_date is null then
    raise exception 'bad_employee';
  end if;
  if p_id is null then
    insert into employees (name, hire_date) values (btrim(p_name), p_hire_date)
    returning * into v_row;
  else
    update employees set name = btrim(p_name), hire_date = p_hire_date
     where id = p_id
    returning * into v_row;
    if not found then
      raise exception 'not_found';
    end if;
  end if;
  return v_row;
end;
$$;

create or replace function leave_set_active(p_token text, p_id bigint, p_active boolean)
returns void
language plpgsql security definer
set search_path = public
as $$
begin
  perform leave_check(p_token);
  update employees set active = p_active where id = p_id;
  if not found then
    raise exception 'not_found';
  end if;
end;
$$;

-- 공용 링크 재발급 (기존 링크는 즉시 무효). 새 토큰을 돌려준다.
create or replace function leave_reset_access_token(p_token text)
returns text
language plpgsql security definer
set search_path = public
as $$
declare
  v_new text := encode(extensions.gen_random_bytes(24), 'hex');
begin
  perform leave_check(p_token);
  update app_settings set value = v_new where key = 'access_token';
  return v_new;
end;
$$;

-- ---------------------------------------------------------------- grants

revoke all on function
  leave_balance_json(employees, date),
  leave_check(text)
from public, anon, authenticated;

revoke execute on function
  leave_overview(text), leave_list_requests(text),
  leave_submit(text, bigint, text, date, date, text),
  leave_decide(text, bigint, boolean, text), leave_cancel(text, bigint, text),
  leave_save_employee(text, bigint, text, date), leave_set_active(text, bigint, boolean),
  leave_reset_access_token(text)
from public;

grant execute on function
  leave_overview(text), leave_list_requests(text),
  leave_submit(text, bigint, text, date, date, text),
  leave_decide(text, bigint, boolean, text), leave_cancel(text, bigint, text),
  leave_save_employee(text, bigint, text, date), leave_set_active(text, bigint, boolean),
  leave_reset_access_token(text)
to anon, authenticated;
