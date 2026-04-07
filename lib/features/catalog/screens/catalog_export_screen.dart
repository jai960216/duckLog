import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

import '../../../config/colors.dart';
import '../../../shared/models/catalog.dart';
import '../../../shared/models/catalog_character.dart';
import '../../../shared/models/catalog_item.dart';
import '../../../shared/models/goods.dart';
import '../../../shared/widgets/widgets.dart';
import '../../subscription/services/subscription_service.dart';
import '../../subscription/widgets/pro_upsell_dialog.dart';
import '../services/catalog_service.dart';

enum _ExportSize {
  small(1.0, '소'),
  medium(2.0, '중'),
  large(3.0, '대');

  final double pixelRatio;
  final String label;
  const _ExportSize(this.pixelRatio, this.label);
}

class CatalogExportScreen extends ConsumerStatefulWidget {
  final String catalogId;

  const CatalogExportScreen({super.key, required this.catalogId});

  @override
  ConsumerState<CatalogExportScreen> createState() =>
      _CatalogExportScreenState();
}

class _CatalogExportScreenState extends ConsumerState<CatalogExportScreen> {
  final _repaintKey = GlobalKey();
  bool _isLoading = true;
  bool _isExporting = false;
  Catalog? _catalog;
  List<CatalogCharacter> _characters = [];
  List<CatalogItem> _ungrouped = [];

  bool _showWatermark = true;
  _ExportSize _exportSize = _ExportSize.medium;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final service = ref.read(catalogServiceProvider);
      final catalog = await service.getCatalogById(widget.catalogId);
      final grouped = await service.getGroupedItems(widget.catalogId);

      // Precache all images
      if (mounted) {
        final futures = <Future>[];

        if (catalog.coverUrl != null && catalog.coverUrl!.isNotEmpty) {
          futures.add(precacheImage(
            CachedNetworkImageProvider(catalog.coverUrl!),
            context,
          ).catchError((_) {}));
        }

        for (final ch in grouped.characters) {
          if (ch.photoUrl != null && ch.photoUrl!.isNotEmpty) {
            futures.add(precacheImage(
              CachedNetworkImageProvider(ch.photoUrl!),
              context,
            ).catchError((_) {}));
          }
          for (final item in ch.items) {
            if (item.photoUrl != null && item.photoUrl!.isNotEmpty) {
              futures.add(precacheImage(
                CachedNetworkImageProvider(item.photoUrl!),
                context,
              ).catchError((_) {}));
            }
          }
        }

        for (final item in grouped.ungrouped) {
          if (item.photoUrl != null && item.photoUrl!.isNotEmpty) {
            futures.add(precacheImage(
              CachedNetworkImageProvider(item.photoUrl!),
              context,
            ).catchError((_) {}));
          }
        }

        await Future.wait(futures);
      }

      if (mounted) {
        setState(() {
          _catalog = catalog;
          _characters = grouped.characters;
          _ungrouped = grouped.ungrouped;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        DuckSnackBar.error(context, '데이터를 불러올 수 없어요');
        Navigator.pop(context);
      }
    }
  }

  Future<void> _toggleWatermark(bool value) async {
    if (!value) {
      // 워터마크 제거는 Pro 전용
      final isPro = await ref.read(isProProvider.future);
      if (!isPro) {
        if (mounted) {
          ProUpsellDialog.show(
            context,
            feature: '워터마크 제거는 Pro 전용 기능이에요.',
          );
        }
        return;
      }
    }
    setState(() => _showWatermark = value);
  }

