import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { getServiceClient } from "../_shared/supabase-client.ts";
import { fetchWithRetry, withConcurrencyLimit } from "../_shared/rate-limit.ts";
import type { WebtoonRow } from "../_shared/types.ts";

const KAKAO_API = "https://gateway-kw.kakao.com";

const PLACEMENTS: Record<string, string> = {
  timetable_mon: "MON",
  timetable_tue: "TUE",
  timetable_wed: "WED",
  timetable_thu: "THU",
  timetable_fri: "FRI",
  timetable_sat: "SAT",
  timetable_sun: "SUN",
  timetable_complete: "COMPLETE",
};

const HEADERS = {
  Accept: "application/json",
  "Accept-Language": "ko",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = getServiceClient();
    const webtoonMap = new Map<string, WebtoonRow>();

    // 1. 요일별 + 완결 타임테이블 가져오기
    for (const [placement, day] of Object.entries(PLACEMENTS)) {
      const response = await fetchWithRetry(
        `${KAKAO_API}/section/v2/timetables/days?placement=${placement}`,
        { headers: HEADERS }
      );

      if (!response.ok) {
        console.error(`Kakao timetable error for ${placement}: ${response.status}`);
        continue;
      }

      const json = await response.json();
      // API 응답: { data: [ { cardGroups: [ { cards: [ { content: {...} } ] } ] } ] }
      const sections = json.data || [];

      for (const section of sections) {
        const cardGroups = section.cardGroups || [];
        for (const group of cardGroups) {
          const cards = group.cards || [];
          for (const card of cards) {
            const content = card.content;
            if (!content) continue;

            const contentId = content.id;
            if (!contentId) continue;

            const id = `kakao_${contentId}`;
            const isComplete = day === "COMPLETE";

            const existing = webtoonMap.get(id);
            if (existing) {
              if (!isComplete && !existing.update_days.includes(day)) {
                existing.update_days.push(day);
              }
            } else {
              const thumbnails: string[] = [];
              if (content.featuredCharacterImageA) {
                thumbnails.push(content.featuredCharacterImageA);
              } else if (content.thumbnailImage) {
                thumbnails.push(content.thumbnailImage);
              }

              // badges에서 FREE_PUBLISHING 확인
              const badges = content.badges || [];
              const hasFree = badges.some((b: { title: string }) => b.title === "FREE_PUBLISHING");

              webtoonMap.set(id, {
                id,
                title: content.title || "",
                provider: "KAKAO",
                update_days: isComplete ? [] : [day],
                url: `https://webtoon.kakao.com/content/${content.seoId || contentId}/${contentId}`,
                thumbnail: thumbnails,
                is_end: isComplete,
                is_free: hasFree,
                is_updated: content.isUpdated || false,
                age_grade: content.adult ? 19 : 0,
                free_wait_hour: null,
                authors: Array.isArray(content.authors)
                  ? content.authors.map((a: { name: string }) => a.name)
                  : [],
              });
            }
          }
        }
      }
    }

    // 2. 티켓 정보 (무료/유료 판별) - 동시 10개 제한
    const contentIds = Array.from(webtoonMap.keys()).map((id) =>
      id.replace("kakao_", "")
    );

    const ticketTasks = contentIds.map((contentId) => async () => {
      try {
        const response = await fetchWithRetry(
          `${KAKAO_API}/ticket/v1/views/ticket-charged-summary?contentId=${contentId}&limit=30`,
          { headers: HEADERS }
        );
        if (!response.ok) return;

        const data = await response.json();
        const id = `kakao_${contentId}`;
        const webtoon = webtoonMap.get(id);
        if (!webtoon) return;

        const waitHour = data.data?.waitForFreeInfo?.waitForFreeHour;
        if (waitHour && waitHour > 0) {
          webtoon.is_free = false;
          webtoon.free_wait_hour = waitHour;
        }
      } catch {
        // 티켓 정보 실패는 무시 (필수 아님)
      }
    });

    await withConcurrencyLimit(ticketTasks, 10);

    // 3. Upsert
    const rows = Array.from(webtoonMap.values());
    let upserted = 0;

    for (let i = 0; i < rows.length; i += 500) {
      const batch = rows.slice(i, i + 500);
      const { error } = await supabase
        .from("webtoons")
        .upsert(batch, { onConflict: "id" });

      if (error) {
        console.error(`Batch upsert error at ${i}:`, error.message);
      } else {
        upserted += batch.length;
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        provider: "KAKAO",
        total: rows.length,
        upserted,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (e) {
    console.error("Kakao crawler error:", e);
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
