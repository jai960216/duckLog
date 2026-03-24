import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/widgets/widgets.dart';
import '../../goods/services/goods_service.dart';
import '../../goods/screens/goods_detail_screen.dart';

class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  String? _selectedWorkTag;

  @override
  Widget build(BuildContext context) {
    // Fetch goods that have photos
    final goodsAsync = ref.watch(goodsListProvider(
      GoodsFilter(
        workTag: _selectedWorkTag,
        pageSize: 50,
      ),
    ));

    return Column(
      children: [
        // Work tag filter
        SizedBox(
          height: 48,
          child: FutureBuilder<List<String>>(
            future: ref.read(goodsServiceProvider).getWorkTags(),
            builder: (context, snapshot) {
              final tags = snapshot.data ?? [];
              return ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  DuckChip(
                    label: '전체',
                    selected: _selectedWorkTag == null,
                    onTap: () => setState(() => _selectedWorkTag = null),
                  ),
                  ...tags.map((tag) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: DuckChip(
                          label: tag,
                          selected: _selectedWorkTag == tag,
                          onTap: () => setState(() {
                            _selectedWorkTag =
                                _selectedWorkTag == tag ? null : tag;
                          }),
                        ),
                      )),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Gallery grid
        Expanded(
          child: goodsAsync.when(
            data: (goods) {
              final withPhotos =
                  goods.where((g) => g.photoUrls.isNotEmpty).toList();

              if (withPhotos.isEmpty) {
                return const DuckEmptyState(
                  message: '사진이 있는 굿즈가 없어요.\n굿즈 등록 시 사진을 추가해보세요!',
                  icon: PhosphorIconsBold.images,
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 1,
                ),
                itemCount: withPhotos.length,
                itemBuilder: (context, index) {
                  final item = withPhotos[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              GoodsDetailScreen(goodsId: item.id),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: item.photoUrls.first,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(
                          color: DuckColors.surface,
                        ),
                        errorWidget: (_, _, _) => Container(
                          color: DuckColors.surface,
                          child: const Icon(
                            PhosphorIconsBold.imageBroken,
                            color: DuckColors.textSub,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: DuckColors.primary),
            ),
            error: (_, _) => const DuckEmptyState(
              message: '데이터를 불러올 수 없어요.',
              icon: PhosphorIconsBold.warning,
            ),
          ),
        ),
      ],
    );
  }
}
