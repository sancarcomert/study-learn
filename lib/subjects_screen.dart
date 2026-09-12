import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'subject_provider.dart';
import 'subject_model.dart';
import 'topic_provider.dart';
import 'add_subject_sheet.dart';
import 'tap_scale.dart';
import 'widgets/empty_state_card.dart';
import 'widgets/app_buttons.dart';
import 'widgets/app_snackbar.dart';

class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Derslerim', style: AppTextStyles.heading2),
      ),
      body: subjects.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: EmptyStateCard(
                  icon: Icons.menu_book_outlined,
                  message: 'Henüz ders eklemedin.\nAşağıdaki + butonuna dokun.',
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: subjects.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final subject = subjects[index];
                return _SubjectCard(subject: subject, ref: ref);
              },
            ),
      floatingActionButton: GradientFab(
        tooltip: 'Ders ekle',
        onPressed: () => _showAddSubjectSheet(context),
      ),
    );
  }

  void _showAddSubjectSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddSubjectSheet(),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final SubjectModel subject;
  final WidgetRef ref;

  const _SubjectCard({required this.subject, required this.ref});

  void _showEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddSubjectSheet(subjectToEdit: subject),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(subject.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text("Ders silinsin mi?"),
                content: const Text(
                  "Bu derse bağlı görevler silinmez, yalnızca dersi boş "
                  "kalır. Kısa süreliğine geri alabilirsin.",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Vazgeç"),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text("Sil"),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) {
        // Notifier'ı burada, ref hâlâ geçerliyken yakalayıp doğrudan
        // kullanıyoruz — "GERİ AL" gecikmeli çalıştığı için ref'i
        // closure içinde tekrar okumak, ait olduğu widget dispose
        // olduğunda Riverpod hatasına yol açabilir (bkz. task_tile.dart).
        final notifier = ref.read(subjectProvider.notifier);
        final deleted = notifier.deleteSubject(subject.id);
        if (deleted != null) {
          // Ders silinince ona bağlı konular da temizlenir — aksi halde
          // subjectId'si artık var olmayan bir derse işaret eden konular
          // Hive'da öksüz kalıp kapsama hesaplarını sessizce bozardı.
          ref.read(topicProvider.notifier).deleteForSubject(subject.id);
          AppSnackBar.undo(
            context,
            '"${deleted.name}" silindi',
            onUndo: () => notifier.restoreSubject(deleted),
          );
        }
      },
      child: TapScale(
        onTap: () => _showEditSheet(context),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(subject.colorValue).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Color(subject.colorValue).withValues(alpha: 0.35)),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Color(subject.colorValue),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.menu_book_outlined,
                    size: 18,
                    color: AppColors.onColor(Color(subject.colorValue))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(subject.name,
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w700)),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}