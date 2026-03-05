import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/colors.dart';
import '../../../shared/models/goods.dart';
import '../../../shared/widgets/widgets.dart';

/// 아이템 편집 데이터 (UI 전용)
class ItemSetupData {
  String? id; // 기존 아이템 ID (null이면 신규)
  String name;

  ItemSetupData({this.id, required this.name});
}

/// 캐릭터+아이템 편집 데이터 (UI 전용)
class CharacterSetupData {
  String? id; // 기존 캐릭터 ID (null이면 신규)
  String name;
  String? photoUrl;
  String? externalId;
  List<ItemSetupData> items;

  CharacterSetupData({
    this.id,
    required this.name,
    this.photoUrl,
    this.externalId,
    List<ItemSetupData>? items,
  }) : items = items ?? [];
}

/// 도감 설정 공용 위젯 — 생성 Step 2 / 수정 모드 공유
class CatalogSetupForm extends StatefulWidget {
  final String? initialName;
  final String? initialCategory;
  final String? initialWorkTag;
  final String initialVisibility;
  final List<CharacterSetupData> characters;
  final bool isEditing;
  final bool isLoading;
  final Future<void> Function({
    required String name,
    required String? category,
    required String? workTag,
    required String visibility,
    required List<CharacterSetupData> characters,
  }) onSubmit;

  const CatalogSetupForm({
    super.key,
    this.initialName,
    this.initialCategory,
    this.initialWorkTag,
    this.initialVisibility = 'private',
    required this.characters,
    this.isEditing = false,
    this.isLoading = false,
    required this.onSubmit,
  });

  @override
  State<CatalogSetupForm> createState() => _CatalogSetupFormState();
}

