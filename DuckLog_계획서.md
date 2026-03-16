# DuckLog - 앱 개발 계획서

> "내 덕질을 기록한다"
> 서브컬처 팬(덕후)을 위한 개인 덕질 기록 + 콘텐츠 캘린더 앱

---

## 1. 프로젝트 개요

### 배경
- 원래 DuckMap(지도 기반 서브컬처 LBS)으로 기획
- SNS 크롤링 의존도 문제로 방향 전환 → 운영자 개입 없이 돌아가는 구조로 재설계
- 자동화 불가능한 기능(아이돌 스케줄, 팝업 이벤트, 굿즈 발매일 등)은 과감히 제외

### 핵심 가치
- **운영자 개입 제로**: 사람 없이 자동으로 돌아가는 앱
- **실비 기반 유료화**: 비용 안 드는 기능은 전부 무료, 광고 없음
- **몽글몽글 디자인**: 하얀 배경 + 둥근 UI + 오리 마스코트

### 플랫폼 전략
- **Android 우선 개발 및 출시** (Windows 환경에서 개발/테스트)
- iOS는 추후 Mac 환경 확보 시 대응 (Flutter이므로 코드 변경 최소)
- iOS 빌드만 필요 시 **Codemagic** (클라우드 CI/CD) 활용 가능

---

## 2. 기술 스택

| 구분 | 선택 | 이유 |
|------|------|------|
| Frontend | **Flutter** | 크로스플랫폼, 커스텀 UI(몽글몽글 디자인)에 강함 |
| Backend/DB | **Supabase** | Auth, PostgreSQL, Storage, Edge Functions 올인원. 무료 티어로 MVP 가능 |
| 상태 관리 | **Riverpod** | Flutter 커뮤니티 표준. Supabase 연동 예제 풍부 |
| Auth | **Supabase Auth** | Kakao OAuth + Google OAuth 네이티브 지원 |
| ~~OCR~~ | ~~Gemini 2.0 Flash~~ | **제외** — 영수증 OCR은 정확도/비용 대비 효용이 낮아 제외 |
| 콘텐츠 캘린더 | **AniList API + IGDB API** | 공식 무료 API. 애니 방영일 + 게임 출시일 자동 동기화 |
| 이미지 저장 | **Supabase Storage** | 굿즈 사진, 영수증 사진 저장 (S3 호환 객체 저장소) |
| 이미지 압축 | **flutter_image_compress** | 업로드 전 클라이언트에서 리사이즈+압축 → Storage 비용 절감 |
| 차트 | **fl_chart** | 지출 통계 시각화 |
| 푸시 알림 | **Firebase Cloud Messaging** | Supabase Edge Function에서 트리거 → FCM 발송 |
| 애니메이션 | **Lottie** | 오리 캐릭터 인터랙션 애니메이션 |
| 로컬 캐시 | **Hive** | 오프라인 임시 저장 + 네트워크 복구 시 동기화 |
| 딥링크 | **Firebase Dynamic Links 또는 app_links** | 프로필 공유 URL → 외부 SNS에서 앱으로 유입 |
| 이미지 캐싱 | **cached_network_image** | 다운받은 이미지 로컬 캐시 |

---

## 3. 핵심 기능 정의

### 3-1. 인증 (Auth)
- 카카오 소셜 로그인
- 구글 소셜 로그인
- 로그아웃 / 회원탈퇴

### 3-2. 덕질 기록 (Spending Tracker)
- **직접 입력**: 품목명, 금액, 카테고리, 작품/아티스트 태그, 구매일, 메모
- ~~영수증 촬영 (OCR)~~: **제외** — 직접 입력으로 대체
- **굿즈 사진 등록**: 카메라/갤러리에서 사진 첨부
- **수정/삭제**: 등록된 모든 항목 수정 및 삭제 가능
- **목록 뷰**: 날짜순 리스트, 작품별/카테고리별 필터
- **통계**: 월별/연별 지출 차트, 카테고리별 비율, "이번 달 최다 지출 작품" 등

### 3-3. 컬렉션 갤러리 (Collection Archive)
- 등록한 굿즈를 사진 중심 갤러리로 표시
- 작품/아티스트별 분류
- 공개 범위 설정: **공개 / 비공개 / 친구 공개** (항목별 or 전체)

