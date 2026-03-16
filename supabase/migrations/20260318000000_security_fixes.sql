-- ============================================
-- 보안 수정: RPC 접근제어 + 자동정지 강화
-- ============================================

-- 1. Admin RPC 함수들에서 anon/authenticated 호출 권한 제거
-- service_role (Edge Function)만 호출 가능하도록 제한
REVOKE EXECUTE ON FUNCTION admin_get_reports(TEXT) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION admin_get_suspended_users() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION admin_dismiss_report(UUID) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION admin_unsuspend_user(UUID) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION admin_suspend_user(UUID) FROM anon, authenticated;

-- 2. 자동정지 강화: 임계값 3→5, 7일 이상 된 계정만 카운트
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

  -- 누적 신고 수 확인 (서로 다른 신고자, 7일 이상 된 계정만)
  SELECT COUNT(DISTINCT r.reporter_id) INTO v_report_count
  FROM reports r
  JOIN profiles p ON p.id = r.reporter_id
  WHERE r.reported_user_id = p_reported_user_id
    AND p.created_at < now() - interval '7 days';

  -- 5명 이상 신고 시 자동 정지
  IF v_report_count >= 5 THEN
    UPDATE profiles
    SET is_suspended = true, is_public = false
    WHERE id = p_reported_user_id AND is_suspended = false;

    v_auto_suspended = true;
  END IF;

  RETURN jsonb_build_object('already_reported', false, 'auto_suspended', v_auto_suspended);
END;
$$ LANGUAGE plpgsql;
