import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_text_styles.dart';

/// Uygulama genelinde tek bir Eyebrow (üst etiket) tanımı.
/// "BUGÜNÜN ODAĞI", "BU HAFTA", "DERSLERİN" gibi tüm üst etiketler
/// bu widget'ı kullanır — her ekran kendi kopyasını üretmez.
class Eyebrow extends StatelessWidget {
  final String text;
  final Color? color;

  const Eyebrow({super.key, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.eyebrow.copyWith(
        color: color ?? AppColors.textSecondary,
      ),
    );
  }
}