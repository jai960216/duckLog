import { corsHeaders } from "../_shared/cors.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const IGDB_CLIENT_ID = Deno.env.get("IGDB_CLIENT_ID")!;
const IGDB_CLIENT_SECRET = Deno.env.get("IGDB_CLIENT_SECRET")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const IGDB_API_BASE = "https://api.igdb.com/v4";
const TWITCH_TOKEN_URL = "https://id.twitch.tv/oauth2/token";

// In-memory token cache (per isolate)
let cachedToken: string | null = null;
let tokenExpiry: number = 0; // unix ms

async function getTwitchToken(): Promise<string> {
  const now = Date.now();
  if (cachedToken && now < tokenExpiry) {
    return cachedToken;
  }

  const res = await fetch(TWITCH_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: IGDB_CLIENT_ID,
      client_secret: IGDB_CLIENT_SECRET,
      grant_type: "client_credentials",
    }),
  });

  if (!res.ok) {
    throw new Error(`Twitch token error: ${res.status} ${await res.text()}`);
  }

  const data = await res.json();
  cachedToken = data.access_token;
  // Expire 60s early to avoid edge cases
  tokenExpiry = now + (data.expires_in - 60) * 1000;
  return cachedToken!;
}

const ALLOWED_ENDPOINTS = [
  "games",
  "covers",
  "characters",
  "genres",
  "platforms",
  "release_dates",
  "search",
];

Deno.serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // --- Auth: verify Supabase JWT ---
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing Authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Invalid or expired token" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // --- Parse request ---
    if (req.method !== "POST") {
      return new Response(
        JSON.stringify({ error: "Method not allowed" }),
        { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const { endpoint, body } = await req.json();

    if (!endpoint || typeof endpoint !== "string") {
      return new Response(
        JSON.stringify({ error: "Missing endpoint" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (!ALLOWED_ENDPOINTS.includes(endpoint)) {
      return new Response(
        JSON.stringify({ error: `Endpoint not allowed: ${endpoint}` }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // --- Forward to IGDB ---
    const token = await getTwitchToken();

    const igdbRes = await fetch(`${IGDB_API_BASE}/${endpoint}`, {
      method: "POST",
      headers: {
        "Client-ID": IGDB_CLIENT_ID,
        "Authorization": `Bearer ${token}`,
        "Content-Type": "text/plain",
      },
      body: body ?? "",
    });

    const igdbBody = await igdbRes.text();

    return new Response(igdbBody, {
      status: igdbRes.status,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    });
  } catch (e) {
    console.error("igdb-proxy error:", e);
    return new Response(
      JSON.stringify({ error: e.message ?? "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
