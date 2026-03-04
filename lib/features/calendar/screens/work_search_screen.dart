import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/widgets/widgets.dart';
import '../services/calendar_service.dart';
import 'work_detail_screen.dart';

class WorkSearchScreen extends ConsumerStatefulWidget {
  const WorkSearchScreen({super.key});

  @override
  ConsumerState<WorkSearchScreen> createState() => _WorkSearchScreenState();
}

class _WorkSearchScreenState extends ConsumerState<WorkSearchScreen> {
  String _selectedType = 'anime';
  final _titleController = TextEditingController();
  bool _isAdding = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _addWork() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isAdding = true);
    try {
      final service = ref.read(calendarServiceProvider);
      await service.followWork(workType: _selectedType, title: title);
      _titleController.clear();
      ref.invalidate(followedWorksProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('\'$title\' 팔로우 시작!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('추가 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _unfollowWork(String id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('팔로우 해제'),
        content: Text('\'$title\'을(를) 팔로우 해제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('해제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final service = ref.read(calendarServiceProvider);
      await service.unfollowWork(id);
      ref.invalidate(followedWorksProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('해제 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final followedWorks = ref.watch(followedWorksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('작품 추가')),
      body: Column(
        children: [
          // Work type selector
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                DuckChip(
                  label: '애니',
                  icon: PhosphorIconsBold.television,
                  selected: _selectedType == 'anime',
                  backgroundColor: DuckColors.subLight,
                  onTap: () => setState(() => _selectedType = 'anime'),
                ),
                const SizedBox(width: 8),
                DuckChip(
                  label: '게임',
                  icon: PhosphorIconsBold.gameController,
                  selected: _selectedType == 'game',
                  backgroundColor: DuckColors.accentLight,
                  onTap: () => setState(() => _selectedType = 'game'),
                ),
              ],
            ),
          ),

          // Title input + add button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: DuckTextField(
                    hint: '작품 제목을 입력하세요',
                    controller: _titleController,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                DuckButton(
                  text: '추가',
                  icon: PhosphorIconsBold.plus,
                  isLoading: _isAdding,
                  onPressed:
                      _titleController.text.trim().isEmpty ? null : _addWork,
                ),
              ],
            ),
          ),

          const Divider(height: 24),

          // Followed works list header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Text(
                  '팔로우 중인 작품',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                followedWorks.when(
                  data: (list) => Text(
                    '${list.length}개',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: DuckColors.textSub),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          // Followed works list
          Expanded(
            child: followedWorks.when(
              data: (works) {
                if (works.isEmpty) {
                  return const DuckEmptyState(
                    message: '아직 팔로우한 작품이 없어요.\n위에서 작품을 추가해보세요!',
                    icon: PhosphorIconsBold.heartStraight,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: works.length,
                  itemBuilder: (context, index) {
                    final work = works[index];
                    final isAnime = work.workType == 'anime';

                    return DuckCard(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WorkDetailScreen(work: work),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Type icon
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isAnime
                                  ? DuckColors.subLight
                                  : DuckColors.accentLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isAnime
                                  ? PhosphorIconsBold.television
                                  : PhosphorIconsBold.gameController,
                              size: 20,
                              color: isAnime
                                  ? DuckColors.sub
                                  : DuckColors.accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Title
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  work.title,
                                  style: Theme.of(context).textTheme.titleSmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  isAnime ? '애니메이션' : '게임',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: DuckColors.textSub),
                                ),
                              ],
                            ),
                          ),
                          // Unfollow button
                          IconButton(
                            onPressed: () =>
                                _unfollowWork(work.id, work.title),
                            icon: Icon(
                              PhosphorIconsBold.heartBreak,
                              size: 20,
                              color: DuckColors.textSub,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => DuckEmptyState(
                message: '작품 목록을 불러올 수 없어요.\n$e',
                icon: PhosphorIconsBold.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
