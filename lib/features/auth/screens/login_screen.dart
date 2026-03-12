import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/widgets/widgets.dart';
import '../services/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
    } catch (e) {
      if (mounted) {
        DuckSnackBar.error(context, '로그인에 실패했어요');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithKakao() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).signInWithKakao();
    } catch (e) {
      if (mounted) {
        DuckSnackBar.error(context, '로그인에 실패했어요');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),

                // Duck mascot
                const Text(
                  '\u{1F425}',
                  style: TextStyle(fontSize: 80),
                ),
                const SizedBox(height: 24),

                // App name
                Text(
                  'DuckLog',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '내 덕질을 기록한다',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: DuckColors.textSub,
                      ),
                ),

                const SizedBox(height: 56),

                // Login buttons
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(
                      color: DuckColors.primary,
                    ),
                  )
                else ...[
                  // Kakao Login
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _signInWithKakao,
                      icon: const Icon(PhosphorIconsBold.chatCircle, size: 18),
                      label: const Text('카카오로 시작하기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFEE500),
                        foregroundColor: const Color(0xFF191919),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Google Login
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _signInWithGoogle,
                      icon: const Icon(PhosphorIconsBold.googleLogo, size: 18),
                      label: const Text('Google로 시작하기'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: const BorderSide(
                          color: DuckColors.surface,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Terms note
                Text(
                  '로그인 시 이용약관 및 개인정보처리방침에 동의합니다.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
