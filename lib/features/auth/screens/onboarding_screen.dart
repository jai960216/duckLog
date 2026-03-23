import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/colors.dart';
import '../../../shared/utils/profanity_filter.dart';
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
  final _birthYearController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _birthYearController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final birthYear = int.tryParse(_birthYearController.text.trim());
    if (birthYear == null) return;

    final currentYear = DateTime.now().year;
    final age = currentYear - birthYear;
    if (age < 14) {
      DuckSnackBar.error(context, '만 14세 미만은 서비스를 이용할 수 없어요');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final nickname = _nicknameController.text.trim();

      await ref.read(authServiceProvider).upsertProfile(
            nickname: nickname,
            birthYear: birthYear,
          );
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
                    child: Center(
                      child: Image.asset('assets/images/splash_logo.png', width: 64, height: 64),
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
                  '덕질 기록을 시작하기 전에\n간단한 정보를 입력해주세요.',
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
                    return ProfanityFilter.validate(value);
                  },
                ),
                const SizedBox(height: 16),

                DuckTextField(
                  label: '출생연도',
                  hint: '예: 2000',
                  controller: _birthYearController,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '출생연도를 입력해주세요';
                    }
                    final year = int.tryParse(value.trim());
                    if (year == null) return '숫자로 입력해주세요';
                    final currentYear = DateTime.now().year;
                    if (year < 1900 || year > currentYear) {
                      return '올바른 연도를 입력해주세요';
                    }
                    if (currentYear - year < 14) {
                      return '만 14세 이상만 이용할 수 있어요';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '만 14세 이상만 서비스를 이용할 수 있습니다.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DuckColors.textSub,
                      ),
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
