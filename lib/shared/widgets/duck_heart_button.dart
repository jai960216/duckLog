import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../config/colors.dart';

class DuckHeartButton extends StatefulWidget {
  final bool isLiked;
  final int likeCount;
  final VoidCallback? onTap;
  final double size;

  const DuckHeartButton({
    super.key,
    required this.isLiked,
    this.likeCount = 0,
    this.onTap,
    this.size = 22,
  });

  @override
  State<DuckHeartButton> createState() => _DuckHeartButtonState();
}

class _DuckHeartButtonState extends State<DuckHeartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  bool _wasLiked = false;

  @override
  void initState() {
    super.initState();
    _wasLiked = widget.isLiked;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(DuckHeartButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_wasLiked && widget.isLiked) {
      _controller.forward(from: 0);
    }
    _wasLiked = widget.isLiked;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Icon(
                  widget.isLiked
                      ? PhosphorIconsFill.heart
                      : PhosphorIconsBold.heart,
                  size: widget.size,
                  color: widget.isLiked ? DuckColors.error : DuckColors.textSub,
                ),
              );
            },
          ),
          if (widget.likeCount > 0) ...[
            const SizedBox(width: 4),
            Text(
              '${widget.likeCount}',
              style: TextStyle(
                fontSize: widget.size * 0.6,
                color: widget.isLiked ? DuckColors.error : DuckColors.textSub,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
