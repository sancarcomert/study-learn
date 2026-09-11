import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 6 rütbenin amblemi — elle işlenmiş akademik madalya SVG'leri
/// (`assets/ranks/rank_N.svg`). Yıldızlı bir madalya + kurdele; rütbe
/// yükseldikçe defne çelengi ve kenar tırtılı zenginleşir. Maskot değil,
/// nesne — eğitim/başarı bağlamına uygun. SVG kendi rengini taşır (rütbe
/// renk rampasıyla aynı).
class RankEmblem extends StatelessWidget {
  final int rank; // 1..6
  final double size;

  const RankEmblem({super.key, required this.rank, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final r = rank.clamp(1, 6);
    return SvgPicture.asset(
      'assets/ranks/rank_$r.svg',
      width: size,
      height: size,
    );
  }
}
