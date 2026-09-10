import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Herhangi bir widget'ı bununla sarmalarsan, dokunulduğunda hafifçe
// küçülüp bırakınca geri büyür - "premium" dokunuş hissi verir.
// Ayrıca hafif bir haptic feedback tetikler - uygulamanın önceden hiç
// dokunsal geri bildirimi yoktu, artık her TapScale kullanan yerde var.
class TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const TapScale({super.key, required this.child, this.onTap});

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  double _scale = 1.0;

  void _setScale(double value) => setState(() => _scale = value);

  @override
  Widget build(BuildContext context) {
    // Erişilebilirlik: "hareketi azalt" açıkken küçülme animasyonunu tamamen
    // atla (dokunma + haptik aynen kalır).
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return GestureDetector(
      // Varsayılan (deferToChild) davranışta, Column/Row gibi kendi arka
      // planını boyamayan child'larda GestureDetector SADECE içerideki
      // çizilen widget'ların (ikon glifi, metin) tam sınırlarını "dokunulur"
      // sayıyor — aralarındaki SizedBox boşlukları görünmez ama gerçek ölü
      // bölge oluyor. Nav bar ve chip gibi küçük hedeflerde parmak birkaç
      // piksel kaysa dokunma hiç algılanmıyordu. opaque, TÜM geometrik
      // alanı tıklanabilir yapar.
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              widget.onTap!();
            },
      onTapDown: reduceMotion ? null : (_) => _setScale(0.96),
      onTapUp: reduceMotion ? null : (_) => _setScale(1.0),
      onTapCancel: reduceMotion ? null : () => _setScale(1.0),
      child: reduceMotion
          ? widget.child
          : AnimatedScale(
              scale: _scale,
              duration: const Duration(milliseconds: 100),
              child: widget.child,
            ),
    );
  }
}