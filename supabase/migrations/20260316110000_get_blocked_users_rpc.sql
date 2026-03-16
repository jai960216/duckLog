-- 차단 관리 화면용 RPC: RLS를 우회하여 차단한 유저의 프로필 정보를 조회
CREATE OR REPLACE FUNCTION get_blocked_users()
RETURNS TABLE(
  id UUID,
  blocked_id UUID,
  created_at TIMESTAMPTZ,
  nickname TEXT,
  avatar_url TEXT
)
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT b.id, b.blocked_id, b.created_at, p.nickname, p.avatar_url
  FROM blocks b
  LEFT JOIN profiles p ON p.id = b.blocked_id
  WHERE b.blocker_id = auth.uid()
  ORDER BY b.created_at DESC;
END;
$$ LANGUAGE plpgsql;
