import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/colors.dart';
import '../../../shared/models/goods.dart';
import '../../../shared/utils/image_quality.dart';
import '../../../shared/utils/profanity_filter.dart';
import '../../../shared/widgets/widgets.dart';
import '../screens/anilist_character_picker_screen.dart';

/// 아이템 편집 데이터 (UI 전용)
class ItemSetupData {
  String? id; // 기존 아이템 ID (null이면 신규)
  String name;
  String? category; // 아이템별 카테고리

  ItemSetupData({this.id, required this.name, this.category});
}

/// 캐릭터+아이템 편집 데이터 (UI 전용)
class CharacterSetupData {
  String? id; // 기존 캐릭터 ID (null이면 신규)
  String name;
  String? photoUrl;
  String? externalId;
  XFile? newPhotoFile; // 갤러리에서 선택한 로컬 사진
  List<ItemSetupData> items;

  CharacterSetupData({
    this.id,
    required this.name,
    this.photoUrl,
    this.externalId,
    this.newPhotoFile,
    List<ItemSetupData>? items,
  }) : items = items ?? [];
}

/// 도감 설정 공용 위젯 — 생성 Step 2 / 수정 모드 공유
class CatalogSetupForm extends StatefulWidget {
  final String? initialName;
  final List<String> initialCategories;
  final String? initialWorkTag;
  final String initialVisibility;
  final List<CharacterSetupData> characters;
  final bool isEditing;
  final bool hideCharacters;
  final String? initialCoverUrl;
  final double initialCoverFitX;
  final double initialCoverFitY;
  final double initialCoverScale;
  final bool isPro;
  final bool isLoading;
  final Future<void> Function({
    required String name,
    required List<String> categories,
    required String? workTag,
    required String visibility,
    required List<CharacterSetupData> characters,
    required String? coverUrl,
    required XFile? newCoverPhoto,
    required double coverFitX,
    required double coverFitY,
    required double coverScale,
  }) onSubmit;

