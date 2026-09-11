import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'topic_catalog.dart';
import 'topic_model.dart';
import 'topic_provider.dart';
import 'tap_scale.dart';
import 'widgets/eyebrow.dart';
import 'widgets/app_snackbar.dart';

/// Bir dersin konu listesi. Satıra dokun → durum döngüsü
/// (başlanmadı → çalışıldı → tekrar). Sola kaydır → sil.
class SubjectTopicsScreen extends ConsumerStatefulWidget {
  final String subjectId;
  final String subjectName;

  const SubjectTopicsScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  ConsumerState<SubjectTopicsScreen> createState() =>
      _SubjectTopicsScreenState();
}

class _SubjectTopicsScreenState extends ConsumerState<SubjectTopicsScreen> {
  final _addController = TextEditingController();

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  void _add() {
    final name = _addController.text.trim();
    if (name.isEmpty) return;
    ref.read(topicProvider.notifier).addTopic(widget.subjectId, name);
    _addController.clear();
  }

  void _addCatalog() {
    final catalog = TopicCatalog.forSubject(widget.subjectName);
    if (catalog.isEmpty) return;
    final added =
        ref.read(topicProvider.notifier).addMany(widget.subjectId, catalog);
    AppSnackBar.success(
      context,
      added > 0 ? '$added konu eklendi' : 'Zaten hepsi ekli',
    );
  }

  static String _statusLabel(TopicStatus s) => switch (s) {
        TopicStatus.notStarted => 'Başlanmadı',
        TopicStatus.studied => 'Çalışıldı',
        TopicStatus.reviewed => 'Tekrar edildi',
      };

  static Color _statusColor(TopicStatus s) => switch (s) {
        TopicStatus.notStarted => AppColors.textMuted,
        TopicStatus.studied => AppColors.primary,
        TopicStatus.reviewed => AppColors.success,
      };

  static IconData _statusIcon(TopicStatus s) => switch (s) {
        TopicStatus.notStarted => Icons.circle_outlined,
        TopicStatus.studied => Icons.check_circle_outline,
        TopicStatus.reviewed => Icons.verified_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final topics = ref.watch(topicsForSubjectProvider(widget.subjectId));
    final covered = topics.where((t) => t.isCovered).length;
    final catalog = TopicCatalog.forSubject(widget.subjectName);
    final showCatalogButton =
        catalog.isNotEmpty && topics.length < catalog.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(widget.subjectName, style: AppTextStyles.heading2),
      ),
      body: Column(
        children: [
          if (topics.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Text(
                    '$covered / ${topics.length} konu · %${topics.isEmpty ? 0 : (covered / topics.length * 100).round()}',
                    style: AppTextStyles.bodySecondary
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          Expanded(
            child: topics.isEmpty
                ? _EmptyTopics(
                    hasCatalog: catalog.isNotEmpty,
                    onAddCatalog: _addCatalog,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    children: [
                      const Eyebrow(text: 'KONULAR'),
                      const SizedBox(height: 10),
                      ...topics.map((t) => Dismissible(
                            key: ValueKey(t.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: AppColors.tonal(AppColors.danger),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.delete_outline,
                                  color: AppColors.danger),
                            ),
                            confirmDismiss: (_) async {
                              return await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text("Konu silinsin mi?"),
                                      content: const Text(
                                        "Kısa süreliğine geri alabilirsin.",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text("Vazgeç"),
                                        ),
                                        TextButton(
                                          style: TextButton.styleFrom(
                                            foregroundColor: AppColors.danger,
                                          ),
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text("Sil"),
                                        ),
                                      ],
                                    ),
                                  ) ??
                                  false;
                            },
                            onDismissed: (_) {
                              // Notifier'ı burada, ref hâlâ geçerliyken
                              // yakalayıp doğrudan kullanıyoruz — "GERİ AL"
                              // gecikmeli çalıştığı için ref'i closure
                              // içinde tekrar okumak, ait olduğu widget
                              // dispose olduğunda Riverpod hatasına yol
                              // açabilir (bkz. task_tile.dart).
                              final notifier =
                                  ref.read(topicProvider.notifier);
                              final deleted = notifier.deleteTopic(t.id);
                              if (deleted != null) {
                                AppSnackBar.undo(
                                  context,
                                  '"${deleted.name}" silindi',
                                  onUndo: () => notifier.restoreTopic(deleted),
                                );
                              }
                            },
                            child: _TopicRow(
                              name: t.name,
                              status: t.status,
                              label: _statusLabel(t.status),
                              color: _statusColor(t.status),
                              icon: _statusIcon(t.status),
                              onTap: () => ref
                                  .read(topicProvider.notifier)
                                  .cycleStatus(t.id),
                            ),
                          )),
                      if (showCatalogButton) ...[
                        const SizedBox(height: 8),
                        _CatalogButton(onTap: _addCatalog),
                      ],
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.surfaceVariant, width: 1),
                      ),
                      child: TextField(
                        controller: _addController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _add(),
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Konu ekle…',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _add,
                    icon: const Icon(Icons.add, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.ink,
                      minimumSize: const Size(44, 44),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  final String name;
  final TopicStatus status;
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _TopicRow({
    required this.name,
    required this.status,
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: status == TopicStatus.notStarted
              ? AppColors.surface
              : AppColors.tonal(color),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: status == TopicStatus.notStarted
                ? AppColors.surfaceVariant
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textPrimary,
                  decoration: status == TopicStatus.reviewed
                      ? TextDecoration.none
                      : null,
                ),
              ),
            ),
            Text(
              label,
              style: AppTextStyles.caption
                  .copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CatalogButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.tonal(AppColors.secondary),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.playlist_add_outlined,
                size: 18, color: AppColors.secondary),
            const SizedBox(width: 10),
            Text(
              'Yaygın konuları ekle',
              style: AppTextStyles.body.copyWith(
                color: AppColors.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTopics extends StatelessWidget {
  final bool hasCatalog;
  final VoidCallback onAddCatalog;

  const _EmptyTopics({required this.hasCatalog, required this.onAddCatalog});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.tonal(AppColors.primary),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.checklist_outlined,
                  color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              'Henüz konu yok.',
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              hasCatalog
                  ? 'Aşağıdan tek tek ekle ya da hazır listeyi kullan.'
                  : 'Aşağıdan tek tek ekle.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary,
            ),
            if (hasCatalog) ...[
              const SizedBox(height: 18),
              _CatalogButton(onTap: onAddCatalog),
            ],
          ],
        ),
      ),
    );
  }
}
