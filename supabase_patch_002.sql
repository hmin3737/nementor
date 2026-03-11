-- ============================================================
-- 패치 002: info_verify_requests 테이블 + 관련 RPC
-- Supabase > SQL Editor 에서 실행하세요.
-- ============================================================

-- 1. info_verify_requests 테이블 생성
create table if not exists info_verify_requests (
  id          uuid primary key default uuid_generate_v4(),
  mentor_id   uuid not null references users on delete cascade,
  field_key   text not null,   -- 'real_name' | 'middle_school' | 'high_school' | 'university' | 'department'
  field_value text not null,
  note        text,
  file_url    text,
  status      text not null default 'pending', -- 'pending' | 'approved' | 'rejected'
  admin_note  text,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

alter table info_verify_requests enable row level security;

-- 멘토 본인만 등록/조회
create policy "본인만 등록" on info_verify_requests
  for insert with check (mentor_id = auth.uid());

create policy "본인만 조회" on info_verify_requests
  for select using (mentor_id = auth.uid());

-- 관리자(admin role) 전체 조회/수정
create policy "관리자 전체 조회" on info_verify_requests
  for select using (
    exists (select 1 from users where id = auth.uid() and role = 'admin')
  );

create policy "관리자 수정" on info_verify_requests
  for update using (
    exists (select 1 from users where id = auth.uid() and role = 'admin')
  );

-- 2. RPC: approve_info_verify_request
--    승인 시 mentor_profiles의 해당 필드 업데이트 + verified_fields 배열에 추가
create or replace function approve_info_verify_request(p_request_id uuid, p_admin_note text default null)
returns void language plpgsql security definer as $$
declare
  v_mentor_id   uuid;
  v_field_key   text;
  v_field_value text;
begin
  select mentor_id, field_key, field_value
  into v_mentor_id, v_field_key, v_field_value
  from info_verify_requests
  where id = p_request_id and status = 'pending';

  if not found then
    raise exception '요청을 찾을 수 없거나 이미 처리된 요청입니다';
  end if;

  -- 상태 업데이트
  update info_verify_requests
  set status = 'approved', admin_note = p_admin_note, updated_at = now()
  where id = p_request_id;

  -- mentor_profiles 해당 필드 업데이트 및 verified_fields 추가
  execute format(
    'update mentor_profiles set %I = $1, verified_fields = array_append(
      coalesce(verified_fields, array[]::text[]), $2
    ), updated_at = now() where user_id = $3',
    v_field_key
  ) using v_field_value, v_field_key, v_mentor_id;
end;
$$;

-- 3. RPC: reject_info_verify_request
create or replace function reject_info_verify_request(p_request_id uuid, p_admin_note text default null)
returns void language plpgsql security definer as $$
begin
  update info_verify_requests
  set status = 'rejected', admin_note = p_admin_note, updated_at = now()
  where id = p_request_id and status = 'pending';

  if not found then
    raise exception '요청을 찾을 수 없거나 이미 처리된 요청입니다';
  end if;
end;
$$;

-- 4. users 테이블에 avatar_url 컬럼 추가 (없는 경우)
alter table users add column if not exists avatar_url text;

-- 5. mentor_profiles에 verified_fields 컬럼 추가 (없는 경우)
alter table mentor_profiles add column if not exists verified_fields text[] default array[]::text[];
