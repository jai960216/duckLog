import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/colors.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/services/auth_service.dart';

class SuspensionScreen extends ConsumerWidget {
  final String userId;
  final String nickname;

  const SuspensionScreen({
    super.key,
    required this.userId,
    required this.nickname,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                PhosphorIconsBold.prohibit,
                size: 64,
                color: DuckColors.error,
              ),
              const SizedBox(height: 24),
              Text(
                '계정이 정지되었습니다',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                '커뮤니티 가이드라인 위반으로 인해\n계정이 정지되었습니다.\n\n'
                '오해가 있다고 생각하시면\n이의제기를 통해 검토를 요청할 수 있습니다.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: DuckColors.textSub,
                      height: 1.6,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: DuckButton(
                  text: '이의제기',
                  onPressed: () => _launchAppeal(context),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => ref.read(authServiceProvider).signOut(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('로그아웃'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _launchAppeal(BuildContext context) {
    final uri = Uri(
      scheme: 'mailto',
      path: 'ducklog.app@gmail.com',
      queryParameters: {
        'subject': '[DuckLog] 계정 정지 이의제기 - $nickname',
        'body': '계정 ID: $userId\n닉네임: $nickname\n\n이의제기 사유:\n\n',
      },
    );

    launchUrl(uri);
  }
}
