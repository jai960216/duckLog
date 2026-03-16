-- ============================================
-- 신고 처리 시스템: 자동차단, 자동정지, 이의제기
-- ============================================

-- 1. profiles에 정지 상태 컬럼 추가
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN DEFAULT false;

-- 2. 동일 유저에 대한 중복 신고 영구 차단 (차단/해제는 자유)
CREATE UNIQUE INDEX IF NOT EXISTS idx_reports_unique_reporter_user
  ON reports(reporter_id, reported_user_id);

-- 3. 신고 + 자동차단 + 자동정지 원자적 처리 RPC
CREATE OR REPLACE FUNCTION report_and_block(
  p_reported_user_id UUID,
  p_reported_goods_id UUID DEFAULT NULL,
  p_reason TEXT DEFAULT 'other',
  p_description TEXT DEFAULT NULL
) RETURNS JSONB
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_reporter_id UUID := auth.uid();
  v_report_count INT;
  v_auto_suspended BOOLEAN := false;
BEGIN
  -- 자기 자신 신고 방지
  IF v_reporter_id = p_reported_user_id THEN
    RAISE EXCEPTION 'cannot_report_self';
  END IF;

  -- 이미 신고한 유저인지 확인
  IF EXISTS (
    SELECT 1 FROM reports
    WHERE reporter_id = v_reporter_id AND reported_user_id = p_reported_user_id
  ) THEN
    RETURN jsonb_build_object('already_reported', true, 'auto_suspended', false);
  END IF;

  -- 신고 등록
  INSERT INTO reports (reporter_id, reported_user_id, reported_goods_id, reason, description)
  VALUES (v_reporter_id, p_reported_user_id, p_reported_goods_id, p_reason, p_description);

  -- 자동 차단 (upsert - 이미 차단한 경우 무시)
  INSERT INTO blocks (blocker_id, blocked_id)
  VALUES (v_reporter_id, p_reported_user_id)
  ON CONFLICT (blocker_id, blocked_id) DO NOTHING;

  -- 누적 신고 수 확인 (서로 다른 신고자)
  SELECT COUNT(DISTINCT reporter_id) INTO v_report_count
  FROM reports
  WHERE reported_user_id = p_reported_user_id;

  -- 3명 이상 신고 시 자동 정지
  IF v_report_count >= 3 THEN
    UPDATE profiles
    SET is_suspended = true, is_public = false
    WHERE id = p_reported_user_id AND is_suspended = false;

    v_auto_suspended = true;
  END IF;

  RETURN jsonb_build_object('already_reported', false, 'auto_suspended', v_auto_suspended);
END;
$$ LANGUAGE plpgsql;

-- 4. 중복 신고 사전 확인 RPC
CREATE OR REPLACE FUNCTION check_report_exists(p_reported_user_id UUID)
RETURNS BOOLEAN
SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS(
    SELECT 1 FROM reports
    WHERE reporter_id = auth.uid() AND reported_user_id = p_reported_user_id
  );
$$ LANGUAGE sql;

-- 5. 정지된 유저를 피드에서 숨기기 위한 RLS 업데이트
-- profiles
DROP POLICY IF EXISTS "Users can view public profiles (excluding blocked)" ON profiles;
CREATE POLICY "Users can view profiles (excluding blocked/suspended)"
  ON profiles FOR SELECT
  USING (
    id = auth.uid()
    OR (
      is_public = true
      AND (is_suspended = false OR is_suspended IS NULL)
      AND NOT EXISTS (
        SELECT 1 FROM blocks
        WHERE (blocker_id = auth.uid() AND blocked_id = profiles.id)
           OR (blocker_id = profiles.id AND blocked_id = auth.uid())
      )
    )
  );

