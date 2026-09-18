import 'package:flutter/material.dart';
import '../app_text_styles.dart';

/// Uygulama genelinde tek bölüm başlığı deseni (2026-09-16, Home'daki yeni
/// turuncu/amber konseptten diğer ekranlara taşındı) — kalın normal başlık
/// + sağda opsiyonel küçük "trailing" metni + altında opsiyonel açıklayıcı
/// alt satır. Eski küçük-harf `Eyebrow` etiketinin yerini alıyor; ekranlar
/// kademeli geçiyor, ikisi bir arada bir süre kullanılabilir.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final String? subtitle;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(title, style: AppTextStyles.heading3)),
            if (trailing != null)
              Text(trailing!,
                  style:
                      AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: AppTextStyles.caption),
        ],
      ],
    );
  }
}
