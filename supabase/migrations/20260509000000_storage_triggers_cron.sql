-- migrations에 없는 함수 3개 복원

-- 1) decrement_photo_usage (월간 사진 사용량 차감)
CREATE OR REPLACE FUNCTION public.decrement_photo_usage(count integer DEFAULT 1)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  UPDATE monthly_usage
  SET photo_count = GREATEST(photo_count - count, 0),
      updated_at = now()
  WHERE user_id = auth.uid()
    AND month = date_trunc('month', now())::date;
END;
$function$;

-- 2) notify_friend_request (friendships INSERT 시 Edge Function 호출)
-- ⚠️ 중요: 새 프로젝트의 SUPABASE_URL로 교체 필요
CREATE OR REPLACE FUNCTION public.notify_friend_request()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  payload jsonb;
BEGIN
  IF NEW.status != 'pending' THEN
    RETURN NEW;
  END IF;

  payload := jsonb_build_object(
    'type', 'INSERT',
    'table', 'friendships',
    'record', jsonb_build_object(
      'id', NEW.id,
      'requester_id', NEW.requester_id,
      'receiver_id', NEW.receiver_id,
      'status', NEW.status
    )
  );

  BEGIN
    PERFORM net.http_post(
      url := 'https://tmndjqefsnccllbgczxv.supabase.co/functions/v1/notify-friend-request',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('supabase.service_role_key')
      ),
      body := payload
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'notify_friend_request failed: %', SQLERRM;
  END;

  RETURN NEW;
END;
$function$;

-- 3) notify_like (likes INSERT 시 Edge Function 호출)
-- ⚠️ 중요: 새 프로젝트의 SUPABASE_URL로 교체 필요
CREATE OR REPLACE FUNCTION public.notify_like()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  payload jsonb;
BEGIN
  payload := jsonb_build_object(
    'type', 'INSERT',
    'table', 'likes',
    'record', jsonb_build_object(
      'id', NEW.id,
      'user_id', NEW.user_id,
      'goods_id', NEW.goods_id
    )
  );

  BEGIN
    PERFORM net.http_post(
      url := 'https://tmndjqefsnccllbgczxv.supabase.co/functions/v1/notify-like',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('supabase.service_role_key')
      ),
      body := payload
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'notify_like failed: %', SQLERRM;
  END;

  RETURN NEW;
END;
$function$;
-- 트리거 복원
-- ⚠️ 기존 DB에는 같은 일을 하는 트리거가 2개씩 걸려있어 중복 알림 발송 중.
-- 새 프로젝트에선 PG function 방식만 만들고 Webhook 방식은 만들지 말 것.

-- friendships INSERT → notify_friend_request 함수
DROP TRIGGER IF EXISTS on_friend_request_insert ON public.friendships;
CREATE TRIGGER on_friend_request_insert
AFTER INSERT ON public.friendships
FOR EACH ROW
EXECUTE FUNCTION notify_friend_request();

-- likes INSERT → notify_like 함수
DROP TRIGGER IF EXISTS on_like_insert ON public.likes;
CREATE TRIGGER on_like_insert
AFTER INSERT ON public.likes
FOR EACH ROW
EXECUTE FUNCTION notify_like();

-- 만들지 말 것 (참고):
-- "notify-friend-request" 트리거 (Dashboard Webhook UI로 만들어졌던 것 — 중복)
-- "notify-like" 트리거 (Dashboard Webhook UI로 만들어졌던 것 — 중복)
-- Storage 버킷 4개 생성
-- 대시보드 Storage UI에서 만들어도 되지만 SQL이 더 빠름

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('avatars', 'avatars', true, NULL, NULL),
  ('catalog-photos', 'catalog-photos', true, NULL, NULL),
  ('goods-photos', 'goods-photos', true, NULL, NULL),
  ('receipt-photos', 'receipt-photos', false, NULL, NULL)
ON CONFLICT (id) DO NOTHING;
-- Storage RLS 정책 16개
-- migrations 20260412010000_rls_audit_fixes.sql에 일부(UPDATE/DELETE)만 있어 전체 재생성

-- avatars
DROP POLICY IF EXISTS "Anyone can view avatars" ON storage.objects;
CREATE POLICY "Anyone can view avatars" ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');
DROP POLICY IF EXISTS "Users can upload avatars" ON storage.objects;
CREATE POLICY "Users can upload avatars" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'avatars' AND (auth.uid())::text = (storage.foldername(name))[1]);
DROP POLICY IF EXISTS "Users can update own avatars" ON storage.objects;
CREATE POLICY "Users can update own avatars" ON storage.objects FOR UPDATE
  USING (bucket_id = 'avatars' AND (auth.uid())::text = (storage.foldername(name))[1]);
DROP POLICY IF EXISTS "Users can delete own avatars" ON storage.objects;
CREATE POLICY "Users can delete own avatars" ON storage.objects FOR DELETE
  USING (bucket_id = 'avatars' AND (auth.uid())::text = (storage.foldername(name))[1]);

