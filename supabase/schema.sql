-- DuckLog Database Schema
-- Run this in Supabase SQL Editor

-- ============================================
-- TABLES
-- ============================================

-- 유저 프로필
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nickname TEXT NOT NULL,
  avatar_url TEXT,
  bio TEXT,
  sns_links JSONB DEFAULT '{}',
  is_public BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 굿즈 기록
CREATE TABLE IF NOT EXISTS goods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  price INTEGER,
  category TEXT,
  work_tag TEXT,
  artist_tag TEXT,
  photo_urls TEXT[] DEFAULT '{}',
  purchased_at DATE,
  memo TEXT,
  visibility TEXT DEFAULT 'public',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 영수증
CREATE TABLE IF NOT EXISTS receipts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  photo_url TEXT NOT NULL,
  extracted_data JSONB,
  total_amount INTEGER,
  store_name TEXT,
  purchased_at DATE,
  is_processed BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 팔로우 중인 작품
CREATE TABLE IF NOT EXISTS followed_works (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  work_type TEXT NOT NULL,
  external_id TEXT NOT NULL,
  title TEXT NOT NULL,
  cover_url TEXT,
  notify BOOLEAN DEFAULT true,
  UNIQUE(user_id, work_type, external_id)
);

-- 캘린더 이벤트 캐시
CREATE TABLE IF NOT EXISTS calendar_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_type TEXT NOT NULL,
  external_id TEXT NOT NULL,
  title TEXT NOT NULL,
  event_type TEXT NOT NULL,
  event_date DATE NOT NULL,
  episode_number INTEGER,
  synced_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(work_type, external_id, event_date, episode_number)
);

-- 좋아요
CREATE TABLE IF NOT EXISTS likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  goods_id UUID REFERENCES goods(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, goods_id)
);

-- 친구 관계
CREATE TABLE IF NOT EXISTS friendships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  receiver_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(requester_id, receiver_id)
);

-- ============================================
-- INDEXES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_goods_user_id ON goods(user_id);
CREATE INDEX IF NOT EXISTS idx_goods_purchased_at ON goods(purchased_at);
CREATE INDEX IF NOT EXISTS idx_goods_category ON goods(category);
CREATE INDEX IF NOT EXISTS idx_goods_work_tag ON goods(work_tag);
CREATE INDEX IF NOT EXISTS idx_receipts_user_id ON receipts(user_id);
CREATE INDEX IF NOT EXISTS idx_followed_works_user_id ON followed_works(user_id);
CREATE INDEX IF NOT EXISTS idx_calendar_events_date ON calendar_events(event_date);
CREATE INDEX IF NOT EXISTS idx_likes_goods_id ON likes(goods_id);
CREATE INDEX IF NOT EXISTS idx_friendships_requester ON friendships(requester_id);
CREATE INDEX IF NOT EXISTS idx_friendships_receiver ON friendships(receiver_id);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

-- Profiles
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view public profiles"
  ON profiles FOR SELECT
  USING (is_public = true OR id = auth.uid());

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (id = auth.uid());

CREATE POLICY "Users can insert own profile"
  ON profiles FOR INSERT
  WITH CHECK (id = auth.uid());

CREATE POLICY "Users can delete own profile"
  ON profiles FOR DELETE
  USING (id = auth.uid());

-- Goods
ALTER TABLE goods ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own goods"
  ON goods FOR ALL
  USING (user_id = auth.uid());

CREATE POLICY "Users can view public goods"
  ON goods FOR SELECT
  USING (
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
  );

-- Receipts
ALTER TABLE receipts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own receipts"
  ON receipts FOR ALL
  USING (user_id = auth.uid());

-- Followed Works
ALTER TABLE followed_works ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own followed works"
  ON followed_works FOR ALL
  USING (user_id = auth.uid());

-- Calendar Events (public read)
ALTER TABLE calendar_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read calendar events"
  ON calendar_events FOR SELECT
  USING (true);

-- Likes
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own likes"
  ON likes FOR ALL
  USING (user_id = auth.uid());

CREATE POLICY "Anyone can view likes"
  ON likes FOR SELECT
  USING (true);

-- Friendships
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own friendships"
  ON friendships FOR SELECT
  USING (requester_id = auth.uid() OR receiver_id = auth.uid());

CREATE POLICY "Users can create friendship requests"
  ON friendships FOR INSERT
  WITH CHECK (requester_id = auth.uid());

CREATE POLICY "Users can update friendships they received"
  ON friendships FOR UPDATE
  USING (receiver_id = auth.uid());

CREATE POLICY "Users can delete own friendship requests"
  ON friendships FOR DELETE
  USING (requester_id = auth.uid() OR receiver_id = auth.uid());

-- ============================================
-- STORAGE BUCKETS
-- ============================================

INSERT INTO storage.buckets (id, name, public)
VALUES
  ('goods-photos', 'goods-photos', true),
  ('receipt-photos', 'receipt-photos', false),
  ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies
CREATE POLICY "Users can upload goods photos"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'goods-photos'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Anyone can view goods photos"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'goods-photos');

CREATE POLICY "Users can upload receipt photos"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'receipt-photos'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can view own receipt photos"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'receipt-photos'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can upload avatars"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Anyone can view avatars"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

-- ============================================
-- FUNCTIONS
-- ============================================

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Don't auto-create; let the app handle onboarding
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
