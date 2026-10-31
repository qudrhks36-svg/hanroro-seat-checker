-- schema.sql 검증용 시나리오 테스트 (로컬 Postgres에서 실행: psql -v ON_ERROR_STOP=1 -f test.sql)
-- 실행 전에 빈 DB에 schema.sql 을 먼저 적용해야 한다. 끝나면 롤백된다.

begin;

create or replace function pg_temp.eq(label text, got anyelement, want anyelement) returns void
language plpgsql as $$
begin
  if got is distinct from want then
    raise exception 'FAIL %: got %, want %', label, got, want;
  end if;
  raise notice 'ok   %', label;
end $$;

create or replace function pg_temp.fails(label text, sql text, want text) returns void
language plpgsql as $$
begin
  begin
    execute sql;
  exception when others then
    if sqlerrm = want then
      raise notice 'ok   % (%)', label, sqlerrm;
      return;
    end if;
    raise exception 'FAIL %: error %, want %', label, sqlerrm, want;
  end;
  raise exception 'FAIL %: no error, want %', label, want;
end $$;

-- ---- 1. 발생 규칙 (고정 날짜) -------------------------------------------
select pg_temp.eq('입사 당일 0개',            (select granted from leave_entitlement('2025-03-10', '2025-03-10')), 0::numeric);
select pg_temp.eq('1개월 되기 전 0개',        (select granted from leave_entitlement('2025-03-10', '2025-04-09')), 0::numeric);
select pg_temp.eq('1개월 되는 날 1개',        (select granted from leave_entitlement('2025-03-10', '2025-04-10')), 1::numeric);
select pg_temp.eq('6개월 6개',                (select granted from leave_entitlement('2025-03-10', '2025-09-10')), 6::numeric);
select pg_temp.eq('11개월 11개(상한)',        (select granted from leave_entitlement('2025-03-10', '2026-02-10')), 11::numeric);
select pg_temp.eq('1년 되기 전날 11개',       (select granted from leave_entitlement('2025-03-10', '2026-03-09')), 11::numeric);
select pg_temp.eq('1년 되는 날 15개',         (select granted from leave_entitlement('2025-03-10', '2026-03-10')), 15::numeric);
select pg_temp.eq('2년차 시작일',             (select period_start from leave_entitlement('2025-03-10', '2027-03-10')), '2027-03-10'::date);
select pg_temp.eq('2년차 직전은 1년차 기간',  (select period_start from leave_entitlement('2025-03-10', '2027-03-09')), '2026-03-10'::date);
select pg_temp.eq('기간 끝',                  (select period_end from leave_entitlement('2025-03-10', '2026-06-01')), '2027-03-10'::date);
select pg_temp.eq('주말 제외 일수',           leave_weekdays('2026-11-02', '2026-11-08'), 5);  -- 월~일

-- ---- 2. 신청/승인/취소 흐름 ---------------------------------------------
insert into employees (name, role, token) values ('대표', 'admin', 'ADMIN');
-- 입사 3년차(15개) 직원 / 입사 3개월차(3개) 직원
insert into employees (name, hire_date, token)
values ('고참', current_date - interval '3 years 2 months', 'OLD'),
       ('신입', current_date - interval '3 months', 'NEW');

-- 다음 주 월요일부터의 날짜들 (항상 미래, 평일 기준)
create temp table d as
  select (current_date + ((8 - extract(isodow from current_date)::int) % 7 + 7))::date as mon;

select pg_temp.eq('고참 발생 15', (leave_me('OLD')->'balance'->>'granted')::numeric, 15::numeric);
select pg_temp.eq('신입 발생 3',  (leave_me('NEW')->'balance'->>'granted')::numeric, 3::numeric);

-- 연차 3일(월~수) 신청 → 대기 중에도 잔여에서 빠진다
select leave_submit('OLD', 'annual', (select mon from d), (select mon + 2 from d), '여행');
select pg_temp.eq('대기 3일 → 잔여 12', (leave_me('OLD')->'balance'->>'remaining')::numeric, 12::numeric);
select pg_temp.eq('대기 3일 표시',      (leave_me('OLD')->'balance'->>'pending')::numeric, 3::numeric);
select pg_temp.eq('아직 사용 0',        (leave_me('OLD')->'balance'->>'used')::numeric, 0::numeric);

-- 승인하면 사용으로 넘어가고 잔여는 그대로
select leave_admin_decide('ADMIN', (select max(id) from leave_requests), true, 'ok');
select pg_temp.eq('승인 → 사용 3',  (leave_me('OLD')->'balance'->>'used')::numeric, 3::numeric);
select pg_temp.eq('승인 → 대기 0',  (leave_me('OLD')->'balance'->>'pending')::numeric, 0::numeric);
select pg_temp.eq('승인 → 잔여 12', (leave_me('OLD')->'balance'->>'remaining')::numeric, 12::numeric);

