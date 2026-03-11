-- patch 006: give_up_question RPC
-- 멘토가 답변 포기 시 질문을 open 상태로 되돌리고 시스템 메시지 삽입

create or replace function give_up_question(
  p_question_id uuid,
  p_mentor_id   uuid
)
returns void
language plpgsql
security definer
as $$
declare
  v_room_id uuid;
begin
  -- 권한 확인: 해당 멘토가 accepted 상태로 선점한 질문인지
  if not exists (
    select 1 from questions
    where id = p_question_id
      and mentor_id = p_mentor_id
      and status = 'accepted'
  ) then
    raise exception 'not_authorized';
  end if;

  -- 연결된 채팅방 ID 조회
  select id into v_room_id
  from chat_rooms
  where question_id = p_question_id
  limit 1;

  -- 시스템 메시지 삽입
  if v_room_id is not null then
    insert into chat_messages (room_id, sender_id, text, type)
    values (v_room_id, p_mentor_id, '멘토가 답변을 포기했습니다. 질문이 다시 오픈됩니다.', 'system');
  end if;

  -- 질문을 open 상태로 초기화
  update questions
  set
    status        = 'open',
    mentor_id     = null,
    accepted_at   = null,
    updated_at    = now()
  where id = p_question_id;
end;
$$;
