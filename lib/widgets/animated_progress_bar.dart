import 'package:flutter/material.dart';

/// Tüm doğrusal ilerleme çubukları (ders bazlı ilerleme, gün detayı vb.)
/// için tek kaynak — daha önce aynı ClipRRect + LinearProgressIndicator
/// kodu 3 farklı dosyada tekrarlanıyordu. Artık tek yerden değişir ve
/// değer değiştiğinde yumuşak bir animasyonla akar.
class AnimatedProgressBar extends StatelessWidget {
  final double value; // 0.0 - 1.0
  final Color color;
  final Color backgroundColor;
  final double height;
  final double borderRadius;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    required this.color,
    required this.backgroundColor,
    this.height = 8,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, animatedValue, _) {
          return LinearProgressIndicator(
            value: animatedValue,
            minHeight: height,
            backgroundColor: backgroundColor,
            valueColor: AlwaysStoppedAnimation(color),
          );
        },
      ),
    );
  }
}