### 3-4. 콘텐츠 캘린더 (Auto Calendar)
- **관심 작품 팔로우**: 작품 검색 → 팔로우
- **애니 방영 스케줄**: AniList GraphQL API → 시즌별 방영 요일/시간 자동 동기화
- **게임 출시일**: IGDB API → 출시 예정 게임 자동 동기화
- **캘린더 뷰**: 월간/주간 뷰로 한눈에 확인
- **푸시 알림**: "내일 OO 8화 방영!" 식의 리마인더

### 3-5. 소셜 (Lightweight Social)
- **프로필**: 닉네임, 프로필 사진, 자기소개, 외부 SNS 링크(인스타/트위터/기타 선택적)
- **공개 프로필 탐색**: 다른 유저의 공개 컬렉션 구경
- **좋아요**: 다른 유저의 굿즈/컬렉션에 좋아요 (글/댓글 없음, 채팅 없음)
- **친구 시스템**: 친구 추가 → 친구 공개 컬렉션 열람
- **프로필 공유 딥링크**: 고유 URL 생성 → 외부 SNS에 붙여서 유입 유도
- **월간 리포트**: "이번 달 덕질 요약" 이미지 자동 생성 → 외부 SNS 공유

---

## 4. DB 스키마 (Supabase PostgreSQL)

```sql
-- 유저
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  nickname TEXT NOT NULL,
  avatar_url TEXT,
  bio TEXT,
  sns_links JSONB DEFAULT '{}',  -- {"instagram": "url", "twitter": "url"}
  is_public BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 굿즈 기록
CREATE TABLE goods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  price INTEGER,                  -- 원 단위
  category TEXT,                  -- figure, photocard, acrylic, album, etc.
  work_tag TEXT,                  -- 작품명
  artist_tag TEXT,                -- 아티스트명
  photo_urls TEXT[] DEFAULT '{}',
  purchased_at DATE,
  memo TEXT,
  visibility TEXT DEFAULT 'public',  -- public / private / friends
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 영수증
CREATE TABLE receipts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  photo_url TEXT NOT NULL,
  extracted_data JSONB,           -- Gemini가 추출한 원본 데이터
  total_amount INTEGER,
  store_name TEXT,
  purchased_at DATE,
  is_processed BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 팔로우 중인 작품
CREATE TABLE followed_works (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  work_type TEXT NOT NULL,        -- anime / game
  external_id TEXT NOT NULL,      -- AniList ID or IGDB ID
  title TEXT NOT NULL,
  cover_url TEXT,
  notify BOOLEAN DEFAULT true,
  UNIQUE(user_id, work_type, external_id)
);

-- 캘린더 이벤트 (자동 동기화 캐시)
CREATE TABLE calendar_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_type TEXT NOT NULL,
  external_id TEXT NOT NULL,
  title TEXT NOT NULL,
  event_type TEXT NOT NULL,       -- airing (방영) / release (출시)
  event_date DATE NOT NULL,
  episode_number INTEGER,
  synced_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(work_type, external_id, event_date, episode_number)
);

-- 좋아요
CREATE TABLE likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  goods_id UUID REFERENCES goods(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, goods_id)
);

-- 친구 관계
CREATE TABLE friendships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  receiver_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'pending',  -- pending / accepted / rejected
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(requester_id, receiver_id)
);
```

-- 유저 차단
CREATE TABLE blocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  blocked_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(blocker_id, blocked_id)
);

