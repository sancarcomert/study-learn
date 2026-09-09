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
import 'add_task_screen.dart';
import 'smart_plan_screen.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(statsProvider.notifier).checkStreakBroken();
      _maybeShowNotificationPermissionPrompt();
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

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Günaydın! ☀️';
    if (hour < 18) return 'İyi günler! 👋';
    return 'İyi akşamlar! 🌙';
  }

  String _subGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Güne güzel bir başlangıç yapalım.';
    if (hour < 18) return 'Bugün çalışmaya hazır mısın?';
    return 'Günü kapatmadan son bir tur atalım mı?';
  }

  List<TaskModel> _sortedBySchedule(List<TaskModel> tasks) {
    final withTime = tasks.where((t) => t.scheduledTime != null).toList()
      ..sort((a, b) => a.scheduledTime!.compareTo(b.scheduledTime!));

    final withoutTime = tasks.where((t) => t.scheduledTime == null).toList();

    return [...withTime, ...withoutTime];
  }

  String? _nextBlockText(TaskModel? upcomingTask) {
    if (upcomingTask == null || upcomingTask.scheduledTime == null) {
      return null;
    }

    final diff = upcomingTask.scheduledTime!.difference(DateTime.now());

    if (diff.inMinutes > 0) {
      return 'Bir sonraki çalışma bloğuna kadar ${diff.inMinutes} dakikan var.';
    }

    return 'Bir görevin başlama zamanı geldi.';
  }

  String _fmtDuration(int minutes) {
    if (minutes <= 0) return '0 dk';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m dk';
    if (m == 0) return '$h sa';
    return '$h sa $m dk';
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
    final examDate = ref.watch(statsProvider).examDate;

    final nextTask = allTasks
        .where((task) => task.scheduledTime != null && !task.isCompleted)
        .toList()
      ..sort((a, b) => a.scheduledTime!.compareTo(b.scheduledTime!));

    final upcomingTask = nextTask.isEmpty ? null : nextTask.first;

    ref.listen<int>(taskCompletionEventProvider, (previous, next) {
      if (previous != null && next > previous) {
        AppSnackBar.success(
          context,
          "Görev tamamlandı!",
          duration: const Duration(seconds: 1),
        );
      }
    });

    ref.listen<int>(goalReachedEventProvider, (previous, next) {
      if (previous != null && next > previous) {
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
                  Text(_greeting(), style: AppTextStyles.heading1),
                  const SizedBox(height: 8),
                  Text(
                    _nextBlockText(upcomingTask) ?? _subGreeting(),
                    style: AppTextStyles.bodySecondary,
                  ),

                  const SizedBox(height: 32),

                  // 3) KRAL BUTON
                  _KingButton(
                    label: 'Bugünü Planla',
                    icon: Icons.auto_awesome_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SmartPlanScreen()),
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
                  if (todayTasks.isEmpty)
                    const EmptyStateCard(
                      icon: Icons.task_alt_outlined,
                      message:
                          'Bugün için görev yok.\nSağ alttaki + ile ekleyebilirsin.',
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