  const CatalogSetupForm({
    super.key,
    this.initialName,
    this.initialCategories = const [],
    this.initialWorkTag,
    this.initialCoverUrl,
    this.initialCoverFitX = 0.5,
    this.initialCoverFitY = 0.5,
    this.initialCoverScale = 1.0,
    this.initialVisibility = 'private',
    required this.characters,
    this.isEditing = false,
    this.hideCharacters = false,
    this.isPro = false,
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
  late List<String> _selectedCategories;
  late String _visibility;
  late List<CharacterSetupData> _characters;
  String? _coverUrl;
  XFile? _newCoverPhoto;
  late double _coverFitX;
  late double _coverFitY;
  late double _coverScale;
  double _baseScale = 1.0;
  Uint8List? _cachedCoverBytes;
  bool _isPicking = false;
  bool _isLoading = false;

  // Cached controllers for character/item name fields (keyed by object identity)
  final Map<int, TextEditingController> _charNameControllers = {};
  final Map<int, TextEditingController> _itemNameControllers = {};

  TextEditingController _charController(CharacterSetupData ch) {
    final key = identityHashCode(ch);
    return _charNameControllers.putIfAbsent(
      key,
      () => TextEditingController(text: ch.name),
    );
  }

  TextEditingController _itemController(ItemSetupData item) {
    final key = identityHashCode(item);
    return _itemNameControllers.putIfAbsent(
      key,
      () => TextEditingController(text: item.name),
    );
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _workTagController = TextEditingController(text: widget.initialWorkTag ?? '');
    _selectedCategories = List<String>.from(widget.initialCategories);
    _visibility = widget.initialVisibility;
    _coverUrl = widget.initialCoverUrl;
    _coverFitX = widget.initialCoverFitX;
    _coverFitY = widget.initialCoverFitY;
    _coverScale = widget.initialCoverScale;
    _characters = widget.characters.map((c) => CharacterSetupData(
      id: c.id,
      name: c.name,
      photoUrl: c.photoUrl,
      externalId: c.externalId,
      newPhotoFile: c.newPhotoFile,
      items: c.items.map((i) => ItemSetupData(id: i.id, name: i.name)).toList(),
    )).toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _workTagController.dispose();
    for (final c in _charNameControllers.values) {
      c.dispose();
    }
    for (final c in _itemNameControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // 작품태그 + 캐릭터/아이템 이름 금칙어 검사
    final workTag = _workTagController.text.trim();
    if (workTag.isNotEmpty && ProfanityFilter.containsProfanity(workTag)) {
      DuckSnackBar.error(context, '작품/콘텐츠에 부적절한 표현이 포함되어 있어요');
      return;
    }
    for (final ch in _characters) {
      if (ProfanityFilter.containsProfanity(ch.name)) {
        DuckSnackBar.error(context, '캐릭터 이름에 부적절한 표현이 포함되어 있어요');
        return;
      }
      for (final item in ch.items) {
        if (ProfanityFilter.containsProfanity(item.name)) {
          DuckSnackBar.error(context, '아이템 이름에 부적절한 표현이 포함되어 있어요');
          return;
        }
      }
    }

    setState(() => _isLoading = true);
    try {
      await widget.onSubmit(
        name: _nameController.text.trim(),
        categories: _selectedCategories,
        workTag: workTag.isEmpty ? null : workTag,
        visibility: _visibility,
        characters: _characters,
        coverUrl: _coverUrl,
        newCoverPhoto: _newCoverPhoto,
        coverFitX: _coverFitX,
        coverFitY: _coverFitY,
        coverScale: _coverScale,
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
    final item = _characters[charIndex].items[itemIndex];
    final key = identityHashCode(item);
    _itemNameControllers.remove(key)?.dispose();
    setState(() {
      _characters[charIndex].items.removeAt(itemIndex);
    });
  }

  void _addCharacter() {
    showModalBottomSheet(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: DuckColors.textLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(PhosphorIconsBold.magnifyingGlass),
              title: const Text('작품에서 선택'),
              subtitle: const Text('AniList에서 캐릭터를 검색해요'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickFromAnilist();
              },
            ),
            ListTile(
              leading: const Icon(PhosphorIconsBold.pencilSimple),
              title: const Text('직접 추가'),
              subtitle: const Text('캐릭터를 직접 입력해요'),
              onTap: () {
                Navigator.pop(sheetCtx);
                setState(() {
                  _characters.add(CharacterSetupData(
                    name: '캐릭터 ${_characters.length + 1}',
                    items: [ItemSetupData(name: '아이템')],
                  ));
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromAnilist() async {
    final result = await Navigator.of(context).push<List<CharacterSetupData>>(
      MaterialPageRoute(
        builder: (_) => const AnilistCharacterPickerScreen(),
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() {
        _characters.addAll(result);
      });
    }
  }

  void _removeCharacter(int charIndex) {
    final ch = _characters[charIndex];
    // Dispose controllers for this character and its items
    _charNameControllers.remove(identityHashCode(ch))?.dispose();
    for (final item in ch.items) {
      _itemNameControllers.remove(identityHashCode(item))?.dispose();
    }
    setState(() {
      _characters.removeAt(charIndex);
    });
  }

  void _onReorderCharacters(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _characters.removeAt(oldIndex);
      _characters.insert(newIndex, item);
    });
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
              _buildCoverSection(),
              const SizedBox(height: 16),
              DuckTextField(
                label: '도감 이름',
                hint: '예: 귀멸의 칼날 피규어 컬렉션',
                controller: _nameController,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '도감 이름을 입력해주세요';
                  return ProfanityFilter.validate(v);
                },
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
              if (widget.hideCharacters)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: DuckColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(PhosphorIconsBold.info,
                          size: 18, color: DuckColors.textSub),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '개별 카드의 이름·사진 수정은 도감 화면에서\n카드를 탭하여 변경할 수 있어요.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: DuckColors.text,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!widget.hideCharacters && _characters.isNotEmpty) ...[
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
          padding: EdgeInsets.fromLTRB(
            0, 12, 0,
            20 + MediaQuery.of(context).viewPadding.bottom,
          ),
          child: Column(
            children: [
              if (!widget.hideCharacters)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _addCharacter,
                      icon: const Icon(PhosphorIconsBold.plus, size: 16),
                      label: const Text('캐릭터 추가'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DuckColors.primaryDark,
                        side: const BorderSide(color: DuckColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: DuckButton(
                  text: widget.isEditing ? '수정 완료' : '만들기',
                  onPressed: _submit,
                  isLoading: loading,
                ),
              ),
            ],
          ),
        ),
        itemCount: widget.hideCharacters ? 0 : _characters.length,
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
              // Image (tap to pick photo)
              GestureDetector(
                onTap: () => _pickCharacterPhoto(charIndex),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (ch.newPhotoFile != null)
                          FutureBuilder<List<int>>(
                            future: ch.newPhotoFile!.readAsBytes(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return Image.memory(
                                  snapshot.data! as dynamic,
                                  fit: BoxFit.cover,
                                );
                              }
                              return Container(color: DuckColors.textLight);
                            },
                          )
                        else if (ch.photoUrl != null)
                          CachedNetworkImage(
                            imageUrl: ch.photoUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, _) =>
                                Container(color: DuckColors.textLight),
                            errorWidget: (_, _, _) => Container(
                              color: DuckColors.textLight,
                              child: const Icon(PhosphorIconsBold.user,
                                  size: 18, color: DuckColors.textSub),
                            ),
                          )
                        else
                          Container(
                            color: DuckColors.textLight,
                            child: const Icon(PhosphorIconsBold.user,
                                size: 18, color: DuckColors.textSub),
                          ),
                        // Camera overlay
                        if (ch.newPhotoFile != null || ch.photoUrl != null)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(6),
                                ),
                              ),
                              child: const Icon(PhosphorIconsBold.camera,
                                  size: 10, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _charController(ch),
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
              final item = ch.items[ii];
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 8),
                        const Icon(PhosphorIconsBold.dotOutline,
                            size: 12, color: DuckColors.textSub),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 36,
                            child: TextField(
                              controller: _itemController(item),
                              onChanged: (v) => item.name = v,
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
                    // 아이템 카테고리 선택
                    Padding(
                      padding: const EdgeInsets.only(left: 28, top: 4, bottom: 4),
                      child: _buildItemCategoryChips(item),
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

  Widget _buildItemCategoryChips(ItemSetupData item) {
    return SizedBox(
      height: 28,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: Goods.categories.map((cat) {
          final selected = item.category == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  item.category = selected ? null : cat;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? DuckColors.primaryLight
                      : DuckColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: selected
                      ? Border.all(color: DuckColors.primary, width: 1)
                      : null,
                ),
                child: Text(
                  Goods.categoryLabel(cat),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? DuckColors.primaryDark : DuckColors.textSub,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _pickCharacterPhoto(int charIndex) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _characters[charIndex].newPhotoFile = picked);
    }
  }

  ImageQualitySettings get _iq => ImageQualitySettings.fromPro(widget.isPro);

  Future<void> _pickCoverImage() async {
    if (_isPicking) return;
    _isPicking = true;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: _iq.maxWidth,
        imageQuality: _iq.quality,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _newCoverPhoto = picked;
          _cachedCoverBytes = bytes;
          _coverFitX = 0.5;
          _coverFitY = 0.5;
        _coverScale = 1.0;
      });
    }
    } finally {
      _isPicking = false;
    }
  }

  void _removeCoverImage() {
    setState(() {
      _coverUrl = null;
      _newCoverPhoto = null;
      _cachedCoverBytes = null;
      _coverFitX = 0.5;
      _coverFitY = 0.5;
      _coverScale = 1.0;
    });
  }

  Widget _buildCoverSection() {
    final hasCover = _newCoverPhoto != null || _coverUrl != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('커버 이미지', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            if (hasCover)
              GestureDetector(
                onTap: _removeCoverImage,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(PhosphorIconsBold.x,
                      size: 18, color: DuckColors.textSub),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_cachedCoverBytes != null)
          _buildCropGuideOverlay(
            Image.memory(
              _cachedCoverBytes!,
              fit: BoxFit.cover,
              alignment: Alignment(0, _coverFitY * 2 - 1),
              width: double.infinity,
              height: 280,
            ),
          )
        else if (_coverUrl != null)
          _buildCropGuideOverlay(
            CachedNetworkImage(
              imageUrl: _coverUrl!,
              fit: BoxFit.cover,
              alignment: Alignment(0, _coverFitY * 2 - 1),
              width: double.infinity,
              height: 280,
              placeholder: (_, _) =>
                  Container(height: 280, color: DuckColors.surface),
              errorWidget: (_, _, _) =>
                  _buildCoverPlaceholder(),
            ),
          )
        else
          GestureDetector(
            onTap: _pickCoverImage,
            child: _buildCoverPlaceholder(),
          ),
        if (hasCover) ...[
          const SizedBox(height: 6),
          const Center(
            child: Text(
              '드래그 또는 핀치하여 커버 영역을 조정할 수 있어요',
              style: TextStyle(fontSize: 12, color: DuckColors.textSub),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCropGuideOverlay(Widget imageWidget) {
    return SizedBox(
      height: 280,
      width: double.infinity,
      child: Stack(
        children: [
          // 드래그/핀치 영역
          Positioned.fill(
            child: RawGestureDetector(
              gestures: {
                _EagerScaleGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                        _EagerScaleGestureRecognizer>(
                  () => _EagerScaleGestureRecognizer(),
                  (instance) {
                    instance
                      ..onStart = (_) {
                        _baseScale = _coverScale;
                      }
                      ..onUpdate = (details) {
                        setState(() {
                          _coverScale =
                              (_baseScale * details.scale).clamp(1.0, 3.0);
                          _coverFitX = (_coverFitX -
                                  details.focalPointDelta.dx /
                                      (280 * _coverScale))
                              .clamp(0.0, 1.0);
                          _coverFitY = (_coverFitY -
                                  details.focalPointDelta.dy /
                                      (280 * _coverScale))
                              .clamp(0.0, 1.0);
                        });
                      };
                  },
                ),
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxTx =
                        constraints.maxWidth * (_coverScale - 1) / 2;
                    final tx = (1 - _coverFitX * 2) * maxTx;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..translate(tx, 0.0)
                            ..scale(_coverScale, _coverScale),
                          child: imageWidget,
                        ),
                        // Top dark overlay
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 80,
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                        ),
                        // Bottom dark overlay
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 80,
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                        ),
                        // Center cover area border + label
                        Positioned(
                          top: 80,
                          left: 0,
                          right: 0,
                          height: 120,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.symmetric(
                                horizontal: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '커버에 표시되는 영역',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          // 이미지 변경 버튼 (RawGestureDetector 바깥)
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: _pickCoverImage,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(PhosphorIconsBold.camera,
                    size: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverPlaceholder() {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: DuckColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DuckColors.textLight, width: 1.5),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIconsBold.image,
              size: 28, color: DuckColors.textSub),
          SizedBox(height: 6),
          Text(
            '탭하여 커버 이미지 추가',
            style: TextStyle(fontSize: 12, color: DuckColors.textSub),
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
        const SizedBox(height: 4),
        const Text(
          '여러 개 선택할 수 있어요',
          style: TextStyle(fontSize: 12, color: DuckColors.textSub),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: Goods.categories.map((cat) {
            final selected = _selectedCategories.contains(cat);
            return DuckChip(
              label: Goods.categoryLabel(cat),
              selected: selected,
              onTap: () {
                setState(() {
                  if (selected) {
                    _selectedCategories.remove(cat);
                  } else {
                    _selectedCategories.add(cat);
                  }
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

class _EagerScaleGestureRecognizer extends ScaleGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
