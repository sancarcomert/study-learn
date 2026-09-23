import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_colors.dart';
import '../app_text_styles.dart';

/// Bir görev tamamlanınca ekranda anlık beliren "+10 XP" — Duolingo tarzı
/// mikro ödül anı. Rütbe/XP zaten hesaplanıyordu (rank_system.dart) ama en
/// sık yapılan eylemde (tek görev tamamlama) hiçbir görünür karşılığı
/// yoktu; günlük hedef/rütbe atlama gibi nadir anlar tam kutlama alırken,
/// en sık eylem yalnızca 1 saniyelik düz bir "Görev tamamlandı!" yazısı
/// alıyordu.
///
/// Bilinçli olarak `Overlay`'e ekleniyor (bir `TaskTile`/`Stack` içine değil)
/// — böylece liste kaydırmasından/kartın sınırlarından etkilenmez, yukarı
/// süzülürken kesilmez. Animasyon bitince kendini kaldırır, hiçbir state
/// bırakmaz. Yalnızca TAMAMLAMADA çağrılmalı — geri almada ASLA (kullanıcı
/// cezalandırılmasın, sadece ödül tek yönlü).
void showXpPopup(BuildContext context, Offset globalCenter, int xp) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  HapticFeedback.mediumImpact();

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _XpPopup(
      center: globalCenter,
      xp: xp,
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _XpPopup extends StatefulWidget {
  final Offset center;
  final int xp;
  final VoidCallback onDone;

  const _XpPopup({
    required this.center,
    required this.xp,
    required this.onDone,
  });

  @override
  State<_XpPopup> createState() => _XpPopupState();
}

class _XpPopupState extends State<_XpPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  late final Animation<double> _rise = Tween<double>(begin: 0, end: -52)
      .chain(CurveTween(curve: Curves.easeOutCubic))
      .animate(_controller);

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
        tween: Tween(begin: 0.5, end: 1.18)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 35),
    TweenSequenceItem(tween: ConstantTween(1.18), weight: 15),
    TweenSequenceItem(
        tween: Tween(begin: 1.18, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 30),
  ]).animate(_controller);

  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 12),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 58),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
  ]).animate(_controller);

  @override
  void initState() {
    super.initState();
    // Reduced-motion: animasyonu atla ama rozeti kısa bir süre sabit
    // göster — tamamen sessiz kalmasın, sadece hareketsiz.
    final reduceMotion = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (reduceMotion) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) widget.onDone();
      });
      return;
    }
    _controller.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [AppColors.glow(AppColors.primary)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded,
              size: 14, color: AppColors.onColor(AppColors.primary)),
          const SizedBox(width: 3),
          Text(
            '+${widget.xp} XP',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.onColor(AppColors.primary),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );

    if (reduceMotion) {
      return Positioned(
        left: widget.center.dx - 34,
        top: widget.center.dy - 14,
        child: IgnorePointer(child: badge),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Positioned(
        left: widget.center.dx - 34,
        top: widget.center.dy + _rise.value - 14,
        child: IgnorePointer(
          child: Opacity(
            opacity: _opacity.value,
            child: Transform.scale(scale: _scale.value, child: child),
          ),
        ),
      ),
      child: badge,
    );
  }
}