  void _openPreview() {
    if (_catalog == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullPreviewScreen(
          repaintKey: _repaintKey,
          catalog: _catalog!,
          characters: _characters,
          ungrouped: _ungrouped,
          showWatermark: _showWatermark,
        ),
      ),
    );
  }

  Future<void> _exportAndShare() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final boundary = _repaintKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      await Future.delayed(const Duration(milliseconds: 100));
      final image =
          await boundary.toImage(pixelRatio: _exportSize.pixelRatio);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('이미지 생성에 실패했어요');

      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/ducklog_export_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (mounted) {
        DuckSnackBar.error(context, '내보내기에 실패했어요');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resWidth = (360 * _exportSize.pixelRatio).toInt();

    return Scaffold(
      appBar: AppBar(
        title: const Text('이미지 내보내기'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.caretLeft),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsBold.magnifyingGlassPlus, size: 22),
            tooltip: '미리보기',
            onPressed: _isLoading ? null : _openPreview,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Export options
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom:
                          BorderSide(color: DuckColors.surface, width: 1),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Watermark toggle
                      Row(
                        children: [
                          const Icon(PhosphorIconsBold.textT,
                              size: 18, color: DuckColors.textSub),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text('워터마크',
                                style: TextStyle(
                                    fontSize: 14, color: DuckColors.text)),
                          ),
                          SizedBox(
                            height: 28,
                            child: Switch(
                              value: _showWatermark,
                              onChanged: _toggleWatermark,
                              activeColor: DuckColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Size selector
                      Row(
                        children: [
                          const Icon(PhosphorIconsBold.resize,
                              size: 18, color: DuckColors.textSub),
                          const SizedBox(width: 10),
                          const Text('크기',
                              style: TextStyle(
                                  fontSize: 14, color: DuckColors.text)),
                          const Spacer(),
                          _SizeChips(
                            selected: _exportSize,
                            onChanged: (s) =>
                                setState(() => _exportSize = s),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Resolution hint
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${resWidth}px 너비',
                          style: const TextStyle(
                              fontSize: 11, color: DuckColors.textLight),
                        ),
                      ),
                    ],
                  ),
                ),

                // Preview
                Expanded(
                  child: GestureDetector(
                    onTap: _openPreview,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: RepaintBoundary(
                          key: _repaintKey,
                          child: _ExportWidget(
                            catalog: _catalog!,
                            characters: _characters,
                            ungrouped: _ungrouped,
                            showWatermark: _showWatermark,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom share button
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: const BoxDecoration(
                    color: DuckColors.background,
                    border: Border(
                      top: BorderSide(
                        color: DuckColors.surface,
                        width: 1,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isExporting ? null : _exportAndShare,
                        icon: _isExporting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: DuckColors.text,
                                ),
                              )
                            : const Icon(PhosphorIconsBold.shareFat),
                        label:
                            Text(_isExporting ? '내보내는 중...' : '공유하기'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// --- Size selector chips ---

class _SizeChips extends StatelessWidget {
  final _ExportSize selected;
  final ValueChanged<_ExportSize> onChanged;

  const _SizeChips({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _ExportSize.values.map((s) {
        final isSelected = s == selected;
        return Padding(
          padding: const EdgeInsets.only(left: 6),
          child: GestureDetector(
            onTap: () => onChanged(s),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? DuckColors.primary : DuckColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                s.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : DuckColors.textSub,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// --- Full-screen preview ---

class _FullPreviewScreen extends StatelessWidget {
  final GlobalKey repaintKey;
  final Catalog catalog;
  final List<CatalogCharacter> characters;
  final List<CatalogItem> ungrouped;
  final bool showWatermark;

  const _FullPreviewScreen({
    required this.repaintKey,
    required this.catalog,
    required this.characters,
    required this.ungrouped,
    required this.showWatermark,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('미리보기'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.caretLeft),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _ExportWidget(
              catalog: catalog,
              characters: characters,
              ungrouped: ungrouped,
              showWatermark: showWatermark,
            ),
          ),
        ),
      ),
    );
  }
}

/// The widget that gets captured as an image
class _ExportWidget extends StatelessWidget {
  final Catalog catalog;
  final List<CatalogCharacter> characters;
  final List<CatalogItem> ungrouped;
  final bool showWatermark;

  const _ExportWidget({
    required this.catalog,
    required this.characters,
    required this.ungrouped,
    this.showWatermark = true,
  });

  @override
  Widget build(BuildContext context) {
    final allItems = [
      ...characters.expand((c) => c.items),
      ...ungrouped,
    ];
    final collected = allItems.where((i) => i.isCollected).length;
    final total = allItems.length;
    final pct = total > 0 ? (collected / total * 100).toInt() : 0;

    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: DuckColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DuckColors.textLight.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cover image — catalog_card.dart와 동일한 OverflowBox 패턴
          if (catalog.coverUrl != null && catalog.coverUrl!.isNotEmpty)
            SizedBox(
              height: 100,
              width: double.infinity,
              child: ClipRect(
                child: OverflowBox(
                  maxHeight: 280,
                  alignment: Alignment.center,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxTx = constraints.maxWidth *
                          (catalog.coverScale - 1) / 2;
                      final tx = (1 - catalog.coverFitX * 2) * maxTx;
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..translate(tx, 0.0)
                          ..scale(
                              catalog.coverScale, catalog.coverScale),
                        child: CachedNetworkImage(
                          imageUrl: catalog.coverUrl!,
                          height: 280,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          alignment: Alignment(
                              0, catalog.coverFitY * 2 - 1),
                          errorWidget: (_, e, s) => Container(
                            height: 100,
                            color: DuckColors.surface,
                            child: const Center(
                              child: Icon(PhosphorIconsBold.image,
                                  color: DuckColors.textLight,
                                  size: 32),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

          // Header info
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                Text(
                  catalog.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: DuckColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                // Tags
                if (catalog.workTag != null || catalog.category != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      [
                        if (catalog.workTag != null) catalog.workTag!,
                        if (catalog.category != null)
                          Goods.categoryLabel(catalog.category!),
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 13,
                        color: DuckColors.textSub,
                      ),
                    ),
                  ),
                // Progress bar
                _buildProgressBar(collected, total, pct),
              ],
            ),
          ),

          // Divider
          Container(height: 1, color: DuckColors.surface),

          // Character sections
          ...characters.map((ch) => _buildCharacterSection(ch)),

          // Ungrouped section
          if (ungrouped.isNotEmpty) _buildUngroupedSection(),

          // Watermark
          if (showWatermark)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: const Center(
                child: Text(
                  'DuckLog',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: DuckColors.textLight,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildProgressBar(int collected, int total, int pct) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? collected / total : 0,
              backgroundColor: DuckColors.textLight.withValues(alpha: 0.3),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(DuckColors.primary),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$collected/$total ($pct%)',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: DuckColors.primaryDark,
          ),
        ),
      ],
    );
  }

  Widget _buildCharacterSection(CatalogCharacter ch) {
    final collected = ch.items.where((i) => i.isCollected).length;
    final total = ch.items.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Character header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              // Avatar
              if (ch.photoUrl != null && ch.photoUrl!.isNotEmpty)
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: CachedNetworkImageProvider(ch.photoUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: DuckColors.surface,
                  ),
                  child: const Icon(PhosphorIconsBold.user,
                      size: 14, color: DuckColors.textLight),
                ),
              Expanded(
                child: Text(
                  ch.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: DuckColors.text,
                  ),
                ),
              ),
              Text(
                '$collected/$total',
                style: const TextStyle(
                  fontSize: 13,
                  color: DuckColors.textSub,
                ),
              ),
            ],
          ),
        ),
        // Items grid
        if (ch.items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _buildItemsGrid(ch.items),
          ),
        Container(height: 1, color: DuckColors.surface),
      ],
    );
  }

  Widget _buildUngroupedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            '미분류 (${ungrouped.length})',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: DuckColors.textSub,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _buildItemsGrid(ungrouped),
        ),
        Container(height: 1, color: DuckColors.surface),
      ],
    );
  }

  Widget _buildItemsGrid(List<CatalogItem> items) {
    const crossAxisCount = 5;
    final rows = (items.length / crossAxisCount).ceil();

    return Column(
      children: List.generate(rows, (rowIdx) {
        final start = rowIdx * crossAxisCount;
        final end = (start + crossAxisCount).clamp(0, items.length);
        final rowItems = items.sublist(start, end);

        return Padding(
          padding: EdgeInsets.only(bottom: rowIdx < rows - 1 ? 6 : 0),
          child: Row(
            children: [
              ...rowItems.map((item) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _ExportItemTile(item: item),
                    ),
                  )),
              // Fill remaining slots with empty expanded
              ...List.generate(
                crossAxisCount - rowItems.length,
                (_) => const Expanded(child: SizedBox()),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// Compact item tile for the export image
class _ExportItemTile extends StatelessWidget {
  final CatalogItem item;

  const _ExportItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Thumbnail
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: item.isCollected ? null : DuckColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: item.isCollected
                    ? DuckColors.primary
                    : DuckColors.textLight.withValues(alpha: 0.3),
                width: item.isCollected ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (item.photoUrl != null && item.photoUrl!.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: item.photoUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, e, s) => _buildPlaceholder(),
                  )
                else
                  _buildPlaceholder(),
                // Check icon for collected
                if (item.isCollected)
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: DuckColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        PhosphorIconsBold.check,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        // Name
        Text(
          item.name,
          style: const TextStyle(
            fontSize: 9,
            color: DuckColors.text,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return const Center(
      child: Icon(
        PhosphorIconsBold.image,
        size: 16,
        color: DuckColors.textLight,
      ),
    );
  }
}
