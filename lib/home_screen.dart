// lib/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'task_provider.dart';
import 'subject_provider.dart';
import 'stats_provider.dart';
import 'widgets/next_task_card.dart';
import 'widgets/eyebrow.dart';
import 'widgets/exam_countdown.dart';
import 'task_model.dart';
import 'task_time_status.dart';
import 'study_advisor.dart';
import 'topic_provider.dart';
import 'add_task_screen.dart';
import 'coach_screen.dart';
import 'widgets/task_tile.dart';
import 'stats_screen.dart';
import 'profile_screen.dart';
import 'tap_scale.dart';
import 'widgets/empty_state_card.dart';
import 'widgets/app_snackbar.dart';
import 'notification_service.dart';
import 'dart:async';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final ConfettiController _goalConfetti =
      ConfettiController(duration: const Duration(seconds: 1));

  Timer? _liveClockTicker;

  // Günlük hedef kutlaması günde bir kez çıksın. dailyGoal=1 iken hedefe
  // ulaştıktan sonra tamamlanan HER görev goalReachedEvent'i yeniden
  // tetikliyor; bu bayrak aynı gün ikinci konfetiyi engeller. Uygulama
  // yeniden açılınca sıfırlanır (yeni oturumda bir kez görmek kabul).
  DateTime? _celebratedOn;

  // Geçmiş günden kalan tamamlanmamış görevler için "bugüne al?" sorusu —
  // oturum başına bir kez.
  bool _carryOverPrompted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(statsProvider.notifier).checkStreakBroken();
      await _maybeShowNotificationPermissionPrompt();
      if (mounted) await _maybeShowCarryOverPrompt();
    });

    _liveClockTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _goalConfetti.dispose();
    _liveClockTicker?.cancel();
    super.dispose();
  }

  // Sistem bildirim izni popup'ı artık direkt çıkmıyor — önce kullanıcıya
  // neden istendiğini açıklıyoruz, "Devam Et" derse asıl sistem isteği
  // tetikleniyor. Sadece Home ilk açıldığında, kullanıcı başına bir kere.
  Future<void> _maybeShowNotificationPermissionPrompt() async {
    final alreadySeen =
        ref.read(statsProvider).hasSeenNotificationPrompt == true;
    if (alreadySeen) return;

    if (!mounted) return;

    final continueRequested = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      // Butonlar dialog'un KENDİ context'iyle pop ediliyor — dış (State)
      // context'i onboarding→MainShell geçişinde dispose olabiliyor ve o
      // context üzerinden Navigator.pop çağrısı "Null check operator used
      // on a null value" fırlatıp dialog'u kilitliyordu.
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.notifications_active_outlined,
          color: AppColors.primary,
          size: 32,
        ),
        title: const Text('Hatırlatmalara izin ver'),
        content: const Text(
          'Hatırlatmalar için bildirim izni gerekiyor, kaçırdığın görevleri sana hatırlatabilelim.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Şimdi Değil'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Devam Et'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    ref.read(statsProvider.notifier).markNotificationPromptSeen();

    if (continueRequested == true) {
      await NotificationService.instance.requestPermissions();
    }
  }

  /// Önceki günlerden kalan tamamlanmamış görevleri topluca bugüne taşımayı
  /// önerir — profesyonel yapılacaklar uygulamalarındaki "carry over" akışı.
  /// Görev oluşturma/güncelleme mevcut `taskProvider.updateTask` ile yapılır.
  Future<void> _maybeShowCarryOverPrompt() async {
    if (_carryOverPrompted || !mounted) return;

    final now = DateTime.now();
    final stale = ref
        .read(taskProvider)
        .where((t) => t.isPastDayIncompleteAt(now))
        .toList();
    if (stale.isEmpty) return;

    _carryOverPrompted = true;
    final n = stale.length;

    final move = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.history_rounded,
            color: AppColors.primary, size: 30),
        title: Text(n == 1
            ? 'Önceki günden kalan 1 görev var'
            : 'Önceki günlerden $n görev kaldı'),
        content: const Text(
          'Tamamlanmamış görevleri bugüne taşıyalım mı?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Şimdi Değil'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Bugüne Taşı'),
          ),
        ],
      ),
    );

    if (!mounted || move != true) return;

    final today = DateTime(now.year, now.month, now.day);
    final notifier = ref.read(taskProvider.notifier);
    for (final t in stale) {
      final st = t.scheduledTime;
      notifier.updateTask(
        t,
        title: t.title,
        subjectId: t.subjectId,
        dueDate: today,
        priority: t.priority,
        scheduledTime: st == null
            ? null
            : DateTime(today.year, today.month, today.day, st.hour, st.minute),
        estimatedMinutes: t.estimatedMinutes,
        difficulty: t.difficulty,
      );
    }
    if (mounted) {
      AppSnackBar.success(
          context, n == 1 ? 'Görev bugüne taşındı' : '$n görev bugüne taşındı');
    }
  }

  String _greeting(String? name) {
    final hour = DateTime.now().hour;
    final base = hour < 12
        ? 'Günaydın'
        : hour < 18
            ? 'İyi günler'
            : 'İyi akşamlar';
    final emoji = hour < 12 ? '☀️' : (hour < 18 ? '👋' : '🌙');
    final who = (name != null && name.trim().isNotEmpty) ? ', ${name.trim()}' : '';
    return '$base$who! $emoji';
  }

  /// Alt selam satırı davranışa göre değişir: bugünkü görevlerin hepsi
  /// bittiyse tebrik, hiç yoksa plan çağrısı, aksi halde saate göre.
  String _subGreeting({required int total, required int completed}) {
    if (total > 0 && completed >= total) {
      return 'Bugünü tamamladın 👏 Yarına hazırsın.';
    }
    if (total == 0) {
      return 'Bugün için henüz plan yok — "Bugünü Planla" ile başla.';
    }
    final left = total - completed;
    final hour = DateTime.now().hour;
    if (hour >= 18) return 'Günü kapatmadan $left görev kaldı.';
    return '$left görevin var, hadi başlayalım.';
  }

  List<TaskModel> _sortedBySchedule(List<TaskModel> tasks) {
    final withTime = tasks.where((t) => t.scheduledTime != null).toList()
      ..sort((a, b) => a.scheduledTime!.compareTo(b.scheduledTime!));

    final withoutTime = tasks.where((t) => t.scheduledTime == null).toList();

    return [...withTime, ...withoutTime];
  }

  static String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// Hero'nun alt satırı için zaman-farkında durum metni. Öncelik:
  /// gecikmiş > şu an devam eden > yaklaşan. Hiçbiri yoksa null (davranışa
  /// göre selam devreye girer).
  String? _statusLine({
    required List<TaskModel> overdue,
    required TaskModel? inProgress,
    required TaskModel? upcoming,
  }) {
    if (overdue.isNotEmpty) {
      return overdue.length == 1
          ? '"${overdue.first.title}" gecikti — dokun, ertele ya da tamamla.'
          : '${overdue.length} görev gecikti.';
    }
    if (inProgress != null) {
      return 'Şu an: ${_hhmm(inProgress.scheduledTime!)} · ${inProgress.title}';
    }
    if (upcoming != null) {
      final mins = upcoming.scheduledTime!.difference(DateTime.now()).inMinutes;
      return mins <= 90
          ? '$mins dk sonra: ${upcoming.title}'
          : 'Sıradaki: ${_hhmm(upcoming.scheduledTime!)} · ${upcoming.title}';
    }
    return null;
  }

  String _fmtDuration(int minutes) {
    if (minutes <= 0) return '0 dk';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m dk';
    if (m == 0) return '$h sa';
    return '$h sa $m dk';
  }

  /// "Nereden başlasan?" önerisine dokunma — o ders için bugüne sade bir
  /// görev oluşturur (Akıllı Plan'ın konusuz çıktısıyla aynı biçim).
  void _handleSuggestionTap(StudySuggestion s) {
    ref.read(taskProvider.notifier).addTask(
          title: s.subjectName,
          subjectId: s.subjectId,
          dueDate: DateTime.now(),
          estimatedMinutes: 45,
        );
    AppSnackBar.success(context, '${s.subjectName} bugüne eklendi');
  }

  void _showGoalCelebration() {
    showDialog(
      context: context,
      barrierColor: Colors.black26,
      barrierDismissible: true,
      builder: (dialogContext) {
        Future.delayed(const Duration(seconds: 2), () {
          if (Navigator.canPop(dialogContext)) {
            Navigator.pop(dialogContext);
          }
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _goalConfetti.play();
          }
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: -40,
                child: ConfettiWidget(
                  confettiController: _goalConfetti,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  numberOfParticles: 24,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("🎉", style: TextStyle(fontSize: 40)),
                    SizedBox(height: 12),
                    Text(
                      "Günlük hedef tamamlandı!",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayTasksRaw = ref.watch(todayTasksProvider);
    final todayTasks = _sortedBySchedule(todayTasksRaw);
    final allTasks = ref.watch(taskProvider);
    final subjects = ref.watch(subjectProvider);
    final stats = ref.watch(statsProvider);
    final examDate = stats.examDate;

    final now = DateTime.now();
    // "Sıradaki görev" / durum satırı YALNIZ bugünün zamanlı görevlerini
    // dikkate alır. Başka güne planlı bir görev "685 dakika sonra" gibi
    // saçma metinler üretiyordu.
    final scheduledIncomplete = allTasks
        .where((task) =>
            task.scheduledTime != null &&
            !task.isCompleted &&
            task.scheduledTime!.year == now.year &&
            task.scheduledTime!.month == now.month &&
            task.scheduledTime!.day == now.day)
        .toList()
      ..sort((a, b) => a.scheduledTime!.compareTo(b.scheduledTime!));

    final overdueTasks = scheduledIncomplete
        .where((t) => t.timeStatusAt(now) == TaskTimeStatus.overdue)
        .toList();
    TaskModel? firstWithStatus(TaskTimeStatus s) {
      for (final t in scheduledIncomplete) {
        if (t.timeStatusAt(now) == s) return t;
      }
      return null;
    }

    final inProgressTask = firstWithStatus(TaskTimeStatus.inProgress);
    // "Sıradaki görev" kartı ve metni artık yalnız GERÇEKTEN gelecekteki
    // görevi gösterir — gecikmiş olan "sıradaki" değildir.
    final upcomingTask = firstWithStatus(TaskTimeStatus.upcoming);

    ref.listen<int>(taskCompletionEventProvider, (previous, next) {
      if (previous != null && next > previous) {
        AppSnackBar.success(
          context,
          "Görev tamamlandı!",
          duration: const Duration(seconds: 1),
        );
        // Kaydırarak tamamlamayı kendi kendine keşfettiyse ipucu şeridine
        // gerek kalmadı.
        ref.read(statsProvider.notifier).markTaskHintsSeen();
      }
    });

    ref.listen<int>(goalReachedEventProvider, (previous, next) {
      if (previous != null && next > previous) {
        final t = DateTime.now();
        final today = DateTime(t.year, t.month, t.day);
        if (_celebratedOn == today) return;
        _celebratedOn = today;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showGoalCelebration();
        });
      }
    });

    final completedCount = todayTasks.where((t) => t.isCompleted).length;
    final totalCount = todayTasks.length;

    final remainingMin = todayTasks
        .where((t) => !t.isCompleted)
        .fold<int>(0, (s, t) => s + (t.estimatedMinutes ?? 0));

    // "Nereden başlasan?" — yalnızca bugün hiç görev yokken göster.
    final coverage = ref.watch(coverageBySubjectProvider);
    final suggestions = todayTasks.isEmpty
        ? StudyAdvisor.suggest(
            subjects: subjects,
            tasks: allTasks,
            examDate: examDate,
            limit: 3,
            coveragePercent: {
              for (final e in coverage.entries)
                if (e.value.hasTopics) e.key: e.value.ratio,
            },
          )
        : const <StudySuggestion>[];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // 1) HEADER — 32dp
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 20, 0),
              child: SizedBox(
                height: 32,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const _BrandMark(),
                    _ProfileRing(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (examDate != null && daysUntilExam(examDate) >= 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TapScale(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const StatsScreen()),
                    ),
                    child: ExamCountdownChip(examDate: examDate),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  // 2) HERO
                  Text(_greeting(stats.userName),
                      style: AppTextStyles.heading1),
                  const SizedBox(height: 8),
                  Text(
                    _statusLine(
                          overdue: overdueTasks,
                          inProgress: inProgressTask,
                          upcoming: upcomingTask,
                        ) ??
                        _subGreeting(
                          total: totalCount,
                          completed: completedCount,
                        ),
                    style: AppTextStyles.bodySecondary.copyWith(
                      color: overdueTasks.isNotEmpty
                          ? AppColors.warning
                          : null,
                      fontWeight: overdueTasks.isNotEmpty
                          ? FontWeight.w600
                          : null,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 3) KRAL BUTON
                  _KingButton(
                    label: 'Bugünü Planla',
                    icon: Icons.auto_awesome_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CoachScreen()),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // 4) BENTO GRID
                  Row(
                    children: [
                      Expanded(
                        child: _BentoCard(
                          eyebrow: 'BUGÜN',
                          value: '$completedCount/$totalCount',
                          sub: 'görev tamam',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BentoCard(
                          eyebrow: 'KALAN SÜRE',
                          value: _fmtDuration(remainingMin),
                          sub: 'bugün',
                        ),
                      ),
                    ],
                  ),

                  if (upcomingTask != null) ...[
                    const SizedBox(height: 28),
                    NextTaskCard(task: upcomingTask, subjects: subjects),
                  ],

                  const SizedBox(height: 32),

                  // 5) BUGÜNKÜ GÖREVLER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Eyebrow(text: 'BUGÜNKÜ GÖREVLER'),
                      if (totalCount > 0)
                        Text(
                          '$completedCount/$totalCount',
                          style: AppTextStyles.caption
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!stats.hasSeenTaskHints &&
                      todayTasks.any((t) => !t.isCompleted)) ...[
                    _HintStrip(
                      onDismiss: () => ref
                          .read(statsProvider.notifier)
                          .markTaskHintsSeen(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (todayTasks.isEmpty)
                    suggestions.isEmpty
                        ? const EmptyStateCard(
                            icon: Icons.task_alt_outlined,
                            message:
                                'Bugün için görev yok.\nSağ alttaki + ile ekleyebilirsin.',
                          )
                        : _SuggestionStrip(
                            suggestions: suggestions,
                            onTap: _handleSuggestionTap,
                          )
                  else
                    Column(
                      children: todayTasks
                          .map((task) => _AnimatedTaskEntry(
                                key: ValueKey(task.id),
                                child:
                                    TaskTile(task: task, subjects: subjects),
                              ))
                          .toList(),
                    ),

                  const SizedBox(height: 96),
                ],
              ),
            ),
          ],
        ),
      ),
      // Kral buton "Bugünü Planla" ekranın baskın eylemi; FAB ikincil
      // kalsın diye dar/dairesel (extended değil).
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.ink,
        elevation: 0,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddTaskScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Yeni kullanıcıya bir kez gösterilen ipucu şeridi — görev listesindeki
/// iki gizli/az belirgin etkileşimi anlatır. "Anladım"a basınca ya da
/// kullanıcı bir görevi kendi kaydırıp tamamlayınca bir daha çıkmaz.
class _HintStrip extends StatelessWidget {
  final VoidCallback onDismiss;

  const _HintStrip({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.tonal(AppColors.primary),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline,
              size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daireye dokun → tamamla · ▶ → odak kronometresi',
                  style: AppTextStyles.bodySecondary.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sağa kaydır → yarına ertele · sola kaydır → sil',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          TapScale(
            onTap: onDismiss,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                'Anladım',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bugün hiç görev yokken boş durum kartı yerine gösterilen 1–3 ders önerisi.
/// Dokununca ilgili ders bugüne eklenir.
class _SuggestionStrip extends StatelessWidget {
  final List<StudySuggestion> suggestions;
  final ValueChanged<StudySuggestion> onTap;

  const _SuggestionStrip({required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow(text: 'NEREDEN BAŞLASAN?'),
          const SizedBox(height: 4),
          Text(
            'Bugün için plan yok. Bir öneriye dokun, bugüne eklensin.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 12),
          ...suggestions.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TapScale(
                onTap: () => onTap(s),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.tonal(AppColors.primary),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.subjectName,
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(s.reason, style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.add_circle_outline,
                          size: 20, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pusula',
          style: AppTextStyles.heading2.copyWith(
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Container(width: 22, height: 2, color: AppColors.primary),
      ],
    );
  }
}

class _ProfileRing extends StatelessWidget {
  final VoidCallback onTap;

  const _ProfileRing({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.textMuted, width: 1.4),
        ),
        child: const Icon(
          Icons.person_outline,
          size: 17,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _KingButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _KingButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        height: 64,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(32),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: AppColors.ink),
            const SizedBox(width: 10),
            Text(label, style: AppTextStyles.button.copyWith(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class _BentoCard extends StatelessWidget {
  final String eyebrow;
  final String value;
  final String sub;

  const _BentoCard({
    required this.eyebrow,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceVariant, width: 1),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Eyebrow(text: eyebrow),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppTextStyles.heading2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(sub, style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnimatedTaskEntry extends StatefulWidget {
  final Widget child;

  const _AnimatedTaskEntry({super.key, required this.child});

  @override
  State<_AnimatedTaskEntry> createState() => _AnimatedTaskEntryState();
}

class _AnimatedTaskEntryState extends State<_AnimatedTaskEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut)),
        child: widget.child,
      ),
    );
  }
}