-- 유저/콘텐츠 신고
CREATE TABLE reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  reported_user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  reported_goods_id UUID REFERENCES goods(id) ON DELETE SET NULL,
  reason TEXT NOT NULL,          -- inappropriate, spam, harassment, impersonation, other
  description TEXT,
  status TEXT DEFAULT 'pending', -- pending, reviewed, resolved, dismissed
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(reporter_id, reported_user_id)  -- 동일 유저 중복 신고 영구 차단
);
```

### profiles 확장 컬럼
- `birth_year INTEGER` — 연령 확인 (만14세 이상)
- `is_verified BOOLEAN DEFAULT false` — 공식 계정 파란체크 배지
- `is_suspended BOOLEAN DEFAULT false` — 누적 신고 자동 정지
- `friend_code TEXT` — 친구 추가용 고유 코드

### RLS (Row Level Security) 정책
- `goods`: 본인 것은 CRUD 가능. 타인 것은 visibility 규칙에 따라 SELECT만. 차단/정지 유저 제외
- `profiles`: 본인 것은 UPDATE 가능. is_public=true이고 차단/정지되지 않은 프로필만 SELECT
- `catalogs`: goods와 동일한 visibility + 차단/정지 필터링
- `likes`: 본인이 생성/삭제 가능
- `friendships`: 관련 당사자만 접근
- `blocks`: 본인이 생성한 차단만 관리 가능
- `reports`: 본인이 생성한 신고만 INSERT/SELECT 가능

---

## 5. UI/UX 디자인 가이드

### 레퍼런스
- `UI 분위기.png` — 몰랑 스타일 캐릭터: 굵은 아웃라인, 순백 바탕, 볼터치 핑크, 심플하고 둥근 형태
- `UI 예시.png` — 펫 관리 앱 목업: 하얀 배경 카드 UI, 둥근 칩/버튼, 캐릭터가 곳곳에 자연스럽게 등장

### 디자인 컨셉: "하얀 몽글몽글"
깨끗한 흰 배경 위에 둥근 요소들이 떠 있는 느낌.
캐릭터(오리)는 몰랑처럼 굵은 아웃라인 + 단순한 형태 + 볼터치로 통일.

### 컬러 팔레트
```
Background:  #FFFFFF  (순백)
Surface:     #F7F7F7  (카드/섹션 배경, 아주 연한 그레이)
Primary:     #FFC847  (부드러운 노란색 — 오리 테마, 주요 버튼/강조)
Accent:      #FFB0B0  (볼터치 핑크 — 좋아요, 하이라이트)
Sub:         #B8E6C8  (연한 민트 — 보조 태그, 칩)
Outline:     #2D2D2D  (캐릭터/아이콘 아웃라인 — 굵고 부드러운 다크)
Text:        #2D2D2D  (본문)
TextSub:     #999999  (보조 텍스트)
```

### 디자인 규칙
- **배경**: 순백(#FFFFFF). 크림/아이보리 아님. 깨끗하고 밝은 톤
- **카드**: 흰색 or 연한 그레이(#F7F7F7), border-radius 20~24px, 그림자 거의 없음 (blur:8, opacity:0.05)
- **버튼/칩**: 완전 둥근 모서리 (pill shape, border-radius: 999), 내부 패딩 넉넉하게
- **아웃라인 스타일**: UI 요소에도 부드러운 2~3px 아웃라인 활용 (카드 테두리, 입력 필드)
- **폰트**: 둥근 한글 폰트 (카페24 써라운드에어 or Pretendard Round)
- **아이콘**: 둥글고 굵은 선 스타일 (Phosphor Icons bold 또는 유사한 rounded icon set)
- **여백**: 넉넉한 패딩. 요소 간 간격 16~24px. 답답하지 않게
- **그림자**: 거의 사용 안 함. 쓰더라도 blur 큰 연한 그림자만

### 오리 마스코트 스타일
몰랑 레퍼런스 기반:
- **굵은 검정 아웃라인** (2~3px)
- **순백 몸통** + **핑크 볼터치**
- 눈은 작은 점, 표정 미니멀
- 필요한 일러스트:
  - 기본 오리 (프로필 기본 아바타)
  - 걷는 오리 (로딩)
  - 돋보기 오리 (OCR 인식 중)
  - 하트 오리 (좋아요)
  - 물음표 오리 (빈 상태 / 에러)

### 마스코트 등장 위치
- **로딩 화면**: 오리가 뒤뚱뒤뚱 걷는 Lottie 애니메이션
- **빈 상태**: "아직 기록이 없어요! 첫 덕질을 등록해볼까요?" + 물음표 오리
- **좋아요 탭 시**: 오리가 하트를 뿅 날리는 짧은 애니메이션
- **영수증 인식 중**: 돋보기 오리 + 로딩 인디케이터
- **월간 리포트**: 오리와 함께하는 카드형 이미지
- **온보딩**: 각 단계마다 다른 포즈의 오리 등장

### 주요 화면 구성
```
[BottomNavBar — 4탭]
  아이콘: 둥근 outlined 스타일, 선택 시 filled + Primary 컬러
  1. 홈 (기록)     — 이번 달 요약 카드 + 최근 굿즈 리스트
  2. 캘린더        — 월간/주간 뷰 + 관심 작품 일정
  3. 컬렉션        — 사진 갤러리 그리드 (내 굿즈 모아보기)
  4. 마이페이지     — 프로필, 통계, 설정

