/// 금칙어 필터링 유틸리티
class ProfanityFilter {
  ProfanityFilter._();

  // 한국어/영어 금칙어 목록
  static const _bannedWords = <String>[
    // ── 욕설 ──
    '시발', '씨발', '씨팔', '시팔', '씨바', '시바', 'ㅅㅂ', 'ㅆㅂ',
    '병신', 'ㅂㅅ', '빙신', '븅신', '병딱',
    '지랄', 'ㅈㄹ', '짓랄',
    '개새끼', '개세끼', '개새기', '개세키', '개색끼', '개색기',
    '새끼', '세끼',
    '미친놈', '미친년', '미친새끼', '미친',
    '좆', '좃', 'ㅈㄴ', '좇',
    '닥쳐', '닥치', '닥본',
    '꺼져', '꺼저',
    '애미', '애비', '에미', '에비', '엠창', '앰창',
    '느금마', '느금',
    '썅', '쌍놈', '쌍년',
    '개년', '개놈',
    '존나', '졸라', '존내', '좐나',
    '뒤져', '뒤져라', '뒈져', '뒈져라',
    '죽어', '죽여',
    '엿먹어', '엿같',
    '등신', '멍청',

    // ── 성적/음란 ──
    '보지', 'ㅂㅈ',
    '자지', 'ㅈㅈ',
    '걸레', '화냥년',
    '창녀', '창년',
    '성매매', '원조교제', '조건만남',
    '야동', '포르노', '섹스', '씹',
    '강간', '성폭행', '몰카',
    '딸딸이', '자위',
    '음경', '페니스',

    // ── 비방/혐오 ──
    '쓰레기년', '쓰레기놈',
    '한남', '한녀',
    '김치녀', '된장녀',
    '맘충', '틀딱',
    '장애인놈', '장애인년',
    '흑인놈', '흑인년',
    '쪽바리', '짱깨', '짱개', '짱꼴라',
    '홍어', '가오리',
    '똥꼬충', '급식충', '한남충', '한녀충',
    '재기해', '재기하',

    // ── 영어 욕설/음란 ──
    'fuck', 'shit', 'bitch', 'asshole', 'dick', 'pussy',
    'bastard', 'nigger', 'nigga', 'faggot', 'retard',
    'slut', 'whore', 'cunt', 'cock', 'porn', 'hentai',
    'rape', 'molest',
  ];

  /// 텍스트에 금칙어가 포함되어 있는지 검사
  /// 포함 시 해당 단어 반환, 없으면 null
  static String? check(String text) {
    if (text.trim().isEmpty) return null;

    // 공백, 특수문자 제거 후 검사 (우회 방지)
    final normalized = _normalize(text);

    for (final word in _bannedWords) {
      final normalizedWord = _normalize(word);
      if (normalized.contains(normalizedWord)) {
        return word;
      }
    }
    return null;
  }

  /// 금칙어 포함 여부 (bool)
  static bool containsProfanity(String text) => check(text) != null;

  /// Form validator용 - 금칙어 포함 시 에러 메시지 반환
  static String? validate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (containsProfanity(value)) {
      return '부적절한 표현이 포함되어 있어요';
    }
    return null;
  }

  /// 텍스트 정규화: 한글/영문 외 모든 문자 제거 (우회 방지)
  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^가-힣ㄱ-ㅎㅏ-ㅣa-z]'), '');
  }
}
