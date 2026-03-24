  import "jsr:@supabase/functions-js/edge-runtime.d.ts";

  interface WebhookPayload {
    type: "INSERT";
    table: string;
    record: {
      id: string;
      requester_id: string;
      receiver_id: string;
      status: string;
    };
  }

  function base64url(data: Uint8Array | string): string {
    const str = typeof data === "string" ? btoa(data) : btoa(String.fromCharCode(...data));
    return str.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  }

  async function getAccessToken(serviceAccount: any): Promise<string> {
    const now = Math.floor(Date.now() / 1000);
    const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
    const claimSet = base64url(
      JSON.stringify({
        iss: serviceAccount.client_email,
        scope: "https://www.googleapis.com/auth/firebase.messaging",
        aud: "https://oauth2.googleapis.com/token",
        iat: now,
        exp: now + 3600,
      })
    );

    const keyData = serviceAccount.private_key
      .replace(/-----BEGIN PRIVATE KEY-----/g, "")
      .replace(/-----END PRIVATE KEY-----/g, "")
      .replace(/\n/g, "");
    const binaryKey = Uint8Array.from(atob(keyData), (c) => c.charCodeAt(0));
    const cryptoKey = await crypto.subtle.importKey(
      "pkcs8",
      binaryKey,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["sign"]
    );

    const encoder = new TextEncoder();
    const signature = new Uint8Array(
      await crypto.subtle.sign(
        "RSASSA-PKCS1-v1_5",
        cryptoKey,
        encoder.encode(`${header}.${claimSet}`)
      )
    );

    const jwt = `${header}.${claimSet}.${base64url(signature)}`;

    const res = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
    });
    const data = await res.json();
    if (!data.access_token) {
      console.error("Token error:", JSON.stringify(data));
      throw new Error("Failed to get access token");
    }
    return data.access_token;
  }

  Deno.serve(async (req: Request) => {
    try {
      const payload: WebhookPayload = await req.json();
      console.log("Received:", JSON.stringify(payload));

      if (payload.record.status !== "pending") {
        return new Response(JSON.stringify({ skipped: true }), { status: 200 });
      }

      const serviceAccount = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!);
      const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
      const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
      const headers = { apikey: supabaseKey, Authorization: `Bearer ${supabaseKey}` };

      const profileRes = await fetch(`${supabaseUrl}/rest/v1/profiles?select=nickname&id=eq.${payload.record.requester_id}`, { headers });
      const profiles = await profileRes.json();
      const nickname = profiles[0]?.nickname ?? "누군가";

      const tokenRes = await fetch(`${supabaseUrl}/rest/v1/fcm_tokens?select=token&user_id=eq.${payload.record.receiver_id}`, { headers });
      const tokens = await tokenRes.json();
      console.log("Tokens found:", tokens.length);

      if (!tokens.length) {
        return new Response(JSON.stringify({ skipped: "no token" }), { status: 200 });
      }

      const accessToken = await getAccessToken(serviceAccount);
      const projectId = serviceAccount.project_id;

      const fcmRes = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
        method: "POST",
        headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          message: {
            token: tokens[0].token,
            notification: { title: "새 친구 요청", body: `${nickname}님이 친구 요청을 보냈어요!` },
            data: { type: "friend_request", friendship_id: payload.record.id },
          },
        }),
      });

      const result = await fcmRes.json();
      console.log("FCM result:", JSON.stringify(result));
      return new Response(JSON.stringify(result), { status: 200 });
    } catch (err) {
      console.error("Error:", err.message);
      return new Response(JSON.stringify({ error: err.message }), { status: 500 });
    }
  });