[FAB (Floating Action Button)]
  오리 모양 둥근 FAB (Primary 컬러 배경) → 탭하면 바텀시트:
    - "굿즈 등록" (직접 입력)
    - "영수증 촬영" (OCR)

[카드 레이아웃]
  각 굿즈 항목: 흰 카드 + 왼쪽 사진 썸네일 + 오른쪽 정보(품목명, 금액, 태그 칩)
  태그 칩: pill 모양, 연한 배경색 (민트/핑크/노랑)
```

---

## 6. 개발 로드맵

### Phase 1: 프로젝트 세팅 + 인증 (1주) ✅
- [x] Flutter 프로젝트 생성 + 폴더 구조 잡기
- [x] Supabase 프로젝트 생성 + DB 스키마 적용
- [x] 디자인 시스템 구축 (컬러, 폰트, 공통 위젯)
- [x] 카카오 로그인 연동
- [x] 구글 로그인 연동
- [x] 온보딩 / 프로필 초기 설정 화면

### Phase 2: 덕질 기록 핵심 (2주) ✅
- [x] 굿즈 직접 입력 화면 (폼 UI)
- [x] 사진 촬영/갤러리 선택 + 업로드 전 압축 (flutter_image_compress)
- [x] Supabase Storage 업로드
- [x] 기록 목록 뷰 (날짜순, 필터링)
- [x] 기록 상세 뷰 + 수정/삭제 기능
- [x] 카테고리/작품/아티스트 태그 시스템
- [ ] 오프라인 임시 저장 (Hive) — 알림 설정에만 사용 중, 굿즈 오프라인 저장은 미구현

### ~~Phase 3: 영수증 OCR~~ (제외)
- OCR 기능은 정확도/비용 대비 효용이 낮아 제외
- 영수증은 사진 첨부 + 직접 입력으로 대체

### Phase 4: 통계 & 리포트 (1주) ✅
- [x] 월별/연별 지출 차트 (fl_chart)
- [x] 카테고리별 파이차트
- [x] "이번 달 덕질 요약" 카드 (홈 화면 상단)
- [x] 월간 리포트 이미지 생성 + 공유 기능

### Phase 5: 콘텐츠 캘린더 (2주) ✅
- [x] AniList GraphQL API 연동 — 애니 검색 + 방영 스케줄 가져오기
- [x] IGDB API 연동 — 게임 검색 + 출시일 가져오기
- [x] 웹툰 API 연동 — Supabase Edge Function (Naver/Kakao 크롤러)
- [x] 작품 팔로우 기능
- [x] 캘린더 뷰 UI (월간)
- [x] Supabase Edge Function: 웹툰 데이터 자동 동기화 (pg_cron)
- [x] 푸시 알림 (FCM 연동)

### Phase 6: 소셜 & 프로필 (2주) ✅
- [x] 프로필 편집 (닉네임, 사진, 자기소개, SNS 링크)
- [x] 공개 범위 설정 (전체/항목별)
- [x] 다른 유저 프로필 탐색 & 컬렉션 구경
- [x] 좋아요 기능
- [x] 친구 요청/수락 시스템
- [x] 친구 공개 컬렉션 열람
- [x] 프로필 공유 (친구 코드 기반)

### Phase 7: 폴리싱 & 출시 준비 (2주)
- [x] Lottie 애니메이션 적용 — 오리 로딩/빈 상태/좋아요 하트 에셋 + DuckLoading, DuckHeartButton 위젯
- [x] 에러 핸들링 & 엣지 케이스 처리
- [x] 성능 최적화 (이미지 캐싱, 페이지네이션, 스켈레톤 로더)
- [x] 개인정보처리방침 작성 + 웹 호스팅 (GitHub Pages)
- [x] 서비스 이용약관 작성
- [x] 결제 약관 작성 — 이용약관 제7조에 유료 서비스/구독/환불/청약철회 조항 추가
- [x] 앱 내 약관 동의 화면
- [x] 굿즈 오프라인 임시 저장 (Hive) — DraftService + 자동 저장/복원 다이얼로그
- [x] Firebase Analytics + Crashlytics — 화면 추적 + 크래시 리포팅 (디버그 모드 비활성화)
- [x] KakaoPage 크롤러 Edge Function 삭제 (403 차단, 공식 API 없음 — 의도적 차단으로 제외)
- [x] Render + UptimeRobot 삭제 완료
- [x] 안전 기능 (Google Play UGC 정책 준수)
  - [x] 유저 차단/해제 — BlockService + 차단 관리 화면
  - [x] 콘텐츠/유저 신고 — 신고 다이얼로그 + 사유 선택
  - [x] 연령 확인 (만14세) — 온보딩 출생연도 입력 + 자기보고식 연령 게이트
  - [x] 공식 배지 (블루체크) — is_verified 플래그 + Supabase 대시보드에서 수동 부여
  - [x] 스팸 방지 — ActionThrottle (좋아요 1초, 친구요청 5초, 신고 30초)
  - [x] 금칙어 필터링 — ProfanityFilter (한국어/영어 ~90개 금칙어, 특수문자 우회 방지)
    - 적용: 닉네임, 바이오, 굿즈명/메모/태그, 도감명/설명/작품태그, 아이템명/설명, 캐릭터명
  - [x] 신고 처리 시스템
    - 신고 → 자동 차단 (report_and_block RPC 원자적 처리)
    - 동일 유저 중복 신고 영구 차단 (차단/해제는 자유)
    - 누적 3명 신고 → 자동 정지 (is_suspended + 프로필 비공개)
    - 정지 화면 + 이의제기 (이메일 발송)
    - 관리자 대시보드 (Edge Function — 신고 목록/기각/정지/해제)
- [ ] Play Store 메타데이터 준비 (스크린샷, 설명, 데이터 안전 섹션)
- [ ] IARC 콘텐츠 등급 설문
- [ ] Google Play 출시

**총 예상: 약 11주 (Android 우선 출시)**

---

## 7. 캘린더 자동 동기화 상세

### AniList API (애니)
```graphql
query {
  Page {
    media(season: WINTER, seasonYear: 2026, type: ANIME, status: RELEASING) {
      id
      title { romaji native }
      coverImage { large }
      nextAiringEpisode { airingAt episode }
      airingSchedule { nodes { airingAt episode } }
    }
  }
}
```
- 인증 불필요, rate limit: 90 req/min
- 매일 1회 cron으로 동기화하면 충분

### IGDB API (게임)
```
fields name, cover.url, first_release_date, platforms.name;
where first_release_date > {now} & first_release_date < {3months_later};
sort first_release_date asc;
```
- Twitch 인증 필요 (Client Credentials, 무료)
- rate limit: 4 req/sec

### 동기화 방식
- Supabase Edge Function을 **cron job (매일 06:00 KST)** 으로 실행
- API 응답 → `calendar_events` 테이블에 upsert
- 유저의 `followed_works`와 매칭하여 푸시 알림 대상 결정

---

## 8. ~~영수증 OCR 상세~~ (제외)

> OCR 기능은 제외됨. 영수증은 사진 첨부 + 금액/매장명 직접 입력으로 처리.

---

## 9. 수익 모델

### 원칙
- **광고 없음** (유저 경험 최우선)
- **핵심 기능의 가치를 훼손하지 않음** — 기록, 캘린더, 소셜 등 핵심 기능은 무료
- 실비가 드는 부분(Storage, DB)을 업로드 용량 기준으로 자연스럽게 유료 전환
- 가능한 것을 인위적으로 불가능하게 만들지 않음

### 실제 비용이 드는 항목
| 항목 | 비용 |
|------|------|
| Supabase Storage | 1GB 무료, 이후 GB당 ~27원/월 |
| Supabase DB | 500MB 무료, 이후 $25/월~ |
| AniList / IGDB API | 무료 |
| FCM 푸시 | 무료 |

### Free vs Pro (업로드 용량 기반)

**Free (무료)**
- 굿즈 등록: 무제한 (텍스트 기록은 제한 없음)
- 사진 업로드: **월 50장** (굿즈 + 영수증 + 도감 합산)
- 도감: 3개까지 생성
- 캘린더, 소셜, 통계, 내보내기: 전부 무료
- 핵심 기능은 제한 없이 사용 가능

**Pro (월 구독 또는 연 구독)**
- 사진 업로드: **무제한**
- 도감: **무제한** 생성
- 프로필 서포터 배지 표시
- 가격안: 월 2,900원 / 연 24,900원 (2개월 할인)

### 업로드 제한 기준 근거
- 라이트 유저: 월 10~20장 → Free로 충분
- 헤비 유저: 월 50장 초과 → Storage 비용 발생하는 구간 = Pro 전환 유도
- 텍스트 기록은 DB 비용이 미미하므로 제한하지 않음

### 향후 확장 (디자이너 합류 후)
- 오리 코스튬 개별 판매 (개당 500~1,500원)
- 프리미엄 리포트 템플릿 팩 (팩당 1,500원)

### 수익화 타임라인
```
출시 초기 (1~2개월):  완전 무료 (제한 없음). 유저 확보에 집중.
출시 후 2~3개월:      Free/Pro 구분 도입. 기존 유저 데이터는 유지.
디자이너 합류 후:      코스튬, 템플릿 등 확장.
```

---

## 10. 보안

| 항목 | 대응 |
|------|------|
| API 키 노출 방지 | IGDB 등 외부 API 키는 **--dart-define-from-file**로 주입 (소스코드에 하드코딩하지 않음) |
| DB 접근 제어 | Supabase **RLS** — 본인 데이터만 CRUD, 타인은 visibility 규칙에 따라 READ만 |
| 이미지 업로드 검증 | 파일 타입(jpg/png만), 용량 제한(10MB), Supabase Storage policy |
| 인증 토큰 보관 | flutter_secure_storage로 JWT 안전 보관 |
| SQL Injection | Supabase client SDK가 parameterized query 처리 (직접 SQL 작성 안 함) |

---

## 11. 캐싱 & 메모리

| 항목 | 대응 |
|------|------|
| 이미지 캐싱 | **cached_network_image** — 다운받은 이미지 로컬 캐시, 메모리 자동 관리 |
| 목록 메모리 | **ListView.builder** (화면 밖 위젯 자동 해제) + 페이지네이션 (20건씩) |
| API 응답 캐시 | 캘린더 데이터는 calendar_events 테이블에 캐싱 (매일 1회 동기화). 클라이언트는 DB만 조회 |
| 오프라인 캐시 | Hive — 입력 폼 임시 저장 + 자주 쓰는 태그 로컬 저장 |

---

## 12. 법적 요구사항 & 출시 준비

### Google Play 출시 필수 항목
| 항목 | 상세 |
|------|------|
| 개발자 계정 | Google Play Console ($25 일회성) |
| 타겟 API 레벨 | Android 14 (API 34) 이상 |
| 콘텐츠 등급 | IARC 등급 설문 작성 |
| 스크린샷 | 최소 2장, 권장 4~8장 |
| 개인정보처리방침 URL | **필수** — 없으면 심사 거절 |
| 데이터 안전 섹션 | 수집 데이터 종류/목적 고지 **필수** |

### 개인정보처리방침 (법적 의무 — 개인정보보호법 + 정보통신망법)
앱 내 설정 화면 + 외부 웹 URL(Google Play 등록용) 두 곳에 게시.
```
필수 고지 항목:
- 수집 항목: 이메일, 닉네임, 프로필 사진, 구매 기록, 굿즈 사진
- 수집 목적: 서비스 제공, 통계, 소셜 기능
- 보유 기간: 회원 탈퇴 시 즉시 파기 (법정 보존 기간 예외)
- 제3자 제공: Supabase(DB/Storage), Google(인증), Kakao(인증)
- 파기 절차: 탈퇴 요청 시 30일 내 전체 파기
- 개인정보 보호책임자 연락처
```

### 서비스 이용약관 (강력 권장)
```
핵심 조항:
- 회원가입/탈퇴 조건
- 유저 업로드 콘텐츠에 대한 책임은 유저 본인에게 있음
- 서비스 중단/변경 권리
- 면책 조항 (데이터 손실 등)
- 부정 이용 금지 (허위 데이터, 타인 사칭 등)
```

### 결제 약관 (인앱 구매 시 필수)
```
- 결제 처리: Google Play 인앱 결제 → Google 약관 적용
- 청약철회 (한국 전자상거래법):
  - Pro 구독: 정기 결제 해지 시 다음 결제일까지 이용 가능, 일할 환불 불가 → 구매 전 고지 필수
  - 디지털 콘텐츠(코스튬 등): 제공 즉시 청약철회 제한 → 동의 후 구매
