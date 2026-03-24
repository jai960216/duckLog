import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { getServiceClient } from "../_shared/supabase-client.ts";
import { fetchWithRetry, withConcurrencyLimit } from "../_shared/rate-limit.ts";
import type { WebtoonRow } from "../_shared/types.ts";

const NAVER_API = "https://comic.naver.com/api/webtoon/titlelist";

interface NaverWebtoon {
  titleId: number;
  titleName: string;
  author: string;
  thumbnailUrl: string;
  finish: boolean;
  rest: boolean;
  adult: boolean;
  starScore: number;
  webtoonsUrl: string;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = getServiceClient();
    const webtoonMap = new Map<string, WebtoonRow>();

    // 1. 요일별 웹툰
    const weekdays = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"];
    // Naver API returns full day names (MONDAY, TUESDAY, etc.)
    const dayNameToShort: Record<string, string> = {
      MONDAY: "MON", TUESDAY: "TUE", WEDNESDAY: "WED",
      THURSDAY: "THU", FRIDAY: "FRI", SATURDAY: "SAT", SUNDAY: "SUN",
    };
    const weekdayResponse = await fetchWithRetry(
      `${NAVER_API}/weekday?order=user`
    );
    const weekdayData = await weekdayResponse.json();

    if (weekdayData.titleListMap) {
      for (const [day, titles] of Object.entries(weekdayData.titleListMap)) {
        const dayUpper = day.toUpperCase();
        const dayShort = dayNameToShort[dayUpper] || dayUpper;
        if (!weekdays.includes(dayShort)) continue;

        for (const t of titles as NaverWebtoon[]) {
          const id = `naver_${t.titleId}`;
          const existing = webtoonMap.get(id);
          if (existing) {
            if (!existing.update_days.includes(dayShort)) {
              existing.update_days.push(dayShort);
            }
          } else {
            webtoonMap.set(id, {
              id,
              title: t.titleName,
              provider: "NAVER",
              update_days: [dayShort],
              url: `https://comic.naver.com/webtoon/list?titleId=${t.titleId}`,
              thumbnail: t.thumbnailUrl ? [t.thumbnailUrl] : [],
              is_end: t.finish || false,
              is_free: true,
              is_updated: !t.rest,
              age_grade: t.adult ? 19 : 0,
              free_wait_hour: null,
              authors: t.author
                ? t.author.split(/\s*[,/]\s*/).filter(Boolean)
                : [],
            });
          }
        }
      }
    }

    // 2. dailyPlus (매일+) — 개별 API에서 실제 연재 요일 조회
    const dailyResponse = await fetchWithRetry(
      `${NAVER_API}/weekday?week=dailyPlus&order=user`
    );
    const dailyData = await dailyResponse.json();

    if (dailyData.titleList) {
      const dailyTitles = (dailyData.titleList as NaverWebtoon[])
        .filter((t) => !webtoonMap.has(`naver_${t.titleId}`));

      // 개별 웹툰 정보 API에서 publishDayOfWeekList 가져오기 (동시 5개)
      const dailyTasks = dailyTitles.map((t) => async () => {
        const id = `naver_${t.titleId}`;
        let updateDays: string[] = [];
        try {
          const infoRes = await fetchWithRetry(
            `https://comic.naver.com/api/article/list/info?titleId=${t.titleId}`
          );
          if (infoRes.ok) {
            const info = await infoRes.json();
            const pubDays = info.publishDayOfWeekList as string[] | undefined;
            if (pubDays && pubDays.length > 0) {
              // SATURDAY → SAT, MONDAY → MON 등
              updateDays = pubDays.map((d: string) =>
                dayNameToShort[d.toUpperCase()] || d.substring(0, 3).toUpperCase()
              );
            }
          }
        } catch (_) {}

        webtoonMap.set(id, {
          id,
          title: t.titleName,
          provider: "NAVER",
          update_days: updateDays,
          url: `https://comic.naver.com/webtoon/list?titleId=${t.titleId}`,
          thumbnail: t.thumbnailUrl ? [t.thumbnailUrl] : [],
          is_end: t.finish || false,
          is_free: true,
          is_updated: !t.rest,
          age_grade: t.adult ? 19 : 0,
          free_wait_hour: null,
          authors: t.author
            ? t.author.split(/\s*[,/]\s*/).filter(Boolean)
            : [],
        });
      });

      await withConcurrencyLimit(dailyTasks, 2);
    }

    // 3. 완결 웹툰 (페이지네이션)
    for (let page = 1; page <= 10; page++) {
      const finishedResponse = await fetchWithRetry(
        `${NAVER_API}/finished?page=${page}&order=UPDATE`
      );
      const finishedData = await finishedResponse.json();
      const titles = finishedData.titleList as NaverWebtoon[] | undefined;

      if (!titles || titles.length === 0) break;

      for (const t of titles) {
        const id = `naver_${t.titleId}`;
        if (!webtoonMap.has(id)) {
          webtoonMap.set(id, {
            id,
            title: t.titleName,
            provider: "NAVER",
            update_days: [],
            url: `https://comic.naver.com/webtoon/list?titleId=${t.titleId}`,
            thumbnail: t.thumbnailUrl ? [t.thumbnailUrl] : [],
            is_end: true,
            is_free: true,
            is_updated: false,
            age_grade: t.adult ? 19 : 0,
            free_wait_hour: null,
            authors: t.author
              ? t.author.split(/\s*[,/]\s*/).filter(Boolean)
              : [],
          });
        }
      }
    }

    // 4. Upsert to Supabase (500개씩 배치)
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
        provider: "NAVER",
        total: rows.length,
        upserted,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (e) {
    console.error("Naver crawler error:", e);
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
