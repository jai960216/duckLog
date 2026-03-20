import { getServiceClient } from "../_shared/supabase-client.ts";

const ADMIN_SECRET = Deno.env.get("ADMIN_SECRET");
if (!ADMIN_SECRET) {
  throw new Error("ADMIN_SECRET environment variable is not set");
}

// Rate limiter: IP별 1분에 30회 제한
const rateLimitMap = new Map<string, { count: number; resetAt: number }>();
const RATE_LIMIT = 30;
const RATE_WINDOW_MS = 60_000;

function checkRateLimit(ip: string): boolean {
  const now = Date.now();
  const entry = rateLimitMap.get(ip);
  if (!entry || now > entry.resetAt) {
    rateLimitMap.set(ip, { count: 1, resetAt: now + RATE_WINDOW_MS });
    return true;
  }
  entry.count++;
  return entry.count <= RATE_LIMIT;
}

// 오래된 항목 정리 (5분마다)
setInterval(() => {
  const now = Date.now();
  for (const [ip, entry] of rateLimitMap) {
    if (now > entry.resetAt) rateLimitMap.delete(ip);
  }
}, 300_000);

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "https://jai960216.github.io",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "x-admin-secret, content-type",
};

function unauthorized() {
  return new Response("Unauthorized", { status: 401, headers: CORS_HEADERS });
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

Deno.serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  const url = new URL(req.url);
  const ip = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim()
    || req.headers.get("cf-connecting-ip")
    || "unknown";

  if (!checkRateLimit(ip)) {
    return new Response(JSON.stringify({ error: "Too many requests" }), {
      status: 429,
      headers: { "Content-Type": "application/json", "Retry-After": "60", ...CORS_HEADERS },
    });
  }

  const secret = req.headers.get("x-admin-secret");

  if (secret !== ADMIN_SECRET) return unauthorized();

  const action = url.searchParams.get("action") || "reports";
  const client = getServiceClient();

  if (action === "reports") {
    const status = url.searchParams.get("status") || "pending";
    const { data, error } = await client.rpc("admin_get_reports", { p_status: status });
    if (error) return json({ error: error.message }, 500);
    return json(data);
  }

  if (action === "suspended") {
    const { data, error } = await client.rpc("admin_get_suspended_users");
    if (error) return json({ error: error.message }, 500);
    return json(data);
  }

  if (req.method === "POST" && action === "dismiss") {
    const reportId = url.searchParams.get("report_id");
    if (!reportId) return json({ error: "report_id required" }, 400);
    const { error } = await client.rpc("admin_dismiss_report", { p_report_id: reportId });
    if (error) return json({ error: error.message }, 500);
    return json({ ok: true });
  }

  if (req.method === "POST" && action === "unsuspend") {
    const userId = url.searchParams.get("user_id");
    if (!userId) return json({ error: "user_id required" }, 400);
    const { error } = await client.rpc("admin_unsuspend_user", { p_user_id: userId });
    if (error) return json({ error: error.message }, 500);
    return json({ ok: true });
  }

  if (req.method === "POST" && action === "suspend") {
    const userId = url.searchParams.get("user_id");
    if (!userId) return json({ error: "user_id required" }, 400);
    const { error } = await client.rpc("admin_suspend_user", { p_user_id: userId });
    if (error) return json({ error: error.message }, 500);
    return json({ ok: true });
  }

  // 유저 검색
  if (action === "search_users") {
    const query = url.searchParams.get("query") || "";
    if (!query.trim()) return json([]);
    const { data, error } = await client
      .from("profiles")
      .select("id, nickname, avatar_url, is_verified, is_suspended")
      .or(`nickname.ilike.%${query}%,friend_code.eq.${query}`)
      .limit(20);
    if (error) return json({ error: error.message }, 500);
    return json(data);
  }

  // 공식 배지 토글
  if (req.method === "POST" && action === "set_verified") {
    const userId = url.searchParams.get("user_id");
    const verified = url.searchParams.get("verified") === "true";
    if (!userId) return json({ error: "user_id required" }, 400);
    const { error } = await client
      .from("profiles")
      .update({ is_verified: verified })
      .eq("id", userId);
    if (error) return json({ error: error.message }, 500);
    return json({ ok: true });
  }

  // 구독 목록
  if (action === "subscriptions") {
    const { data, error } = await client
      .from("subscriptions")
      .select("*, profiles!inner(nickname)")
      .order("created_at", { ascending: false })
      .limit(50);
    if (error) return json({ error: error.message }, 500);
    return json(data);
  }

  // 구독 부여/해제
  if (req.method === "POST" && action === "set_subscription") {
    const userId = url.searchParams.get("user_id");
    const plan = url.searchParams.get("plan"); // "pro" or "free"
    if (!userId) return json({ error: "user_id required" }, 400);

    if (plan === "pro") {
      const endDate = new Date();
      endDate.setFullYear(endDate.getFullYear() + 1);
      const { error } = await client
        .from("subscriptions")
        .upsert({
          user_id: userId,
          plan: "pro",
          status: "active",
          source: "admin",
          current_period_start: new Date().toISOString(),
          current_period_end: endDate.toISOString(),
        }, { onConflict: "user_id" });
      if (error) return json({ error: error.message }, 500);
    } else {
      const { error } = await client
        .from("subscriptions")
        .delete()
        .eq("user_id", userId);
      if (error) return json({ error: error.message }, 500);
    }
    return json({ ok: true });
  }

  return json({ error: "unknown action" }, 400);
});
