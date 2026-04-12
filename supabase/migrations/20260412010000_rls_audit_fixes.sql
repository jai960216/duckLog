-- ============================================================
-- RLS audit fixes: subscription DELETE deny, calendar_events
-- SELECT restrict, catalog friends visibility, storage policies
-- ============================================================

-- 1. subscriptions: 클라이언트에서 DELETE 불가 (서버 전용)
ALTER POLICY "Users can delete own subscription" ON public.subscriptions
  USING (false);

-- 2. calendar_events: 커스텀 이벤트는 본인만 조회 가능
DROP POLICY IF EXISTS "Anyone can read calendar events" ON calendar_events;
CREATE POLICY "Anyone can read calendar events"
  ON calendar_events FOR SELECT
  USING (
    (external_id NOT LIKE 'custom_%')
    OR (external_id LIKE ('custom_' || auth.uid() || '_%'))
  );

-- 3. catalog_collections: friends visibility 추가
DROP POLICY IF EXISTS "Users can view collections in visible catalogs" ON catalog_collections;
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
              WHERE friendships.status = 'accepted'
                AND (
                  (friendships.requester_id = auth.uid() AND friendships.receiver_id = catalogs.user_id)
                  OR (friendships.receiver_id = auth.uid() AND friendships.requester_id = catalogs.user_id)
                )
            )
          )
        )
    )
  );

-- 4. catalog_items: friends visibility 추가
DROP POLICY IF EXISTS "Users can view items in visible catalogs" ON catalog_items;
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
              WHERE friendships.status = 'accepted'
                AND (
                  (friendships.requester_id = auth.uid() AND friendships.receiver_id = catalogs.user_id)
                  OR (friendships.receiver_id = auth.uid() AND friendships.requester_id = catalogs.user_id)
                )
            )
          )
        )
    )
  );

-- 5. Storage: avatars UPDATE/DELETE 정책 추가
CREATE POLICY "Users can update own avatars"
  ON storage.objects FOR UPDATE
  USING (bucket_id = 'avatars' AND (auth.uid())::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can delete own avatars"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'avatars' AND (auth.uid())::text = (storage.foldername(name))[1]);

-- 6. Storage: goods-photos UPDATE/DELETE 정책 추가
CREATE POLICY "Users can update own goods photos"
  ON storage.objects FOR UPDATE
  USING (bucket_id = 'goods-photos' AND (auth.uid())::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can delete own goods photos"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'goods-photos' AND (auth.uid())::text = (storage.foldername(name))[1]);

-- 7. Storage: receipt-photos UPDATE/DELETE 정책 ���가
CREATE POLICY "Users can update own receipt photos"
  ON storage.objects FOR UPDATE
  USING (bucket_id = 'receipt-photos' AND (auth.uid())::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can delete own receipt photos"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'receipt-photos' AND (auth.uid())::text = (storage.foldername(name))[1]);
