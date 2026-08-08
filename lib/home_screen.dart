// lib/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'task_provider.dart';
import 'widgets/week_strip.dart';
import 'subject_provider.dart';
import 'stats_provider.dart';
import 'widgets/next_task_card.dart';
import 'widgets/smart_plan_banner.dart';
import 'widgets/eyebrow.dart';
import 'task_model.dart';
import 'subject_model.dart';
import 'day_detail_screen.dart';
import 'subjects_screen.dart';
import 'add_task_screen.dart';
import 'widgets/task_tile.dart';
import 'stats_screen.dart';
import 'tap_scale.dart';
import 'widgets/hero_progress_card.dart';
import 'widgets/animated_progress_bar.dart';
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
  String _searchQuery = '';
  bool _searchExpanded = false;

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
      builder: (_) => AlertDialog(
        icon: const Icon(
          Icons.notifications_active_rounded,
          color: AppColors.primary,
          size: 32,
        ),
        title: const Text('Hatırlatmalara izin ver'),
        content: const Text(
          'Hatırlatmalar için bildirim izni gerekiyor, kaçırdığın görevleri sana hatırlatabilelim.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Şimdi Değil'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Devam Et'),
          ),
        ],
      ),
    );

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
                    Text(
                      "🎉",
                      style: TextStyle(fontSize: 40),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Günlük hedef tamamlandı!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
    final progress = totalCount == 0 ? 0.0 : completedCount / totalCount;

    final filteredTasks = _searchQuery.isEmpty
        ? todayTasks
        : todayTasks
            .where((t) => t.title.toLowerCase().contains(_searchQuery))
            .toList();

    return Scaffold(
      // Artık ham hex yok — AppColors.background zaten sıcak beyaz,
      // tema (scaffoldBackgroundColor) bunu otomatik uyguluyor.
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_greeting(), style: AppTextStyles.heading1),
                          const SizedBox(height: 4),
                          Text(_subGreeting(),
                              style: AppTextStyles.bodySecondary),
                        ],
                      ),
                    ),
                    TapScale(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const StatsScreen()),
                        );
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: const Icon(Icons.bar_chart_rounded,
                            color: AppColors.primary, size: 20),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                HeroProgressCard(
                  progress: progress,
                  completedCount: completedCount,
                  totalCount: totalCount,
                  streak: stats.currentStreak,
                  longestStreak: stats.longestStreak,
                  nextBlockText: _nextBlockText(upcomingTask),
                ),

                const SizedBox(height: 16),

                NextTaskCard(
                  task: upcomingTask,
                  subjects: subjects,
                ),

                const SizedBox(height: 12),

                const SmartPlanBanner(),

                const SizedBox(height: 28),

                const Eyebrow(text: 'BU HAFTA'),
                const SizedBox(height: 6),
                Text('Çalışma ritmin', style: AppTextStyles.heading3),
                const SizedBox(height: 16),

                WeekStrip(
                  allTasks: allTasks,
                  onDaySelected: (date) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DayDetailScreen(date: date),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 28),

                const Eyebrow(text: 'DERSLERİN'),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Bugünkü dağılım', style: AppTextStyles.heading3),
                    TapScale(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const SubjectsScreen()),
                        );
                      },
                      child: Text(
                        'Tümünü Gör',
                        style: AppTextStyles.bodySecondary.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                subjects.isEmpty
                    ? EmptyStateCard(
                        icon: Icons.menu_book_rounded,
                        message: 'Henüz ders eklemedin.\nHadi ilk dersini ekle!',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const SubjectsScreen()),
                          );
                        },
                      )
                    : Column(
                        children: subjects.map((subject) {
                          final subjectTasks = todayTasks
                              .where((t) => t.subjectId == subject.id)
                              .toList();
                          final completed = subjectTasks
                              .where((t) => t.isCompleted)
                              .length;
                          final total = subjectTasks.length;
                          final minutes = subjectTasks.fold<int>(
                            0,
                            (sum, t) => sum + (t.estimatedMinutes ?? 0),
                          );

                          return _SubjectProgressRow(
                            subject: subject,
                            completed: completed,
                            total: total,
                            minutes: minutes,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const SubjectsScreen()),
                              );
                            },
                          );
                        }).toList(),
                      ),

                const SizedBox(height: 28),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Bugünkü Görevler',
                              style: AppTextStyles.heading2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                                width: _searchExpanded ? 110 : 0,
                                height: 36,
                                child: _searchExpanded
                                    ? TextField(
                                        autofocus: true,
                                        style: AppTextStyles.bodySecondary,
                                        decoration: const InputDecoration(
                                          hintText: 'Ara...',
                                          contentPadding:
                                              EdgeInsets.symmetric(vertical: 0),
                                        ),
                                        onChanged: (value) => setState(
                                            () => _searchQuery = value.toLowerCase()),
                                      )
                                    : null,
                              ),
                              IconButton(
                                icon: Icon(
                                  _searchExpanded
                                      ? Icons.close_rounded
                                      : Icons.search_rounded,
                                  size: 20,
                                  color: AppColors.textSecondary,
                                ),
                                onPressed: () {
                                  setState(() {
                                    if (_searchExpanded) {
                                      _searchExpanded = false;
                                      _searchQuery = '';
                                    } else {
                                      _searchExpanded = true;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      filteredTasks.isEmpty
                          ? (_searchQuery.isEmpty
                              ? const EmptyStateCard(
                                  icon: Icons.task_alt_rounded,
                                  message:
                                      'Bugün için görev yok.\nSağ alttaki butonla ekleyebilirsin.',
                                )
                              : Text('Sonuç bulunamadı',
                                  style: AppTextStyles.bodySecondary))
                          : Column(
                              children: filteredTasks
                                  .map((task) => _AnimatedTaskEntry(
                                        key: ValueKey(task.id),
                                        child: TaskTile(task: task, subjects: subjects),
                                      ))
                                  .toList(),
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
      // Home'da tek FAB kalıyor: "Görev Ekle" (birincil, günlük eylem).
      // "Akıllı Plan" FAB'ı kaldırıldı — o özelliğe erişim artık sadece
      // aşağıdaki SmartPlanBanner üzerinden. Plan sekmesi ileride tam bir
      // "Planning Hub" olacağı için Home'un bu özelliği FAB gibi kalıcı/
      // baskın bir şekilde sahiplenmesi doğru değil.
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Görev Ekle', style: TextStyle(color: Colors.white)),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddTaskScreen()),
          );
        },
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

class _SubjectProgressRow extends StatelessWidget {
  final SubjectModel subject;
  final int completed;
  final int total;
  final int minutes;
  final VoidCallback onTap;

  const _SubjectProgressRow({
    required this.subject,
    required this.completed,
    required this.total,
    required this.minutes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(subject.colorValue);
    final ratio = total == 0 ? 0.0 : completed / total;

    return TapScale(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Text(
                subject.name.isNotEmpty ? subject.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subject.name, style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
                  const SizedBox(height: 2),
                  Text(
                    total == 0
                        ? 'Bugün görev yok'
                        : '$total görev, $minutes dakika',
                    style: AppTextStyles.caption,
                  ),
                  if (total > 0) ...[
                    const SizedBox(height: 8),
                    AnimatedProgressBar(
                      value: ratio,
                      color: color,
                      backgroundColor: color.withOpacity(0.12),
                      height: 6,
                      borderRadius: 6,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (total > 0)
              Text(
                '$completed/$total',
                style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}