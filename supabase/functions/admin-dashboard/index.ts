import { getServiceClient } from "../_shared/supabase-client.ts";

const ADMIN_SECRET = Deno.env.get("ADMIN_SECRET") || "changeme";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
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
  const secret = url.searchParams.get("secret") || req.headers.get("x-admin-secret");

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

  return json({ error: "unknown action" }, 400);
});
