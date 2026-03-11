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
import 'features/catalog/screens/card_type_select_screen.dart';
import 'features/catalog/screens/direct_catalog_create_screen.dart';
import 'features/catalog/services/catalog_service.dart';
import 'features/calendar/screens/work_search_screen.dart';
import 'features/calendar/services/calendar_service.dart';
import 'features/goods/screens/goods_input_screen.dart';
import 'features/goods/screens/receipt_scan_screen.dart';
import 'features/goods/services/goods_service.dart';
import 'features/social/screens/notification_settings_screen.dart';
import 'shared/utils/formatters.dart';
import 'shared/widgets/widgets.dart';

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
    ref.invalidate(monthlyStatsProvider);
  }

  Future<void> _navigateToCatalogScreen(Widget screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
    if (!mounted) return;
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
                subtitle: const Text('캐릭터와 아이템을 직접 입력해요'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToCatalogScreen(const DirectCatalogCreateScreen());
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
                title: const Text('카드 도감'),
                subtitle: const Text('포켓몬·유희왕·MTG·디지몬 카드 도감을 만들어요'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToCatalogScreen(const CardTypeSelectScreen());
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
                title: const Text('영수증 보관'),
                subtitle: const Text('영수증을 찍어서 보관해요'),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ReceiptScanScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCalendarAddSheet() {
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
                  child: const Icon(PhosphorIconsBold.calendarPlus,
                      size: 20, color: DuckColors.outline),
                ),
                title: const Text('일정 추가'),
                subtitle: const Text('커스텀 일정을 추가해요'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddCustomEventDialog();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: DuckColors.subLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(PhosphorIconsBold.plusCircle,
                      size: 20, color: DuckColors.outline),
                ),
                title: const Text('작품 추가'),
                subtitle: const Text('작품을 팔로우해서 일정을 받아요'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const WorkSearchScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddCustomEventDialog() async {
    final titleController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('일정 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  hintText: '일정 제목',
                  prefixIcon: Icon(PhosphorIconsBold.notepad, size: 20),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setDialogState(() => selectedDate = picked);
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: DuckColors.textLight),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(PhosphorIconsBold.calendar,
                          size: 20, color: DuckColors.textSub),
                      const SizedBox(width: 8),
                      Text(Formatters.date(selectedDate)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );

    if (result == true && titleController.text.trim().isNotEmpty) {
      try {
        final service = ref.read(calendarServiceProvider);
        await service.addCustomEvent(
          title: titleController.text.trim(),
          eventDate: selectedDate,
        );
        final key =
            '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}';
        ref.invalidate(monthAiringScheduleProvider(key));
        if (mounted) {
          DuckSnackBar.success(context, '일정이 추가되었어요.');
        }
      } catch (e) {
        debugPrint('일정 추가 실패: $e');
        if (mounted) {
          DuckSnackBar.error(context, '일정 추가 실패');
        }
      }
    }
    titleController.dispose();
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
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const NotificationSettingsScreen()),
                );
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
            : _currentIndex == 2
                ? _showCalendarAddSheet
                : _showAddBottomSheet,
        child: const Icon(PhosphorIconsBold.plus, size: 24),
      ),
      bottomNavigationBar: BottomNavigationBar(
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
    );
  }
}
