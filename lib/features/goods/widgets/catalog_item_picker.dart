import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/models/catalog.dart';
import '../../../shared/models/catalog_character.dart';
import '../../../shared/models/catalog_item.dart';
import '../../catalog/services/catalog_service.dart';

/// 도감 아이템 피커 결과
class CatalogItemPickerResult {
  final String catalogId;
  final String itemId;
  final String catalogName;
  final String itemName;
  final String visibility;
  final String? characterName;
  final String? category;
  final String? workTag;

  const CatalogItemPickerResult({
    required this.catalogId,
    required this.itemId,
    required this.catalogName,
    required this.itemName,
    required this.visibility,
    this.characterName,
    this.category,
    this.workTag,
  });
}

/// 도감 아이템 선택 바텀시트
Future<CatalogItemPickerResult?> showCatalogItemPicker(BuildContext context) {
  return showModalBottomSheet<CatalogItemPickerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CatalogItemPickerSheet(),
  );
}

class _CatalogItemPickerSheet extends ConsumerStatefulWidget {
  const _CatalogItemPickerSheet();

  @override
  ConsumerState<_CatalogItemPickerSheet> createState() =>
      _CatalogItemPickerSheetState();
}

class _CatalogItemPickerSheetState
    extends ConsumerState<_CatalogItemPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _isLoading = true;
  List<_CatalogGroup> _groups = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final service = ref.read(catalogServiceProvider);
      final data = await service.getMyItemsGrouped();
      if (!mounted) return;

      final groups = <_CatalogGroup>[];
      for (final entry in data) {
        final items = <_PickerItem>[];

        // Character-grouped items
        for (final ch in entry.characters) {
          for (final item in ch.items) {
            items.add(_PickerItem(
              item: item,
              characterName: ch.name,
            ));
          }
        }

        // Ungrouped items
        for (final item in entry.ungrouped) {
          items.add(_PickerItem(item: item));
        }

        if (items.isNotEmpty) {
          groups.add(_CatalogGroup(
            catalog: entry.catalog,
            characters: entry.characters,
            items: items,
          ));
        }
      }

      setState(() {
        _groups = groups;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<_CatalogGroup> get _filteredGroups {
    if (_query.isEmpty) return _groups;
    final q = _query.toLowerCase();
    return _groups
        .map((group) {
          final filtered = group.items
              .where((pi) => pi.item.name.toLowerCase().contains(q))
              .toList();
          if (filtered.isEmpty) return null;
          return _CatalogGroup(
            catalog: group.catalog,
            characters: group.characters,
            items: filtered,
          );
        })
        .whereType<_CatalogGroup>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: DuckColors.textLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  '도감 아이템 연결',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '아이템 검색',
                    hintStyle: const TextStyle(color: DuckColors.textLight),
                    prefixIcon: const Icon(PhosphorIconsBold.magnifyingGlass,
                        size: 18, color: DuckColors.textSub),
                    filled: true,
                    fillColor: DuckColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
              const SizedBox(height: 4),
              // Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: DuckColors.primary))
                    : _filteredGroups.isEmpty
                        ? Center(
                            child: Text(
                              _groups.isEmpty
                                  ? '도감이 없어요.\n먼저 도감을 만들어주세요!'
                                  : '검색 결과가 없어요',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: DuckColors.textSub,
                                fontSize: 14,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.only(bottom: 20),
                            itemCount: _filteredGroups.length,
                            itemBuilder: (context, index) {
                              return _CatalogGroupWidget(
                                group: _filteredGroups[index],
                                initiallyExpanded: index == 0,
                                onSelect: (item, characterName) {
                                  final group = _filteredGroups[index];
                                  Navigator.of(context).pop(
                                    CatalogItemPickerResult(
                                      catalogId: group.catalog.id,
                                      itemId: item.id,
                                      catalogName: group.catalog.name,
                                      itemName: item.name,
                                      visibility: group.catalog.visibility,
                                      characterName: characterName,
                                      category: group.catalog.category,
                                      workTag: group.catalog.workTag ?? group.catalog.name,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CatalogGroup {
  final Catalog catalog;
  final List<CatalogCharacter> characters;
  final List<_PickerItem> items;

  const _CatalogGroup({
    required this.catalog,
    required this.characters,
    required this.items,
  });
}

class _PickerItem {
  final CatalogItem item;
  final String? characterName;

  const _PickerItem({required this.item, this.characterName});
}

class _CatalogGroupWidget extends StatefulWidget {
  final _CatalogGroup group;
  final bool initiallyExpanded;
  final void Function(CatalogItem item, String? characterName) onSelect;

  const _CatalogGroupWidget({
    required this.group,
    required this.initiallyExpanded,
    required this.onSelect,
  });

  @override
  State<_CatalogGroupWidget> createState() => _CatalogGroupWidgetState();
}

class _CatalogGroupWidgetState extends State<_CatalogGroupWidget> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final catalog = widget.group.catalog;
    final hasCharacters = widget.group.characters.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Catalog header
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Icon(
                  _expanded
                      ? PhosphorIconsBold.caretDown
                      : PhosphorIconsBold.caretRight,
                  size: 14,
                  color: DuckColors.textSub,
                ),
                const SizedBox(width: 8),
                Icon(PhosphorIconsBold.books,
                    size: 16, color: DuckColors.primaryDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    catalog.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${catalog.collectedItems}/${catalog.totalItems}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: DuckColors.textSub,
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_expanded) ...[
          if (hasCharacters) ...[
            // Group by character
            ..._buildCharacterGrouped(),
          ] else ...[
            // Flat items
            ...widget.group.items.map((pi) => _itemTile(pi.item, pi.characterName)),
          ],
        ],

        const Divider(height: 1),
      ],
    );
  }

  List<Widget> _buildCharacterGrouped() {
    final widgets = <Widget>[];
    // Group items by characterName
    final byChar = <String?, List<_PickerItem>>{};
    for (final pi in widget.group.items) {
      byChar.putIfAbsent(pi.characterName, () => []).add(pi);
    }

    for (final entry in byChar.entries) {
      if (entry.key != null) {
        // Character header
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 42, top: 4, bottom: 2),
            child: Row(
              children: [
                const Icon(PhosphorIconsBold.user,
                    size: 12, color: DuckColors.textSub),
                const SizedBox(width: 6),
                Text(
                  entry.key!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: DuckColors.textSub,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      for (final pi in entry.value) {
        widgets.add(_itemTile(pi.item, pi.characterName));
      }
    }
    return widgets;
  }

  Widget _itemTile(CatalogItem item, String? characterName) {
    return InkWell(
      onTap: () => widget.onSelect(item, characterName),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            const SizedBox(width: 36),
            if (item.photoUrl != null && item.photoUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  item.photoUrl!,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: DuckColors.surface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(PhosphorIconsBold.image,
                        size: 14, color: DuckColors.textLight),
                  ),
                ),
              )
            else
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: DuckColors.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(PhosphorIconsBold.cube,
                    size: 14, color: DuckColors.textLight),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.name,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (item.isCollected)
              const Icon(PhosphorIconsBold.checkCircle,
                  size: 16, color: DuckColors.primary),
          ],
        ),
      ),
    );
  }
}
