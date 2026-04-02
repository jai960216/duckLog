import 'package:flutter/material.dart';

class LegalScreen extends StatelessWidget {
  final String title;
  final String content;

  const LegalScreen({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20, 20, 20,
          20 + MediaQuery.of(context).viewPadding.bottom,
        ),
        child: Text(
          content,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.8),
        ),
      ),
    );
  }

  static const String privacyPolicyText = '''
개인정보처리방침

1. 수집하는 개인정보 항목
- 필수: 이메일 주소, 닉네임
- 선택: 프로필 사진, 자기소개, SNS 링크

2. 개인정보의 수집 및 이용목적
- 회원 가입 및 서비스 이용
- 소셜 기능 (친구, 피드) 제공
- 서비스 개선 및 통계 분석

3. 개인정보의 보유 및 이용기간
- 회원 탈퇴 시까지 보유하며, 탈퇴 즉시 파기합니다.

4. 개인정보의 파기절차 및 방법
- 회원탈퇴 시 관련 데이터를 즉시 삭제합니다.
- 전자적 파일: 복구 불가능한 방법으로 영구 삭제

5. 개인정보 제3자 제공
- 이용자의 동의 없이 제3자에게 개인정보를 제공하지 않습니다.

6. 이용자의 권리
- 개인정보 열람, 수정, 삭제를 요청할 수 있습니다.
- 마이페이지 > 프로필 수정에서 직접 변경 가능합니다.

7. 문의처
- 이메일: jai96021@gmail.com
''';

  static const String termsOfServiceText = '''
이용약관

제1조 (목적)
본 약관은 덕로그(이하 "서비스")의 이용 조건 및 절차를 규정함을 목적으로 합니다.

제2조 (정의)
① "서비스"란 덕로그가 제공하는 덕질 기록 및 소셜 기능을 말합니다.
② "회원"이란 서비스에 가입하여 이용하는 자를 말합니다.

제3조 (서비스 이용)
① 회원은 서비스를 무료로 이용할 수 있습니다.
② 서비스 내 콘텐츠의 저작권은 각 회원에게 있습니다.

제4조 (회원의 의무)
① 타인의 개인정보를 무단으로 수집하거나 이용할 수 없습니다.
② 서비스의 정상적인 운영을 방해하는 행위를 할 수 없습니다.
③ 불법적이거나 부적절한 콘텐츠를 게시할 수 없습니다.

제5조 (서비스 변경 및 중단)
① 서비스는 운영상 필요한 경우 변경되거나 중단될 수 있습니다.
② 변경 시 사전에 공지합니다.

제6조 (회원 탈퇴)
① 회원은 언제든지 탈퇴할 수 있으며, 탈퇴 시 모든 데이터가 삭제됩니다.
② 삭제된 데이터는 복구할 수 없습니다.

제7조 (유료 서비스 및 결제)
① 서비스는 무료 기능 외에 Pro 구독 등 유료 서비스를 제공할 수 있습니다.
② 유료 서비스의 결제는 Google Play 인앱 결제를 통해 처리되며, Google의 결제 약관이 적용됩니다.
③ Pro 구독은 월간 또는 연간 단위로 자동 갱신되며, 갱신일 최소 24시간 전까지 해지하지 않으면 자동으로 결제됩니다.
④ 구독 해지 시 현재 결제 기간이 종료될 때까지 Pro 기능을 이용할 수 있으며, 이후 무료 플랜으로 전환됩니다.
⑤ 이미 제공된 디지털 콘텐츠(코스튬, 템플릿 등)는 전자상거래법 제17조에 따라 청약철회가 제한될 수 있으며, 구매 전 이를 고지합니다.
⑥ 구독 관리 및 환불은 Google Play 스토어 설정에서 처리할 수 있습니다.

제8조 (면책)
① 서비스는 천재지변 등 불가항력으로 인한 서비스 중단에 대해 책임지지 않습니다.
② 회원 간 거래에 대해서는 서비스가 책임지지 않습니다.
③ 유료 서비스 결제와 관련한 분쟁은 Google Play의 환불 정책에 따릅니다.
''';
}
