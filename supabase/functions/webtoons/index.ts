import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { rowToResponse } from "../_shared/types.ts";

serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const params = url.searchParams;

    const keyword = params.get("keyword")?.trim() || "";
    const provider = params.get("provider") || "";
    const updateDay = params.get("updateDay") || "";
    const isUpdated = params.get("isUpdated");
    const isFree = params.get("isFree");
    const page = Math.max(1, parseInt(params.get("page") || "1"));
    const perPage = Math.min(100, Math.max(1, parseInt(params.get("perPage") || "30")));
    const sort = params.get("sort") === "DESC" ? false : true; // ASC default

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!
    );

    let query = supabase
      .from("webtoons")
      .select("*", { count: "exact" });

    // Filters
    if (keyword) {
      query = query.ilike("title", `%${keyword}%`);
    }
    if (provider) {
      query = query.eq("provider", provider);
    }
    if (updateDay) {
      query = query.contains("update_days", [updateDay]);
    }
    if (isUpdated === "true") {
      query = query.eq("is_updated", true);
    }
    if (isFree === "true") {
      query = query.eq("is_free", true);
    } else if (isFree === "false") {
      query = query.eq("is_free", false);
    }

    // Pagination
    const offset = (page - 1) * perPage;
    query = query
      .order("title", { ascending: sort })
      .range(offset, offset + perPage - 1);

    const { data, count, error } = await query;

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const total = count || 0;
    const webtoons = (data || []).map(rowToResponse);

    return new Response(
      JSON.stringify({
        webtoons,
        total,
        isLastPage: offset + perPage >= total,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
