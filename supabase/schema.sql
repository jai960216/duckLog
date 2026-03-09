-- DuckLog Database Schema
-- Run this in Supabase SQL Editor

-- ============================================
-- TABLES
-- ============================================

-- 유저 프로필
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nickname TEXT NOT NULL,
  friend_code TEXT UNIQUE NOT NULL,  -- 6자리 영숫자 (예: "e1r8es")
  avatar_url TEXT,
  bio TEXT,
  sns_links JSONB DEFAULT '{}',
  is_public BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ※ 기존 DB 마이그레이션 시:
-- ALTER TABLE profiles ADD COLUMN friend_code TEXT UNIQUE;
-- UPDATE profiles SET friend_code = substr(md5(random()::text), 1, 6) WHERE friend_code IS NULL;
-- ALTER TABLE profiles ALTER COLUMN friend_code SET NOT NULL;
-- DROP INDEX IF EXISTS idx_profiles_nickname;

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
  catalog_item_id UUID REFERENCES catalog_items(id) ON DELETE SET NULL,
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
  category TEXT,
  purchase_channel TEXT,
  expense_type TEXT,
  memo TEXT,
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

-- 도감
CREATE TABLE IF NOT EXISTS catalogs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  category TEXT,
  work_tag TEXT,
  cover_url TEXT,
  cover_fit_y DOUBLE PRECISION DEFAULT 0.5,
  visibility TEXT DEFAULT 'private',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 도감 캐릭터
CREATE TABLE IF NOT EXISTS catalog_characters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  catalog_id UUID REFERENCES catalogs(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  photo_url TEXT,
  external_id TEXT,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 도감 아이템
CREATE TABLE IF NOT EXISTS catalog_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  catalog_id UUID REFERENCES catalogs(id) ON DELETE CASCADE,
  character_id UUID REFERENCES catalog_characters(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  description TEXT,
  photo_url TEXT,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 도감 수집 현황
CREATE TABLE IF NOT EXISTS catalog_collections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  catalog_id UUID REFERENCES catalogs(id) ON DELETE CASCADE,
  catalog_item_id UUID REFERENCES catalog_items(id) ON DELETE CASCADE,
  collected_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, catalog_item_id)
);

-- ============================================
-- INDEXES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_profiles_nickname ON profiles(nickname);
CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_friend_code ON profiles(friend_code);
CREATE INDEX IF NOT EXISTS idx_goods_user_id ON goods(user_id);
CREATE INDEX IF NOT EXISTS idx_goods_purchased_at ON goods(purchased_at);
CREATE INDEX IF NOT EXISTS idx_goods_category ON goods(category);
CREATE INDEX IF NOT EXISTS idx_goods_work_tag ON goods(work_tag);
CREATE INDEX IF NOT EXISTS idx_goods_catalog_item_id ON goods(catalog_item_id);
CREATE INDEX IF NOT EXISTS idx_receipts_user_id ON receipts(user_id);
CREATE INDEX IF NOT EXISTS idx_receipts_category ON receipts(category);
CREATE INDEX IF NOT EXISTS idx_receipts_purchase_channel ON receipts(purchase_channel);
CREATE INDEX IF NOT EXISTS idx_receipts_expense_type ON receipts(expense_type);
CREATE INDEX IF NOT EXISTS idx_followed_works_user_id ON followed_works(user_id);
CREATE INDEX IF NOT EXISTS idx_calendar_events_date ON calendar_events(event_date);
CREATE INDEX IF NOT EXISTS idx_likes_goods_id ON likes(goods_id);
CREATE INDEX IF NOT EXISTS idx_friendships_requester ON friendships(requester_id);
CREATE INDEX IF NOT EXISTS idx_friendships_receiver ON friendships(receiver_id);
CREATE INDEX IF NOT EXISTS idx_catalogs_user_id ON catalogs(user_id);
CREATE INDEX IF NOT EXISTS idx_catalogs_visibility ON catalogs(visibility);
CREATE INDEX IF NOT EXISTS idx_catalog_characters_catalog_id ON catalog_characters(catalog_id);
CREATE INDEX IF NOT EXISTS idx_catalog_items_catalog_id ON catalog_items(catalog_id);
CREATE INDEX IF NOT EXISTS idx_catalog_items_character_id ON catalog_items(character_id);
CREATE INDEX IF NOT EXISTS idx_catalog_collections_user_id ON catalog_collections(user_id);
CREATE INDEX IF NOT EXISTS idx_catalog_collections_catalog_id ON catalog_collections(catalog_id);

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

CREATE POLICY "Authenticated users can insert calendar events"
  ON calendar_events FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can update calendar events"
  ON calendar_events FOR UPDATE
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can delete calendar events"
  ON calendar_events FOR DELETE
  USING (auth.uid() IS NOT NULL);

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

-- Catalogs
ALTER TABLE catalogs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own catalogs"
  ON catalogs FOR ALL
  USING (user_id = auth.uid());

CREATE POLICY "Users can view public catalogs"
  ON catalogs FOR SELECT
  USING (
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
  );

-- Catalog Characters
ALTER TABLE catalog_characters ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage characters in own catalogs"
  ON catalog_characters FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM catalogs
      WHERE catalogs.id = catalog_characters.catalog_id
      AND catalogs.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can view characters in visible catalogs"
  ON catalog_characters FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM catalogs
      WHERE catalogs.id = catalog_characters.catalog_id
      AND (
        catalogs.visibility = 'public'
        OR catalogs.user_id = auth.uid()
        OR (
          catalogs.visibility = 'friends'
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
    )
  );

-- Catalog Items
ALTER TABLE catalog_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage items in own catalogs"
  ON catalog_items FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM catalogs
      WHERE catalogs.id = catalog_items.catalog_id
      AND catalogs.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can view items in visible catalogs"
  ON catalog_items FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM catalogs
      WHERE catalogs.id = catalog_items.catalog_id
      AND (
        catalogs.visibility = 'public'
        OR catalogs.user_id = auth.uid()
        OR (
          catalogs.visibility = 'friends'
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
    )
  );

-- Catalog Collections
ALTER TABLE catalog_collections ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own collections"
  ON catalog_collections FOR ALL
  USING (user_id = auth.uid());

CREATE POLICY "Users can view collections in visible catalogs"
  ON catalog_collections FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM catalogs
      WHERE catalogs.id = catalog_collections.catalog_id
      AND (
        catalogs.visibility = 'public'
        OR catalogs.user_id = auth.uid()
        OR (
          catalogs.visibility = 'friends'
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
    )
  );

-- ============================================
-- STORAGE BUCKETS
-- ============================================

INSERT INTO storage.buckets (id, name, public)
VALUES
  ('goods-photos', 'goods-photos', true),
  ('receipt-photos', 'receipt-photos', false),
  ('avatars', 'avatars', true),
  ('catalog-photos', 'catalog-photos', true)
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

CREATE POLICY "Users can upload catalog photos"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'catalog-photos'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Anyone can view catalog photos"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'catalog-photos');

CREATE POLICY "Users can update own catalog photos"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'catalog-photos'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can delete own catalog photos"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'catalog-photos'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

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
