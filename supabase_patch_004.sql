-- ============================================================
-- 패치 004: cert_requests 테이블 + notifications INSERT 정책
-- Supabase > SQL Editor 에서 실행하세요.
-- ============================================================

-- 1. cert_requests 테이블 생성
create table if not exists cert_requests (
  id          uuid primary key default uuid_generate_v4(),
  mentor_id   uuid not null references users on delete cascade,
  subject     text not null,
  level       text not null default 'pro',  -- 'pro' | 'master'
  message     text,
  file_url    text,
  status      text not null default 'pending',  -- 'pending' | 'approved' | 'rejected'
  created_at  timestamptz not null default now()
);

alter table cert_requests enable row level security;

-- 멘토 본인만 등록
create policy "본인만 등록" on cert_requests
  for insert with check (mentor_id = auth.uid());

-- 본인만 조회
create policy "본인만 조회" on cert_requests
  for select using (mentor_id = auth.uid());

-- 관리자 전체 조회
create policy "관리자 전체 조회" on cert_requests
  for select using (
    exists (select 1 from users where id = auth.uid() and role = 'admin')
  );

-- 관리자 수정 (승인/반려)
create policy "관리자 수정" on cert_requests
  for update using (
    exists (select 1 from users where id = auth.uid() and role = 'admin')
  );

-- 2. notifications: 관리자 INSERT 허용
create policy "관리자 알림 등록 가능" on notifications
  for insert with check (
    exists (select 1 from users where id = auth.uid() and role = 'admin')
  );
