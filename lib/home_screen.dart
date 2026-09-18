// lib/home_screen.dart
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'task_provider.dart';
import 'subject_provider.dart';
import 'subject_model.dart';
import 'stats_provider.dart';
import 'task_model.dart';
import 'task_time_status.dart';
import 'study_advisor.dart';
import 'topic_provider.dart';
import 'deneme_provider.dart';
import 'focus_session_provider.dart';
import 'focus_screen.dart';
import 'add_task_screen.dart';
import 'coach_screen.dart';
import 'profile_screen.dart';
import 'rank_provider.dart';
import 'rank_system.dart';
import 'rank_ladder_screen.dart';
import 'widgets/rank_emblem.dart';
import 'tap_scale.dart';
import 'widgets/empty_state_card.dart';
import 'widgets/app_buttons.dart';
import 'widgets/app_snackbar.dart';
import 'widgets/share_card.dart';
import 'widgets/task_tile.dart' show TaskSwipeActions;
import 'widgets/section_header.dart';
import 'widgets/metric_tile.dart';
import 'notification_service.dart';
import 'hive_boxes.dart';
import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';

/// Home'un arkasındaki yumuşak, yavaşça süzülen renkli parıltı — Home'u
/// tamamen düz koyu zeminden ayıran tek en büyük "premium" sinyali (konsept
/// tasarım geçişi, 2026-09). Sabit üç leke tek bir ImageFiltered blur
/// katmanı içinde. 2026-09-16: leke renkleri turuncu/amber konseptine göre
/// retinted (primary artık altın değil turuncu — otomatik yansıyor;
/// üçüncü leke nane yerine amber, yeni paletle daha uyumlu).
class _AuroraBackground extends StatefulWidget {
  const _AuroraBackground();

  @override
  State<_AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<_AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  @override
  void initState() {
    super.initState();
    final reduceMotion = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (!reduceMotion) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value * 2 * math.pi;
              return ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
                child: Stack(
                  children: [
                    Positioned(
                      top: -130 + math.sin(t) * 12,
                      left: -70 + math.cos(t) * 10,
                      child: _blob(260, AppColors.primary, 0.24),
                    ),
                    Positioned(
                      top: -100 + math.cos(t * 0.9) * 10,
                      right: -90 + math.sin(t * 0.9) * 10,
                      child: _blob(240, AppColors.vibrantViolet, 0.16),
                    ),
                    Positioned(
                      top: 240 + math.sin(t * 0.7) * 14,
                      left: 40 + math.cos(t * 0.7) * 12,
                      child: _blob(280, AppColors.vibrantAmber, 0.10),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _blob(double size, Color color, double alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: alpha),
      ),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  // MainShell, IndexedStack kullanıyor — sekmeler arasında geçince bu
  // ekran dispose OLMUYOR, sadece görünmez oluyor. isActive olmadan
  // 30 sn'lik canlı saat zamanlayıcısı başka bir sekmedeyken bile
  // çalışmaya devam edip gereksiz yere StudyAdvisor.suggest gibi ağır
  // hesaplamaları tetikliyordu (bkz. main_shell.dart).
  final bool isActive;
  const HomeScreen({super.key, this.isActive = true});

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
      if (mounted) await _maybeScheduleStreakRisk();
    });

    if (widget.isActive) _startLiveClockTicker();
  }

