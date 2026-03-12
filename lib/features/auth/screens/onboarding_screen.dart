import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/colors.dart';
import '../../../shared/widgets/widgets.dart';
import '../services/auth_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final nickname = _nicknameController.text.trim();

      await ref.read(authServiceProvider).upsertProfile(
            nickname: nickname,
          );
      // 프로필 생성 후 ProfileGate가 다시 체크하도록 갱신
      ref.invalidate(currentProfileProvider);
    } catch (e) {
      if (mounted) {
        DuckSnackBar.error(context, '프로필 생성에 실패했어요');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => ref.read(authServiceProvider).signOut(),
            child: Text(
              '로그아웃',
              style: TextStyle(color: DuckColors.textSub),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // Duck greeting
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: DuckColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: DuckColors.outline,
                        width: 3,
                      ),
                    ),
                    child: const Center(
                      child: Text('🐥', style: TextStyle(fontSize: 48)),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                Text(
                  '반가워요!',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '덕질 기록을 시작하기 전에\n닉네임을 정해주세요.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: DuckColors.textSub,
                      ),
                ),
                const SizedBox(height: 32),

                DuckTextField(
                  label: '닉네임',
                  hint: '2~12자로 입력해주세요',
                  controller: _nicknameController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '닉네임을 입력해주세요';
                    }
                    if (value.trim().length < 2) {
                      return '2자 이상 입력해주세요';
                    }
                    if (value.trim().length > 12) {
                      return '12자 이하로 입력해주세요';
                    }
                    return null;
                  },
                ),

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  child: DuckButton(
                    text: '시작하기',
                    onPressed: _submit,
                    isLoading: _isLoading,
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
