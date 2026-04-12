-- ============================================================
-- Launch security hardening: RLS, constraints, unique indexes
-- ============================================================

-- 1. 닉네임 길이 제약 (서버사이드 검증)
DO $$ BEGIN
  ALTER TABLE profiles
    ADD CONSTRAINT chk_nickname_len
    CHECK (char_length(nickname) BETWEEN 2 AND 12);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 2. likes 테이블 unique 제약 (좋아요 중복 insert 방지)
DO $$ BEGIN
  ALTER TABLE likes
    ADD CONSTRAINT uq_likes_user_goods
    UNIQUE (user_id, goods_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 3. fcm_tokens RLS 활성화 및 정책
ALTER TABLE fcm_tokens ENABLE ROW LEVEL SECURITY;

-- 본인 토큰만 조회
DO $$ BEGIN
  CREATE POLICY "Users can view own fcm tokens"
    ON fcm_tokens FOR SELECT
    USING (user_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 본인 토큰만 삽입
DO $$ BEGIN
  CREATE POLICY "Users can insert own fcm tokens"
    ON fcm_tokens FOR INSERT
    WITH CHECK (user_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 본인 토큰만 수정
DO $$ BEGIN
  CREATE POLICY "Users can update own fcm tokens"
    ON fcm_tokens FOR UPDATE
    USING (user_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 본인 토큰만 삭제
DO $$ BEGIN
  CREATE POLICY "Users can delete own fcm tokens"
    ON fcm_tokens FOR DELETE
    USING (user_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 4. calendar_events DELETE/UPDATE를 커스텀 이벤트 소유자로 제한
-- 기존 너무 느슨한 정책 삭제 후 재생성
DROP POLICY IF EXISTS "Authenticated users can update calendar events" ON calendar_events;
DROP POLICY IF EXISTS "Authenticated users can delete calendar events" ON calendar_events;

-- 커스텀 이벤트는 본인만, 나머지는 서비스 역할만 (크롤러 등)
CREATE POLICY "Users can update own custom calendar events"
  ON calendar_events FOR UPDATE
  USING (
    external_id LIKE 'custom_' || auth.uid() || '_%'
  );

CREATE POLICY "Users can delete own custom calendar events"
  ON calendar_events FOR DELETE
  USING (
    external_id LIKE 'custom_' || auth.uid() || '_%'
  );

-- INSERT: 커스텀 이벤트만 직접 삽입 가능 (크롤러는 service_role)
DROP POLICY IF EXISTS "Authenticated users can insert calendar events" ON calendar_events;

CREATE POLICY "Users can insert custom calendar events"
  ON calendar_events FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND external_id LIKE 'custom_' || auth.uid() || '_%'
  );
