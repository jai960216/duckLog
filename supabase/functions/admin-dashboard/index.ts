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
  <button class="tab active" onclick="showTab('reports')">신고 목록</button>
  <button class="tab" onclick="showTab('suspended')">정지된 유저</button>
</div>

<div class="content" id="content">
  <div class="empty">로딩 중...</div>
</div>

<script>
const SECRET = "__SECRET__";
const BASE = window.location.pathname;

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

const REASON_MAP = {
  inappropriate: '부적절한 콘텐츠',
  spam: '스팸/광고',
  harassment: '괴롭힘/욕설',
  impersonation: '사칭',
  other: '기타'
};

async function loadReports() {
  const data = await api('reports', { status: 'pending' });
  const el = document.getElementById('content');

  if (!data.length) {
    el.innerHTML = '<div class="empty">대기 중인 신고가 없습니다.</div>';
    return;
  }

  el.innerHTML = '<div class="stats">'
    + '<div class="stat-card"><div class="num">' + data.length + '</div><div class="label">대기 중 신고</div></div>'
    + '</div>'
    + '<table><thead><tr>'
    + '<th>신고자</th><th>대상</th><th>사유</th><th>설명</th><th>날짜</th><th>조치</th>'
    + '</tr></thead><tbody>'
    + data.map(r => '<tr>'
      + '<td>' + esc(r.reporter_nickname || '-') + '</td>'
      + '<td>' + esc(r.reported_nickname || '-') + '</td>'
      + '<td>' + (REASON_MAP[r.reason] || r.reason) + '</td>'
      + '<td>' + esc(r.description || '-') + '</td>'
      + '<td>' + new Date(r.created_at).toLocaleDateString('ko') + '</td>'
      + '<td>'
      + '<button class="btn btn-gray" onclick="dismiss(\'' + r.report_id + '\')">기각</button> '
      + '<button class="btn btn-danger" onclick="suspend(\'' + r.reported_user_id + '\')">정지</button>'
      + '</td>'
      + '</tr>').join('')
    + '</tbody></table>';
}

async function loadSuspended() {
  const data = await api('suspended');
  const el = document.getElementById('content');

  if (!data.length) {
    el.innerHTML = '<div class="empty">정지된 유저가 없습니다.</div>';
    return;
  }

  el.innerHTML = '<table><thead><tr>'
    + '<th>닉네임</th><th>신고 수</th><th>정지 시점</th><th>조치</th>'
    + '</tr></thead><tbody>'
    + data.map(u => '<tr>'
      + '<td>' + esc(u.nickname || '-') + '</td>'
      + '<td>' + u.report_count + '건</td>'
      + '<td>' + (u.suspended_since ? new Date(u.suspended_since).toLocaleDateString('ko') : '-') + '</td>'
      + '<td><button class="btn btn-success" onclick="unsuspend(\'' + u.user_id + '\')">정지 해제</button></td>'
      + '</tr>').join('')
    + '</tbody></table>';
}

async function dismiss(reportId) {
  if (!confirm('이 신고를 기각하시겠습니까?')) return;
  await api('dismiss', { report_id: reportId });
  loadReports();
}

async function suspend(userId) {
  if (!confirm('이 유저를 정지하시겠습니까?')) return;
  await api('suspend', { user_id: userId });
  loadReports();
}

async function unsuspend(userId) {
  if (!confirm('이 유저의 정지를 해제하시겠습니까?')) return;
  await api('unsuspend', { user_id: userId });
  loadSuspended();
}

function esc(s) { const d = document.createElement('div'); d.textContent = s; return d.innerHTML; }

loadReports();
</script>
</body>
</html>`;
