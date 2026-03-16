import { getServiceClient } from "../_shared/supabase-client.ts";

const ADMIN_SECRET = Deno.env.get("ADMIN_SECRET") || "changeme";

function unauthorized() {
  return new Response("Unauthorized", { status: 401 });
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const secret = url.searchParams.get("secret") || req.headers.get("x-admin-secret");

  if (secret !== ADMIN_SECRET) return unauthorized();

  const action = url.searchParams.get("action") || "page";
  const client = getServiceClient();

  // API endpoints
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

  // HTML page
  return new Response(HTML.replace("__SECRET__", secret || ""), {
    headers: { "Content-Type": "text/html; charset=utf-8" },
  });
});

const HTML = `<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>DuckLog Admin</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f5f5f5; color: #333; }
  .header { background: #FFC843; padding: 16px 24px; display: flex; align-items: center; gap: 12px; }
  .header h1 { font-size: 20px; font-weight: 700; }
  .tabs { display: flex; gap: 8px; padding: 16px 24px 0; }
  .tab { padding: 10px 20px; border: none; background: #ddd; border-radius: 8px 8px 0 0; cursor: pointer; font-size: 14px; font-weight: 600; }
  .tab.active { background: #fff; }
  .content { background: #fff; margin: 0 24px; border-radius: 0 8px 8px 8px; padding: 20px; min-height: 400px; }
  table { width: 100%; border-collapse: collapse; font-size: 13px; }
  th, td { padding: 10px 12px; text-align: left; border-bottom: 1px solid #eee; }
  th { font-weight: 600; background: #fafafa; }
  .btn { padding: 6px 14px; border: none; border-radius: 6px; cursor: pointer; font-size: 12px; font-weight: 600; }
  .btn-danger { background: #ff4444; color: #fff; }
  .btn-success { background: #22c55e; color: #fff; }
  .btn-gray { background: #888; color: #fff; }
  .btn:hover { opacity: 0.85; }
  .badge { display: inline-block; padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 600; }
  .badge-pending { background: #fff3cd; color: #856404; }
  .empty { padding: 40px; text-align: center; color: #999; }
  .stats { display: flex; gap: 16px; margin-bottom: 20px; }
  .stat-card { background: #f9f9f9; padding: 16px; border-radius: 8px; flex: 1; text-align: center; }
  .stat-card .num { font-size: 28px; font-weight: 700; }
  .stat-card .label { font-size: 12px; color: #888; margin-top: 4px; }
</style>
</head>
<body>
<div class="header">
  <span style="font-size:28px">&#x1F425;</span>
  <h1>DuckLog Admin Dashboard</h1>
</div>

<div class="tabs">
  <button class="tab active" onclick="showTab('reports')" id="tab-reports"></button>
  <button class="tab" onclick="showTab('suspended')" id="tab-suspended"></button>
</div>

<div class="content" id="content"></div>

<script>
const SECRET = "__SECRET__";
const BASE = window.location.pathname;

// All Korean strings as JS (avoids encoding issues in Edge Function deployment)
const L = {
  tabReports: "\\uc2e0\\uace0 \\ubaa9\\ub85d",
  tabSuspended: "\\uc815\\uc9c0\\ub41c \\uc720\\uc800",
  loading: "\\ub85c\\ub529 \\uc911...",
  noReports: "\\ub300\\uae30 \\uc911\\uc778 \\uc2e0\\uace0\\uac00 \\uc5c6\\uc2b5\\ub2c8\\ub2e4.",
  noSuspended: "\\uc815\\uc9c0\\ub41c \\uc720\\uc800\\uac00 \\uc5c6\\uc2b5\\ub2c8\\ub2e4.",
  pendingCount: "\\ub300\\uae30 \\uc911 \\uc2e0\\uace0",
  thReporter: "\\uc2e0\\uace0\\uc790",
  thTarget: "\\ub300\\uc0c1",
  thReason: "\\uc0ac\\uc720",
  thDesc: "\\uc124\\uba85",
  thDate: "\\ub0a0\\uc9dc",
  thAction: "\\uc870\\uce58",
  thNickname: "\\ub2c9\\ub124\\uc784",
  thReportCount: "\\uc2e0\\uace0 \\uc218",
  thSuspendedSince: "\\uc815\\uc9c0 \\uc2dc\\uc810",
  btnDismiss: "\\uae30\\uac01",
  btnSuspend: "\\uc815\\uc9c0",
  btnUnsuspend: "\\uc815\\uc9c0 \\ud574\\uc81c",
  confirmDismiss: "\\uc774 \\uc2e0\\uace0\\ub97c \\uae30\\uac01\\ud558\\uc2dc\\uaca0\\uc2b5\\ub2c8\\uae4c?",
  confirmSuspend: "\\uc774 \\uc720\\uc800\\ub97c \\uc815\\uc9c0\\ud558\\uc2dc\\uaca0\\uc2b5\\ub2c8\\uae4c?",
  confirmUnsuspend: "\\uc774 \\uc720\\uc800\\uc758 \\uc815\\uc9c0\\ub97c \\ud574\\uc81c\\ud558\\uc2dc\\uaca0\\uc2b5\\ub2c8\\uae4c?",
  reasonInappropriate: "\\ubd80\\uc801\\uc808\\ud55c \\ucf58\\ud150\\uce20",
  reasonSpam: "\\uc2a4\\ud338/\\uad11\\uace0",
  reasonHarassment: "\\uad34\\ub86d\\ud798/\\uc695\\uc124",
  reasonImpersonation: "\\uc0ac\\uce6d",
  reasonOther: "\\uae30\\ud0c0",
  unitCount: "\\uac74"
};

// Init tab labels
document.getElementById('tab-reports').textContent = L.tabReports;
document.getElementById('tab-suspended').textContent = L.tabSuspended;

const REASON_MAP = {
  inappropriate: L.reasonInappropriate,
  spam: L.reasonSpam,
  harassment: L.reasonHarassment,
  impersonation: L.reasonImpersonation,
  other: L.reasonOther
};

async function api(action, params = {}) {
  const qs = new URLSearchParams({ secret: SECRET, action, ...params });
  const method = ['dismiss','unsuspend','suspend'].includes(action) ? 'POST' : 'GET';
  const res = await fetch(BASE + '?' + qs, { method });
  return res.json();
}

let currentTab = 'reports';

function showTab(tab) {
  currentTab = tab;
  document.querySelectorAll('.tab').forEach((t, i) => {
    t.classList.toggle('active', (i === 0 && tab === 'reports') || (i === 1 && tab === 'suspended'));
  });
  if (tab === 'reports') loadReports();
  else loadSuspended();
}

async function loadReports() {
  const el = document.getElementById('content');
  el.innerHTML = '<div class="empty">' + L.loading + '</div>';

  const data = await api('reports', { status: 'pending' });

  if (!data.length) {
    el.innerHTML = '<div class="empty">' + L.noReports + '</div>';
    return;
  }

  el.innerHTML = '<div class="stats">'
    + '<div class="stat-card"><div class="num">' + data.length + '</div><div class="label">' + L.pendingCount + '</div></div>'
    + '</div>'
    + '<table><thead><tr>'
    + '<th>' + L.thReporter + '</th><th>' + L.thTarget + '</th><th>' + L.thReason + '</th><th>' + L.thDesc + '</th><th>' + L.thDate + '</th><th>' + L.thAction + '</th>'
    + '</tr></thead><tbody>'
    + data.map(r => '<tr>'
      + '<td>' + esc(r.reporter_nickname || '-') + '</td>'
      + '<td>' + esc(r.reported_nickname || '-') + '</td>'
      + '<td>' + (REASON_MAP[r.reason] || r.reason) + '</td>'
      + '<td>' + esc(r.description || '-') + '</td>'
      + '<td>' + new Date(r.created_at).toLocaleDateString('ko') + '</td>'
      + '<td>'
      + '<button class="btn btn-gray" onclick="dismiss(\\'' + r.report_id + '\\')">' + L.btnDismiss + '</button> '
      + '<button class="btn btn-danger" onclick="suspend(\\'' + r.reported_user_id + '\\')">' + L.btnSuspend + '</button>'
      + '</td>'
      + '</tr>').join('')
    + '</tbody></table>';
}

async function loadSuspended() {
  const el = document.getElementById('content');
  el.innerHTML = '<div class="empty">' + L.loading + '</div>';

  const data = await api('suspended');

  if (!data.length) {
    el.innerHTML = '<div class="empty">' + L.noSuspended + '</div>';
    return;
  }

  el.innerHTML = '<table><thead><tr>'
    + '<th>' + L.thNickname + '</th><th>' + L.thReportCount + '</th><th>' + L.thSuspendedSince + '</th><th>' + L.thAction + '</th>'
    + '</tr></thead><tbody>'
    + data.map(u => '<tr>'
      + '<td>' + esc(u.nickname || '-') + '</td>'
      + '<td>' + u.report_count + L.unitCount + '</td>'
      + '<td>' + (u.suspended_since ? new Date(u.suspended_since).toLocaleDateString('ko') : '-') + '</td>'
      + '<td><button class="btn btn-success" onclick="unsuspend(\\'' + u.user_id + '\\')">' + L.btnUnsuspend + '</button></td>'
      + '</tr>').join('')
    + '</tbody></table>';
}

async function dismiss(reportId) {
  if (!confirm(L.confirmDismiss)) return;
  await api('dismiss', { report_id: reportId });
  loadReports();
}

async function suspend(userId) {
  if (!confirm(L.confirmSuspend)) return;
  await api('suspend', { user_id: userId });
  loadReports();
}

async function unsuspend(userId) {
  if (!confirm(L.confirmUnsuspend)) return;
  await api('unsuspend', { user_id: userId });
  loadSuspended();
}

function esc(s) { const d = document.createElement('div'); d.textContent = s; return d.innerHTML; }

loadReports();
</script>
</body>
</html>`;
