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

-- 편의: 직원 이름으로 잔여 JSON 을 꺼낸다
create or replace function pg_temp.bal(p_name text, p_field text) returns numeric
language sql as $$
  select (e->'balance'->>p_field)::numeric
  from jsonb_array_elements(leave_overview((select value from app_settings where key = 'access_token'))->'employees') e
  where e->>'name' = p_name;
$$;

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
-- 공용 토큰을 알려진 값으로 고정
update app_settings set value = 'TOKEN' where key = 'access_token';

-- 입사 3년차(15개) 직원 / 입사 3개월차(3개) 직원
select leave_save_employee('TOKEN', null, ' 고참 ', (current_date - interval '3 years 2 months')::date);
select leave_save_employee('TOKEN', null, '신입', (current_date - interval '3 months')::date);
create temp table ids as
  select (select id from employees where name = '고참') as old_id,
         (select id from employees where name = '신입') as new_id;

-- 다음 주 월요일부터의 날짜들 (항상 미래, 평일 기준)
create temp table d as
  select (current_date + ((8 - extract(isodow from current_date)::int) % 7 + 7))::date as mon;

select pg_temp.eq('이름 앞뒤 공백 제거', (select count(*) from employees where name = '고참'), 1::bigint);
select pg_temp.eq('고참 발생 15', pg_temp.bal('고참', 'granted'), 15::numeric);
select pg_temp.eq('신입 발생 3',  pg_temp.bal('신입', 'granted'), 3::numeric);

-- 연차 3일(월~수) 신청 → 대기 중에도 잔여에서 빠진다
select leave_submit('TOKEN', (select old_id from ids), 'annual', (select mon from d), (select mon + 2 from d), '여행');
select pg_temp.eq('대기 3일 → 잔여 12', pg_temp.bal('고참', 'remaining'), 12::numeric);
select pg_temp.eq('대기 3일 표시',      pg_temp.bal('고참', 'pending'), 3::numeric);
select pg_temp.eq('아직 사용 0',        pg_temp.bal('고참', 'used'), 0::numeric);
select pg_temp.eq('승인 대기 건수 1',   (leave_overview('TOKEN')->>'pending_count')::int, 1);

-- 승인하면 사용으로 넘어가고 잔여는 그대로
select leave_decide('TOKEN', (select max(id) from leave_requests), true, 'ok');
select pg_temp.eq('승인 → 사용 3',  pg_temp.bal('고참', 'used'), 3::numeric);
select pg_temp.eq('승인 → 대기 0',  pg_temp.bal('고참', 'pending'), 0::numeric);
select pg_temp.eq('승인 → 잔여 12', pg_temp.bal('고참', 'remaining'), 12::numeric);

-- 반차는 0.5, 같은 날 오전/오후 두 개는 1일
select leave_submit('TOKEN', (select old_id from ids), 'half_am', (select mon + 7 from d), null, '');
select leave_submit('TOKEN', (select old_id from ids), 'half_pm', (select mon + 7 from d), null, '');
select pg_temp.eq('반차 둘 → 잔여 11', pg_temp.bal('고참', 'remaining'), 11::numeric);
select pg_temp.fails('같은 반차 중복',
  format($q$select leave_submit('TOKEN',%s,'half_am','%s',null,'')$q$, (select old_id from ids), (select mon + 7 from d)), 'overlap');
select pg_temp.fails('연차와 겹침',
  format($q$select leave_submit('TOKEN',%s,'half_am','%s',null,'')$q$, (select old_id from ids), (select mon + 1 from d)), 'overlap');

-- 반려는 잔여를 돌려준다
select leave_decide('TOKEN', (select max(id) from leave_requests), false, '인력 부족');
select pg_temp.eq('반려 → 잔여 11.5', pg_temp.bal('고참', 'remaining'), 11.5::numeric);

-- 승인된 건을 취소하면 복구
select leave_cancel('TOKEN', (select min(id) from leave_requests), '일정 변경');
select pg_temp.eq('승인 취소 → 잔여 14.5', pg_temp.bal('고참', 'remaining'), 14.5::numeric);

-- 대기 중인 건 취소
select leave_cancel('TOKEN', (select max(id) from leave_requests where status = 'pending'));
select pg_temp.eq('대기 취소 → 잔여 15', pg_temp.bal('고참', 'remaining'), 15::numeric);

