import { getServiceClient } from "../_shared/supabase-client.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Google Play Android Developer API로 구독 영수증 검증
// 필요 환경변수: GOOGLE_SERVICE_ACCOUNT_JSON (Play Console 서비스 계정 키)

const SERVICE_ACCOUNT_JSON = Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON");
const VALID_PRODUCTS = ["ducklog_pro_monthly", "ducklog_pro_yearly"];

interface ServiceAccountKey {
  client_email: string;
  private_key: string;
  token_uri: string;
}

// JWT 생성 → access_token 발급
async function getAccessToken(sa: ServiceAccountKey): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = btoa(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = btoa(
    JSON.stringify({
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/androidpublisher",
      aud: sa.token_uri,
      iat: now,
      exp: now + 3600,
    })
  );

  const signInput = `${header}.${payload}`;

  // Import RSA key
  const pemContent = sa.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\n/g, "");
  const binaryKey = Uint8Array.from(atob(pemContent), (c) => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(signInput)
  );

  const sig = btoa(String.fromCharCode(...new Uint8Array(signature)));
  const jwt = `${signInput}.${sig}`;

  const tokenRes = await fetch(sa.token_uri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenRes.json();
  return tokenData.access_token;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  try {
    // 서비스 계정이 없으면 검증 불가 — 거부
    if (!SERVICE_ACCOUNT_JSON) {
      return new Response(
        JSON.stringify({ error: "Purchase verification not configured" }),
        { status: 503, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // JWT에서 인증된 유저 ID 추출
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Authorization required" }),
        { status: 401, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: authError } = await userClient.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Invalid auth token" }),
        { status: 401, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    const userId = user.id;
    const { product_id, purchase_token } = await req.json();

    if (!product_id || !purchase_token) {
      return new Response(
        JSON.stringify({ error: "product_id and purchase_token required" }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // product_id 유효성 검증
    if (!VALID_PRODUCTS.includes(product_id)) {
      return new Response(
        JSON.stringify({ error: "Invalid product_id" }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // Google Play API로 구독 상태 검증
    const sa: ServiceAccountKey = JSON.parse(SERVICE_ACCOUNT_JSON);
    const accessToken = await getAccessToken(sa);
    const packageName = "com.ducklog.ducklog";

    const verifyUrl = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/purchases/subscriptions/${product_id}/tokens/${purchase_token}`;

    const verifyRes = await fetch(verifyUrl, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });

    if (!verifyRes.ok) {
      return new Response(
        JSON.stringify({ error: "Google Play verification failed" }),
        { status: 403, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    const data = await verifyRes.json();
    // paymentState: 0=pending, 1=received, 2=free_trial, 3=deferred
    if (data.paymentState !== 1 && data.paymentState !== 2) {
      return new Response(
        JSON.stringify({ error: "Payment not completed" }),
        { status: 403, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    const startTime = data.startTimeMillis
      ? new Date(parseInt(data.startTimeMillis)).toISOString()
      : null;
    const expiryTime = data.expiryTimeMillis
      ? new Date(parseInt(data.expiryTimeMillis)).toISOString()
      : null;

    // 구독 정보 DB에 저장 (service role — RLS 우회)
    const client = getServiceClient();
    const plan = product_id.includes("yearly") ? "pro_yearly" : "pro_monthly";

    await client.from("subscriptions").upsert(
      {
        user_id: userId,
        plan,
        status: "active",
        provider: "google_play",
        provider_subscription_id: purchase_token,
        current_period_start: startTime,
        current_period_end: expiryTime,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "user_id" }
    );

    return new Response(
      JSON.stringify({ ok: true, plan }),
      { status: 200, headers: { "Content-Type": "application/json", ...corsHeaders } }
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ error: (e as Error).message }),
      { status: 500, headers: { "Content-Type": "application/json", ...corsHeaders } }
    );
  }
});