- 사업자등록: 수익 발생 시 사업자등록 + 통신판매업 신고 필요
  → 초기 소규모(연 매출 일정 이하)는 간이과세자로 시작 가능
```

### 저작권
```
- 애니/게임 표지: AniList, IGDB API 제공 이미지 URL 참조만 (자체 서버 복제/저장 안 함)
  → 각 API ToS에서 "정보 표시 목적" 허용
- 유저 업로드 사진: 유저 책임 (이용약관에 명시)
- 오리 마스코트: 본인 창작물 → 문제 없음
- 폰트: 사용 전 상업적 이용 라이선스 반드시 확인
  (카페24 써라운드에어: 상업 무료 / Pretendard: SIL OFL 무료)
```

---

## 13. Supabase 인프라 계획

### 무료 티어 한도
| 항목 | 무료 한도 | 예상 소진 시점 |
|------|-----------|---------------|
| DB | 500MB | 유저 5,000명+ (텍스트 위주라 여유 있음) |
| Storage | 1GB | 유저 500~1,000명 (이미지 압축 적용 기준) |
| Edge Functions | 50만 호출/월 | cron 감안 시 유저 5,000명+ |
| 비활성 중지 | 7일 미사용 시 | 개발 중에만 해당. 출시 후 무관 |

### Pro 전환 기준
- Storage 80% 도달 시 → Pro($25/월) 전환
- 이 시점이면 Pro 구독 수익으로 서버비 커버 가능한 규모

---

## 14. 폴더 구조 (Flutter)

```
lib/
├── main.dart
├── app.dart
├── config/
│   ├── theme.dart              # 몽글몽글 디자인 시스템
│   ├── colors.dart
│   └── supabase_config.dart
├── features/
│   ├── auth/
│   │   ├── screens/            # 로그인, 온보딩
│   │   └── services/           # Supabase Auth 래퍼
│   ├── goods/
│   │   ├── screens/            # 입력, 목록, 상세, 수정
│   │   ├── widgets/            # 굿즈 카드, 필터 칩 등
│   │   └── services/           # CRUD
│   ├── calendar/
│   │   ├── screens/            # 캘린더 뷰, 작품 검색
│   │   ├── widgets/            # 이벤트 카드
│   │   └── services/           # AniList, IGDB API 호출
│   ├── collection/
│   │   ├── screens/            # 갤러리 뷰
│   │   └── widgets/            # 갤러리 그리드 아이템
│   ├── social/
│   │   ├── screens/            # 프로필, 유저 탐색
│   │   └── services/           # 좋아요, 친구 관리
│   └── stats/
│       ├── screens/            # 통계 대시보드
│       └── widgets/            # 차트 위젯
├── shared/
│   ├── widgets/                # 공통 위젯 (버튼, 카드, 입력필드)
│   ├── models/                 # 데이터 모델 클래스
│   └── utils/                  # 날짜 포맷, 금액 포맷 등
└── assets/
    ├── lottie/                 # 오리 애니메이션 파일
    ├── images/                 # 오리 일러스트, 아이콘
    └── fonts/                  # 커스텀 폰트
