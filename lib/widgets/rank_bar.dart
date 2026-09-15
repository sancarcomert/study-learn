import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../rank_system.dart';

/// 6 parçalı rütbe çubuğu — soğuktan sıcağa bir renk merdiveni (yeşil → kor).
/// Geçilen rütbeler kendi renginde dolu, gelecek rütbeler soluk ama **görünür**
/// (yolculuğu gözle gör), şu anki parça ilerlemeye göre akıcı dolar + parlar.
class RankBar extends StatelessWidget {
  final RankInfo info;
  final double height;

  const RankBar({super.key, required this.info, this.height = 12});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < 6; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              child: _Segment(
                color: Color(RankSystem.colors[i]),
                state: i < info.rank - 1
                    ? _SegState.done
                    : i == info.rank - 1
                        ? _SegState.current
                        : _SegState.upcoming,
                fill: i == info.rank - 1 ? info.progress : 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _SegState { done, current, upcoming }

class _Segment extends StatelessWidget {
  final Color color;
  final _SegState state;
  final double fill;

  const _Segment({
    required this.color,
    required this.state,
    required this.fill,
  });

  static final _radius = BorderRadius.circular(3);

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _SegState.done:
        return DecoratedBox(
          decoration: BoxDecoration(color: color, borderRadius: _radius),
        );

      case _SegState.upcoming:
        // Çerçeveli — koyu zeminde her hue net ayrışır (dolu + soluk olunca
        // sıcak renkler birbirine benziyordu).
        return DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: _radius,
            border: Border.all(
              color: color.withValues(alpha: 0.65),
              width: 1.3,
            ),
          ),
        );

      case _SegState.current:
        return ClipRRect(
          borderRadius: _radius,
          child: Stack(
            children: [
              const Positioned.fill(
                child: ColoredBox(color: AppColors.surfaceVariant),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fill.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: v <= 0 ? 0.0001 : v,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.85),
                          blurRadius: 15,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // "Buradasın" — parça çevresinde parlak kenarlık.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: _radius,
                    border: Border.all(color: color, width: 1.4),
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }
}
