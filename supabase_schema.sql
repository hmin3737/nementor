-- ============================================================
-- 내멘토 Supabase 스키마
-- Supabase > SQL Editor 에 전체 붙여넣고 Run 하세요.
-- ============================================================

-- ── Extensions ──────────────────────────────────────────────
create extension if not exists "uuid-ossp";

-- ── ENUM 타입 ────────────────────────────────────────────────
create type user_role as enum ('student', 'mentor', 'admin');
create type cert_level as enum ('pro', 'master');
create type question_status as enum ('open', 'accepted', 'closed', 'cancelled');
create type chat_message_type as enum ('text', 'image', 'math', 'system');
create type ledger_type as enum (
  'iap_charge', 'question_hold', 'question_refund',
  'mentor_earn', 'platform_fee', 'consulting_hold', 'admin_adjust'
);
create type dispute_status as enum ('pending', 'reviewing', 'resolved');
create type consulting_status as enum ('pending', 'accepted', 'ongoing', 'ended', 'cancelled');
create type doc_status as enum ('pending', 'approved', 'rejected');

-- ============================================================
-- 1. users
-- ============================================================
create table users (
  id          uuid primary key references auth.users on delete cascade,
  email       text not null,
  nickname    text not null unique,
  role        user_role not null default 'student',
  cash_balance int not null default 0 check (cash_balance >= 0),
  created_at  timestamptz not null default now()
);

alter table users enable row level security;

create policy "본인만 조회/수정" on users
  for all using (auth.uid() = id);

create policy "멘토 프로필은 모두 조회 가능" on users
  for select using (role = 'mentor' or auth.uid() = id);

-- ============================================================
-- 2. mentor_profiles
-- ============================================================
create table mentor_profiles (
  user_id         uuid primary key references users on delete cascade,
  real_name       text,
  middle_school   text,
  high_school     text,
  university      text,
  department      text,
  verified        boolean not null default false,
  hourly_rate_min int,
  hourly_rate_max int,
  intro           text,
  bio             text,
  subjects        text[] not null default '{}',
  rating          numeric(3,2) not null default 0,
  review_count    int not null default 0,
  created_at      timestamptz not null default now()
);

alter table mentor_profiles enable row level security;

create policy "모두 조회 가능" on mentor_profiles
  for select using (true);

create policy "본인만 등록" on mentor_profiles
  for insert with check (auth.uid() = user_id);

create policy "본인만 수정" on mentor_profiles
  for update using (auth.uid() = user_id);

-- ============================================================
-- 3. mentor_certifications
-- ============================================================
create table mentor_certifications (
  id          uuid primary key default uuid_generate_v4(),
  mentor_id   uuid not null references users on delete cascade,
  subject     text not null,
  level       cert_level not null,
  granted_at  timestamptz not null default now(),
  unique (mentor_id, subject)
);

alter table mentor_certifications enable row level security;

create policy "모두 조회 가능" on mentor_certifications
  for select using (true);

create policy "관리자만 수정" on mentor_certifications
  for all using (
    exists (select 1 from users where id = auth.uid() and role = 'admin')
  );

-- ============================================================
-- 4. mentor_documents (서류 심사)
-- ============================================================
create table mentor_documents (
  id            uuid primary key default uuid_generate_v4(),
  mentor_id     uuid not null references users on delete cascade,
  document_type text not null,
  file_url      text not null,
  status        doc_status not null default 'pending',
  created_at    timestamptz not null default now()
);

alter table mentor_documents enable row level security;

create policy "본인 서류만 조회" on mentor_documents
  for select using (auth.uid() = mentor_id);

create policy "본인만 등록" on mentor_documents
  for insert with check (auth.uid() = mentor_id);

create policy "관리자는 전체 조회/수정" on mentor_documents
  for all using (
    exists (select 1 from users where id = auth.uid() and role = 'admin')
  );

