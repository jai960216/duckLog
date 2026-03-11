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
import '../services/catalog_service.dart';

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
      debugPrint('데이터를 불러올 수 없어요: $e');
      if (mounted) {
        DuckSnackBar.error(context, '데이터를 불러올 수 없어요');
        Navigator.pop(context);
      }
    }
  }

  Future<void> _exportAndShare() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final boundary = _repaintKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      await Future.delayed(const Duration(milliseconds: 100));
      final image = await boundary.toImage(pixelRatio: 2.0);
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
      debugPrint('내보내기에 실패했어요: $e');
      if (mounted) {
        DuckSnackBar.error(context, '내보내기에 실패했어요');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('이미지 내보내기'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.caretLeft),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: RepaintBoundary(
                        key: _repaintKey,
                        child: _ExportWidget(
                          catalog: _catalog!,
                          characters: _characters,
                          ungrouped: _ungrouped,
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
                        label: Text(_isExporting ? '내보내는 중...' : '공유하기'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// The widget that gets captured as an image
class _ExportWidget extends StatelessWidget {
  final Catalog catalog;
  final List<CatalogCharacter> characters;
  final List<CatalogItem> ungrouped;

  const _ExportWidget({
    required this.catalog,
    required this.characters,
    required this.ungrouped,
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
          // Cover image
          if (catalog.coverUrl != null && catalog.coverUrl!.isNotEmpty)
            SizedBox(
              height: 100,
              child: CachedNetworkImage(
                imageUrl: catalog.coverUrl!,
                fit: BoxFit.cover,
                alignment: Alignment(0, catalog.coverFitY * 2 - 1),
                errorWidget: (_, e, s) => Container(
                  color: DuckColors.surface,
                  child: const Center(
                    child: Icon(PhosphorIconsBold.image,
                        color: DuckColors.textLight, size: 32),
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
          ),
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
