import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'config/colors.dart';
import 'features/stats/screens/home_screen.dart';
import 'features/social/screens/feed_screen.dart';
import 'features/calendar/screens/calendar_screen.dart';
import 'features/catalog/screens/catalog_list_screen.dart';
import 'features/social/screens/my_page_screen.dart';
import 'features/catalog/screens/anilist_character_screen.dart';
import 'features/catalog/screens/ocr_import_screen.dart';
import 'features/catalog/screens/pokemon_tcg_search_screen.dart';
import 'features/catalog/screens/catalog_form_screen.dart';
import 'features/catalog/services/catalog_service.dart';
import 'features/goods/screens/goods_input_screen.dart';
import 'features/goods/services/goods_service.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(
        onNavigateToMyPage: () => setState(() => _currentIndex = 4),
      ),
      const FeedScreen(),
      const CalendarScreen(),
      const CatalogListScreen(),
      const MyPageScreen(),
    ];
  }

  final _titles = const [
    'DuckLog',
    '피드',
    '덕질캘린더',
    '도감',
    '마이페이지',
  ];

  void _refreshData() {
    ref.invalidate(goodsListProvider);
    ref.invalidate(monthlySpendingProvider);
  }

  void _navigateToCatalogScreen(Widget screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
    ref.invalidate(myCatalogsProvider);
  }

  void _showCatalogCreateSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: DuckColors.textLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: DuckColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(PhosphorIconsBold.pencilSimple,
                      size: 20, color: DuckColors.outline),
                ),
                title: const Text('직접 만들기'),
                subtitle: const Text('도감 이름과 아이템을 직접 입력해요'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToCatalogScreen(const CatalogFormScreen());
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: DuckColors.tagPhotocard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(PhosphorIconsBold.cards,
                      size: 20, color: DuckColors.outline),
                ),
                title: const Text('포켓몬 카드'),
                subtitle: const Text('카드 세트를 검색해서 도감을 자동 생성해요'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToCatalogScreen(const PokemonTcgSearchScreen());
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: DuckColors.tagFigure,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(PhosphorIconsBold.usersFour,
                      size: 20, color: DuckColors.outline),
                ),
                title: const Text('작품 선택'),
                subtitle: const Text('작품을 검색해서 캐릭터 도감을 만들어요'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToCatalogScreen(const AnilistCharacterScreen());
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: DuckColors.subLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(PhosphorIconsBold.scan,
                      size: 20, color: DuckColors.outline),
                ),
                title: const Text('이미지에서 추출'),
                subtitle: const Text('체크리스트 이미지에서 아이템을 추출해요'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToCatalogScreen(const OcrImportScreen());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddBottomSheet() {
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
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: DuckColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(PhosphorIconsBold.package,
                      size: 20, color: DuckColors.outline),
                ),
                title: const Text('굿즈 등록'),
                subtitle: const Text('직접 입력으로 기록해요'),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => const GoodsInputScreen(),
                    ),
                  );
                  if (result == true) {
                    _refreshData();
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: DuckColors.accentLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(PhosphorIconsBold.receipt,
                      size: 20, color: DuckColors.outline),
                ),
                title: const Text('영수증 촬영'),
                subtitle: const Text('영수증을 찍으면 자동으로 인식해요'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Navigate to receipt OCR screen
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          if (_currentIndex == 0)
            IconButton(
              icon: const Icon(PhosphorIconsBold.bell, size: 22),
              onPressed: () {
                // TODO: Notifications
              },
            ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _currentIndex == 3
            ? _showCatalogCreateSheet
            : _showAddBottomSheet,
        child: const Icon(PhosphorIconsBold.plus, size: 24),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: DuckColors.surface, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: Icon(_currentIndex == 0
                  ? PhosphorIconsFill.house
                  : PhosphorIconsBold.house),
              label: '홈',
            ),
            BottomNavigationBarItem(
              icon: Icon(_currentIndex == 1
                  ? PhosphorIconsFill.newspaper
                  : PhosphorIconsBold.newspaper),
              label: '피드',
            ),
            BottomNavigationBarItem(
              icon: Icon(_currentIndex == 2
                  ? PhosphorIconsFill.calendarDots
                  : PhosphorIconsBold.calendarDots),
              label: '덕질캘린더',
            ),
            BottomNavigationBarItem(
              icon: Icon(_currentIndex == 3
                  ? PhosphorIconsFill.books
                  : PhosphorIconsBold.books),
              label: '도감',
            ),
            BottomNavigationBarItem(
              icon: Icon(_currentIndex == 4
                  ? PhosphorIconsFill.user
                  : PhosphorIconsBold.user),
              label: '마이',
            ),
          ],
        ),
      ),
    );
  }
}
