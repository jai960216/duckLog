import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'config/colors.dart';
import 'features/stats/screens/home_screen.dart';
import 'features/social/screens/feed_screen.dart';
import 'features/calendar/screens/calendar_screen.dart';
import 'features/collection/screens/collection_screen.dart';
import 'features/social/screens/my_page_screen.dart';
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
      const CollectionScreen(),
      const MyPageScreen(),
    ];
  }

  final _titles = const [
    'DuckLog',
    '피드',
    '캘린더',
    '컬렉션',
    '마이페이지',
  ];

  void _refreshData() {
    ref.invalidate(goodsListProvider);
    ref.invalidate(monthlySpendingProvider);
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
        onPressed: _showAddBottomSheet,
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
              label: '캘린더',
            ),
            BottomNavigationBarItem(
              icon: Icon(_currentIndex == 3
                  ? PhosphorIconsFill.images
                  : PhosphorIconsBold.images),
              label: '컬렉션',
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