-- ============================================================
-- 5. questions
-- ============================================================
create table questions (
  id            uuid primary key default uuid_generate_v4(),
  student_id    uuid not null references users on delete cascade,
  mentor_id     uuid references users,
  school_level  text,                              -- 선택 사항
  subject       text,                              -- 선택 사항
  title         text,
  body          text not null,
  image_urls    text[] not null default '{}',
  price         int not null check (price >= 0),
  status        question_status not null default 'open',
  expires_at    timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

alter table questions enable row level security;

create policy "로그인 사용자 전체 조회" on questions
  for select using (auth.uid() is not null);

create policy "본인만 등록" on questions
  for insert with check (auth.uid() = student_id);

create policy "본인만 수정" on questions
  for update using (auth.uid() = student_id or auth.uid() = mentor_id);

-- ============================================================
-- 6. question_filters
-- ============================================================
create table question_filters (
  id                      uuid primary key default uuid_generate_v4(),
  question_id             uuid not null references questions on delete cascade,
  filter_type             text not null,   -- 'all' | 'specific' | 'condition'
  allowed_mentor_ids      uuid[],          -- filter_type='specific' 일 때
  require_cert_conditions jsonb,           -- filter_type='condition' 일 때
  require_university      text             -- AND 조건으로 추가 가능
);

alter table question_filters enable row level security;

create policy "로그인 사용자 전체 조회" on question_filters
  for select using (auth.uid() is not null);

create policy "본인만 등록" on question_filters
  for insert with check (
    exists (select 1 from questions where id = question_id and student_id = auth.uid())
  );

-- ============================================================
-- 7. chat_rooms
-- ============================================================
create table chat_rooms (
  id            uuid primary key default uuid_generate_v4(),
  question_id   uuid references questions on delete set null,
  student_id    uuid not null references users,
  mentor_id     uuid not null references users,
  is_declared   boolean not null default false,
  declared_at   timestamptz,
  closed_at     timestamptz,
  created_at    timestamptz not null default now()
);

alter table chat_rooms enable row level security;

create policy "참여자만 조회" on chat_rooms
  for select using (auth.uid() = student_id or auth.uid() = mentor_id);

-- ============================================================
-- 8. chat_messages
-- ============================================================
create table chat_messages (
  id              uuid primary key default uuid_generate_v4(),
  room_id         uuid not null references chat_rooms on delete cascade,
  sender_id       uuid references users,
  type            chat_message_type not null default 'text',
  text            text,
  math_expression text,
  image_url       text,
  created_at      timestamptz not null default now()
);

alter table chat_messages enable row level security;

create policy "채팅방 참여자만 조회/등록" on chat_messages
  for all using (
    exists (
      select 1 from chat_rooms
      where id = room_id
        and (student_id = auth.uid() or mentor_id = auth.uid())
    )
  );

-- Realtime 활성화
alter publication supabase_realtime add table chat_messages;

-- ============================================================
-- 9. cash_ledger
-- ============================================================
create table cash_ledger (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references users on delete cascade,
  amount      int not null,
  balance     int not null,
  type        ledger_type not null,
  ref_id      uuid,
  note        text,
  created_at  timestamptz not null default now()
);

alter table cash_ledger enable row level security;

create policy "본인 내역만 조회" on cash_ledger
  for select using (auth.uid() = user_id);

-- ============================================================
-- 10. cash_holds
-- ============================================================
create table cash_holds (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references users on delete cascade,
  amount      int not null,
  ref_id      uuid,
  released_at timestamptz,
  created_at  timestamptz not null default now()
);

alter table cash_holds enable row level security;

create policy "본인 내역만 조회" on cash_holds
  for select using (auth.uid() = user_id);

-- ============================================================
-- 11. disputes
-- ============================================================
create table disputes (
  id          uuid primary key default uuid_generate_v4(),
  question_id uuid references questions on delete set null,
  user_id     uuid not null references users,
  reason      text not null,
  status      dispute_status not null default 'pending',
  result      text,
  created_at  timestamptz not null default now()
);

alter table disputes enable row level security;

create policy "본인 분쟁만 조회" on disputes
  for select using (auth.uid() = user_id);

create policy "본인만 등록" on disputes
  for insert with check (auth.uid() = user_id);

create policy "관리자는 전체 조회/수정" on disputes
  for all using (
    exists (select 1 from users where id = auth.uid() and role = 'admin')
  );

-- ============================================================
-- 12. reviews
-- ============================================================
create table reviews (
  id          uuid primary key default uuid_generate_v4(),
  question_id uuid references questions on delete set null,
  student_id  uuid not null references users,
  mentor_id   uuid not null references users,
  rating      int not null check (rating between 1 and 5),
  comment     text,
  created_at  timestamptz not null default now(),
  unique (question_id, student_id)
);

alter table reviews enable row level security;

create policy "모두 조회 가능" on reviews
  for select using (true);

create policy "본인만 등록" on reviews
  for insert with check (auth.uid() = student_id);

-- 리뷰 등록 시 mentor_profiles.rating 자동 갱신
create or replace function update_mentor_rating()
returns trigger language plpgsql security definer as $$
begin
  update mentor_profiles
  set
    rating = (select avg(rating) from reviews where mentor_id = new.mentor_id),
    review_count = (select count(*) from reviews where mentor_id = new.mentor_id)
  where user_id = new.mentor_id;
  return new;
end;
$$;

create trigger trg_update_mentor_rating
after insert on reviews
for each row execute function update_mentor_rating();

-- ============================================================
-- 13. board_posts
-- ============================================================
create table board_posts (
  id                  uuid primary key default uuid_generate_v4(),
  mentor_id           uuid not null references users on delete cascade,
  mentor_nickname     text not null,
  mentor_university   text,
  title               text not null,
  body                text not null,
  view_count          int not null default 0,
  like_count          int not null default 0,
  comment_count       int not null default 0,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

alter table board_posts enable row level security;

create policy "모두 조회 가능" on board_posts
  for select using (true);

create policy "멘토만 등록" on board_posts
  for insert with check (
    auth.uid() = mentor_id and
    exists (select 1 from users where id = auth.uid() and role = 'mentor')
  );

create policy "본인만 수정/삭제" on board_posts
  for all using (auth.uid() = mentor_id);

create policy "관리자 게시물 삭제" on board_posts
  for delete using (
    exists (select 1 from users where id = auth.uid() and role = 'admin')
  );

-- ============================================================
-- 14. board_comments
-- ============================================================
create table board_comments (
  id            uuid primary key default uuid_generate_v4(),
  post_id       uuid not null references board_posts on delete cascade,
  user_id       uuid not null references users on delete cascade,
  user_nickname text not null,
  user_role     user_role not null default 'student',
  parent_id     uuid references board_comments on delete cascade,
  body          text not null,
  created_at    timestamptz not null default now()
);

alter table board_comments enable row level security;

create policy "모두 조회 가능" on board_comments
  for select using (true);

create policy "로그인 사용자 등록 가능" on board_comments
  for insert with check (auth.uid() = user_id);

create policy "본인만 삭제" on board_comments
  for delete using (auth.uid() = user_id);

create policy "관리자 댓글 삭제" on board_comments
  for delete using (
    exists (select 1 from users where id = auth.uid() and role = 'admin')
  );

-- 댓글 수 자동 갱신
create or replace function update_comment_count()
returns trigger language plpgsql security definer as $$
begin
  if tg_op = 'INSERT' then
    update board_posts set comment_count = comment_count + 1 where id = new.post_id;
  elsif tg_op = 'DELETE' then
    update board_posts set comment_count = comment_count - 1 where id = old.post_id;
  end if;
  return null;
end;
$$;

create trigger trg_comment_count
after insert or delete on board_comments
for each row execute function update_comment_count();

-- ============================================================
-- 15. board_likes
-- ============================================================
create table board_likes (
  id       uuid primary key default uuid_generate_v4(),
  post_id  uuid not null references board_posts on delete cascade,
  user_id  uuid not null references users on delete cascade,
  unique (post_id, user_id)
);

alter table board_likes enable row level security;

create policy "모두 조회 가능" on board_likes
  for select using (true);

create policy "로그인 사용자 등록/삭제" on board_likes
  for all using (auth.uid() = user_id);

-- 좋아요 수 자동 갱신
create or replace function update_like_count()
returns trigger language plpgsql security definer as $$
begin
  if tg_op = 'INSERT' then
    update board_posts set like_count = like_count + 1 where id = new.post_id;
  elsif tg_op = 'DELETE' then
    update board_posts set like_count = like_count - 1 where id = old.post_id;
  end if;
  return null;
end;
$$;

create trigger trg_like_count
after insert or delete on board_likes
for each row execute function update_like_count();

-- ============================================================
-- 16. subject_default_prices
-- ============================================================
create table subject_default_prices (
  id           uuid primary key default uuid_generate_v4(),
  school_level text not null,
  subject      text not null,
  price        int not null,
  avg_minutes  int not null default 30,
  unique (school_level, subject)
);

alter table subject_default_prices enable row level security;

create policy "모두 조회 가능" on subject_default_prices
  for select using (true);

create policy "관리자만 수정" on subject_default_prices
  for all using (
    exists (select 1 from users where id = auth.uid() and role = 'admin')
  );

-- 기본 가격 시드 데이터
insert into subject_default_prices (school_level, subject, price, avg_minutes) values
  ('고등', '수학', 3000, 25),
  ('고등', '국어', 2000, 30),
  ('고등', '영어', 2000, 30),
  ('고등', '과학', 2500, 28),
  ('중등', '수학', 2000, 30),
  ('중등', '영어', 1500, 30),
  ('초등', '수학', 1000, 35);

-- ============================================================
-- 17. notifications
-- ============================================================
create table notifications (
  id         uuid primary key default uuid_generate_v4(),
  user_id    uuid not null references users on delete cascade,
  type       text not null, -- 'question'|'chat'|'review'|'consulting'|'system'
  title      text not null,
  body       text not null,
  ref_id     uuid,
  is_read    boolean not null default false,
  created_at timestamptz not null default now()
);

alter table notifications enable row level security;

create policy "본인 알림만 조회" on notifications
  for select using (auth.uid() = user_id);

create policy "본인 알림만 수정" on notifications
  for update using (auth.uid() = user_id);

-- ============================================================
-- 18. mentor_consultation_rates
-- ============================================================
create table mentor_consultation_rates (
  id          uuid primary key default uuid_generate_v4(),
  mentor_id   uuid not null references users on delete cascade unique,
  hourly_rate int not null,
  updated_at  timestamptz not null default now()
);

alter table mentor_consultation_rates enable row level security;

create policy "모두 조회 가능" on mentor_consultation_rates
  for select using (true);

create policy "본인만 수정" on mentor_consultation_rates
  for all using (auth.uid() = mentor_id);

-- ============================================================
-- 19. consulting_sessions
-- ============================================================
create table consulting_sessions (
  id           uuid primary key default uuid_generate_v4(),
  student_id   uuid not null references users on delete cascade,
  mentor_id    uuid not null references users on delete cascade,
  subject      text,
  status       consulting_status not null default 'pending',
  chat_room_id uuid references chat_rooms on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

alter table consulting_sessions enable row level security;

create policy "참여자만 조회" on consulting_sessions
  for select using (auth.uid() = student_id or auth.uid() = mentor_id);

create policy "학생만 신청" on consulting_sessions
  for insert with check (auth.uid() = student_id);

create policy "참여자만 수정" on consulting_sessions
  for update using (auth.uid() = student_id or auth.uid() = mentor_id);

-- ============================================================
-- 20. Storage 버킷 생성
-- ============================================================
insert into storage.buckets (id, name, public) values
  ('question-images',   'question-images',   true),
  ('mentor-documents',  'mentor-documents',  false),
  ('avatars',           'avatars',           true),
  ('board-images',      'board-images',      true),
  ('dispute-evidence',  'dispute-evidence',  false)
on conflict do nothing;

-- Storage 정책: 공개 버킷은 모두 읽기 가능
create policy "question-images 공개 읽기" on storage.objects
  for select using (bucket_id = 'question-images');

create policy "avatars 공개 읽기" on storage.objects
  for select using (bucket_id = 'avatars');

create policy "board-images 공개 읽기" on storage.objects
  for select using (bucket_id = 'board-images');

-- 로그인 사용자 업로드
create policy "로그인 사용자 업로드" on storage.objects
  for insert with check (
    auth.uid() is not null and
    bucket_id in ('question-images', 'avatars', 'board-images', 'mentor-documents', 'dispute-evidence')
  );

-- ============================================================
-- 21. RPC: 선점 (preempt question)
-- ============================================================
create or replace function preempt_question(p_question_id uuid, p_mentor_id uuid)
returns uuid language plpgsql security definer as $$
declare
  v_room_id uuid;
  v_student_id uuid;
  v_price int;
begin
  -- 낙관적 잠금: open 상태인 경우만
  update questions
  set status = 'accepted', mentor_id = p_mentor_id
  where id = p_question_id and status = 'open'
  returning student_id, price into v_student_id, v_price;

  if not found then
    raise exception '이미 선점된 질문이에요';
  end if;

  -- 채팅방 생성
  insert into chat_rooms (question_id, student_id, mentor_id)
  values (p_question_id, v_student_id, p_mentor_id)
  returning id into v_room_id;

  return v_room_id;
end;
$$;

-- ============================================================
-- 22. RPC: 종료 선언 (declare_end)
-- ============================================================
create or replace function declare_end(p_room_id uuid)
returns void language plpgsql security definer as $$
begin
  update chat_rooms
  set is_declared = true, declared_at = now()
  where id = p_room_id
    and (student_id = auth.uid() or mentor_id = auth.uid());
end;
$$;

-- ============================================================
-- 22b. mentor_favorites (관심 멘토)
-- ============================================================
create table mentor_favorites (
  id         uuid primary key default uuid_generate_v4(),
  student_id uuid not null references users on delete cascade,
  mentor_id  uuid not null references users on delete cascade,
  created_at timestamptz not null default now(),
  unique (student_id, mentor_id)
);

alter table mentor_favorites enable row level security;

create policy "본인 즐겨찾기만 조회" on mentor_favorites
  for select using (auth.uid() = student_id);

create policy "본인만 등록/삭제" on mentor_favorites
  for all using (auth.uid() = student_id);

-- ============================================================
-- 23. RPC: 캐시 차감 (질문 등록 시)
-- ============================================================
create or replace function deduct_cash_for_question(p_question_id uuid, p_amount int)
returns void language plpgsql security definer as $$
declare
  v_student_id uuid;
  v_new_balance int;
begin
  -- 질문 소유자 = 현재 로그인 사용자인지 확인
  select student_id into v_student_id
  from questions
  where id = p_question_id and student_id = auth.uid();

  if not found then
    raise exception '권한이 없어요';
  end if;

  -- 잔액 차감 (check (cash_balance >= 0) 가 자동으로 음수 방어)
  update users
  set cash_balance = cash_balance - p_amount
  where id = v_student_id and cash_balance >= p_amount
  returning cash_balance into v_new_balance;

  if not found then
    raise exception '캐시가 부족해요';
  end if;

  -- 원장 기록
  insert into cash_ledger (user_id, amount, balance, type, ref_id, note)
  values (v_student_id, -p_amount, v_new_balance, 'question_hold', p_question_id, '질문 등록 차감');
end;
$$;

-- ============================================================
-- 24. RPC: 질문 취소 및 캐시 환불
-- ============================================================
create or replace function cancel_question(p_question_id uuid)
returns void language plpgsql security definer as $$
declare
  v_student_id uuid;
  v_price      int;
  v_status     question_status;
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

  -- 질문 취소
  update questions set status = 'cancelled', updated_at = now()
  where id = p_question_id;

  -- 캐시 전액 환불
  update users
  set cash_balance = cash_balance + v_price
  where id = v_student_id
  returning cash_balance into v_new_balance;

  -- 원장 기록
  insert into cash_ledger (user_id, amount, balance, type, ref_id, note)
  values (v_student_id, v_price, v_new_balance, 'question_refund', p_question_id, '질문 취소 환불');
end;
$$;

-- ============================================================
-- 완료!
-- ============================================================
