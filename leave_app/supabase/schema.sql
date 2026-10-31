-- 연차/반차 결재 시스템 스키마
--
-- 규칙
--  * 입사일 기준. 입사 1년 미만: 개근한 달마다 1개씩 발생(최대 11개).
--  * 입사 1년부터: 입사 기념일마다 15개 발생. 미사용 연차 이월 없음(기간이 지나면 소멸).
--  * 연차 1일 = 1.0, 반차(오전/오후) = 0.5. 주말은 연차 일수에서 제외.
--  * 잔여 = 발생 - 승인된 사용분 - 승인 대기 중인 신청분
--
-- 접근 방식
--  * 로그인 없이 직원별 전용 링크(토큰)로 접속한다.
--  * 테이블은 RLS를 켜고 정책을 두지 않아 anon 키로 직접 읽거나 쓸 수 없다.
--    모든 접근은 아래 SECURITY DEFINER 함수(RPC)가 토큰을 검증한 뒤에만 가능하다.

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------- tables

create table if not exists employees (
  id          bigint generated always as identity primary key,
  name        text    not null check (length(btrim(name)) > 0),
  role        text    not null default 'staff' check (role in ('staff', 'admin')),
  hire_date   date,
  token       text    not null unique
              default encode(extensions.gen_random_bytes(24), 'hex'),
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  -- 직원은 입사일이 필수, 대표(admin)는 선택
  constraint staff_needs_hire_date check (role = 'admin' or hire_date is not null)
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

create index if not exists leave_requests_emp_idx on leave_requests (employee_id, start_date);
create index if not exists leave_requests_status_idx on leave_requests (status);

alter table employees      enable row level security;
alter table leave_requests enable row level security;
revoke all on employees, leave_requests from anon, authenticated;

-- ---------------------------------------------------------------- pure helpers

-- 기준일(d)이 속한 연차 기간 [period_start, period_end) 과 그 시점까지 발생한 연차 수
create or replace function leave_entitlement(p_hire date, p_on date)
returns table (period_start date, period_end date, granted numeric)
language plpgsql immutable
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

create or replace function leave_auth(p_token text, p_need_admin boolean default false)
returns employees
language plpgsql stable security definer
set search_path = public
as $$
declare
  emp employees;
begin
  select * into emp from employees where token = p_token and active;
  if not found then
    raise exception 'invalid_token' using errcode = 'P0001';
  end if;
  if p_need_admin and emp.role <> 'admin' then
    raise exception 'forbidden' using errcode = 'P0001';
  end if;
  return emp;
end;
$$;

-- ---------------------------------------------------------------- staff RPC

create or replace function leave_me(p_token text)
returns jsonb
language plpgsql stable security definer
set search_path = public
as $$
declare
  emp employees := leave_auth(p_token);
begin
  return jsonb_build_object(
    'id', emp.id,
    'name', emp.name,
    'role', emp.role,
    'hire_date', emp.hire_date,
    'balance', case when emp.hire_date is null then null
                    else leave_balance_json(emp, current_date) end
  );
end;
$$;

create or replace function leave_my_requests(p_token text)
returns setof leave_requests
language plpgsql stable security definer
set search_path = public
as $$
declare
  emp employees := leave_auth(p_token);
begin
  return query
    select * from leave_requests
    where employee_id = emp.id
    order by start_date desc, id desc;
end;
$$;

create or replace function leave_submit(
  p_token text, p_type text, p_start date, p_end date, p_reason text
) returns leave_requests
language plpgsql security definer
set search_path = public
as $$
declare
  emp      employees := leave_auth(p_token);
  v_end    date := coalesce(p_end, p_start);
  v_days   numeric;
  e        record;
  v_active numeric;
  v_row    leave_requests;
begin
  if emp.hire_date is null then
    raise exception 'no_hire_date';
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

  -- 같은 직원의 동시 신청을 직렬화해서 잔여 초과 신청을 막는다
  perform 1 from employees where id = emp.id for update;

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

-- 직원 본인 취소: 대기 중이거나, 아직 시작 전인 승인 건
create or replace function leave_cancel(p_token text, p_id bigint)
returns leave_requests
language plpgsql security definer
set search_path = public
as $$
declare
  emp   employees := leave_auth(p_token);
  v_row leave_requests;
begin
  update leave_requests
     set status = 'cancelled', decided_at = now()
   where id = p_id
     and employee_id = emp.id
     and (status = 'pending' or (status = 'approved' and start_date > current_date))
  returning * into v_row;
  if not found then
    raise exception 'cannot_cancel';
  end if;
  return v_row;
end;
$$;

-- ---------------------------------------------------------------- admin RPC

create or replace function leave_admin_overview(p_token text)
returns jsonb
language plpgsql stable security definer
set search_path = public
as $$
declare
  adm employees := leave_auth(p_token, true);
begin
  return jsonb_build_object(
    'pending_count', (select count(*) from leave_requests where status = 'pending'),
    'employees', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', e.id, 'name', e.name, 'role', e.role, 'hire_date', e.hire_date,
        'token', e.token, 'active', e.active,
        'balance', case when e.hire_date is null then null
                        else leave_balance_json(e, current_date) end
      ) order by e.role desc, e.name)
      from employees e
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function leave_admin_requests(p_token text, p_status text default null)
returns table (
  id bigint, employee_id bigint, employee_name text, leave_type text,
  start_date date, end_date date, days numeric, reason text, status text,
  decision_comment text, decided_at timestamptz, created_at timestamptz
)
language plpgsql stable security definer
set search_path = public
as $$
declare
  adm employees := leave_auth(p_token, true);
