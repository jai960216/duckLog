import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class DuckLoading extends StatelessWidget {
  final double size;

  const DuckLoading({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Lottie.asset(
        'assets/lottie/duck_loading.json',
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}