class _CatalogSetupFormState extends State<CatalogSetupForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _workTagController;
  String? _selectedCategory;
  late String _visibility;
  late List<CharacterSetupData> _characters;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _workTagController = TextEditingController(text: widget.initialWorkTag ?? '');
    _selectedCategory = widget.initialCategory;
    _visibility = widget.initialVisibility;
    _characters = widget.characters.map((c) => CharacterSetupData(
      id: c.id,
      name: c.name,
      photoUrl: c.photoUrl,
      externalId: c.externalId,
      items: c.items.map((i) => ItemSetupData(id: i.id, name: i.name)).toList(),
    )).toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _workTagController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    debugPrint('[SUBMIT] Order: ${_characters.map((c) => '${c.name}(id=${c.id?.substring(0, 6)})').toList()}');
    setState(() => _isLoading = true);
    try {
      final workTag = _workTagController.text.trim();
      await widget.onSubmit(
        name: _nameController.text.trim(),
        category: _selectedCategory,
        workTag: workTag.isEmpty ? null : workTag,
        visibility: _visibility,
        characters: _characters,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addItemToCharacter(int charIndex) {
    setState(() {
      _characters[charIndex].items.add(ItemSetupData(name: '아이템'));
    });
  }

  void _removeItemFromCharacter(int charIndex, int itemIndex) {
    setState(() {
      _characters[charIndex].items.removeAt(itemIndex);
    });
  }

  void _removeCharacter(int charIndex) {
    setState(() {
      _characters.removeAt(charIndex);
    });
  }

  void _onReorderCharacters(int oldIndex, int newIndex) {
    debugPrint('[REORDER] oldIndex=$oldIndex, newIndex=$newIndex');
    debugPrint('[REORDER] BEFORE: ${_characters.map((c) => c.name).toList()}');
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _characters.removeAt(oldIndex);
      _characters.insert(newIndex, item);
    });
    debugPrint('[REORDER] AFTER: ${_characters.map((c) => c.name).toList()}');
  }

  @override
  Widget build(BuildContext context) {
    final loading = _isLoading || widget.isLoading;

    return Form(
      key: _formKey,
      child: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        onReorder: _onReorderCharacters,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        proxyDecorator: (child, index, animation) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final elevation = Tween<double>(begin: 0, end: 6)
                  .animate(animation)
                  .value;
              return Material(
                elevation: elevation,
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: child,
              );
            },
            child: child,
          );
        },
        header: Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DuckTextField(
                label: '도감 이름',
                hint: '예: 귀멸의 칼날 피규어 컬렉션',
                controller: _nameController,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? '도감 이름을 입력해주세요' : null,
              ),
              const SizedBox(height: 16),
              DuckTextField(
                label: '작품/콘텐츠',
                hint: '예: 귀멸의 칼날, 원피스',
                controller: _workTagController,
              ),
              const SizedBox(height: 16),
              _buildCategorySelector(),
              const SizedBox(height: 16),
              _buildVisibilitySelector(),
              const SizedBox(height: 20),
              if (_characters.isNotEmpty) ...[
                Row(
                  children: [
                    Text(
                      '캐릭터 (${_characters.length})',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(PhosphorIconsBold.dotsSixVertical,
                            size: 12, color: DuckColors.textSub),
                        const SizedBox(width: 3),
                        const Text(
                          '꾹 눌러서 순서 변경',
                          style: TextStyle(
                            fontSize: 11,
                            color: DuckColors.textSub,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        footer: Padding(
          padding: const EdgeInsets.fromLTRB(0, 24, 0, 20),
          child: SizedBox(
            width: double.infinity,
            child: DuckButton(
              text: widget.isEditing ? '수정 완료' : '만들기',
              onPressed: _submit,
              isLoading: loading,
            ),
          ),
        ),
        itemCount: _characters.length,
        itemBuilder: (context, ci) => _buildCharacterCard(ci),
      ),
    );
  }

  Widget _buildCharacterCard(int charIndex) {
    final ch = _characters[charIndex];
    return Container(
      key: ValueKey(identityHashCode(ch)),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DuckColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Character header
          Row(
            children: [
              // Drag handle
              ReorderableDragStartListener(
                index: charIndex,
                child: const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(PhosphorIconsBold.dotsSixVertical,
                      size: 18, color: DuckColors.textSub),
                ),
              ),
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: ch.photoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: ch.photoUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: DuckColors.textLight),
                          errorWidget: (_, __, ___) => Container(
                            color: DuckColors.textLight,
                            child: const Icon(PhosphorIconsBold.user,
                                size: 18, color: DuckColors.textSub),
                          ),
                        )
                      : Container(
                          color: DuckColors.textLight,
                          child: const Icon(PhosphorIconsBold.user,
                              size: 18, color: DuckColors.textSub),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: TextEditingController(text: ch.name),
                    onChanged: (v) => ch.name = v,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide(
                            color: DuckColors.textLight, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide(
                            color: DuckColors.textLight, width: 1),
                      ),
                    ),
                  ),
                ),
              ),
              // Remove character
              IconButton(
                onPressed: () => _removeCharacter(charIndex),
                icon: const Icon(PhosphorIconsBold.x,
                    size: 16, color: DuckColors.textSub),
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                padding: EdgeInsets.zero,
              ),
            ],
          ),

          // Items list
          if (ch.items.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...List.generate(ch.items.length, (ii) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    const Icon(PhosphorIconsBold.dotOutline,
                        size: 12, color: DuckColors.textSub),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: TextField(
                          controller: TextEditingController(
                            text: ch.items[ii].name,
                          ),
                          onChanged: (v) => ch.items[ii].name = v,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                              borderSide: BorderSide(
                                  color: DuckColors.textLight, width: 1),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                              borderSide: BorderSide(
                                  color: DuckColors.textLight, width: 1),
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          _removeItemFromCharacter(charIndex, ii),
                      icon: const Icon(PhosphorIconsBold.minus,
                          size: 14, color: DuckColors.error),
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              );
            }),
          ],

          // Add item button
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 2),
            child: GestureDetector(
              onTap: () => _addItemToCharacter(charIndex),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: DuckColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(PhosphorIconsBold.plus,
                        size: 12, color: DuckColors.primaryDark),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '아이템 추가',
                    style: TextStyle(
                      fontSize: 12,
                      color: DuckColors.primaryDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('카테고리', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: Goods.categories.map((cat) {
            return DuckChip(
              label: Goods.categoryLabel(cat),
              selected: _selectedCategory == cat,
              onTap: () {
                setState(() {
                  _selectedCategory = _selectedCategory == cat ? null : cat;
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildVisibilitySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('공개 범위', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            _visibilityChip('public', '전체 공개', PhosphorIconsBold.globe),
            const SizedBox(width: 8),
            _visibilityChip('friends', '친구 공개', PhosphorIconsBold.users),
            const SizedBox(width: 8),
            _visibilityChip('private', '비공개', PhosphorIconsBold.lock),
          ],
        ),
      ],
    );
  }

  Widget _visibilityChip(String value, String label, IconData icon) {
    final selected = _visibility == value;
    return GestureDetector(
      onTap: () => setState(() => _visibility = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? DuckColors.primaryLight : DuckColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: selected
              ? Border.all(color: DuckColors.primary, width: 2)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: DuckColors.text),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
