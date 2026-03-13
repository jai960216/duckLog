export interface WebtoonRow {
  id: string;
  title: string;
  provider: "NAVER" | "KAKAO" | "KAKAO_PAGE";
  update_days: string[];
  url: string;
  thumbnail: string[];
  is_end: boolean;
  is_free: boolean;
  is_updated: boolean;
  age_grade: number;
  free_wait_hour: number | null;
  authors: string[];
  synced_at?: string;
}

export interface WebtoonResponse {
  id: string;
  title: string;
  provider: string;
  updateDays: string[];
  url: string;
  thumbnail: string[];
  isEnd: boolean;
  isFree: boolean;
  isUpdated: boolean;
  ageGrade: number;
  freeWaitHour: number | null;
  authors: string[];
}

export function rowToResponse(row: WebtoonRow): WebtoonResponse {
  return {
    id: row.id,
    title: row.title,
    provider: row.provider,
    updateDays: row.update_days,
    url: row.url,
    thumbnail: row.thumbnail,
    isEnd: row.is_end,
    isFree: row.is_free,
    isUpdated: row.is_updated,
    ageGrade: row.age_grade,
    freeWaitHour: row.free_wait_hour,
    authors: row.authors,
  };
}
