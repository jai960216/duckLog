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

### 다음에 할 작업: AniList API 연동 🔜

**목표**: 작품 검색 시 AniList에서 실제 애니를 검색하고, 팔로우 시 방영 스케줄을 자동으로 가져오기

#### 구현해야 할 것:
1. **AniList GraphQL 클라이언트** (`lib/features/calendar/services/anilist_service.dart`)
   - 작품 검색: title로 검색 → id, title(romaji/native), coverImage, status 반환
   - 방영 스케줄 조회: media id → airingSchedule (airingAt, episode) 가져오기
   - 인증 불필요, rate limit: 90 req/min
   - GraphQL endpoint: `https://graphql.anilist.co`

2. **work_search_screen.dart 수정**
   - 애니 타입 선택 시: 제목 입력 → AniList API 검색 → 결과 리스트 표시
   - 검색 결과에서 선택 → followWork (externalId = AniList media ID)
   - 게임 타입은 당분간 수동 입력 유지 (IGDB는 Twitch 인증 필요)

3. **calendar_service.dart 수정**
   - followWork 시 AniList에서 방영 스케줄 가져와서 calendar_events에 자동 저장
   - external_id를 AniList media ID로 사용

4. **(선택) Supabase Edge Function: 자동 동기화**
   - 매일 cron으로 followed_works 순회 → AniList에서 최신 스케줄 가져와 calendar_events upsert

#### AniList GraphQL 쿼리 참고:
```graphql
# 작품 검색
query ($search: String) {
  Page(perPage: 10) {
    media(search: $search, type: ANIME) {
      id
      title { romaji native }
      coverImage { large }
      status
      nextAiringEpisode { airingAt episode }
    }
  }
}

# 방영 스케줄
query ($mediaId: Int) {
  Media(id: $mediaId) {
    airingSchedule(notYetAired: true, perPage: 25) {
      nodes { airingAt episode }
    }
  }
}
```

#### 참고 사항:
- AniList `airingAt`은 Unix timestamp (초 단위) → `DateTime.fromMillisecondsSinceEpoch(airingAt * 1000)`
- coverImage URL은 그대로 cover_url로 저장 (자체 서버 복제 X, API ToS 준수)
- `http` 패키지 또는 `dio`로 POST 요청 (GraphQL은 POST + JSON body)
- 현재 프로젝트 `pubspec.yaml`에 http 패키지 확인 필요

### 남은 전체 로드맵
- [ ] **AniList API 연동** ← 다음 작업
- [ ] IGDB API 연동 (게임 출시일, Twitch 인증 필요)
- [ ] Phase 3: 영수증 OCR (Gemini Vision Edge Function)
- [ ] Phase 4: 통계 & 리포트 (fl_chart)
- [ ] Phase 5 나머지: 캘린더 자동 동기화 cron + 푸시 알림
- [ ] Phase 6: 소셜 & 프로필
- [ ] Phase 7: 폴리싱 & Play Store 출시
