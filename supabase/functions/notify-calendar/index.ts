import "jsr:@supabase/functions-js/edge-runtime.d.ts";

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

// 요일 숫자 → update_days 코드 매핑 (JS Date: 0=SUN, 1=MON, ...)
const WEEKDAY_MAP: Record<number, string> = {
  0: "SUN", 1: "MON", 2: "TUE", 3: "WED",
  4: "THU", 5: "FRI", 6: "SAT",
};

Deno.serve(async (_req: Request) => {
  try {
    const serviceAccount = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!);
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const headers = { apikey: supabaseKey, Authorization: `Bearer ${supabaseKey}` };
    const projectId = serviceAccount.project_id;

    // 내일 요일 계산 (KST = UTC+9)
    const now = new Date();
    const kst = new Date(now.getTime() + 9 * 60 * 60 * 1000);
    const tomorrow = new Date(kst);
    tomorrow.setDate(tomorrow.getDate() + 1);
    const tomorrowDay = WEEKDAY_MAP[tomorrow.getDay()];
    console.log("Tomorrow (KST):", tomorrow.toISOString().split("T")[0], "Day:", tomorrowDay);

    // followed_works에서 내일 요일에 해당하는 웹툰을 팔로우한 유저 조회
    // update_days 배열에 내일 요일이 포함된 행만 필터
    const followsRes = await fetch(
      `${supabaseUrl}/rest/v1/followed_works?select=user_id,title&work_type=eq.webtoon&update_days=cs.{${tomorrowDay}}`,
      { headers }
    );
    const follows = await followsRes.json();
    console.log("Webtoon follows for tomorrow:", follows.length);

    if (!follows.length) {
      return new Response(JSON.stringify({ message: "no webtoon updates tomorrow", day: tomorrowDay }), { status: 200 });
    }

    // 유저별로 알림 그룹핑
    const userNotifications: Record<string, string[]> = {};
    for (const follow of follows) {
      if (!userNotifications[follow.user_id]) {
        userNotifications[follow.user_id] = [];
      }
      userNotifications[follow.user_id].push(follow.title);
    }

    const accessToken = await getAccessToken(serviceAccount);
    let sent = 0;

    for (const [userId, titles] of Object.entries(userNotifications)) {
      const tokenRes = await fetch(
        `${supabaseUrl}/rest/v1/fcm_tokens?select=token&user_id=eq.${userId}`,
        { headers }
      );
      const tokens = await tokenRes.json();
      if (!tokens.length) continue;

      const body = titles.length === 1
        ? `내일 "${titles[0]}" 새 회차가 올라와요!`
        : `내일 "${titles[0]}" 외 ${titles.length - 1}개 웹툰 새 회차가 올라와요!`;

      await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
        method: "POST",
        headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          message: {
            token: tokens[0].token,
            notification: { title: "내일 웹툰 알림", body },
            data: { type: "calendar" },
          },
        }),
      });
      sent++;
    }

    console.log("Sent:", sent);
    return new Response(JSON.stringify({ sent, day: tomorrowDay }), { status: 200 });
  } catch (err) {
    console.error("Error:", err.message);
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});
