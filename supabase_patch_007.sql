-- patch 007: notifications INSERT 정책 추가
-- 멘토→학생 선점 알림 등 인증된 사용자가 다른 사용자에게 알림을 삽입할 수 있도록 허용

create policy "인증된 사용자 알림 삽입 가능" on notifications
  for insert with check (auth.uid() is not null);
