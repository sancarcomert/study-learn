import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'widgets/eyebrow.dart';

/// "Verin Sende" şeffaflık ekranı — docs/pusula_savas_plani_2026-09.md §5
/// "Katil özellik önerileri #1". Rakip araştırmasında görülen somut güven
/// açıklarına (veri silinemiyor, iade sözü tutulmuyor, gizli veri toplama)
/// karşı soyut bir slogan değil, kod/manifest'ten doğrulanabilir iddialar.
/// Hiçbir rakip ismi geçmez — kıyas dışarıda (Play açıklaması/pazarlama),
/// burada yalnız kendi somut gerçeğimiz var.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Hakkında', style: AppTextStyles.heading2),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Eyebrow(text: 'VERİN SENDE'),
          const SizedBox(height: 10),
          Text(
            'Bunlar soyut bir vaat değil — kontrol edebileceğin, '
            'doğrulayabileceğin gerçekler.',
            style: AppTextStyles.bodySecondary,
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppColors.softShadow,
            ),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.wifi_off_outlined,
                  tint: AppColors.secondary,
                  title: 'İnternete hiç bağlanmaz',
                  subtitle:
                      'İnternet izni bile yok. Sunucumuz olmadığı için '
                      'verini sızdıramayız — çünkü hiçbir yere gitmiyor.',
                ),
                _divider(),
                _InfoRow(
                  icon: Icons.no_accounts_outlined,
                  tint: AppColors.secondary,
                  title: 'Hesap yok',
                  subtitle: 'E-posta, şifre ya da telefon numarası '
                      'istemeyiz. Açar açmaz kullanmaya başlarsın.',
                ),
                _divider(),
                _InfoRow(
                  icon: Icons.smartphone_outlined,
                  tint: AppColors.secondary,
                  title: 'Verin yalnızca bu cihazda',
                  subtitle: 'Dersler, görevler, konular, denemeler — '
                      'hepsi telefonunda saklanır. Biz de göremeyiz.',
                ),
                _divider(),
                _InfoRow(
                  icon: Icons.upload_file_outlined,
                  tint: AppColors.secondary,
                  title: 'Yedek her zaman elinde',
                  subtitle: 'İstediğin an tüm verini tek dosyaya '
                      'aktarabilir, istediğin yere taşıyabilirsin.',
                ),
                _divider(),
                _InfoRow(
                  icon: Icons.delete_outline,
                  tint: AppColors.secondary,
                  title: 'Sildiğin gerçekten gider',
                  subtitle: 'Kısa süreli "geri al" dışında, sildiğin bir '
                      'dersin ya da konunun gizli bir kopyası tutulmaz.',
                ),
                _divider(),
                _InfoRow(
                  icon: Icons.money_off_outlined,
                  tint: AppColors.primary,
                  title: 'Reklamsız, taahhütsüz',
                  subtitle: 'Şu an tamamen ücretsiz. Zorla abonelik, '
                      'gizli otomatik yenileme, kilitli taahhüt yok.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'İleride ücretli bir sürüm düşünürsek bunu da aynı açıklıkla '
            'söyleyeceğiz.',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(
        height: 1,
        indent: 56,
        color: AppColors.textSecondary.withValues(alpha: 0.12),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;

  const _InfoRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: tint),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.body),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