-- 이미 처리된 건은 다시 승인/취소 불가
select pg_temp.fails('처리된 건 재승인',
  format($q$select leave_decide('TOKEN', %s, true, '')$q$, (select min(id) from leave_requests)), 'not_pending');
select pg_temp.fails('취소된 건 재취소',
  format($q$select leave_cancel('TOKEN', %s)$q$, (select min(id) from leave_requests)), 'cannot_cancel');

-- ---- 3. 잔여 초과/검증 ---------------------------------------------------
select pg_temp.fails('신입 4일 > 잔여 3',
  format($q$select leave_submit('TOKEN',%s,'annual','%s','%s','')$q$, (select new_id from ids), (select mon from d), (select mon + 3 from d)),
  'insufficient_balance');
select leave_submit('TOKEN', (select new_id from ids), 'annual', (select mon from d), (select mon + 2 from d), '');
select pg_temp.eq('신입 3일 신청 → 잔여 0', pg_temp.bal('신입', 'remaining'), 0::numeric);
select pg_temp.fails('잔여 0 에서 반차',
  format($q$select leave_submit('TOKEN',%s,'half_am','%s',null,'')$q$, (select new_id from ids), (select mon + 7 from d)),
  'insufficient_balance');
select pg_temp.fails('과거 날짜',
  format($q$select leave_submit('TOKEN',%s,'annual',current_date - 1,null,'')$q$, (select old_id from ids)), 'past_date');
select pg_temp.fails('주말만',
  format($q$select leave_submit('TOKEN',%s,'annual','%s','%s','')$q$, (select old_id from ids), (select mon + 5 from d), (select mon + 6 from d)),
  'weekend_only');
select pg_temp.fails('없는 직원', $q$select leave_submit('TOKEN', 999999, 'annual', current_date + 1, null, '')$q$, 'not_found');

-- 승인 시에도 잔여를 다시 검증 (입사일이 바뀌어 발생분이 줄어든 경우)
select leave_save_employee('TOKEN', (select new_id from ids), '신입', (current_date - interval '1 month')::date);
select pg_temp.fails('입사일 변경 후 승인 불가',
  format($q$select leave_decide('TOKEN', %s, true, '')$q$, (select max(id) from leave_requests)),
  'insufficient_balance');

-- 비활성 직원은 신청 불가, 목록에는 남는다
select leave_set_active('TOKEN', (select new_id from ids), false);
select pg_temp.fails('비활성 직원 신청',
  format($q$select leave_submit('TOKEN',%s,'half_am','%s',null,'')$q$, (select new_id from ids), (select mon + 7 from d)),
  'not_found');
select pg_temp.eq('비활성이어도 목록 유지', jsonb_array_length(leave_overview('TOKEN')->'employees'), (select count(*)::int from employees));

select pg_temp.fails('이름 없는 직원', $q$select leave_save_employee('TOKEN', null, '  ', current_date)$q$, 'bad_employee');
select pg_temp.fails('입사일 없는 직원', $q$select leave_save_employee('TOKEN', null, '아무개', null)$q$, 'bad_employee');

-- ---- 4. 공용 링크 ---------------------------------------------------------
select pg_temp.fails('잘못된 토큰', $q$select leave_overview('nope')$q$, 'invalid_token');
select pg_temp.fails('빈 토큰',     $q$select leave_overview(null)$q$, 'invalid_token');
select pg_temp.fails('토큰 없이 신청', format($q$select leave_submit('nope',%s,'annual',current_date + 1,null,'')$q$, (select old_id from ids)), 'invalid_token');
select pg_temp.fails('토큰 없이 승인', $q$select leave_decide('nope', 1, true, '')$q$, 'invalid_token');

-- 링크 재발급: 이전 토큰은 무효, 새 토큰은 유효
create temp table newtok as select leave_reset_access_token('TOKEN') as t;
select pg_temp.fails('재발급 후 옛 링크', $q$select leave_overview('TOKEN')$q$, 'invalid_token');
select pg_temp.eq('새 링크는 유효', jsonb_array_length(leave_overview((select t from newtok))->'employees'), (select count(*)::int from employees));
select pg_temp.eq('새 토큰 길이 48', length((select t from newtok)), 48);

rollback;
