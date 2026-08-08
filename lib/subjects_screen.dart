import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'subject_provider.dart';
import 'subject_model.dart';
import 'add_subject_sheet.dart';
import 'add_task_screen.dart';
import 'tap_scale.dart';
import 'widgets/empty_state_card.dart';
import 'widgets/app_snackbar.dart';

class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Derslerim', style: AppTextStyles.heading2),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add, color: AppColors.primary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddTaskScreen()),
              );
            },
          ),
        ],
      ),
      body: subjects.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: EmptyStateCard(
                  icon: Icons.menu_book_rounded,
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showAddSubjectSheet(context),
        child: const Icon(Icons.add, color: Colors.white),
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
                  "Bu derse bağlı görevler ders bilgisi olmadan kalmaya devam eder. Silindikten sonra kısa süreliğine geri alabilirsin.",
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
        final deleted =
            ref.read(subjectProvider.notifier).deleteSubject(subject.id);
        if (deleted != null) {
          AppSnackBar.undo(
            context,
            '"${deleted.name}" silindi',
            onUndo: () =>
                ref.read(subjectProvider.notifier).restoreSubject(deleted),
          );
        }
      },
      child: TapScale(
        onTap: () => _showEditSheet(context),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(subject.colorValue),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(subject.name, style: AppTextStyles.body),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}