  void _startLiveClockTicker() {
    _liveClockTicker?.cancel();
    _liveClockTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _startLiveClockTicker();
      setState(() {});
    } else if (!widget.isActive && oldWidget.isActive) {
      _liveClockTicker?.cancel();
      _liveClockTicker = null;
    }
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
        icon: Icon(
          Icons.notifications_active_outlined,
          color: AppColors.primary,
          size: 32,
        ),
        title: const Text('Hatırlatmalara izin ver'),
        content: const Text(
          'Bildirim izni ver, kaçırdığın görevleri sana hatırlatalım.',
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

  /// Seri riski bildirimi — günlük hedef akşama kadar tutturulmazsa
  /// 20:30'da hatırlatır. Oturum başına bir kez (Home ilk açıldığında)
  /// zamanlanır; hedef o gün içinde tutturulursa `goalReachedEventProvider`
  /// dinleyicisi bunu iptal eder.
  static String _streakRiskId(DateTime day) =>
      'streak_risk_${day.year}-${day.month}-${day.day}';

  Future<void> _maybeScheduleStreakRisk() async {
    final stats = ref.read(statsProvider);
    final today = DateTime.now();

    final completedToday = ref
        .read(taskProvider)
        .where((t) =>
            t.isCompleted &&
            t.dueDate.year == today.year &&
            t.dueDate.month == today.month &&
            t.dueDate.day == today.day)
        .length;

    if (completedToday >= stats.dailyGoal) return;

    final target = DateTime(today.year, today.month, today.day, 20, 30);
    if (target.isBefore(today)) return;

    final streak = stats.currentStreak;
    final body = streak > 0
        ? '$streak günlük serin bugün kırılabilir. Tek bir görev yeter.'
        : 'Bugünü tamamlayarak yeni bir seri başlat.';

    await NotificationService.instance.scheduleNotification(
      id: _streakRiskId(today),
      category: NotificationCategory.streakWarning,
      title: 'Bugün henüz bitmedi',
      body: body,
      dateTime: target,
    );
  }

  /// Önceki günlerden kalan tamamlanmamış görevleri topluca bugüne taşımayı
  /// önerir. Görev oluşturma/güncelleme mevcut `taskProvider.updateTask`
  /// ile yapılır.
  Future<void> _maybeShowCarryOverPrompt() async {
    if (_carryOverPrompted ||
        !mounted ||
        ref.read(statsProvider.notifier).wasCarryOverPromptedToday) {
      return;
    }

    final now = DateTime.now();
    final stale = ref
        .read(taskProvider)
        .where((t) => t.isPastDayIncompleteAt(now))
        .toList();
    if (stale.isEmpty) return;

    _carryOverPrompted = true;
    ref.read(statsProvider.notifier).markCarryOverPromptedToday();
    final n = stale.length;

    final move = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.history_rounded,
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
    final who = (name != null && name.trim().isNotEmpty) ? name.trim() : null;
    return who == null ? base : '$base $who';
  }

  List<TaskModel> _sortedBySchedule(List<TaskModel> tasks) {
    final withTime = tasks.where((t) => t.scheduledTime != null).toList()
      ..sort((a, b) => a.scheduledTime!.compareTo(b.scheduledTime!));

    final withoutTime = tasks.where((t) => t.scheduledTime == null).toList();

    return [...withTime, ...withoutTime];
  }

  static String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  void _showGoalCelebration() {
    final streak = ref.read(statsProvider).currentStreak;
    final weekTasks = ref.read(tasksCompletedThisWeekProvider);

    showDialog(
      context: context,
      barrierColor: Colors.black26,
      barrierDismissible: true,
      builder: (dialogContext) {
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("🎉",
                        style: AppTextStyles.heading1.copyWith(fontSize: 40)),
                    const SizedBox(height: 12),
                    Text(
                      "Günlük hedef tamamlandı!",
                      textAlign: TextAlign.center,
                      style: AppTextStyles.heading3,
                    ),
                    const SizedBox(height: 16),
                    TapScale(
                      onTap: () {
                        Navigator.of(dialogContext).pop();
                        showShareCardSheet(
                          context,
                          streak: streak,
                          weekTasks: weekTasks,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.tonal(AppColors.primary),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.ios_share_outlined,
                                size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Paylaş',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
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

  /// Rütbe atlama anı — önceden bu HİÇ olmuyordu, rütbe sessizce güncellenen
  /// bir sayıydı. Artık günlük hedef kutlamasıyla aynı görsel dil (konfeti +
  /// kart) ama rütbenin kendi rengiyle + doğrudan merdivene giden bir CTA
  /// ile — "bir sonraki hedef ne" sorusuna hemen cevap veriyor.
  void _showRankUpCelebration(RankInfo info) {
    final color = Color(info.colorHex);
    showDialog(
      context: context,
      barrierColor: Colors.black26,
      barrierDismissible: true,
      builder: (dialogContext) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _goalConfetti.play();
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
                  colors: [color, AppColors.primary],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [color, color.withValues(alpha: 0.6)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [AppColors.glow(color)],
                      ),
                      child: const Icon(Icons.military_tech_outlined,
                          color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Yeni rütbe: ${info.name}',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.heading3,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      info.atMax
                          ? 'Merdivenin zirvesindesin.'
                          : '${info.nextName} için ${info.xpToNextRank} XP kaldı.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySecondary,
                    ),
                    const SizedBox(height: 16),
                    TapScale(
                      onTap: () {
                        Navigator.of(dialogContext).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const RankLadderScreen()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.tonal(color),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.trending_up, size: 16, color: color),
                            const SizedBox(width: 8),
                            Text(
                              'Merdiveni Gör',
                              style: AppTextStyles.body.copyWith(
                                color: color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
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

  void _startWorking({
    TaskModel? task,
    StudySuggestion? suggestion,
  }) {
    if (task == null && suggestion == null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CoachScreen()),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FocusScreen(
          initialNote: task?.title,
          initialTargetMin: task?.estimatedMinutes,
          initialSubjectId: task?.subjectId ?? suggestion?.subjectId,
          initialTopicId: task?.topicId,
          initialTaskId: task?.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayTasksRaw = ref.watch(todayTasksProvider);
    final todayTasks = _sortedBySchedule(todayTasksRaw);
    final allTasks = ref.watch(taskProvider);
    final subjects = ref.watch(subjectProvider);
    final stats = ref.watch(statsProvider);

    final now = DateTime.now();
    final scheduledIncomplete = allTasks
        .where((task) =>
            task.scheduledTime != null &&
            !task.isCompleted &&
            task.scheduledTime!.year == now.year &&
            task.scheduledTime!.month == now.month &&
            task.scheduledTime!.day == now.day)
        .toList()
      ..sort((a, b) => a.scheduledTime!.compareTo(b.scheduledTime!));

    TaskModel? firstWithStatus(TaskTimeStatus s) {
      for (final t in scheduledIncomplete) {
        if (t.timeStatusAt(now) == s) return t;
      }
      return null;
    }

    final activeTask =
        firstWithStatus(TaskTimeStatus.inProgress) ??
            firstWithStatus(TaskTimeStatus.upcoming) ??
            firstWithStatus(TaskTimeStatus.overdue);

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
        NotificationService.instance.cancelNotification(
          _streakRiskId(DateTime.now()),
          NotificationCategory.streakWarning,
        );
        final t = DateTime.now();
        final today = DateTime(t.year, t.month, t.day);
        if (_celebratedOn == today) return;
        _celebratedOn = today;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showGoalCelebration();
        });
      }
    });

    // Rütbe önceden tamamen sessiz bir sayıydı — XP eşiği geçilince arka
    // planda güncellenip hiçbir an/kutlama olmadan bir sonraki açılışta
    // fark ediliyordu ("boş yere duruyor" hissi tam buradan geliyordu).
    // previous null olduğu sürece (oturumun İLK hesaplaması, ör. uygulama
    // az önce açıldı) tetiklenmez — yalnız GERÇEKTEN bu oturum içinde
    // artışta.
    ref.listen<RankInfo>(rankProvider, (previous, next) {
      if (previous != null && next.rank > previous.rank) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showRankUpCelebration(next);
        });
      }
    });

    final completedCount = todayTasks.where((t) => t.isCompleted).length;
    final totalCount = todayTasks.length;
    final todayProgress = totalCount == 0 ? 0.0 : completedCount / totalCount;

    final focusThisWeekMin = ref.watch(focusThisWeekMinutesProvider);
    final thisWeekCompleted = ref.watch(tasksCompletedThisWeekProvider);

    final coverage = ref.watch(coverageBySubjectProvider);
    final suggestions = activeTask == null
        ? StudyAdvisor.suggest(
            subjects: subjects,
            tasks: allTasks,
            examDate: stats.examDate,
            limit: 1,
            coveragePercent: {
              for (final e in coverage.entries)
                if (e.value.hasTopics) e.key: e.value.ratio,
            },
            weakestDenemeSubjectId: ref.watch(weakestDenemeSubjectIdProvider),
            focusMinutesBySubject: ref.watch(focusMinutesBySubjectProvider),
          )
        : const <StudySuggestion>[];
    final topSuggestion = suggestions.isEmpty ? null : suggestions.first;

    SubjectModel? activeSubject;
    final activeSubjectId = activeTask?.subjectId ?? topSuggestion?.subjectId;
    if (activeSubjectId != null) {
      for (final s in subjects) {
        if (s.id == activeSubjectId) {
          activeSubject = s;
          break;
        }
      }
    }

    final focusByDay = ref.watch(focusMinutesByDayProvider);
    final today0 = DateTime(now.year, now.month, now.day);
    final sparkline = List<double>.generate(14, (i) {
      final day = today0.subtract(Duration(days: 13 - i));
      return (focusByDay[day] ?? 0).toDouble();
    });

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _AuroraBackground()),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 110),
              children: [
                _HomeHeader(
                  greeting: _greeting(stats.userName),
                  initial: (stats.userName?.trim().isNotEmpty ?? false)
                      ? stats.userName!.trim()[0].toUpperCase()
                      : null,
                  rank: ref.watch(rankProvider).rank,
                  onProfileTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ),
                  onRankTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RankLadderScreen()),
                  ),
                ),
                const SizedBox(height: 22),
                const _ActiveFocusBanner(),
                _ActiveTopicHero(
                  task: activeTask,
                  subject: activeSubject,
                  suggestion: topSuggestion,
                  hasAnySubject: subjects.isNotEmpty,
                  todayProgress: todayProgress,
                  streak: stats.currentStreak,
                  onStart: () => _startWorking(
                    task: activeTask,
                    suggestion: topSuggestion,
                  ),
                  onAskCoach: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CoachScreen()),
                  ),
                ),
                const SizedBox(height: 26),
                const SectionHeader(
                    title: 'Haftalık İlerleme', trailing: 'Bu Hafta'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: MetricTile(
                        icon: Icons.schedule_outlined,
                        label: 'ÇALIŞMA SÜRESİ',
                        value: (focusThisWeekMin / 60).toStringAsFixed(1),
                        unit: 'Saat',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MetricTile(
                        icon: Icons.menu_book_outlined,
                        label: 'BİTİRİLEN',
                        value: '$thisWeekCompleted',
                        unit: 'Görev',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _StreakCard(streak: stats.currentStreak, values: sparkline),
                const SizedBox(height: 26),
                SectionHeader(
                  title: 'Sıradaki Oturumlar',
                  trailing: scheduledIncomplete.isEmpty
                      ? null
                      : '${scheduledIncomplete.length} planlandı',
                ),
                const SizedBox(height: 12),
                if (scheduledIncomplete.isEmpty)
                  const EmptyStateCard(
                    icon: Icons.event_available_outlined,
                    message: 'Bugün için planlı oturum yok.',
                  )
                else
                  ...scheduledIncomplete.map((task) {
                    SubjectModel? subject;
                    if (task.subjectId != null) {
                      for (final s in subjects) {
                        if (s.id == task.subjectId) {
                          subject = s;
                          break;
                        }
                      }
                    }
                    return _AnimatedTaskEntry(
                      key: ValueKey(task.id),
                      child: TaskSwipeActions(
                        task: task,
                        margin: const EdgeInsets.only(bottom: 10),
                        borderRadius: BorderRadius.circular(18),
                        child: _UpcomingSessionRow(
                          task: task,
                          subject: subject,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  AddTaskScreen(taskToEdit: task),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: GradientFab(
        tooltip: 'Görev ekle',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddTaskScreen()),
          );
        },
      ),
    );
  }
}

/// Üst bilgi satırı — selam + isim solda, sağda profil rozeti (isim
/// baş harfi, altın/turuncu halka + nabız parıltısı).
class _HomeHeader extends StatefulWidget {
  final String greeting;
  final String? initial;
  final int rank;
  final VoidCallback onProfileTap;
  final VoidCallback onRankTap;

  const _HomeHeader({
    required this.greeting,
    required this.initial,
    required this.rank,
    required this.onProfileTap,
    required this.onRankTap,
  });

  @override
  State<_HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<_HomeHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    final reduceMotion = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (!reduceMotion) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(widget.greeting, style: AppTextStyles.heading2),
        SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Semantics(
                button: true,
                label: 'Profil',
                child: TapScale(
                  onTap: widget.onProfileTap,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final t = _controller.value;
                      return Container(
                        width: 44,
                        height: 44,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.primaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary
                                  .withValues(alpha: 0.35 - t * 0.15),
                              blurRadius: 10 + t * 8,
                              spreadRadius: t * 2,
                            ),
                          ],
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surfaceVariant,
                          ),
                          alignment: Alignment.center,
                          child: widget.initial == null
                              ? Icon(Icons.person_outline,
                                  size: 19, color: AppColors.textPrimary)
                              : Text(
                                  widget.initial!,
                                  style: AppTextStyles.body.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // Rütbe rozeti — avatarın köşesinde, Profil'e girmeden
              // rütbenin var olduğunu ve seviyesini gösterir (kullanıcı
              // isteği: Home'a tam rütbe şeridi konmayacak ama bir yerde
              // görünür olsun). Dokununca doğrudan Rütbeler ekranına gider.
              Positioned(
                right: -2,
                bottom: -2,
                child: Semantics(
                  button: true,
                  label: 'Rütbeler',
                  child: TapScale(
                    onTap: widget.onRankTap,
                    child: Container(
                      width: 22,
                      height: 22,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.background,
                        border: Border.all(color: AppColors.background, width: 2),
                        boxShadow: AppColors.softShadow,
                      ),
                      child: RankEmblem(rank: widget.rank, size: 18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Devam eden (arka planda "duraklamış" değil, gerçekten hâlâ sayan) bir
/// odak seansı varsa Home'da gösterilen şerit — kullanıcı Odak ekranına
/// TEKRAR GİRMEDEN kaç dakika geçtiğini/kaldığını görebilsin diye. Rakip
/// uygulamalarda bu genelde sürekli güncellenen bir sistem bildirimiyle
/// çözülüyor; burada bilinçli olarak öyle yapılmadı — proje daha önce native
/// foreground servisten kaçınmayı seçti (bkz. CLAUDE.md P0-5: Play Store
/// "specialUse" FGS inceleme riski). Bunun yerine Home'un kendisi bu görevi
/// üstleniyor: HiveBoxes.focusAnchor'ı dinler (odak ekranı artık geri
/// gidince değil yalnız "Bitir"e basılınca bu çapayı siliyor — bkz.
/// focus_screen.dart), canlı kalması için kendi 1 saniyelik ticker'ı var.
class _ActiveFocusBanner extends ConsumerStatefulWidget {
  const _ActiveFocusBanner();

  @override
  ConsumerState<_ActiveFocusBanner> createState() =>
      _ActiveFocusBannerState();
}

class _ActiveFocusBannerState extends ConsumerState<_ActiveFocusBanner> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _fmt(int totalSec) {
    final s = totalSec.abs();
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box>(
      valueListenable: HiveBoxes.focusAnchor.listenable(),
      builder: (context, box, _) {
        final raw = box.get('current');
        if (raw is! Map) return const SizedBox.shrink();
        final segStartMs = raw['segStartMs'] as int?;
        if (segStartMs == null) return const SizedBox.shrink();

        final mode = raw['mode'] as String? ?? 'free';
        final blockMin = raw['blockMin'] as int? ?? 25;
        final committedSec = raw['committedSec'] as int? ?? 0;
        final subjectId = raw['subjectId'] as String?;
        final note = (raw['note'] as String?)?.trim();

        final segStart = DateTime.fromMillisecondsSinceEpoch(segStartMs);
        final elapsedSec =
            committedSec + DateTime.now().difference(segStart).inSeconds;

        final isPomodoro = mode == 'pomodoro';
        final remainingSec = isPomodoro ? (blockMin * 60 - elapsedSec) : null;

        SubjectModel? subject;
        if (subjectId != null) {
          for (final s in ref.watch(subjectProvider)) {
            if (s.id == subjectId) {
              subject = s;
              break;
            }
          }
        }
        final label = (note?.isNotEmpty ?? false)
            ? note!
            : (subject?.name ?? 'Odak seansı');
        final timeText = remainingSec != null
            ? '${_fmt(remainingSec)} kaldı'
            : '${_fmt(elapsedSec)} geçti';

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TapScale(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FocusScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border:
                    Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                boxShadow: AppColors.softShadow,
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Odak devam ediyor · $label',
                          style: AppTextStyles.body
                              .copyWith(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(timeText, style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Home'un hero'su — "şu an ne çalışmalıyım" tek cevap. Öncelik: bugüne
/// zamanlanmış aktif/sıradaki görev > StudyAdvisor önerisi > boş durum.
/// CTA her zaman aynı yerde: görev/öneri varsa doğrudan o ders/konu için
/// Odak Seansı başlatır, hiçbiri yoksa Çalışma Koçu'nu açar. Koç ayrıca
/// hasTarget=true iken de (görev/öneri varken) küçük bir ikincil butonla
/// HER ZAMAN bir dokunuşla erişilebilir kalır — "bizim AI" (yerel Çalışma
/// Koçu) rakiplerin çoğunun sahte iddia ettiği bir şey, Home'dan hiç
/// kaybolmamalı (kullanıcı kararı, 2026-09-16).
class _ActiveTopicHero extends StatelessWidget {
  final TaskModel? task;
  final SubjectModel? subject;
  final StudySuggestion? suggestion;
  final bool hasAnySubject;
  final double todayProgress;
  final int streak;
  final VoidCallback onStart;
  final VoidCallback onAskCoach;

  const _ActiveTopicHero({
    required this.task,
    required this.subject,
    required this.suggestion,
    required this.hasAnySubject,
    required this.todayProgress,
    required this.streak,
    required this.onStart,
    required this.onAskCoach,
  });

  @override
  Widget build(BuildContext context) {
    final hasTarget = task != null || suggestion != null;
    final tint = subject != null ? Color(subject!.colorValue) : AppColors.primary;

    final String badgeLabel;
    final IconData badgeIcon;
    if (task != null) {
      badgeLabel = 'AKTİF GÖREV';
      badgeIcon = Icons.bolt_outlined;
    } else if (suggestion != null) {
      badgeLabel = 'ÖNERİLEN';
      badgeIcon = Icons.auto_awesome_outlined;
    } else {
      badgeLabel = 'BUGÜN';
      badgeIcon = Icons.wb_sunny_outlined;
    }

    final title = task?.title ?? suggestion?.subjectName ?? 'Bugün için plan yok';
    final subtitle = task != null
        ? (subject?.name ?? 'Derssiz')
        : suggestion?.reason ??
            (hasAnySubject
                ? 'Bir görev planlamadın — hadi başlayalım.'
                : 'Önce bir ders ekle, sonra plan kur.');

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(tint.withValues(alpha: 0.16), AppColors.surface),
            AppColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: tint.withValues(alpha: 0.3)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(badgeIcon, size: 13, color: tint),
                const SizedBox(width: 6),
                Text(
                  badgeLabel,
                  style: AppTextStyles.eyebrow.copyWith(color: tint, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: AppTextStyles.heading1.copyWith(fontSize: 28),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTextStyles.bodySecondary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  icon: Icons.schedule_outlined,
                  value: task?.estimatedMinutes != null
                      ? '${task!.estimatedMinutes} Dakika'
                      : '—',
                  label: 'Hedef Süre',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroMetric(
                  icon: Icons.track_changes_outlined,
                  value: '%${(todayProgress * 100).round()}',
                  label: 'Bugün',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroMetric(
                  icon: Icons.local_fire_department_outlined,
                  value: '$streak Gün',
                  label: 'Seri',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: hasTarget ? 'Çalışmaya Başla' : 'Bugünü Planla',
                  icon: hasTarget
                      ? Icons.play_arrow_rounded
                      : Icons.auto_awesome_outlined,
                  onPressed: onStart,
                ),
              ),
              // Boş durumda CTA zaten Koç'a gidiyor — burada tekrarlamaya
              // gerek yok, yalnız hasTarget=true iken (Koç Home'dan tek
              // yol olan ana CTA tarafından kapatılmışken) gösteriliyor.
              if (hasTarget) ...[
                const SizedBox(width: 10),
                _AskCoachButton(onTap: onAskCoach),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Hero'daki ikincil "Koç'a Sor" butonu — ana CTA'nın (Çalışmaya Başla)
/// yanında, her zaman görünür, sabit boyutlu (64x64, PrimaryButton'la aynı
/// yükseklik) dairesel ikon buton. Violet — Plan sekmesindeki Koç hero'suyla
/// aynı renk kimliği, altın/turuncu ana CTA'yla karışmasın diye.
class _AskCoachButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AskCoachButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tint = AppColors.vibrantViolet;
    return Semantics(
      button: true,
      label: 'Çalışma Koçu\'na sor',
      child: TapScale(
        onTap: onTap,
        child: Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.tonal(tint),
            shape: BoxShape.circle,
            border: Border.all(color: tint.withValues(alpha: 0.4)),
          ),
          child: Icon(Icons.auto_awesome_outlined, color: tint, size: 22),
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _HeroMetric({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(label,
              style: AppTextStyles.caption.copyWith(fontSize: 10.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// "İstikrar" kartı — seri gün sayısı + son 14 günün odak dakikası
/// trendini gösteren parıltılı çizgi grafiği (fl_chart yok — özel
/// CustomPainter, uygulamanın "hiçbir grafik kütüphanesi yok" kuralına
/// uyuyor, bkz. activity_heatmap.dart / _FocusWeekBar).
class _StreakCard extends StatelessWidget {
  final int streak;
  final List<double> values;

  const _StreakCard({required this.streak, required this.values});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.local_fire_department_outlined,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'İSTİKRAR',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
              if (streak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.tonal(AppColors.vibrantViolet),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Aktif Seri',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.vibrantViolet,
                      fontWeight: FontWeight.w700,
                      fontSize: 10.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$streak',
                  style: AppTextStyles.heading2.copyWith(letterSpacing: -0.3)),
              const SizedBox(width: 6),
              Text('Gün',
                  style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 56,
            width: double.infinity,
            child: CustomPaint(
              painter: _SparklinePainter(values: values, color: AppColors.vibrantViolet),
            ),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0) return;
    final maxV = values.fold<double>(1, (a, b) => b > a ? b : a);
    final stepX = size.width / (values.length - 1);

    Offset pointAt(int i) {
      final normalized = maxV <= 0 ? 0.0 : (values[i] / maxV).clamp(0.0, 1.0);
      final y = size.height - normalized * (size.height - 6) - 3;
      return Offset(i * stepX, y);
    }

    final path = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 0; i < values.length - 1; i++) {
      final p0 = pointAt(i);
      final p1 = pointAt(i + 1);
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    final last = pointAt(values.length - 1);
    path.lineTo(last.dx, last.dy);

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.32), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path, glowPaint);

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

/// "Sıradaki Oturumlar" satırı — ders rozeti + başlık + saat. Swipe ile
/// tamamla/ertele/sil (TaskSwipeActions, task_tile.dart ile paylaşılan).
class _UpcomingSessionRow extends StatelessWidget {
  final TaskModel task;
  final SubjectModel? subject;
  final VoidCallback onTap;

  const _UpcomingSessionRow({
    required this.task,
    required this.subject,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tint = subject != null ? Color(subject!.colorValue) : AppColors.primary;
    final scheduled = task.scheduledTime;

    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                subject?.name ?? 'Genel',
                style: AppTextStyles.caption.copyWith(
                  color: tint,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                task.title,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (scheduled != null) ...[
              const SizedBox(width: 8),
              Text(
                _HomeScreenState._hhmm(scheduled),
                style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
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
