import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'add_deneme_screen.dart';
import 'deneme_model.dart';
import 'deneme_provider.dart';
import 'tap_scale.dart';
import 'widgets/app_snackbar.dart';
import 'widgets/empty_state_card.dart';
import 'widgets/eyebrow.dart';

/// Deneme / net takibi (P0-9). Soru bankası YOK — yalnızca TYT/AYT
/// doğru-yanlış-boş girişinden hesaplanan net ve zaman içindeki trendi.
/// Ayrı Hive box'ında; mevcut task/subject/stats/topic modellerine
/// dokunulmadı.
class DenemeScreen extends ConsumerStatefulWidget {
  const DenemeScreen({super.key});

  @override
  ConsumerState<DenemeScreen> createState() => _DenemeScreenState();
}

class _DenemeScreenState extends ConsumerState<DenemeScreen> {
  String _type = 'TYT';

  String _label(DenemeEntry e) =>
      '${e.examType}${e.name != null ? ' • ${e.name}' : ''}';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(denemeProvider);
    final ascending = ref.watch(denemeByTypeProvider(_type));
    final descending = ascending.reversed.toList();
    final chartEntries =
        ascending.length > 8 ? ascending.sublist(ascending.length - 8) : ascending;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Deneme Takip', style: AppTextStyles.heading2),
      ),
      body: all.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: EmptyStateCard(
                icon: Icons.insights_outlined,
                message: 'Henüz deneme eklemedin.\n'
                    'Sağ alttaki + ile ilk deneme netini gir.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                ExamTypeToggle(
                  type: _type,
                  onChanged: (t) => setState(() => _type = t),
                ),
                const SizedBox(height: 22),
                if (ascending.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '$_type türünde henüz deneme yok.',
                      style: AppTextStyles.bodySecondary,
                    ),
                  )
                else ...[
                  const Eyebrow(text: 'NET TRENDİ'),
                  const SizedBox(height: 4),
                  Text(
                    'Son ${chartEntries.length} $_type denemen — soldan '
                    'sağa kronolojik.',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppColors.softShadow,
                    ),
                    child: _NetTrendChart(entries: chartEntries),
                  ),
                ],
                const SizedBox(height: 26),
                const Eyebrow(text: 'GEÇMİŞ'),
                const SizedBox(height: 10),
                ...descending.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Dismissible(
                        key: ValueKey(e.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: AppColors.tonal(AppColors.danger),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.delete_outline,
                              color: AppColors.danger),
                        ),
                        onDismissed: (_) {
                          final label = _label(e);
                          final deleted =
                              ref.read(denemeProvider.notifier).deleteEntry(e.id);
                          if (deleted != null) {
                            AppSnackBar.undo(
                              context,
                              '$label silindi',
                              onUndo: () => ref
                                  .read(denemeProvider.notifier)
                                  .restoreEntry(deleted),
                            );
                          }
                        },
                        child: _DenemeRow(
                          entry: e,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AddDenemeScreen(entryToEdit: e),
                            ),
                          ),
                        ),
                      ),
                    )),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.ink,
        elevation: 0,
        tooltip: 'Deneme ekle',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddDenemeScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ExamTypeToggle extends StatelessWidget {
  final String type;
  final ValueChanged<String> onChanged;

  const ExamTypeToggle({super.key, required this.type, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _seg('TYT'),
          _seg('AYT'),
        ],
      ),
    );
  }

  Widget _seg(String value) {
    final selected = type == value;
    return Expanded(
      child: TapScale(
        onTap: () => onChanged(value),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            value,
            style: AppTextStyles.body.copyWith(
              color: selected ? AppColors.ink : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _NetTrendChart extends StatelessWidget {
  final List<DenemeEntry> entries;
  const _NetTrendChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    final nets = entries.map((e) => e.totalNet).toList();
    final maxNet = nets.fold<double>(1, (a, b) => b > a ? b : a);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < entries.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == entries.length - 1 ? 0 : 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    nets[i].toStringAsFixed(0),
                    style: AppTextStyles.caption
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 72,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor:
                            (nets[i] <= 0 ? 0.03 : nets[i] / maxNet)
                                .clamp(0.03, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: i == entries.length - 1
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat('d MMM', 'tr_TR').format(entries[i].date),
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DenemeRow extends StatelessWidget {
  final DenemeEntry entry;
  final VoidCallback onTap;

  const _DenemeRow({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.tonal(AppColors.secondary),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                entry.examType,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name ??
                        DateFormat('d MMMM y', 'tr_TR').format(entry.date),
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.name != null
                        ? DateFormat('d MMMM y', 'tr_TR').format(entry.date)
                        : '${entry.totalQuestions} soru',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  entry.totalNet.toStringAsFixed(2),
                  style: AppTextStyles.heading3
                      .copyWith(color: AppColors.primary),
                ),
                Text('net', style: AppTextStyles.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
