# DuckLog 초기 설정 가이드

> 아래 3가지를 순서대로 완료하면 앱이 실행됩니다.

---

## 1단계: Supabase 프로젝트 생성 (10분)

### 1-1. 프로젝트 만들기
1. https://supabase.com 접속 → **Start your project** (GitHub 로그인)
2. **New Project** 클릭
3. 설정:
   - Organization: 기본값
   - Project name: `ducklog`
   - Database Password: 안전한 비밀번호 입력 (메모해두세요)
   - Region: `Northeast Asia (Seoul)` 선택
4. **Create new project** 클릭 → 2~3분 대기

### 1-2. API 키 복사
1. 좌측 메뉴 **Project Settings** (⚙️ 톱니바퀴) → **API**
2. 아래 두 값을 복사:
   - **Project URL**: `https://xxxxxxxx.supabase.co`
   - **anon public key**: `eyJhbGci...` (긴 문자열)

### 1-3. 앱에 키 입력
`lib/config/supabase_config.dart` 파일을 열어서:
```dart
static const String url = 'https://YOUR_PROJECT.supabase.co';  // ← Project URL 붙여넣기
static const String anonKey = 'YOUR_ANON_KEY';                  // ← anon key 붙여넣기
```

### 1-4. DB 스키마 적용
1. Supabase Dashboard → 좌측 **SQL Editor** 클릭
2. **New Query** 클릭
3. `supabase/schema.sql` 파일의 내용을 전부 복사해서 붙여넣기
4. **Run** 클릭 (초록 재생 버튼)
5. 에러 없이 "Success" 나오면 완료!

### 1-5. OAuth Redirect URL 설정
1. **Authentication** → **URL Configuration**
2. **Redirect URLs**에 추가:
   ```
   com.ducklog.ducklog://login-callback
   ```
3. **Save** 클릭

---

## 2단계: Google OAuth 설정 (10분)

### 2-1. Google Cloud 프로젝트
1. https://console.cloud.google.com 접속
2. 상단 프로젝트 선택 → **새 프로젝트** → 이름: `DuckLog` → 만들기
3. 생성된 프로젝트 선택

### 2-2. OAuth 동의 화면
1. 좌측 **API 및 서비스** → **OAuth 동의 화면**
2. **외부** 선택 → 만들기
3. 필수 항목만 입력:
   - 앱 이름: `DuckLog`
   - 사용자 지원 이메일: 본인 이메일
   - 개발자 연락처 이메일: 본인 이메일
4. **저장 후 계속** → 범위 설정은 기본값 → 저장 후 계속 → 완료

### 2-3. OAuth 클라이언트 ID 생성
1. **사용자 인증 정보** → **사용자 인증 정보 만들기** → **OAuth 클라이언트 ID**
2. **웹 애플리케이션** 선택:
   - 이름: `DuckLog Web`
   - 승인된 리디렉션 URI 추가:
     ```
     https://YOUR_SUPABASE_PROJECT.supabase.co/auth/v1/callback
     ```
     (YOUR_SUPABASE_PROJECT 부분을 실제 Supabase URL로 변경)
3. **만들기** → Client ID와 Client Secret 복사

### 2-4. Supabase에 Google 연결
1. Supabase Dashboard → **Authentication** → **Providers**
2. **Google** 활성화
3. Client ID, Client Secret 붙여넣기
4. **Save**

### 2-5. Android용 OAuth 클라이언트 (선택사항 - 네이티브 로그인 시)
1. **사용자 인증 정보 만들기** → **OAuth 클라이언트 ID** → **Android**
2. 패키지 이름: `com.ducklog.ducklog`
3. SHA-1 인증서 지문 얻기:
   ```bash
   cd android && ./gradlew signingReport
   ```
   → `SHA1:` 값 복사해서 입력

---

## 3단계: Kakao 로그인 설정 (10분)

### 3-1. Kakao 앱 등록
1. https://developers.kakao.com 접속 → 로그인
2. **내 애플리케이션** → **애플리케이션 추가하기**
3. 앱 이름: `DuckLog`, 사업자명: 본인 이름
4. **저장** → 앱 선택

### 3-2. 키 확인
1. **앱 키** 탭에서 확인:
   - **네이티브 앱 키**: `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
   - **REST API 키**: 메모

### 3-3. 플랫폼 등록
1. **플랫폼** 탭 → **Android 플랫폼 등록**
2. 패키지명: `com.ducklog.ducklog`
3. 키 해시: 아래 명령어로 얻기
   ```bash
   keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android | openssl dgst -sha1 -binary | openssl base64
   ```
4. **저장**

### 3-4. 카카오 로그인 활성화
1. **카카오 로그인** 탭 → **활성화 설정** ON
2. **Redirect URI** 추가:
   ```
   https://YOUR_SUPABASE_PROJECT.supabase.co/auth/v1/callback
   ```
3. **동의항목** → `프로필 정보`, `카카오계정(이메일)` → **필수 동의**로 설정

### 3-5. Supabase에 Kakao 연결
1. Supabase Dashboard → **Authentication** → **Providers**
2. **Kakao** 활성화
3. REST API 키 → Client ID에 입력
4. Client Secret은 공란 가능 (또는 보안 설정 후 입력)
5. **Save**

### 3-6. Android 매니페스트 업데이트
`android/app/src/main/AndroidManifest.xml`에서:
```xml
<data
    android:scheme="kakao{YOUR_KAKAO_NATIVE_APP_KEY}"
    android:host="oauth"/>