begin
  return query
    select r.id, r.employee_id, e.name, r.leave_type, r.start_date, r.end_date,
           r.days, r.reason, r.status, r.decision_comment, r.decided_at, r.created_at
    from leave_requests r
    join employees e on e.id = r.employee_id
    where p_status is null or r.status = p_status
    order by (r.status = 'pending') desc, r.start_date desc, r.id desc;
end;
$$;

-- 승인/반려
create or replace function leave_admin_decide(
  p_token text, p_id bigint, p_approve boolean, p_comment text default ''
) returns leave_requests
language plpgsql security definer
set search_path = public
as $$
declare
  adm   employees := leave_auth(p_token, true);
  v_req leave_requests;
  emp   employees;
  e     record;
  v_other numeric;
begin
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

-- 대표가 승인된(또는 대기 중인) 건을 취소 → 잔여 복구
create or replace function leave_admin_cancel(p_token text, p_id bigint, p_comment text default '')
returns leave_requests
language plpgsql security definer
set search_path = public
as $$
declare
  adm   employees := leave_auth(p_token, true);
  v_row leave_requests;
begin
  update leave_requests
     set status = 'cancelled', decision_comment = coalesce(p_comment, ''), decided_at = now()
   where id = p_id and status in ('pending', 'approved')
  returning * into v_row;
  if not found then
    raise exception 'cannot_cancel';
  end if;
  return v_row;
end;
$$;

create or replace function leave_admin_save_employee(
  p_token text, p_id bigint, p_name text, p_hire_date date
) returns employees
language plpgsql security definer
set search_path = public
as $$
declare
  adm   employees := leave_auth(p_token, true);
  v_row employees;
begin
  if p_id is null then
    insert into employees (name, hire_date) values (btrim(p_name), p_hire_date)
    returning * into v_row;
  else
    update employees set name = btrim(p_name), hire_date = coalesce(p_hire_date, hire_date)
     where id = p_id
    returning * into v_row;
    if not found then
      raise exception 'not_found';
    end if;
  end if;
  return v_row;
end;
$$;

-- 링크 재발급 (기존 링크는 즉시 무효)
create or replace function leave_admin_reset_token(p_token text, p_id bigint)
returns text
language plpgsql security definer
set search_path = public
as $$
declare
  adm   employees := leave_auth(p_token, true);
  v_new text := encode(extensions.gen_random_bytes(24), 'hex');
begin
  update employees set token = v_new where id = p_id;
  if not found then
    raise exception 'not_found';
  end if;
  return v_new;
end;
$$;

create or replace function leave_admin_set_active(p_token text, p_id bigint, p_active boolean)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  adm employees := leave_auth(p_token, true);
begin
  if p_id = adm.id and not p_active then
    raise exception 'cannot_deactivate_self';
  end if;
  update employees set active = p_active where id = p_id;
end;
$$;

-- ---------------------------------------------------------------- grants

revoke all on function
  leave_balance_json(employees, date),
  leave_auth(text, boolean)
from public, anon, authenticated;

revoke execute on function
  leave_me(text), leave_my_requests(text),
  leave_submit(text, text, date, date, text), leave_cancel(text, bigint),
  leave_admin_overview(text), leave_admin_requests(text, text),
  leave_admin_decide(text, bigint, boolean, text), leave_admin_cancel(text, bigint, text),
  leave_admin_save_employee(text, bigint, text, date),
  leave_admin_reset_token(text, bigint), leave_admin_set_active(text, bigint, boolean)
from public;

grant execute on function
  leave_me(text), leave_my_requests(text),
  leave_submit(text, text, date, date, text), leave_cancel(text, bigint),
  leave_admin_overview(text), leave_admin_requests(text, text),
  leave_admin_decide(text, bigint, boolean, text), leave_admin_cancel(text, bigint, text),
  leave_admin_save_employee(text, bigint, text, date),
  leave_admin_reset_token(text, bigint), leave_admin_set_active(text, bigint, boolean)
to anon, authenticated;