-- goods
DROP POLICY IF EXISTS "Users can view public goods (excluding blocked)" ON goods;
CREATE POLICY "Users can view public goods (excluding blocked/suspended)"
  ON goods FOR SELECT
  USING (
    (
      visibility = 'public'
      OR user_id = auth.uid()
      OR (
        visibility = 'friends'
        AND EXISTS (
          SELECT 1 FROM friendships
          WHERE status = 'accepted'
          AND (
            (requester_id = auth.uid() AND receiver_id = goods.user_id)
            OR (receiver_id = auth.uid() AND requester_id = goods.user_id)
          )
        )
      )
    )
    AND NOT EXISTS (
      SELECT 1 FROM blocks
      WHERE (blocker_id = auth.uid() AND blocked_id = goods.user_id)
         OR (blocker_id = goods.user_id AND blocked_id = auth.uid())
    )
    AND NOT EXISTS (
      SELECT 1 FROM profiles WHERE id = goods.user_id AND is_suspended = true
    )
  );

-- catalogs
DROP POLICY IF EXISTS "Users can view public catalogs (excluding blocked)" ON catalogs;
CREATE POLICY "Users can view public catalogs (excluding blocked/suspended)"
  ON catalogs FOR SELECT
  USING (
    (
      visibility = 'public'
      OR user_id = auth.uid()
      OR (
        visibility = 'friends'
        AND EXISTS (
          SELECT 1 FROM friendships
          WHERE status = 'accepted'
          AND (
            (requester_id = auth.uid() AND receiver_id = catalogs.user_id)
            OR (receiver_id = auth.uid() AND requester_id = catalogs.user_id)
          )
        )
      )
    )
    AND NOT EXISTS (
      SELECT 1 FROM blocks
      WHERE (blocker_id = auth.uid() AND blocked_id = catalogs.user_id)
         OR (blocker_id = catalogs.user_id AND blocked_id = auth.uid())
    )
    AND NOT EXISTS (
      SELECT 1 FROM profiles WHERE id = catalogs.user_id AND is_suspended = true
    )
  );

-- 6. 관리자용 RPC 함수들
CREATE OR REPLACE FUNCTION admin_get_reports(p_status TEXT DEFAULT 'pending')
RETURNS TABLE(
  report_id UUID,
  reporter_nickname TEXT,
  reported_nickname TEXT,
  reported_user_id UUID,
  reported_goods_id UUID,
  reason TEXT,
  description TEXT,
  status TEXT,
  created_at TIMESTAMPTZ
)
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    r.id AS report_id,
    rp.nickname AS reporter_nickname,
    tp.nickname AS reported_nickname,
    r.reported_user_id,
    r.reported_goods_id,
    r.reason,
    r.description,
    r.status,
    r.created_at
  FROM reports r
  LEFT JOIN profiles rp ON rp.id = r.reporter_id
  LEFT JOIN profiles tp ON tp.id = r.reported_user_id
  WHERE r.status = p_status
  ORDER BY r.created_at DESC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION admin_get_suspended_users()
RETURNS TABLE(
  user_id UUID,
  nickname TEXT,
  avatar_url TEXT,
  report_count BIGINT,
  suspended_since TIMESTAMPTZ
)
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id AS user_id,
    p.nickname,
    p.avatar_url,
    (SELECT COUNT(DISTINCT reporter_id) FROM reports WHERE reported_user_id = p.id) AS report_count,
    (SELECT MIN(r2.created_at) FROM reports r2 WHERE r2.reported_user_id = p.id) AS suspended_since
  FROM profiles p
  WHERE p.is_suspended = true
  ORDER BY p.nickname;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION admin_dismiss_report(p_report_id UUID)
RETURNS VOID
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  UPDATE reports SET status = 'dismissed' WHERE id = p_report_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION admin_unsuspend_user(p_user_id UUID)
RETURNS VOID
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  UPDATE profiles SET is_suspended = false WHERE id = p_user_id;
  -- 해당 유저 관련 신고를 resolved로 전환
  UPDATE reports SET status = 'resolved' WHERE reported_user_id = p_user_id AND status = 'pending';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION admin_suspend_user(p_user_id UUID)
RETURNS VOID
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  UPDATE profiles SET is_suspended = true, is_public = false WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql;