```
→ `{YOUR_KAKAO_NATIVE_APP_KEY}` 부분을 실제 네이티브 앱 키로 변경
예: `android:scheme="kakaoabc123def456"`

---

## 4단계: IGDB (게임 검색) 설정 (5분, 선택)

> 게임 검색/출시일 기능을 사용하려면 Twitch Developer 앱이 필요합니다.
> 설정하지 않아도 애니메이션 기능은 정상 동작합니다.

### 4-1. Twitch 앱 등록
1. https://dev.twitch.tv/console/apps 접속 (Twitch 계정 + **2FA 필수**)
2. **응용 프로그램** → 앱 등록
3. 설정:
   - 이름: `DuckLog`
   - OAuth 리디렉션 URL: `https://localhost` (개발용)
   - 카테고리: `Application Integration`
4. **만들기** 클릭

> **출시 전 TODO**: 리디렉션 URL을 `https://localhost`에서 실제 프로덕션 URL로 변경할 것 (Twitch Developer Console → 앱 관리에서 수정)

### 4-2. 클라이언트 키 복사
1. 생성된 앱 클릭 → **관리**
2. **Client ID** 복사
3. **새 비밀** 클릭 → **Client Secret** 복사

### 4-3. 앱에 키 입력
`lib/config/igdb_config.dart` 파일을 열어서:
```dart
static const String clientId = 'YOUR_TWITCH_CLIENT_ID';      // ← Client ID 붙여넣기
static const String clientSecret = 'YOUR_TWITCH_CLIENT_SECRET'; // ← Client Secret 붙여넣기
```

---

## 완료 확인

모든 설정이 끝나면:
```bash
flutter run
```

### 체크리스트
- [ ] Supabase URL & anon key가 `supabase_config.dart`에 입력됨
- [ ] `supabase/schema.sql`이 Supabase SQL Editor에서 실행됨
- [ ] Supabase Redirect URL에 `com.ducklog.ducklog://login-callback` 추가됨
- [ ] Google OAuth Client ID/Secret이 Supabase에 설정됨
- [ ] Kakao REST API 키가 Supabase에 설정됨
- [ ] AndroidManifest.xml의 Kakao scheme이 실제 키로 변경됨
- [ ] (선택) Twitch Client ID/Secret이 `igdb_config.dart`에 입력됨

---

## 문제 해결

### "Developer Mode" 경고 (Windows)
```bash
start ms-settings:developers
```
→ 개발자 모드 켜기

### 에뮬레이터에서 OAuth가 안 될 때
- Chrome Custom Tabs가 필요 → 에뮬레이터에 Chrome이 설치되어 있는지 확인
- 또는 실제 기기에서 테스트

### Supabase RLS 에러
- SQL Editor에서 schema.sql을 다시 실행
- 이미 테이블이 있으면 `DROP TABLE` 후 재실행

---

## 개발 진행 상황

> 최종 업데이트: 2026-03-05

### 완료된 작업

#### Phase 1-2: 프로젝트 세팅 + 인증 + 굿즈 기록 ✅
- Flutter 프로젝트 생성, 폴더 구조, 디자인 시스템 (colors, theme, 공통 위젯)
- 모든 화면 스캐폴딩 완료 (auth, goods, calendar, collection, social, stats)
- 모든 모델 클래스 완료 (Goods, FollowedWork, CalendarEvent, Profile 등)
- GoodsService (CRUD, 필터, 통계, 사진 업로드)
- AuthService (Google, Kakao OAuth, 프로필)
- `flutter analyze` 0 errors

#### 캘린더 - 작품 팔로우 기능 ✅ (수동 입력 모드)
구현된 파일:
1. **`lib/features/calendar/services/calendar_service.dart`**
   - `CalendarService`: followWork, unfollowWork, getFollowedWorks, isFollowing, getEventsForMonth, getEventsForWork, addEvent, deleteEvent
   - Providers: `calendarServiceProvider`, `followedWorksProvider`, `monthEventsProvider(family:"yyyy-MM")`, `workEventsProvider(family:externalId)`
   - `_slugify()`: 제목 → external_id 자동 생성

2. **`lib/features/calendar/screens/work_search_screen.dart`**
   - 작품 타입 선택 칩 (애니=민트 / 게임=핑크)
   - 제목 직접 입력 → "추가" 버튼 → followed_works에 저장
   - 팔로우 중인 작품 리스트 (탭→상세, 언팔로우)

