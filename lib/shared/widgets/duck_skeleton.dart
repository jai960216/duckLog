import 'package:flutter/material.dart';
import '../../config/colors.dart';

/// Shimmer 효과가 적용된 스켈레톤 로더
class DuckSkeleton extends StatefulWidget {
  final Widget child;

  const DuckSkeleton({super.key, required this.child});

  @override
  State<DuckSkeleton> createState() => _DuckSkeletonState();
}

class _DuckSkeletonState extends State<DuckSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFFE8E6E1),
                Color(0xFFF5F3EE),
                Color(0xFFE8E6E1),
              ],
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ].map((s) => s.clamp(0.0, 1.0)).toList(),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// 스켈레톤 박스 (둥근 사각형 플레이스홀더)
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: DuckColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// 스켈레톤 원 (아바타 플레이스홀더)
class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: DuckColors.surface,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// 굿즈 카드 스켈레톤
class GoodsCardSkeleton extends StatelessWidget {
  const GoodsCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: DuckColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DuckColors.surface, width: 1.5),
        ),
        child: Row(
          children: [
            const SkeletonBox(width: 56, height: 56, borderRadius: 12),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 120, height: 14, borderRadius: 4),
                  const SizedBox(height: 8),
                  SkeletonBox(width: 80, height: 12, borderRadius: 4),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      SkeletonBox(width: 50, height: 20, borderRadius: 10),
                      const SizedBox(width: 6),
                      SkeletonBox(width: 60, height: 20, borderRadius: 10),
                    ],
                  ),
                ],
              ),
            ),
            SkeletonBox(width: 60, height: 16, borderRadius: 4),
          ],
        ),
      ),
    );
  }
}

/// 피드 카드 스켈레톤
class FeedCardSkeleton extends StatelessWidget {
  const FeedCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: DuckColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DuckColors.surface, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SkeletonCircle(size: 36),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 80, height: 12, borderRadius: 4),
                    const SizedBox(height: 4),
                    SkeletonBox(width: 50, height: 10, borderRadius: 4),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SkeletonBox(width: double.infinity, height: 14, borderRadius: 4),
            const SizedBox(height: 8),
            SkeletonBox(width: 160, height: 12, borderRadius: 4),
            const SizedBox(height: 10),
            Row(
              children: [
                SkeletonBox(width: 50, height: 22, borderRadius: 11),
                const SizedBox(width: 6),
                SkeletonBox(width: 60, height: 22, borderRadius: 11),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 도감 카드 스켈레톤
class CatalogCardSkeleton extends StatelessWidget {
  const CatalogCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: DuckColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DuckColors.surface, width: 1.5),
        ),
        child: Row(
          children: [
            const SkeletonBox(width: 64, height: 64, borderRadius: 14),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 140, height: 14, borderRadius: 4),
                  const SizedBox(height: 8),
                  SkeletonBox(width: 100, height: 12, borderRadius: 4),
                  const SizedBox(height: 8),
                  SkeletonBox(width: double.infinity, height: 6, borderRadius: 3),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 리스트 스켈레톤 (여러 아이템 반복)
class DuckListSkeleton extends StatelessWidget {
  final Widget itemSkeleton;
  final int itemCount;

  const DuckListSkeleton({
    super.key,
    required this.itemSkeleton,
    this.itemCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return DuckSkeleton(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (_, __) => itemSkeleton,
      ),
    );
  }
}
