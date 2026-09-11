import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_colors.dart';
import '../app_text_styles.dart';
import '../tap_scale.dart';
import 'app_snackbar.dart';

/// Kutlama anında paylaşılabilir görsel kart (P0-10). Nag değil — yalnız
/// olumlu bir anda (günlük hedef kutlaması), tek dokunuşla. Marka adı henüz
/// kesinleşmedi (bkz. CLAUDE.md) — kartta metin olarak marka ismi yok.
class ShareCard extends StatelessWidget {
  final int streak;
  final int weekTasks;

  const ShareCard({super.key, required this.streak, required this.weekTasks});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            '$streak günlük serim',
            style: AppTextStyles.heading1.copyWith(fontSize: 26),
          ),
          const SizedBox(height: 8),
          Text(
            'Bu hafta $weekTasks görev tamamladım',
            style:
                AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartı önizleyen + "Paylaş" eylemini sunan diyalog. [streak]/[weekTasks]
/// çağıran yerde zaten okunmuş provider değerleridir — burada yeni bir
/// provider okuması yapılmıyor.
Future<void> showShareCardSheet(
  BuildContext context, {
  required int streak,
  required int weekTasks,
}) async {
  final boundaryKey = GlobalKey();
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            key: boundaryKey,
            child: ShareCard(streak: streak, weekTasks: weekTasks),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TapScale(
                onTap: () => Navigator.of(dialogContext).pop(),
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Kapat',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TapScale(
                onTap: () =>
                    _captureAndShare(dialogContext, boundaryKey),
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.ios_share_outlined,
                          size: 18, color: AppColors.ink),
                      const SizedBox(width: 8),
                      Text(
                        'Paylaş',
                        style: AppTextStyles.button
                            .copyWith(fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Future<void> _captureAndShare(
    BuildContext context, GlobalKey boundaryKey) async {
  try {
    final boundary = boundaryKey.currentContext!.findRenderObject()
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/seri-karti.png');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path, mimeType: 'image/png')]);
  } catch (_) {
    if (context.mounted) {
      AppSnackBar.error(context, 'Paylaşım başarısız oldu.');
    }
  }
}
