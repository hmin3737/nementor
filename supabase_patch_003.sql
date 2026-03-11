-- ============================================================
-- 패치 003: approve_info_verify_request 자유형 credential 지원
-- Supabase > SQL Editor 에서 실행하세요.
-- ============================================================

-- approve_info_verify_request 업데이트:
-- field_key가 mentor_profiles의 고정 컬럼(real_name 등)인 경우에만 컬럼 업데이트.
-- 자유형 credential(수상경력, 학원강사 경력 등)은 컬럼 업데이트 없이
-- verified_fields 배열에만 추가.
create or replace function approve_info_verify_request(p_request_id uuid, p_admin_note text default null)
returns void language plpgsql security definer as $$
declare
  v_mentor_id   uuid;
  v_field_key   text;
  v_field_value text;
  v_known_columns text[] := array['real_name', 'middle_school', 'high_school', 'university', 'department'];
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

  -- 고정 컬럼인 경우에만 mentor_profiles 컬럼도 업데이트
  if v_field_key = any(v_known_columns) then
    execute format(
      'update mentor_profiles set %I = $1 where user_id = $2',
      v_field_key
    ) using v_field_value, v_mentor_id;
  end if;

  -- verified_fields에 추가 (자유형 포함)
  update mentor_profiles
  set verified_fields = array_append(
    coalesce(verified_fields, array[]::text[]),
    v_field_key || ':' || v_field_value
  )
  where user_id = v_mentor_id;
end;
$$;
