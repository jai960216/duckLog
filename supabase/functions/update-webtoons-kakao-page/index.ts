import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { getServiceClient } from "../_shared/supabase-client.ts";
import { fetchWithRetry, withConcurrencyLimit } from "../_shared/rate-limit.ts";
import type { WebtoonRow } from "../_shared/types.ts";

const KAKAO_PAGE_GRAPHQL = "https://page.kakao.com/graphql";

const GQL_HEADERS = {
  "Content-Type": "application/json",
  Referer: "https://page.kakao.com",
  "Accept-Language": "ko",
};

// 장르 섹션 ID (웹툰 카테고리)
const SECTION_IDS = [
  11, // 월요 웹툰
  12, // 화요 웹툰
  13, // 수요 웹툰
  14, // 목요 웹툰
  15, // 금요 웹툰
  16, // 토요 웹툰
  17, // 일요 웹툰
];

const DAY_MAP: Record<number, string> = {
  11: "MON",
  12: "TUE",
  13: "WED",
  14: "THU",
  15: "FRI",
  16: "SAT",
  17: "SUN",
};

async function fetchGenreSection(
  sectionId: number,
  page: number
): Promise<{ seriesIds: number[]; hasNext: boolean }> {
  const query = {
    operationName: "staticLandingGenreSection",
    query: `query staticLandingGenreSection($sectionId: Int!, $page: Int!) {
      staticLandingGenreSection(sectionId: $sectionId, page: $page) {
        groups {
          items {
            eventLog
            seriesId
          }
          count
        }
        isEnd
      }
    }`,
    variables: { sectionId, page },
  };

  const response = await fetchWithRetry(KAKAO_PAGE_GRAPHQL, {
    method: "POST",
    headers: GQL_HEADERS,
    body: JSON.stringify(query),
  });

  if (!response.ok) return { seriesIds: [], hasNext: false };

  const data = await response.json();
  const section = data.data?.staticLandingGenreSection;
  if (!section) return { seriesIds: [], hasNext: false };

  const ids: number[] = [];
  for (const group of section.groups || []) {
    for (const item of group.items || []) {
      if (item.seriesId) ids.push(item.seriesId);
    }
  }

  return { seriesIds: ids, hasNext: !section.isEnd };
}

async function fetchContentDetail(
  seriesId: number
): Promise<Partial<WebtoonRow> | null> {
  const query = {
    operationName: "contentHomeOverview",
    query: `query contentHomeOverview($seriesId: Long!) {
      contentHomeOverview(seriesId: $seriesId) {
        content {
          id
          title
          authors
          thumbnail
          ageGrade
          isEnd
          isFree
          seoId
          pubPeriod
        }
      }
    }`,
    variables: { seriesId },
  };

  try {
    const response = await fetchWithRetry(KAKAO_PAGE_GRAPHQL, {
      method: "POST",
      headers: GQL_HEADERS,
      body: JSON.stringify(query),
    });

    if (!response.ok) return null;

    const data = await response.json();
    const content = data.data?.contentHomeOverview?.content;
    if (!content) return null;

    return {
      id: `kakao_page_${seriesId}`,
      title: content.title || "",
      provider: "KAKAO_PAGE",
      url: `https://page.kakao.com/content/${seriesId}`,
      thumbnail: content.thumbnail ? [content.thumbnail] : [],
      is_end: content.isEnd || false,
      is_free: content.isFree !== false,
      is_updated: false,
      age_grade: content.ageGrade || 0,
      free_wait_hour: null,
      authors: content.authors
        ? content.authors.split(/\s*[,/]\s*/).filter(Boolean)
        : [],
    };
  } catch {
    return null;
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = getServiceClient();
    const webtoonMap = new Map<string, WebtoonRow>();

    // 1. 요일별 섹션에서 seriesId 수집
    const seriesDayMap = new Map<number, string[]>(); // seriesId -> days

    for (const sectionId of SECTION_IDS) {
      const day = DAY_MAP[sectionId];
      let page = 0;
      let hasNext = true;

      while (hasNext && page < 20) {
        const result = await fetchGenreSection(sectionId, page);
        for (const id of result.seriesIds) {
          const days = seriesDayMap.get(id) || [];
          if (!days.includes(day)) days.push(day);
          seriesDayMap.set(id, days);
        }
        hasNext = result.hasNext;
        page++;
      }
    }

    // 2. 각 seriesId의 상세 정보 가져오기 (동시 50개)
    const seriesIds = Array.from(seriesDayMap.keys());

    const detailTasks = seriesIds.map((seriesId) => async () => {
      const detail = await fetchContentDetail(seriesId);
      if (detail) {
        const days = seriesDayMap.get(seriesId) || [];
        webtoonMap.set(detail.id!, {
          ...(detail as WebtoonRow),
          update_days: days,
        });
      }
    });

    await withConcurrencyLimit(detailTasks, 50);

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
        provider: "KAKAO_PAGE",
        total: rows.length,
        upserted,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (e) {
    console.error("KakaoPage crawler error:", e);
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
