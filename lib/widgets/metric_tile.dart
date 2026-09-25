import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_text_styles.dart';

/// Uygulama genelinde tek "durağan istatistik kartı" deseni (2026-09-16,
/// Home'un yeni turuncu/amber konseptinden taşındı) — ikon + küçük harf
/// etiket üstte, büyük değer (+ opsiyonel birim) altta. Bağımsız bir satırda
/// yan yana duran kartlar için (ör. "18.5 Saat" / "8 Görev"). Bir hero
/// kartın İÇİNE gömülü, daha küçük/gölgesiz metrik hücreleri (Home'un
/// _HeroMetric'i, Rütbeler'in _CharStat'ı) bilerek bunun dışında —
/// iç içe kart/gölge oluşturmamak için ayrı kalıyorlar.
class MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? unit;

  const MetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppTextStyles.heading2.copyWith(letterSpacing: -0.3)),
              ),
              if (unit != null) ...[
                const SizedBox(width: 6),
                Text(unit!,
                    style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
