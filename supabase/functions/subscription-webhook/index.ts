import { getServiceClient } from "../_shared/supabase-client.ts";

// Google Play Real-time Developer Notifications (RTDN) webhook
// Cloud Pub/Sub → Push subscription → Edge Function

const WEBHOOK_SECRET = Deno.env.get("PLAY_WEBHOOK_SECRET");
if (!WEBHOOK_SECRET) {
  throw new Error("PLAY_WEBHOOK_SECRET environment variable is not set");
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  // Pub/Sub Push 엔드포인트 URL에 ?secret=... 쿼리 파라미터로 인증
  const url = new URL(req.url);
  const secret = url.searchParams.get("secret");
  if (secret !== WEBHOOK_SECRET) {
    return new Response("Unauthorized", { status: 401 });
  }

  try {
    const body = await req.json();

    // Pub/Sub Push 메시지 포맷: { message: { data: "base64...", ... }, subscription: "..." }
    let payload;
    if (body.message?.data) {
      payload = JSON.parse(atob(body.message.data));
    } else {
      payload = body;
    }
    const notification = payload.subscriptionNotification;

    if (!notification) {
      return new Response(JSON.stringify({ ok: true, skipped: true }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const client = getServiceClient();
    const purchaseToken = notification.purchaseToken;
    const subscriptionId = notification.subscriptionId; // ducklog_pro_monthly or ducklog_pro_yearly
    const notificationType = notification.notificationType;

    // notificationType:
    // 1 = RECOVERED, 2 = RENEWED, 3 = CANCELED,
    // 4 = PURCHASED, 5 = ON_HOLD, 6 = IN_GRACE_PERIOD,
    // 7 = RESTARTED, 12 = REVOKED, 13 = EXPIRED

    const plan = subscriptionId?.includes("yearly")
      ? "pro_yearly"
      : subscriptionId?.includes("monthly")
      ? "pro_monthly"
      : "free";

    // purchaseToken에서 user_id 찾기 (verify-purchase에서 저장한 매핑)
    const { data: subData } = await client
      .from("subscriptions")
      .select("user_id")
      .eq("provider_subscription_id", purchaseToken)
      .maybeSingle();

    if (!subData) {
      // 매핑이 없으면 무시 (verify-purchase에서 먼저 등록되어야 함)
      return new Response(JSON.stringify({ ok: true, skipped: true }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const userId = subData.user_id;

    switch (notificationType) {
      case 1: // RECOVERED
      case 2: // RENEWED
      case 4: // PURCHASED
      case 7: // RESTARTED
        await client
          .from("subscriptions")
          .update({
            plan,
            status: "active",
            updated_at: new Date().toISOString(),
          })
          .eq("user_id", userId);
        // 서포터 배지 부여
        await client
          .from("profiles")
          .update({ is_supporter: true })
          .eq("id", userId);
        break;

      case 3: // CANCELED — 기간 끝까지 Pro 유지, 배지도 유지
        await client
          .from("subscriptions")
          .update({
            status: "cancelled",
            updated_at: new Date().toISOString(),
          })
          .eq("user_id", userId);
        break;

      case 12: // REVOKED
      case 13: // EXPIRED
        await client
          .from("subscriptions")
          .update({
            status: "expired",
            plan: "free",
            updated_at: new Date().toISOString(),
          })
          .eq("user_id", userId);
        // 서포터 배지 해제
        await client
          .from("profiles")
          .update({ is_supporter: false })
          .eq("id", userId);
        break;

      case 5: // ON_HOLD
        await client
          .from("subscriptions")
          .update({
            status: "on_hold",
            updated_at: new Date().toISOString(),
          })
          .eq("user_id", userId);
        break;

      case 6: // IN_GRACE_PERIOD — Google이 결제 재시도 중, Pro 유지
        await client
          .from("subscriptions")
          .update({
            status: "active",
            updated_at: new Date().toISOString(),
          })
          .eq("user_id", userId);
        break;
    }

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: (e as Error).message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