3. **`lib/features/calendar/screens/work_detail_screen.dart`**
   - 작품 정보 헤더 (타입 배지 + 제목 + 칩)
   - 이벤트 수동 추가 다이얼로그 (날짜 DatePicker + 이벤트 타입 방영/발매 + 에피소드 번호)
   - 등록된 이벤트 목록 (날짜, displayTitle, 삭제)
   - 언팔로우 버튼 (AppBar)

4. **`lib/features/calendar/screens/calendar_screen.dart`** (기존 화면 수정)
   - 상단: 팔로우 작품 칩 바 ("작품 추가" + 작품 칩들, 가로 스크롤)
   - 캘린더 날짜 셀: 이벤트 있는 날에 색상 dot (민트=애니, 핑크=게임)
   - 날짜 선택 시: 해당 날짜의 CalendarEvent 카드 리스트 (타입 색상 바, displayTitle, 아이콘)

#### AniList API 연동 ✅
구현된 파일:
1. **`lib/features/calendar/services/anilist_service.dart`** (신규)
   - `AnilistService`: searchAnime, getTrending, getCurrentlyAiring, getAiringSchedule
   - `AnilistMedia` 모델: id, titleRomaji, titleNative, titleEnglish, titleKorean(synonyms에서 추출), coverImageUrl, status, nextAiringEpisode
   - `displayTitle` 우선순위: 한국어 > 영어 > 원어 > romaji, `subtitle` 보조 제목
   - `AnilistAiringSchedule` 모델: airingAt (Unix timestamp), episode
   - GraphQL endpoint: `https://graphql.anilist.co` (인증 불필요)
   - Providers: `anilistServiceProvider`, `trendingAnimeProvider`, `airingAnimeProvider`, `workAiringScheduleProvider(family:externalId)`

2. **`lib/features/calendar/screens/work_search_screen.dart`** (수정)
   - 타입 선택 칩 (애니/게임) + 타입별 탭 전환
   - 애니: 인기(트렌딩) / 방영 중 / 검색 / 내 작품 탭
   - 게임: 인기 / 출시 예정 / 검색 / 내 작품 탭
   - AniList 실시간 검색 (500ms 디바운스), 커버 이미지 + 한글 우선 제목 + 방영 상태 배지
   - IGDB 미설정 시 안내 메시지 표시

3. **`lib/features/calendar/screens/work_detail_screen.dart`** (수정)
   - 커버 이미지 (CachedNetworkImage, full width, 220px)
   - 애니: AniList 방영 스케줄 표시 (에피소드별 날짜 + D-day 라벨)
   - 게임: Supabase calendar_events에서 출시 일정 표시 (출시일 + D-day 라벨)
   - 팔로우 해제 (AppBar 버튼)

4. **`lib/features/calendar/screens/calendar_screen.dart`** (수정)
   - `monthAiringScheduleProvider` 사용 (AniList + Supabase 통합)
   - 날짜별 색상 dot: 민트(애니 방영) + 핑크(게임 출시)
   - 날짜 선택 시 해당 일정 카드 리스트

5. **`lib/features/calendar/services/calendar_service.dart`** (수정)
   - `followWork()`에 `externalId` 선택 파라미터 추가
   - `AiringEntry` 클래스: 애니 방영 + 게임 출시 통합 일정 모델
   - `monthAiringScheduleProvider`: 애니는 AniList API, 게임은 Supabase calendar_events에서 조회

6. **`pubspec.yaml`**: `http: ^1.2.2` 패키지 추가

#### IGDB API 연동 ✅
구현된 파일:
1. **`lib/config/igdb_config.dart`** (신규)
   - Twitch Client ID/Secret 설정 (Developer Console에서 발급)
   - `isConfigured` getter: 실제 키가 입력되었는지 확인

2. **`lib/features/calendar/services/igdb_service.dart`** (신규)
   - `IgdbService`: searchGames, getPopularGames, getUpcomingGames
   - `IgdbGame` 모델: id, name, coverUrl, releaseDate, releaseDateHuman, rating
   - Twitch OAuth2 client_credentials 토큰 자동 발급 + 캐싱
   - IGDB API v4 (Apicalypse 쿼리 문법)
   - Providers: `igdbServiceProvider`, `popularGamesProvider`, `upcomingGamesProvider`

### 다음에 할 작업 🔜

### 남은 전체 로드맵
- [x] **AniList API 연동** ✅
- [x] **IGDB API 연동** ✅
- [ ] Phase 3: 영수증 OCR (Gemini Vision Edge Function)
- [ ] Phase 4: 통계 & 리포트 (fl_chart)
- [ ] Phase 5 나머지: 캘린더 자동 동기화 cron + 푸시 알림
- [ ] Phase 6: 소셜 & 프로필
- [ ] Phase 7: 폴리싱 & Play Store 출시
