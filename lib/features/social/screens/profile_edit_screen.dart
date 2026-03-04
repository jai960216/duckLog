import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/services/auth_service.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _bioController = TextEditingController();
  final _instagramController = TextEditingController();
  final _twitterController = TextEditingController();
  bool _isPublic = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await ref.read(currentProfileProvider.future);
    if (profile != null && mounted) {
      _nicknameController.text = profile.nickname;
      _bioController.text = profile.bio ?? '';
      _instagramController.text = profile.snsLinks['instagram'] ?? '';
      _twitterController.text = profile.snsLinks['twitter'] ?? '';
      setState(() => _isPublic = profile.isPublic);
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    _instagramController.dispose();
    _twitterController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final userId = client.auth.currentUser!.id;

      final snsLinks = <String, String>{};
      if (_instagramController.text.trim().isNotEmpty) {
        snsLinks['instagram'] = _instagramController.text.trim();
      }
      if (_twitterController.text.trim().isNotEmpty) {
        snsLinks['twitter'] = _twitterController.text.trim();
      }

      await client.from('profiles').update({
        'nickname': _nicknameController.text.trim(),
        'bio': _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        'sns_links': snsLinks,
        'is_public': _isPublic,
      }).eq('id', userId);

      ref.invalidate(currentProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필이 저장되었어요!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장에 실패했어요: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필 수정'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('저장'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Avatar
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: DuckColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: DuckColors.outline, width: 3),
                    ),
                    child: const Center(
                      child: Text('🐥', style: TextStyle(fontSize: 40)),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: DuckColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(PhosphorIconsBold.camera,
                          size: 16, color: DuckColors.outline),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            DuckTextField(
              label: '닉네임',
              hint: '2~12자',
              controller: _nicknameController,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '닉네임을 입력해주세요';
                if (v.trim().length < 2) return '2자 이상 입력해주세요';
                if (v.trim().length > 12) return '12자 이하로 입력해주세요';
                return null;
              },
            ),
            const SizedBox(height: 16),

            DuckTextField(
              label: '자기소개',
              hint: '간단한 소개를 적어주세요',
              controller: _bioController,
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            Text('SNS 링크', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),

            DuckTextField(
              hint: 'Instagram 프로필 URL',
              controller: _instagramController,
              prefix: const Padding(
                padding: EdgeInsets.only(left: 16),
                child: Icon(PhosphorIconsBold.instagramLogo, size: 18),
              ),
            ),
            const SizedBox(height: 12),

            DuckTextField(
              hint: 'X(Twitter) 프로필 URL',
              controller: _twitterController,
              prefix: const Padding(
                padding: EdgeInsets.only(left: 16),
                child: Icon(PhosphorIconsBold.xLogo, size: 18),
              ),
            ),
            const SizedBox(height: 24),

            // Visibility toggle
            DuckCard(
              margin: EdgeInsets.zero,
              child: Row(
                children: [
                  const Icon(PhosphorIconsBold.globe, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('프로필 공개',
                            style: Theme.of(context).textTheme.titleSmall),
                        Text(
                          '다른 유저가 내 프로필을 볼 수 있어요',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isPublic,
                    onChanged: (v) => setState(() => _isPublic = v),
                    activeTrackColor: DuckColors.primary,
                    activeThumbColor: DuckColors.background,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Delete account
            Center(
              child: TextButton(
                onPressed: () {
                  // TODO: Implement account deletion with confirmation
                },
                child: Text(
                  '회원탈퇴',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DuckColors.textSub,
                        decoration: TextDecoration.underline,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