```

---

## 15. 검증 방법

1. **인증**: 카카오/구글 로그인 후 Supabase dashboard에서 유저 생성 확인
2. **굿즈 등록**: 직접 입력 → DB 저장 → 목록에 표시 → 수정 → 삭제 전체 플로우 테스트
3. **영수증**: 사진 첨부 + 직접 입력 → 저장 → 목록 표시 플로우 테스트
4. **캘린더**: AniList에서 현재 방영 중인 애니 데이터가 캘린더에 정상 표시되는지 확인
5. **소셜**: 계정 2개로 친구 추가 → 공개/비공개/친구공개 각각 노출 여부 테스트
6. **성능**: 굿즈 100건 등록 후 목록 스크롤 성능 확인

---

## 16. 출시 전 체크리스트

### 🔴 필수 (출시 블로커)
- [x] 카카오 로그인: AndroidManifest 키 교체 + Kakao Developers 플랫폼 등록 완료
- [x] Twitch redirect URL: Supabase 콜백 URL 등록 완료
- [x] Google OAuth: Release/Debug SHA-1 등록 + 동의 화면 프로덕션 전환 완료
- [x] 개인정보처리방침 URL: https://jai960216.github.io/duckLog/privacy-policy.html
- [x] 서비스 이용약관 URL: https://jai960216.github.io/duckLog/terms-of-service.html
- [ ] Play Store 데이터 안전 섹션 작성
- [ ] IARC 콘텐츠 등급 설문

### 🟠 출시 전 완료 항목
- [x] Lottie 애니메이션 적용 — 오리 로딩/빈 상태/좋아요 하트 Lottie 에셋 + 위젯
- [x] 굿즈 오프라인 임시 저장 (Hive) — DraftService 자동 저장/복원
- [x] 결제 약관 작성 — 이용약관 제7조에 유료 서비스/구독/환불 조항 추가
- [x] Firebase Analytics + Crashlytics — 화면 추적 + 크래시 리포팅
- [x] KakaoPage 크롤러 Edge Function 삭제
- [x] Render + UptimeRobot 삭제 완료

### 🟠 코드 품질 (출시 전 해결 권장)
- [x] debugPrint 정리 — FCM/main만 kDebugMode 가드, 나머지 45개 중 36개 제거
- [x] 에러 핸들링 개선 — 7개 Provider의 try-catch 제거, Riverpod error 상태로 전파
- [x] 버튼 중복 탭 방지 — 점검 완료. 다이얼로그 패턴으로 이미 보호됨
- [x] 폼 입력 validation — 점검 완료. 필수 필드(품목명, 도감이름 등) 모두 validator 적용됨
- [x] 네트워크 타임아웃 — 점검 완료. 모든 API 서비스에 15~60초 timeout + 사용자 에러 메시지 구현됨

### 📝 작업 이력
- **2026-03-12**: debugPrint 정리 (36개 제거, FCM/main kDebugMode 가드), Provider 에러 전파 개선 (7개), 개인정보처리방침/이용약관 GitHub Pages 배포, 레포 public 전환
- **2026-03-13**: 스켈레톤 로더 추가 (shimmer 위젯 + 5개 화면), 네트워크 재시도 로직 (HttpRetry 유틸 + 6개 외부 API 서비스)
- **2026-03-14**: 웹툰 API Render→Supabase Edge Function 이전 (Naver/Kakao 크롤러 + webtoons 테이블), 카카오 로그인 플랫폼 등록, Twitch redirect URL 등록, Google OAuth 앱 게시(프로덕션)
- **2026-03-16**: KakaoPage 크롤러 삭제, Firebase Analytics + Crashlytics, Lottie 애니메이션, 굿즈 드래프트 저장, 결제 약관, 유저 차단/신고/콘텐츠 신고 시스템, 연령 확인 (만14세), 공식 배지 (블루체크), 스팸 방지 (ActionThrottle), 차단 관리 화면
- **2026-03-17**: 욕설 필터링 (ProfanityFilter ~90개 금칙어, 전 입력필드 적용), 신고 시스템 고도화 (신고→자동차단, 중복신고 영구방지, 3회 누적 자동정지, 이의제기 이메일), 계정 정지 화면 (SuspensionScreen), 관리자 대시보드 Edge Function (신고 목록/정지 유저 관리), report_and_block RPC 원자적 처리, RLS 정책 정지유저 제외

### 🟡 출시 후 개선
- [x] 네트워크 재시도 로직 — HttpRetry 공통 유틸 + IGDB/Pokemon/MTG/Yu-Gi-Oh/Digimon/MFC 6개 서비스 적용
- [x] 스켈레톤 로더 추가 — DuckSkeleton shimmer 위젯 + 홈/굿즈/피드/도감/캘린더 5개 화면 적용
- [ ] CI/CD 파이프라인 구축
