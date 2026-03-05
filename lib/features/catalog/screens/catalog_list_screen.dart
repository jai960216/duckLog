import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/widgets/duck_empty_state.dart';
import '../services/catalog_service.dart';
import '../widgets/catalog_card.dart';
import 'catalog_detail_screen.dart';
import 'catalog_form_screen.dart';
import 'anilist_character_screen.dart';
import 'pokemon_tcg_search_screen.dart';
import 'ocr_import_screen.dart';

class CatalogListScreen extends ConsumerStatefulWidget {
  const CatalogListScreen({super.key});

  @override
  ConsumerState<CatalogListScreen> createState() => _CatalogListScreenState();
}

class _CatalogListScreenState extends ConsumerState<CatalogListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCreateOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: DuckColors.textLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _createOption(
                icon: PhosphorIconsBold.pencilSimple,
                color: DuckColors.primaryLight,
                title: '직접 만들기',
                subtitle: '도감 이름과 아이템을 직접 입력해요',
                onTap: () {
                  Navigator.pop(context);
                  _navigateTo(const CatalogFormScreen());
                },
              ),
              _createOption(
                icon: PhosphorIconsBold.cards,
                color: DuckColors.tagPhotocard,
                title: '포켓몬 카드',
                subtitle: '카드 세트를 검색해서 도감을 자동 생성해요',
                onTap: () {
                  Navigator.pop(context);
                  _navigateTo(const PokemonTcgSearchScreen());
                },
              ),
              _createOption(
                icon: PhosphorIconsBold.usersFour,
                color: DuckColors.tagFigure,
                title: '작품 선택',
                subtitle: '작품을 검색해서 캐릭터 도감을 만들어요',
                onTap: () {
                  Navigator.pop(context);
                  _navigateTo(const AnilistCharacterScreen());
                },
              ),
              _createOption(
                icon: PhosphorIconsBold.scan,
                color: DuckColors.subLight,
                title: '이미지에서 추출',
                subtitle: '체크리스트 이미지에서 아이템을 추출해요',
                onTap: () {
                  Navigator.pop(context);
                  _navigateTo(const OcrImportScreen());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _createOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: DuckColors.outline),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }

  void _navigateTo(Widget screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
    ref.invalidate(myCatalogsProvider);
  }

  void _navigateToDetail(String catalogId) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CatalogDetailScreen(catalogId: catalogId),
      ),
    );
    if (result == true) {
      ref.invalidate(myCatalogsProvider);
      ref.invalidate(publicCatalogsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: DuckColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: DuckColors.background,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: DuckColors.shadow,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: DuckColors.text,
            unselectedLabelColor: DuckColors.textSub,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(text: '내 도감'),
              Tab(text: '둘러보기'),
            ],
          ),
        ),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMyTab(),
              _buildExploreTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMyTab() {
    final asyncCatalogs = ref.watch(myCatalogsProvider);

    return asyncCatalogs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류가 발생했어요: $e')),
      data: (catalogs) {
        if (catalogs.isEmpty) {
          return DuckEmptyState(
            icon: PhosphorIconsBold.books,
            message: '아직 도감이 없어요\n나만의 수집 도감을 만들어보세요!',
            actionText: '도감 만들기',
            onAction: _showCreateOptions,
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myCatalogsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: catalogs.length,
            itemBuilder: (context, index) {
              final catalog = catalogs[index];
              return CatalogCard(
                catalog: catalog,
                onTap: () => _navigateToDetail(catalog.id),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildExploreTab() {
    final asyncCatalogs = ref.watch(publicCatalogsProvider);

    return asyncCatalogs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류가 발생했어요: $e')),
      data: (catalogs) {
        if (catalogs.isEmpty) {
          return const DuckEmptyState(
            icon: PhosphorIconsBold.globe,
            message: '아직 공개된 도감이 없어요',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(publicCatalogsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: catalogs.length,
            itemBuilder: (context, index) {
              final catalog = catalogs[index];
              return CatalogCard(
                catalog: catalog,
                onTap: () => _navigateToDetail(catalog.id),
              );
            },
          ),
        );
      },
    );
  }
}
