import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_text_styles.dart';
import '../tap_scale.dart';

// EDİTORYAL REDESIGN (2026-09): Referans görseldeki alt nav — ince outline
// ikon + aktif sekmenin altında küçük bir altın nokta. Stock Material
// `NavigationBar`'ın "pill indicator" deseni bu görsel dile uymuyor (ve
// dokunuşta göstergeyi ikonun ALTINA değil ARKASINA koyuyor), o yüzden bu
// dosya onun yerini alan, MainShell'in aynı index/state mantığını
// kullanan salt-görsel bir alt bar. Navigasyon davranışı (seçili index,
// ekran değişimi) MainShell'de hiç değişmedi — sadece bu widget'a taşındı.
class AppBottomNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const AppBottomNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
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
        boxShadow: AppColors.softShadow,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = index == currentIndex;

              return Expanded(
                child: TapScale(
                  onTap: () => onTap(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isSelected ? item.selectedIcon : item.icon,
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: AppTextStyles.caption.copyWith(
                          // Aktif sekme etiketi: seçili ikonla aynı açık ton.
                          // `ink` (neredeyse siyah) koyu nav zemininde
                          // görünmüyordu — karar C.
                          color: isSelected
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      // Sabit boyutlu nokta yuvası — seçili olmayan
                      // sekmelerde şeffaf kalır, böylece seçim değişince
                      // satır yüksekliği zıplamaz.
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