-- 반차는 0.5, 같은 날 오전/오후 두 개는 1일
select leave_submit('OLD', 'half_am', (select mon + 7 from d), null, '');
select leave_submit('OLD', 'half_pm', (select mon + 7 from d), null, '');
select pg_temp.eq('반차 둘 → 잔여 11', (leave_me('OLD')->'balance'->>'remaining')::numeric, 11::numeric);
select pg_temp.fails('같은 반차 중복', format($q$select leave_submit('OLD','half_am','%s',null,'')$q$, (select mon + 7 from d)), 'overlap');
select pg_temp.fails('연차와 겹침',    format($q$select leave_submit('OLD','half_am','%s',null,'')$q$, (select mon + 1 from d)), 'overlap');

-- 반려는 잔여를 돌려준다
select leave_admin_decide('ADMIN', (select max(id) from leave_requests), false, '인력 부족');
select pg_temp.eq('반려 → 잔여 11.5', (leave_me('OLD')->'balance'->>'remaining')::numeric, 11.5::numeric);

-- 승인된 건을 대표가 취소하면 복구
select leave_admin_cancel('ADMIN', (select min(id) from leave_requests where employee_id = (select id from employees where token = 'OLD')), '일정 변경');
select pg_temp.eq('취소 → 잔여 14.5', (leave_me('OLD')->'balance'->>'remaining')::numeric, 14.5::numeric);

-- 직원 본인 취소(시작 전 승인 건 포함)
select leave_cancel('OLD', (select max(id) from leave_requests where employee_id = (select id from employees where token = 'OLD') and status = 'pending'));
select pg_temp.eq('본인 취소 → 잔여 15', (leave_me('OLD')->'balance'->>'remaining')::numeric, 15::numeric);

-- ---- 3. 잔여 초과/검증 ---------------------------------------------------
select pg_temp.fails('신입 4일 > 잔여 3',
  format($q$select leave_submit('NEW','annual','%s','%s','')$q$, (select mon from d), (select mon + 3 from d)),
  'insufficient_balance');
select leave_submit('NEW', 'annual', (select mon from d), (select mon + 2 from d), '');
select pg_temp.eq('신입 3일 신청 → 잔여 0', (leave_me('NEW')->'balance'->>'remaining')::numeric, 0::numeric);
select pg_temp.fails('잔여 0 에서 반차',
  format($q$select leave_submit('NEW','half_am','%s',null,'')$q$, (select mon + 7 from d)),
  'insufficient_balance');
select pg_temp.fails('과거 날짜', $q$select leave_submit('OLD','annual',current_date - 1,null,'')$q$, 'past_date');
select pg_temp.fails('주말만', format($q$select leave_submit('OLD','annual','%s','%s','')$q$, (select mon + 5 from d), (select mon + 6 from d)), 'weekend_only');

-- 승인 시에도 잔여를 다시 검증 (입사일이 바뀌어 발생분이 줄어든 경우)
update employees set hire_date = current_date - interval '1 month' where token = 'NEW';
select pg_temp.fails('입사일 변경 후 승인 불가',
  format($q$select leave_admin_decide('ADMIN', %s, true, '')$q$, (select max(id) from leave_requests)),
  'insufficient_balance');

-- ---- 4. 권한 -------------------------------------------------------------
select pg_temp.fails('잘못된 토큰', $q$select leave_me('nope')$q$, 'invalid_token');
select pg_temp.fails('직원이 승인 시도', format($q$select leave_admin_decide('OLD', %s, true, '')$q$, (select max(id) from leave_requests)), 'forbidden');
select pg_temp.fails('직원이 목록 조회', $q$select leave_admin_overview('OLD')$q$, 'forbidden');
select pg_temp.fails('남의 신청 취소', format($q$select leave_cancel('OLD', %s)$q$, (select max(id) from leave_requests where employee_id = (select id from employees where token = 'NEW'))), 'cannot_cancel');

-- 링크 재발급 후 이전 토큰은 무효
select leave_admin_reset_token('ADMIN', (select id from employees where token = 'OLD'));
select pg_temp.fails('재발급 후 옛 링크', $q$select leave_me('OLD')$q$, 'invalid_token');

-- 비활성화된 직원은 접속 불가
select leave_admin_set_active('ADMIN', (select id from employees where token = 'NEW'), false);
select pg_temp.fails('비활성 직원', $q$select leave_me('NEW')$q$, 'invalid_token');

-- 대표 overview
select pg_temp.eq('직원 목록 3명', jsonb_array_length(leave_admin_overview('ADMIN')->'employees'), 3);

rollback;
