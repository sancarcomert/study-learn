import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_text_styles.dart';
import '../tap_scale.dart';

/// Uygulama genelinde tek bir alt nav tanımı. Her sekme kendi vurgu rengini
/// taşır (2026-09 canlı/çok renkli tasarım geçişi) — seçili sekme, o rengin
/// tonunda dolu bir "hap" (pill) rozetinde belirir; Anadolu Mobil/LearnUp
/// referans görsellerindeki dolu-hap seçim deseniyle aynı dil, tek altın
/// nokta göstergesi yerine.
class AppBottomNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Color color;

  const AppBottomNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.color,
  });
}

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<AppBottomNavItem> items;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: AppColors.softShadow,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 82,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: Row(
              children: List.generate(items.length, (index) {
                final item = items[index];
                final isSelected = index == currentIndex;

                return Expanded(
                  child: TapScale(
                    onTap: () => onTap(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? item.color.withValues(alpha: 0.22)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        border: isSelected
                            ? Border.all(
                                color: item.color.withValues(alpha: 0.4))
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isSelected ? item.selectedIcon : item.icon,
                            color:
                                isSelected ? item.color : AppColors.textMuted,
                            size: 23,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.label,
                            style: AppTextStyles.caption.copyWith(
                              color:
                                  isSelected ? item.color : AppColors.textMuted,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Aktif sekmeyi tek bakışta belli eden ince alt
                          // çizgi — pil rengiyle birlikte çift sinyal.
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            width: isSelected ? 16 : 0,
                            height: 3,
                            decoration: BoxDecoration(
                              color: item.color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
