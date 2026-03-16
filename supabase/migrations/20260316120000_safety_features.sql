-- ============================================
-- 안전 기능: 차단, 신고, 연령 확인, 공식 배지
-- ============================================

-- 1. profiles 테이블 확장
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS birth_year INTEGER;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT false;

-- 2. 유저 차단
CREATE TABLE IF NOT EXISTS blocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  blocked_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(blocker_id, blocked_id)
);

CREATE INDEX IF NOT EXISTS idx_blocks_blocker ON blocks(blocker_id);
CREATE INDEX IF NOT EXISTS idx_blocks_blocked ON blocks(blocked_id);

ALTER TABLE blocks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own blocks"
  ON blocks FOR ALL
  USING (blocker_id = auth.uid());

CREATE POLICY "Users can see if they are blocked"
  ON blocks FOR SELECT
  USING (blocked_id = auth.uid());

-- 3. 신고
CREATE TABLE IF NOT EXISTS reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  reported_user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  reported_goods_id UUID REFERENCES goods(id) ON DELETE SET NULL,
  reason TEXT NOT NULL,          -- inappropriate, spam, harassment, impersonation, other
  description TEXT,              -- 상세 설명 (선택)
  status TEXT DEFAULT 'pending', -- pending, reviewed, resolved, dismissed
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reports_reporter ON reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_reports_status ON reports(status);

ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can create reports"
  ON reports FOR INSERT
  WITH CHECK (reporter_id = auth.uid());

CREATE POLICY "Users can view own reports"
  ON reports FOR SELECT
  USING (reporter_id = auth.uid());

-- 4. 차단된 유저를 피드/프로필에서 숨기기 위한 RLS 업데이트
-- 기존 프로필 조회 정책 대체: 차단한/된 유저 제외
DROP POLICY IF EXISTS "Users can view public profiles" ON profiles;
CREATE POLICY "Users can view public profiles (excluding blocked)"
  ON profiles FOR SELECT
  USING (
    (is_public = true OR id = auth.uid())
    AND NOT EXISTS (
      SELECT 1 FROM blocks
      WHERE (blocker_id = auth.uid() AND blocked_id = profiles.id)
         OR (blocker_id = profiles.id AND blocked_id = auth.uid())
    )
  );

-- 기존 굿즈 공개 조회 정책 대체: 차단한/된 유저 굿즈 제외
DROP POLICY IF EXISTS "Users can view public goods" ON goods;
CREATE POLICY "Users can view public goods (excluding blocked)"
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
  );

-- 기존 도감 공개 조회 정책 대체: 차단한/된 유저 도감 제외
DROP POLICY IF EXISTS "Users can view public catalogs" ON catalogs;
CREATE POLICY "Users can view public catalogs (excluding blocked)"
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
  );
