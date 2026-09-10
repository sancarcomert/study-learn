import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_colors.dart';
import '../app_text_styles.dart';
import '../backup_service.dart';
import '../focus_session_provider.dart';
import '../stats_provider.dart';
import '../subject_provider.dart';
import '../tap_scale.dart';
import '../task_provider.dart';
import '../topic_provider.dart';
import 'app_snackbar.dart';
import 'eyebrow.dart';

/// Profil ekranındaki "VERİLER" bölümü — dışa aktar + yedekten geri yükle.
/// docs/rakip_analizi_ve_yon_2026-09.md §6 A1. Rakiplerin (paralı olanlar
/// dahil) en sık şikayeti veri kaybı; bu, Pusula'nın "asla olmaz"ı.
class DataBackupSection extends ConsumerStatefulWidget {
  const DataBackupSection({super.key});

  @override
  ConsumerState<DataBackupSection> createState() => _DataBackupSectionState();
}

class _DataBackupSectionState extends ConsumerState<DataBackupSection> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow(text: 'VERİLER'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppColors.softShadow,
          ),
          child: Column(
            children: [
              _DataRow(
                icon: Icons.upload_file_outlined,
                title: 'Verini dışa aktar',
                subtitle: 'Tüm verini tek dosyaya kaydet',
                onTap: _busy ? null : _export,
              ),
              Divider(
                height: 1,
                indent: 56,
                color: AppColors.textSecondary.withValues(alpha: 0.12),
              ),
              _DataRow(
                icon: Icons.settings_backup_restore,
                title: 'Yedekten geri yükle',
                subtitle: 'Dosyadan ya da cihazdaki otomatik yedekten',
                onTap: _busy ? null : _openRestoreSheet,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pusula verini yalnızca bu cihazda tutar. Ara sıra dışa aktarıp '
          'güvenli bir yere koy. Ayrıca her gün cihazına otomatik yedek alınır.',
          style: AppTextStyles.caption,
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ EXPORT

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final json = BackupService.exportToJsonString();
      final dir = await getTemporaryDirectory();
      final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final file = File('${dir.path}/pusula-yedek-$stamp.json');
      await file.writeAsString(json);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'Pusula yedeği',
      );
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(context, 'Dışa aktarma başarısız oldu.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ----------------------------------------------------------------- RESTORE

  Future<void> _openRestoreSheet() async {
    final snapshots = await BackupService.listSnapshots();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Yedekten geri yükle', style: AppTextStyles.heading3),
                const SizedBox(height: 4),
                Text(
                  'Şu anki verinin yerine seçilen yedek yüklenir.',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 16),
                _DataRow(
                  icon: Icons.folder_open_outlined,
                  title: 'Dosyadan seç…',
                  subtitle: '.json yedek dosyası',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _restoreFrom(_pickBackupFile);
                  },
                ),
                if (snapshots.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Eyebrow(text: 'CİHAZDAKİ OTOMATİK YEDEKLER'),
                  const SizedBox(height: 8),
                  ...snapshots.map(
                    (s) => _DataRow(
                      icon: Icons.history,
                      title: _snapshotLabel(s),
                      subtitle: '${s.itemCount} kayıt',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _restoreFrom(() => File(s.path).readAsString());
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// [load] null döndürürse (kullanıcı dosya seçmeyi iptal etti) sessizce çıkar.
  Future<void> _restoreFrom(Future<String?> Function() load) async {
    setState(() => _busy = true);
    try {
      final String? raw;
      try {
        raw = await load();
      } on BackupException catch (e) {
        if (mounted) AppSnackBar.error(context, e.message);
        return;
      } catch (_) {
        if (mounted) AppSnackBar.error(context, 'Dosya okunamadı.');
        return;
      }
      if (raw == null || !mounted) return;

      final confirmed = await _confirmRestore();
      if (confirmed != true || !mounted) return;

      try {
        final summary = await BackupService.importFromJsonString(raw);
        // Kutular değişti — provider'ları taze kutudan yeniden kur.
        ref.invalidate(subjectRepositoryProvider);
        ref.invalidate(subjectProvider);
        ref.invalidate(taskRepositoryProvider);
        ref.invalidate(taskProvider);
        ref.invalidate(topicRepositoryProvider);
        ref.invalidate(topicProvider);
        ref.invalidate(focusSessionRepositoryProvider);
        ref.invalidate(focusSessionProvider);
        ref.invalidate(statsRepositoryProvider);
        ref.invalidate(statsProvider);
        if (mounted) {
          AppSnackBar.success(
            context,
            '${summary.subjects} ders · ${summary.tasks} görev · '
            '${summary.topics} konu geri yüklendi.',
          );
        }
      } on BackupException catch (e) {
        if (mounted) AppSnackBar.error(context, e.message);
      } catch (_) {
        if (mounted) AppSnackBar.error(context, 'Geri yükleme başarısız oldu.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirmRestore() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Geri yüklensin mi?'),
        content: const Text(
          'Şu anki tüm verinin (dersler, görevler, konular, istatistikler) '
          'yerine bu yedek yüklenecek. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Geri yükle',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Dosya seçtirir; kullanıcı iptal ederse null döner.
  Future<String?> _pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.single;
    if (picked.bytes != null) {
      return utf8.decode(picked.bytes!, allowMalformed: true);
    }
    final path = picked.path;
    if (path == null) {
      throw const BackupException('Dosya okunamadı.');
    }
    return File(path).readAsString();
  }

  String _snapshotLabel(SnapshotInfo s) {
    final taken = s.takenAt;
    if (taken == null) return 'Otomatik yedek';
    return DateFormat('d MMMM y', 'tr_TR').format(taken);
  }
}

class _DataRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _DataRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
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
        ),
      ),
    );
  }
}