-- catalog-photos
DROP POLICY IF EXISTS "Anyone can view catalog photos" ON storage.objects;
CREATE POLICY "Anyone can view catalog photos" ON storage.objects FOR SELECT
  USING (bucket_id = 'catalog-photos');
DROP POLICY IF EXISTS "Users can upload catalog photos" ON storage.objects;
CREATE POLICY "Users can upload catalog photos" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'catalog-photos' AND (auth.uid())::text = (storage.foldername(name))[1]);
DROP POLICY IF EXISTS "Users can update own catalog photos" ON storage.objects;
CREATE POLICY "Users can update own catalog photos" ON storage.objects FOR UPDATE
  USING (bucket_id = 'catalog-photos' AND (auth.uid())::text = (storage.foldername(name))[1]);
DROP POLICY IF EXISTS "Users can delete own catalog photos" ON storage.objects;
CREATE POLICY "Users can delete own catalog photos" ON storage.objects FOR DELETE
  USING (bucket_id = 'catalog-photos' AND (auth.uid())::text = (storage.foldername(name))[1]);

-- goods-photos
DROP POLICY IF EXISTS "Anyone can view goods photos" ON storage.objects;
CREATE POLICY "Anyone can view goods photos" ON storage.objects FOR SELECT
  USING (bucket_id = 'goods-photos');
DROP POLICY IF EXISTS "Users can upload goods photos" ON storage.objects;
CREATE POLICY "Users can upload goods photos" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'goods-photos' AND (auth.uid())::text = (storage.foldername(name))[1]);
DROP POLICY IF EXISTS "Users can update own goods photos" ON storage.objects;
CREATE POLICY "Users can update own goods photos" ON storage.objects FOR UPDATE
  USING (bucket_id = 'goods-photos' AND (auth.uid())::text = (storage.foldername(name))[1]);
DROP POLICY IF EXISTS "Users can delete own goods photos" ON storage.objects;
CREATE POLICY "Users can delete own goods photos" ON storage.objects FOR DELETE
  USING (bucket_id = 'goods-photos' AND (auth.uid())::text = (storage.foldername(name))[1]);

-- receipt-photos (private)
DROP POLICY IF EXISTS "Users can view own receipt photos" ON storage.objects;
CREATE POLICY "Users can view own receipt photos" ON storage.objects FOR SELECT
  USING (bucket_id = 'receipt-photos' AND (auth.uid())::text = (storage.foldername(name))[1]);
DROP POLICY IF EXISTS "Users can upload receipt photos" ON storage.objects;
CREATE POLICY "Users can upload receipt photos" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'receipt-photos' AND (auth.uid())::text = (storage.foldername(name))[1]);
DROP POLICY IF EXISTS "Users can update own receipt photos" ON storage.objects;
CREATE POLICY "Users can update own receipt photos" ON storage.objects FOR UPDATE
  USING (bucket_id = 'receipt-photos' AND (auth.uid())::text = (storage.foldername(name))[1]);
DROP POLICY IF EXISTS "Users can delete own receipt photos" ON storage.objects;
CREATE POLICY "Users can delete own receipt photos" ON storage.objects FOR DELETE
  USING (bucket_id = 'receipt-photos' AND (auth.uid())::text = (storage.foldername(name))[1]);
-- 크론잡 3개 복원
-- ⚠️ tmndjqefsnccllbgczxv를 새 프로젝트 ref로, JWT는 새 service_role_key로 교체 필요
-- ⚠️ pg_cron 확장이 먼저 활성화되어있어야 함 (01_extensions.sql)

-- 기존 같은 이름의 크론잡 제거 (idempotent)
DO $$ BEGIN
  PERFORM cron.unschedule(jobname) FROM cron.job WHERE jobname IN ('notify-calendar-daily','update-naver','update-kakao');
END $$;

-- 1) 일일 캘린더 알림 (매일 12:00 UTC = KST 21:00)
SELECT cron.schedule(
  'notify-calendar-daily',
  '0 12 * * *',
  $$
  SELECT net.http_post(
    url := 'https://tmndjqefsnccllbgczxv.supabase.co/functions/v1/notify-calendar',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('supabase.service_role_key')
    ),
    body := '{}'::jsonb
  );
  $$
);

-- 2) 네이버 웹툰 갱신 (6시간마다)
SELECT cron.schedule(
  'update-naver',
  '0 */6 * * *',
  $$
  SELECT net.http_post(
    url := 'https://tmndjqefsnccllbgczxv.supabase.co/functions/v1/update-webtoons-naver',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('supabase.service_role_key')
    )
  );
  $$
);

-- 3) 카카오 웹툰 갱신 (6시간 5분마다)
SELECT cron.schedule(
  'update-kakao',
  '5 */6 * * *',
  $$
  SELECT net.http_post(
    url := 'https://tmndjqefsnccllbgczxv.supabase.co/functions/v1/update-webtoons-kakao',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('supabase.service_role_key')
    )
  );
  $$
);

-- 검증: 등록 확인
-- SELECT jobid, jobname, schedule, active FROM cron.job;
