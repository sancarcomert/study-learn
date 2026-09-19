import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_text_styles.dart';
import '../tap_scale.dart';
import 'rank_emblem.dart';

/// Uygulama genelinde tek üst marka satırı — Figma'daki "Mentora" wordmark
/// + sağda profil rozeti deseni (uygulama adı burada "Dodom", bkz. CLAUDE.md
/// marka kimliği). Önceden yalnız home_screen.dart içinde yerel bir widget'tı
/// ("_MentoraHeader") — Dersler ve Koç ekranlarında da AYNI header
/// gösterilmesi gerektiği için (Figma'nın üç referansında da birebir aynı
/// satır var) paylaşılan bir bileşene çıkarıldı; üç dosyada aynı tasarım
/// değerinin tekrar tekrar kopyalanmasını önler.
class AppHeader extends StatefulWidget {
  final String? initial;
  final int rank;
  final VoidCallback onProfileTap;
  final VoidCallback onRankTap;

  const AppHeader({
    super.key,
    required this.initial,
    required this.rank,
    required this.onProfileTap,
    required this.onRankTap,
  });

  @override
  State<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    final reduceMotion = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (!reduceMotion) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Dodom',
          style: AppTextStyles.heading3.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Semantics(
                button: true,
                label: 'Profil',
                child: TapScale(
                  onTap: widget.onProfileTap,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final t = _controller.value;
                      return Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.avatarFill,
                          border: Border.all(
                              color: AppColors.avatarRing, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.avatarRing
                                  .withValues(alpha: 0.25 - t * 0.1),
                              blurRadius: 8 + t * 6,
                              spreadRadius: t * 1.5,
                            ),
                          ],
                        ),
                        child: widget.initial == null
                            ? const Icon(Icons.person_outline,
                                size: 19, color: AppColors.avatarRing)
                            : Text(
                                widget.initial!,
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.avatarRing,
                                ),
                              ),
                      );
                    },
                  ),
                ),
              ),
              // Rütbe rozeti — avatarın köşesinde, Profil'e girmeden
              // rütbenin var olduğunu ve seviyesini gösterir. Dokununca
              // doğrudan Rütbeler ekranına gider.
              Positioned(
                right: -2,
                bottom: -2,
                child: Semantics(
                  button: true,
                  label: 'Rütbeler',
                  child: TapScale(
                    onTap: widget.onRankTap,
                    child: Container(
                      width: 22,
                      height: 22,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.background,
                        border:
                            Border.all(color: AppColors.background, width: 2),
                        boxShadow: AppColors.softShadow,
                      ),
                      child: RankEmblem(rank: widget.rank, size: 18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Figma'daki üç ekranın da (Ana Sayfa, Dersler, Koç) ortak ikinci satırı —
/// rose eyebrow + büyük başlık + gri alt açıklama. Home'da tarih+selam,
/// Dersler'de "ÖĞRENME ALANIN"+"Dersler", Koç'ta "YAPAY ZEKA ÖĞRETMENİN"+
/// "Birlikte çözelim" için aynı tipografik iskelet kullanılıyor.
class AppTitleBlock extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;

  /// Başlığın sağında, aynı satırda opsiyonel bir aksiyon (ör. Görevler'in
  /// "Bugün" atlama butonu) — Figma'nın 3 referansında yok ama bazı
  /// ekranların kendi işlevini korumak için gerekli; verilmezse satır
  /// yalnız başlığı gösterir (Figma'daki üç ekranla birebir aynı).
  final Widget? trailing;

  const AppTitleBlock({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: AppTextStyles.eyebrow.copyWith(color: AppColors.eyebrowRose),
        ),
        const SizedBox(height: 6),
        if (trailing == null)
          Text(title, style: AppTextStyles.heading1)
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(title, style: AppTextStyles.heading1),
              trailing!,
            ],
          ),
        const SizedBox(height: 4),
        Text(subtitle, style: AppTextStyles.bodySecondary),
      ],
    );
  }
}
