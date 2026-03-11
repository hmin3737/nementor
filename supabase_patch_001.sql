-- ============================================================
-- 패치 001: 질문 등록 & 캐시 환불 버그 수정
-- Supabase > SQL Editor 에서 실행하세요.
-- ============================================================

-- 1. questions: school_level / subject NOT NULL 제거 (선택 사항이므로)
alter table questions alter column school_level drop not null;
alter table questions alter column subject drop not null;

-- 2. question_filters: 컬럼명 앱과 일치하도록 재생성
drop table if exists question_filters;

create table question_filters (
  id                      uuid primary key default uuid_generate_v4(),
  question_id             uuid not null references questions on delete cascade,
  filter_type             text not null,   -- 'all' | 'specific' | 'condition'
  allowed_mentor_ids      uuid[],
  require_cert_conditions jsonb,
  require_university      text
);

alter table question_filters enable row level security;

create policy "로그인 사용자 전체 조회" on question_filters
  for select using (auth.uid() is not null);

create policy "본인만 등록" on question_filters
  for insert with check (
    exists (select 1 from questions where id = question_id and student_id = auth.uid())
  );

-- 3. RPC: deduct_cash_for_question (질문 등록 시 캐시 차감)
create or replace function deduct_cash_for_question(p_question_id uuid, p_amount int)
returns void language plpgsql security definer as $$
declare
  v_student_id  uuid;
  v_new_balance int;
begin
  select student_id into v_student_id
  from questions
  where id = p_question_id and student_id = auth.uid();

  if not found then
    raise exception '권한이 없어요';
  end if;

  update users
  set cash_balance = cash_balance - p_amount
  where id = v_student_id and cash_balance >= p_amount
  returning cash_balance into v_new_balance;

  if not found then
    raise exception '캐시가 부족해요';
  end if;

  insert into cash_ledger (user_id, amount, balance, type, ref_id, note)
  values (v_student_id, -p_amount, v_new_balance, 'question_hold', p_question_id, '질문 등록 차감');
end;
$$;

-- 4. RPC: cancel_question (질문 취소 + 캐시 환불)
create or replace function cancel_question(p_question_id uuid)
returns void language plpgsql security definer as $$
declare
  v_student_id  uuid;
  v_price       int;
  v_status      question_status;
  v_new_balance int;
begin
  select student_id, price, status
  into v_student_id, v_price, v_status
  from questions
  where id = p_question_id and student_id = auth.uid();

  if not found then
    raise exception '권한이 없어요';
  end if;

  if v_status != 'open' then
    raise exception '이미 진행 중이거나 종료된 질문은 취소할 수 없어요';
  end if;

  update questions set status = 'cancelled', updated_at = now()
  where id = p_question_id;

  update users
  set cash_balance = cash_balance + v_price
  where id = v_student_id
  returning cash_balance into v_new_balance;

  insert into cash_ledger (user_id, amount, balance, type, ref_id, note)
  values (v_student_id, v_price, v_new_balance, 'question_refund', p_question_id, '질문 취소 환불');
end;
$$;
