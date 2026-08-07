import 'package:flutter/material.dart';

/// Tüm dairesel ilerleme göstergeleri (Hero card yüzdesi, Smart Plan
/// kapasite halkası) için tek kaynak. Değer değiştiğinde anında
/// zıplamak yerine yumuşakça oraya doğru animasyonla akar.
class AnimatedProgressRing extends StatelessWidget {
  final double value; // 0.0 - 1.0
  final double size;
  final double strokeWidth;
  final Color color;
  final Color backgroundColor;
  final Widget? center;

  const AnimatedProgressRing({
    super.key,
    required this.value,
    required this.color,
    required this.backgroundColor,
    this.size = 52,
    this.strokeWidth = 5,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, animatedValue, _) {
              return SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: animatedValue,
                  strokeWidth: strokeWidth,
                  backgroundColor: backgroundColor,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              );
            },
          ),
          if (center != null) center!,
        ],
      ),
    );
  }
}