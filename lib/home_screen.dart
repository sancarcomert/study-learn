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
import 'deneme_provider.dart';
import 'add_task_screen.dart';
import 'coach_screen.dart';
import 'daily_closeout_model.dart';
import 'daily_closeout_provider.dart';
import 'daily_closeout_sheet.dart';
import 'rank_ladder_screen.dart';
import 'rank_provider.dart';
import 'rank_system.dart';
import 'widgets/rank_bar.dart';
import 'widgets/rank_emblem.dart';
import 'widgets/task_tile.dart';
import 'stats_screen.dart';
import 'profile_screen.dart';
import 'tap_scale.dart';
import 'widgets/empty_state_card.dart';
import 'widgets/app_snackbar.dart';
import 'widgets/share_card.dart';
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

  // Akşam "Bugünü kapat" kartını bu oturumda elle kapattıysa tekrar
  // göstermeyiz (ertesi gün yeniden çıkar).
  bool _closeOutDismissed = false;

  // "Yarına taşıyalım mı?" sorusu oturum başına bir kez — "Kalsın" dedikten
  // sonra kartı tekrar açınca (düzenlemek için) yeniden sorulmasın.
  bool _carryForwardTonightAsked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(statsProvider.notifier).checkStreakBroken();
      await _maybeShowNotificationPermissionPrompt();
      if (mounted) await _maybeShowCarryOverPrompt();
      if (mounted) await _maybeScheduleStreakRisk();
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

  /// Seri riski bildirimi (P0-3) — günlük hedef akşama kadar
  /// tutturulmazsa 20:30'da hatırlatır. Oturum başına bir kez (Home ilk
  /// açıldığında) zamanlanır; hedef o gün içinde tutturulursa
  /// `goalReachedEventProvider` dinleyicisi bunu iptal eder — zaten
  /// bitirmiş birine "serin kırılabilir" demeyelim.
  static String _streakRiskId(DateTime day) =>
      'streak_risk_${day.year}-${day.month}-${day.day}';

  Future<void> _maybeScheduleStreakRisk() async {
    final stats = ref.read(statsProvider);
    final today = DateTime.now();

    final completedToday = ref.read(taskProvider).where((t) =>
        t.isCompleted &&
        t.dueDate.year == today.year &&
        t.dueDate.month == today.month &&
        t.dueDate.day == today.day).length;

    if (completedToday >= stats.dailyGoal) return;

    final target = DateTime(today.year, today.month, today.day, 20, 30);
    if (target.isBefore(today)) return;

    final streak = stats.currentStreak;
    final body = streak > 0
        ? '$streak günlük serin bugün kırılabilir. Tek bir görev yeter 🔥'
        : 'Bugünü tamamlayarak yeni bir seri başlat 🔥';

    await NotificationService.instance.scheduleNotification(
      id: _streakRiskId(today),
      category: NotificationCategory.streakWarning,
      title: 'Bugün henüz bitmedi',
      body: body,
      dateTime: target,
    );
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

  /// "Günü Bitir" akışının ilk adımı: bugüne ait bitirilmemiş görev varsa
  /// kapanış özetinden ÖNCE sorar. Sabahki "geçmiş günden kalan" hatırlatması
  /// (_maybeShowCarryOverPrompt) hâlâ bir güvenlik ağı olarak duruyor — bu
  /// akışı hiç kullanmayan/o gün kapatmayan kullanıcı için.
  Future<void> _closeOutToday() async {
    await _maybeAskCarryForwardTonight();
    if (mounted) showDailyCloseoutSheet(context);
  }

  Future<void> _maybeAskCarryForwardTonight() async {
    if (_carryForwardTonightAsked || !mounted) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final unfinished = ref
        .read(taskProvider)
        .where((t) =>
            !t.isCompleted &&
            t.dueDate.year == today.year &&
            t.dueDate.month == today.month &&
            t.dueDate.day == today.day)
        .toList();
    if (unfinished.isEmpty || !mounted) return;

    _carryForwardTonightAsked = true;
    final n = unfinished.length;
    final move = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.nightlight_outlined,
            color: AppColors.primary, size: 30),
        title: Text(n == 1
            ? 'Bitiremediğin 1 görev var'
            : 'Bitiremediğin $n görev var'),
        content: const Text('Yarına taşıyalım mı?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Kalsın'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yarına Taşı'),
          ),
        ],
      ),
    );

    if (!mounted || move != true) return;

    final tomorrow = today.add(const Duration(days: 1));
    final notifier = ref.read(taskProvider.notifier);
    for (final t in unfinished) {
      final st = t.scheduledTime;
      notifier.updateTask(
        t,
        title: t.title,
        subjectId: t.subjectId,
        dueDate: tomorrow,
        priority: t.priority,
        scheduledTime: st == null
            ? null
            : DateTime(
                tomorrow.year, tomorrow.month, tomorrow.day, st.hour, st.minute),
        estimatedMinutes: t.estimatedMinutes,
        difficulty: t.difficulty,
      );
    }
    if (mounted) {
      AppSnackBar.success(context,
          n == 1 ? 'Görev yarına taşındı' : '$n görev yarına taşındı');
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
                    const Text("🎉", style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 12),
                    const Text(
                      "Günlük hedef tamamlandı!",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                            const Icon(Icons.ios_share_outlined,
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
        // Hedef tutturuldu — akşama zamanlanmış "serin kırılabilir"
        // uyarısı artık anlamsız, iptal et.
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

    final completedCount = todayTasks.where((t) => t.isCompleted).length;
    final totalCount = todayTasks.length;

    // P0-4: bu hafta / geçen hafta tamamlanan görev karşılaştırması.
    final thisWeekCompleted = ref.watch(tasksCompletedThisWeekProvider);
    final lastWeekCompleted = ref.watch(tasksCompletedLastWeekProvider);

    // "Bugünü kapat" ritüeli (B3): akşam, henüz kapatılmadıysa entry kartı;
    // kapatıldıktan sonra bu kart kayboluyor ama yerini _RelaxModeCard
    // alıyor (aşağıda, görev listesinin yerinde) — o hem "kapattın" mesajını
    // taşıyor hem dokununca aynı sheet'i (Güncelle modunda) açıyor, tek
    // giriş noktası yeterli, ikisi birden aynı mesajı tekrar etmesin diye.
    // Sabah, dün bir niyet yazıldıysa nazik hatırlatma.
    final todayCloseout = ref.watch(todayCloseoutProvider);
    final yesterdayIntent = ref.watch(yesterdayIntentProvider);
    // "Bugünü Kapat" artık saate bağlı değil — kullanıcı geri bildirimi:
    // saat 18:00'dan önce günü bitirmiş biri kapatamıyordu, "bir var bir
    // yok" tutarsız hissettiriyordu. Şimdi kapatılmadığı sürece her zaman
    // görünür.
    final isEvening = now.hour >= 18;
    final showCloseOutCard = todayCloseout == null && !_closeOutDismissed;
    final showYesterdayIntent = !isEvening &&
        todayCloseout == null &&
        yesterdayIntent != null &&
        yesterdayIntent.isNotEmpty;

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
            weakestDenemeSubjectId: ref.watch(weakestDenemeSubjectIdProvider),
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
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
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

                  if (showYesterdayIntent) ...[
                    const SizedBox(height: 10),
                    _YesterdayIntentLine(text: yesterdayIntent),
                  ],

                  const SizedBox(height: 32),

                  // 3) KRAL BUTON
                  _KingButton(
                    label: 'Bugünü Planla',
                    icon: Icons.auto_awesome_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CoachScreen()),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 3.5) RÜTBE — türetilmiş merdiven (P0-2)
                  TapScale(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const RankLadderScreen()),
                    ),
                    child: _RankStrip(info: ref.watch(rankProvider)),
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

                  if (thisWeekCompleted > 0) ...[
                    const SizedBox(height: 12),
                    _WeekCompareStrip(
                      thisWeek: thisWeekCompleted,
                      lastWeek: lastWeekCompleted,
                    ),
                  ],

                  if (upcomingTask != null) ...[
                    const SizedBox(height: 28),
                    NextTaskCard(task: upcomingTask, subjects: subjects),
                  ],

                  if (showCloseOutCard) ...[
                    const SizedBox(height: 28),
                    _CloseOutCard(
                      onTap: _closeOutToday,
                      onDismiss: () =>
                          setState(() => _closeOutDismissed = true),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // 5) BUGÜNKÜ GÖREVLER — gün kapatıldıysa yerini sakin bir
                  // "dinlenme modu" kartı alır (kullanıcı bulgusu: kapatınca
                  // görev listesi hâlâ orada durmak yanlış hissettiriyordu).
                  if (todayCloseout != null)
                    _RelaxModeCard(
                      closeout: todayCloseout,
                      onReopen: () => ref
                          .read(dailyCloseoutProvider.notifier)
                          .reopenToday(),
                    )
                  else ...[
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
                  ],

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
        tooltip: 'Görev ekle',
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
                  'Daireye dokun, görevi tamamla. ▶ ile odağı başlat.',
                  style: AppTextStyles.bodySecondary.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sağa kaydır: yarına al. Sola kaydır: sil.',
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

/// Home'daki kompakt rütbe şeridi (P0-2). Dokun → Profil (tam kart).
class _RankStrip extends StatelessWidget {
  final RankInfo info;

  const _RankStrip({required this.info});

  @override
  Widget build(BuildContext context) {
    final color = Color(info.colorHex);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          RankEmblem(rank: info.rank, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      info.name.toUpperCase(),
                      style: AppTextStyles.eyebrow.copyWith(color: color),
                    ),
                    const Spacer(),
                    Text(
                      info.atMax
                          ? 'En üst rütbe'
                          : '${info.nextName} için ${info.xpToNextRank} XP',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                RankBar(info: info, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Bu hafta geçen haftandan öndesin" (P0-4) — tek satır, kaygı değil
/// cesaretlendirme tonu. `thisWeek` 0 iken çağıran yerde hiç gösterilmiyor.
class _WeekCompareStrip extends StatelessWidget {
  final int thisWeek;
  final int lastWeek;

  const _WeekCompareStrip({required this.thisWeek, required this.lastWeek});

  @override
  Widget build(BuildContext context) {
    final diff = thisWeek - lastWeek;
    final String tail;
    if (lastWeek == 0) {
      tail = 'geçen hafta kayıt yok';
    } else if (diff > 0) {
      tail = 'geçen haftadan +$diff';
    } else if (diff < 0) {
      tail = 'geçen hafta $lastWeek görevdin — devam';
    } else {
      tail = 'geçen haftayla aynı tempo';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          const Icon(Icons.insights_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Bu hafta $thisWeek görev · $tail',
              style:
                  AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sabah, dün "Bugünü kapat"ta yazılan niyetin nazik hatırlatması (B3).
/// Tek satır, dokunulamaz — sadece bir hatırlatma.
class _YesterdayIntentLine extends StatelessWidget {
  final String text;

  const _YesterdayIntentLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.wb_twilight_outlined,
              size: 15, color: AppColors.textMuted),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Dün için not düşmüştün: $text',
            style: AppTextStyles.caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Gün kapatıldıktan sonra "BUGÜNKÜ GÖREVLER" listesinin yerini alan sakin
/// kart — kullanıcı bulgusu: günü kapatınca görev listesinin hâlâ orada
/// durması yanlış hissettiriyordu, "dinlenme moduna" geçmesi gerekiyordu.
/// Ertesi gün `todayCloseoutProvider` doğal olarak null'a döner (gün
/// anahtarına göre), bu kart otomatik olarak kaybolur — ekstra bir
/// zamanlayıcı/sıfırlama gerekmiyor.
class _RelaxModeCard extends StatelessWidget {
  final DailyCloseout closeout;
  final VoidCallback onReopen;
  const _RelaxModeCard({required this.closeout, required this.onReopen});

  @override
  Widget build(BuildContext context) {
    final hasIntent = closeout.intent.trim().isNotEmpty;
    return TapScale(
      onTap: () => showDailyCloseoutSheet(context),
      child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.tonal(AppColors.secondary),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bedtime_outlined,
                color: AppColors.secondary, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            'Bugünü kapattın',
            style: AppTextStyles.heading3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            closeout.completedTasks == 0
                ? 'Dinlenme vaktin. Yarın devam.'
                : '${closeout.completedTasks} görev bitirdin. Dinlenme vaktin.',
            style: AppTextStyles.bodySecondary,
            textAlign: TextAlign.center,
          ),
          if (hasIntent) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('YARIN', style: AppTextStyles.eyebrow),
                  const SizedBox(height: 4),
                  Text(
                    closeout.intent,
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          // "Aslında biraz daha çalışacağım" — bugünü yeniden açar (kaydı
          // siler), kart kaybolup yerini yeniden görev listesi alır. Ayrı
          // TapScale: dış karttaki (düzenle) dokunmayla çakışmasın. Diğer
          // ikincil aksiyon çiplerinin (ör. "Detayları Gizle") aynı dili —
          // tonal dolgu + ikon — burada da, altı çizili düz metin yerine.
          TapScale(
            onTap: onReopen,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.tonal(AppColors.textSecondary),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.replay_outlined,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    'Bugünü yeniden aç',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
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
    );
  }
}

/// Akşam Home'da beliren "Bugünü kapat" giriş kartı (B3). Dokun → özet
/// sayfası. "×" → bu oturumda gizle (ertesi gün yeniden çıkar). Yalnız
/// henüz kapatılmadıysa gösterilir — kapatıldıktan sonra yerini
/// _RelaxModeCard alır (o da dokununca aynı sheet'i Güncelle modunda
/// açar), iki kart aynı "kapattın" mesajını tekrar etmesin diye.
class _CloseOutCard extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _CloseOutCard({required this.onTap, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.surfaceVariant),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.tonal(AppColors.secondary),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.nightlight_outlined,
                  size: 18, color: AppColors.secondary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bugünü kapat',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('Kısa özet, yarına tek cümle',
                      style: AppTextStyles.caption),
                ],
              ),
            ),
            Semantics(
              button: true,
              label: 'Kartı gizle',
              child: TapScale(
                onTap: onDismiss,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.close, size: 16, color: AppColors.textMuted),
                ),
              ),
            ),
          ],
        ),
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

class _ProfileRing extends StatelessWidget {
  final VoidCallback onTap;

  const _ProfileRing({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Profil',
      child: TapScale(
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
