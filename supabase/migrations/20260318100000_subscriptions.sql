-- ============================================
-- Pro 구독 시스템: 구독 테이블 + 월별 사용량 추적
-- ============================================

-- 1. 구독 테이블 (schema.sql에서 이미 생성됨 — idempotent)
CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
  plan TEXT NOT NULL DEFAULT 'free',
  status TEXT NOT NULL DEFAULT 'active',
  provider TEXT,
  provider_subscription_id TEXT,
  current_period_start TIMESTAMPTZ,
  current_period_end TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- RLS for subscriptions
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own subscription" ON subscriptions;
CREATE POLICY "Users can view own subscription"
  ON subscriptions FOR SELECT
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Deny client insert on subscriptions" ON subscriptions;
CREATE POLICY "Deny client insert on subscriptions"
  ON subscriptions FOR INSERT
  WITH CHECK (false);

DROP POLICY IF EXISTS "Deny client update on subscriptions" ON subscriptions;
CREATE POLICY "Deny client update on subscriptions"
  ON subscriptions FOR UPDATE
  USING (false);

DROP POLICY IF EXISTS "Users can delete own subscription" ON subscriptions;
CREATE POLICY "Users can delete own subscription"
  ON subscriptions FOR DELETE
  USING (auth.uid() = user_id);

-- 2. 월별 사용량 추적
CREATE TABLE IF NOT EXISTS monthly_usage (
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  year_month TEXT NOT NULL,
  photo_count INT DEFAULT 0,
  UNIQUE(user_id, year_month)
);

ALTER TABLE monthly_usage ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own usage"
  ON monthly_usage FOR SELECT
  USING (user_id = auth.uid());

-- monthly_usage는 increment_photo_usage() RPC (SECURITY DEFINER)로만 쓰기 가능
-- 클라이언트 직접 INSERT/UPDATE 차단

-- 3. 사진 업로드 카운트 증가 RPC
CREATE OR REPLACE FUNCTION increment_photo_usage()
RETURNS INT
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_year_month TEXT := to_char(now(), 'YYYY-MM');
  v_count INT;
BEGIN
  INSERT INTO monthly_usage (user_id, year_month, photo_count)
  VALUES (v_user_id, v_year_month, 1)
  ON CONFLICT (user_id, year_month)
  DO UPDATE SET photo_count = monthly_usage.photo_count + 1
  RETURNING photo_count INTO v_count;

  RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- 4. Pro 여부 확인 RPC
CREATE OR REPLACE FUNCTION is_user_pro(p_user_id UUID)
RETURNS BOOLEAN
SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS(
    SELECT 1 FROM subscriptions
    WHERE user_id = p_user_id
      AND plan IN ('pro', 'pro_monthly', 'pro_yearly')
      AND status = 'active'
      AND (current_period_end IS NULL OR current_period_end > now())
  );
$$ LANGUAGE sql;

-- 5. 현재 월 사진 사용량 조회 RPC
CREATE OR REPLACE FUNCTION get_photo_usage()
RETURNS INT
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_count INT;
BEGIN
  SELECT COALESCE(photo_count, 0) INTO v_count
  FROM monthly_usage
  WHERE user_id = auth.uid()
    AND year_month = to_char(now(), 'YYYY-MM');

  IF v_count IS NULL THEN
    v_count := 0;
  END IF;

  RETURN v_count;
END;
$$ LANGUAGE plpgsql;
