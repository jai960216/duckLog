import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/colors.dart';
import '../../../config/supabase_config.dart';
import '../../../shared/utils/profanity_filter.dart';
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
  String? _avatarUrl;
  String _friendCode = '';

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
      setState(() {
        _isPublic = profile.isPublic;
        _avatarUrl = profile.avatarUrl;
        _friendCode = profile.friendCode;
      });
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

  String? _validateSnsId(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final trimmed = value.trim().replaceAll('@', '');
    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(trimmed)) {
      return '영문, 숫자, 밑줄(_), 마침표(.)만 사용할 수 있어요';
    }
    return null;
  }

  /// @나 URL이 섞여 들어와도 아이디만 추출
  String _extractUsername(String input) {
    var trimmed = input.trim();
    // URL 형태면 마지막 경로를 추출
    if (trimmed.contains('instagram.com/') || trimmed.contains('twitter.com/') || trimmed.contains('x.com/')) {
      trimmed = Uri.tryParse(trimmed)?.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => trimmed) ?? trimmed;
    }
    // @ 제거
    return trimmed.replaceAll('@', '');
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _isLoading = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last.toLowerCase();
      final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
      final client = ref.read(supabaseClientProvider);
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) {
          DuckSnackBar.error(context, '로그인이 필요해요');
          setState(() => _isLoading = false);
        }
        return;
      }
      final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await client.storage.from(SupabaseConfig.avatarBucket).uploadBinary(
        path,
        Uint8List.fromList(bytes),
        fileOptions: FileOptions(contentType: contentType, upsert: true),
      );

      final publicUrl = client.storage
          .from(SupabaseConfig.avatarBucket)
          .getPublicUrl(path);

      setState(() => _avatarUrl = publicUrl);
    } catch (e) {
      if (mounted) {
        DuckSnackBar.error(context, '이미지 업로드에 실패했어요');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // 자기소개 금칙어 검사
    final bio = _bioController.text.trim();
    if (bio.isNotEmpty && ProfanityFilter.containsProfanity(bio)) {
      DuckSnackBar.error(context, '자기소개에 부적절한 표현이 포함되어 있어요');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) {
          DuckSnackBar.error(context, '로그인이 필요해요');
          setState(() => _isLoading = false);
        }
        return;
      }
      final nickname = _nicknameController.text.trim();

      final snsLinks = <String, String>{};
      if (_instagramController.text.trim().isNotEmpty) {
        snsLinks['instagram'] = _extractUsername(_instagramController.text);
      }
      if (_twitterController.text.trim().isNotEmpty) {
        snsLinks['twitter'] = _extractUsername(_twitterController.text);
      }

      await client.from('profiles').update({
        'nickname': nickname,
        'bio': _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        'sns_links': snsLinks,
        'is_public': _isPublic,
        'avatar_url': _avatarUrl,
      }).eq('id', userId);

      ref.invalidate(currentProfileProvider);

      if (mounted) {
        DuckSnackBar.success(context, '프로필이 저장되었어요!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        DuckSnackBar.error(context, '저장에 실패했어요');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('회원탈퇴'),
        content: const Text(
          '정말 탈퇴하시겠어요?\n모든 데이터가 삭제되며 복구할 수 없어요.\n\n'
          '⚠️ Pro 구독 중이라면 Play Store → 구독에서 직접 해지해주세요. '
          '탈퇴만으로는 결제가 자동 취소되지 않아요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _executeDeleteAccount();
            },
            child: const Text('탈퇴하기',
                style: TextStyle(color: DuckColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _executeDeleteAccount() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).deleteAccount();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        DuckSnackBar.error(context, '탈퇴에 실패했어요');
      }
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
          padding: EdgeInsets.fromLTRB(
            20, 20, 20,
            20 + MediaQuery.of(context).viewPadding.bottom,
          ),
          children: [
            // Avatar
            Center(
              child: GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: DuckColors.surface,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: DuckColors.outline, width: 3),
                      ),
                      child: _avatarUrl != null
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: _avatarUrl!,
                                width: 96,
                                height: 96,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => const Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                                errorWidget: (_, _, _) => Center(
                                  child: Image.asset('assets/images/duck_avatar.png', width: 48, height: 48),
                                ),
                              ),
                            )
                          : Center(
                              child:
                                  Image.asset('assets/images/duck_avatar.png', width: 48, height: 48),
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
                return ProfanityFilter.validate(v);
              },
            ),
            const SizedBox(height: 16),

            // 친구 코드 (읽기 전용)
            if (_friendCode.isNotEmpty) ...[
              DuckCard(
                margin: EdgeInsets.zero,
                child: Row(
                  children: [
                    const Icon(PhosphorIconsBold.hash,
                        size: 18, color: DuckColors.textSub),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('친구 코드',
                              style: Theme.of(context).textTheme.labelSmall),
                          Text(
                            _friendCode,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(letterSpacing: 2),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(PhosphorIconsBold.copy,
                          size: 18, color: DuckColors.primary),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _friendCode));
                        DuckSnackBar.success(context, '친구 코드가 복사되었어요!');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            DuckTextField(
              label: '자기소개',
              hint: '간단한 소개를 적어주세요',
              controller: _bioController,
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            Text('SNS', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),

            DuckTextField(
              hint: 'Instagram 아이디',
              controller: _instagramController,
              prefix: const Padding(
                padding: EdgeInsets.only(left: 16),
                child: Icon(PhosphorIconsBold.instagramLogo, size: 18),
              ),
              validator: _validateSnsId,
            ),
            const SizedBox(height: 12),

            DuckTextField(
              hint: 'X(Twitter) 아이디',
              controller: _twitterController,
              prefix: const Padding(
                padding: EdgeInsets.only(left: 16),
                child: Icon(PhosphorIconsBold.xLogo, size: 18),
              ),
              validator: _validateSnsId,
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
                onPressed: () => _confirmDeleteAccount(),
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
