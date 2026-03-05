import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/colors.dart';
import '../services/mfc_service.dart';
import '../services/catalog_service.dart';
import 'catalog_detail_screen.dart';

class MfcSearchScreen extends ConsumerStatefulWidget {
  const MfcSearchScreen({super.key});

  @override
  ConsumerState<MfcSearchScreen> createState() => _MfcSearchScreenState();
}

class _MfcSearchScreenState extends ConsumerState<MfcSearchScreen> {
  final _usernameController = TextEditingController();
  String _username = '';
  final Set<int> _selectedIds = {};
  bool _isCreating = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final u = _usernameController.text.trim();
    if (u.isNotEmpty && u != _username) {
      setState(() {
        _username = u;
        _selectedIds.clear();
      });
    }
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<MfcFigure> figures) {
    setState(() {
      if (_selectedIds.length == figures.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(figures.map((f) => f.id));
      }
    });
  }

  Future<void> _createCatalog(List<MfcFigure> allFigures) async {
    final selected =
        allFigures.where((f) => _selectedIds.contains(f.id)).toList();
    if (selected.isEmpty) return;

    setState(() => _isCreating = true);
    try {
      final service = ref.read(catalogServiceProvider);
      final items = selected
          .map((f) => {
                'name': f.name,
                'photo_url': f.imageUrl,
              })
          .toList();

      final catalog = await service.createCatalogWithItems(
        name: '$_username 피규어 컬렉션 (${selected.length}개)',
        description: 'MFC 컬렉션에서 가져옴',
        category: 'figure',
        coverUrl: selected.first.imageUrl,
        items: items,
      );

      if (mounted) {
        ref.invalidate(myCatalogsProvider);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CatalogDetailScreen(catalogId: catalog.id),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('도감 생성에 실패했어요: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('피규어 (MFC)'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.caretLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Username input
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                hintText: 'MFC 유저네임 입력',
                prefixIcon: const Icon(PhosphorIconsBold.user, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(PhosphorIconsBold.arrowRight, size: 20),
                  onPressed: _onSearch,
                ),
              ),
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _onSearch(),
            ),
          ),

          // Info banner
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: DuckColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(PhosphorIconsBold.warning,
                    size: 16, color: DuckColors.primaryDark),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '비공식 API라 간헐적으로 작동하지 않을 수 있어요',
                    style:
                        TextStyle(fontSize: 12, color: DuckColors.textSub),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          if (_username.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PhosphorIconsBold.user,
                          size: 48, color: DuckColors.textLight),
                      const SizedBox(height: 16),
                      const Text(
                        'MyFigureCollection 유저네임을 입력하면\n소유 중인 피규어 목록을 가져와요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: DuckColors.textSub,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            _buildResults(),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final asyncResults = ref.watch(mfcCollectionProvider(_username));

    return Expanded(
      child: asyncResults.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(PhosphorIconsBold.warning,
                    size: 40, color: DuckColors.warning),
                const SizedBox(height: 12),
                Text(
                  e.toString().replaceAll('Exception: ', ''),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: DuckColors.textSub),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        ref.invalidate(mfcCollectionProvider(_username));
                      },
                      child: const Text('다시 시도'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('직접 만들기'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        data: (figures) {
          if (figures.isEmpty) {
            return const Center(
              child: Text('컬렉션이 비어있어요',
                  style: TextStyle(color: DuckColors.textSub)),
            );
          }

          return Stack(
            children: [
              Column(
                children: [
                  // Select all / count
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          '${figures.length}개의 피규어',
                          style: const TextStyle(
                            fontSize: 13,
                            color: DuckColors.textSub,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => _selectAll(figures),
                          child: Text(
                            _selectedIds.length == figures.length
                                ? '선택 해제'
                                : '전체 선택',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.only(
                        bottom: _selectedIds.isNotEmpty ? 80 : 16,
                      ),
                      itemCount: figures.length,
                      itemBuilder: (context, index) {
                        final figure = figures[index];
                        final isSelected = _selectedIds.contains(figure.id);
                        return _buildFigureTile(figure, isSelected);
                      },
                    ),
                  ),
                ],
              ),

              // Bottom action bar
              if (_selectedIds.isNotEmpty)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: SafeArea(
                    child: ElevatedButton.icon(
                      onPressed:
                          _isCreating ? null : () => _createCatalog(figures),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: _isCreating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(PhosphorIconsBold.books, size: 20),
                      label: Text(
                          '${_selectedIds.length}개로 도감 만들기'),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFigureTile(MfcFigure figure, bool isSelected) {
    return GestureDetector(
      onTap: () => _toggleSelection(figure.id),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? DuckColors.primaryLight.withValues(alpha: 0.3)
              : DuckColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? DuckColors.primary : DuckColors.surface,
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            // Checkbox
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? DuckColors.primary : DuckColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: isSelected
                    ? null
                    : Border.all(color: DuckColors.textLight),
              ),
              child: isSelected
                  ? const Icon(PhosphorIconsBold.check,
                      size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),

            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 56,
                child: figure.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: figure.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: DuckColors.surface),
                        errorWidget: (_, __, ___) => Container(
                          color: DuckColors.surface,
                          child: const Icon(PhosphorIconsBold.image,
                              size: 20, color: DuckColors.textLight),
                        ),
                      )
                    : Container(
                        color: DuckColors.surface,
                        child: const Icon(PhosphorIconsBold.image,
                            size: 20, color: DuckColors.textLight),
                      ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Text(
                figure.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
