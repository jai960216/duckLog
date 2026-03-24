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

// base64url 인코딩 (Google OAuth JWT에 필수)
function base64url(input: string): string {
  return btoa(input).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64urlFromBytes(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

// JWT 생성 → access_token 발급
async function getAccessToken(sa: ServiceAccountKey): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = base64url(
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

  const sig = base64urlFromBytes(new Uint8Array(signature));
  const jwt = `${signInput}.${sig}`;

  const tokenRes = await fetch(sa.token_uri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenRes.json();
  if (!tokenData.access_token) {
    console.error("Token error:", JSON.stringify(tokenData));
    throw new Error("Failed to get access token");
  }
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

    // Google Play API v2로 구독 상태 검증
    const sa: ServiceAccountKey = JSON.parse(SERVICE_ACCOUNT_JSON);
    const accessToken = await getAccessToken(sa);
    const packageName = "com.ducklog.ducklog";

    const verifyUrl = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/purchases/subscriptionsv2/tokens/${purchase_token}`;

    const verifyRes = await fetch(verifyUrl, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });

    const data = await verifyRes.json();

    if (!verifyRes.ok) {
      console.error("Google Play API error:", JSON.stringify(data));
      return new Response(
        JSON.stringify({ error: "Google Play verification failed", detail: data }),
        { status: 403, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    console.log("Google Play response:", JSON.stringify(data));

    // subscriptionsv2 응답: subscriptionState로 검증
    const state = data.subscriptionState;
    const validStates = [
      "SUBSCRIPTION_STATE_ACTIVE",
      "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
    ];
    if (!validStates.includes(state)) {
      return new Response(
        JSON.stringify({ error: "Subscription not active", state }),
        { status: 403, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // lineItems에서 시작/만료 시간 추출
    const lineItem = data.lineItems?.[0];
    const startTime = data.startTime ?? null;
    const expiryTime = lineItem?.expiryTime ?? null;

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
