-- ============================================================
-- 패치 005: cert_requests admin_note 컬럼 추가
-- Supabase > SQL Editor 에서 실행하세요.
-- ============================================================

alter table cert_requests add column if not exists admin_note text;
