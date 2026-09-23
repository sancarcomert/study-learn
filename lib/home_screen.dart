// lib/home_screen.dart
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'task_provider.dart';
import 'carry_over_planner.dart';
import 'daily_closeout_provider.dart';
import 'daily_closeout_sheet.dart';
import 'subject_provider.dart';
import 'subject_model.dart';
import 'stats_provider.dart';
import 'task_model.dart';
import 'task_time_status.dart';
import 'study_advisor.dart';
import 'study_intent.dart';
import 'study_recommendation.dart';
import 'next_task_picker.dart';
import 'topic_provider.dart';
import 'goal_gap_provider.dart';
import 'focus_anchor.dart';
import 'today_study.dart';
import 'topic_evidence_provider.dart';
import 'focus_session_provider.dart';
import 'focus_screen.dart';
import 'add_subject_sheet.dart';
import 'add_task_screen.dart';
import 'coach_screen.dart';
import 'profile_screen.dart';
import 'subject_topics_screen.dart';
import 'tasks_screen.dart';
import 'rank_provider.dart';
import 'rank_system.dart';
import 'rank_ladder_screen.dart';
import 'tap_scale.dart';
import 'widgets/empty_state_card.dart';
import 'widgets/app_buttons.dart';
import 'widgets/app_snackbar.dart';
import 'widgets/share_card.dart';
import 'widgets/task_tile.dart' show TaskSwipeActions;
import 'widgets/section_header.dart';
import 'widgets/metric_tile.dart';
import 'widgets/app_header.dart';
import 'widgets/exam_countdown.dart';
import 'widgets/goal_gap_chip.dart';
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
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
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
        .where((t) =>
            // Tekrarlayan görevler (recurringGroupId != null) her gün için
            // zaten kendi ayrı örneğini üretir (addRecurringTask, 30/12 örneği
            // baştan oluşturuyor) — dünkü örneği "bugüne taşırsak" bugünün
            // kendi örneğiyle YAN YANA, aynı başlıkta iki görev oluşurdu.
            t.recurringGroupId == null && t.isPastDayIncompleteAt(now))
        .toList();
    if (stale.isEmpty) return;

    _carryOverPrompted = true;
    ref.read(statsProvider.notifier).markCarryOverPromptedToday();
    final n = stale.length;
    // Kronik erteleme — bu taşımadan sonra 3. (ya da daha fazla) kez
    // ertelenmiş/yeniden planlanmış olacak görevler. Sessizce sonsuza dek
    // biriktirmek yerine (cezalandırmadan) fark ettiriyoruz — "recovery,
    // not guilt". BİLEREK postponeCount + systemRescheduleCount toplamı:
    // bu diyalog "bu görev tekrar tekrar sıkışıyor, küçültelim mi" diyor —
    // kaynağı (öğrenci mi taşıdı, sistem mi yaydı) burada önemli değil.
    // StudyAdvisor'ın "kaçınma" SİNYALİ ise SADECE postponeCount'a bakar
    // (bkz. task_model.dart'taki systemRescheduleCount notu) — o yüzden bu
    // diyalog kronik saysa bile StudyAdvisor öğrenciyi suçlamaz.
    final chronic = stale
        .where((t) => (t.postponeCount + t.systemRescheduleCount) >= 2)
        .toList();

    // "Bugüne taşı" tek başına, kalan görev hacmi büyükse gerçekçi olmayan
    // bir yığın yaratır (5 kaçırılmış görevi bugüne dayatmak, yarın için
    // aynı kaçırma döngüsünü baştan başlatır — "recovery" değil, sadece
    // ertelemenin yeri değişir). Saf/test edilmiş dağıtım mantığı
    // `carry_over_planner.dart`'ta (bkz. test/carry_over_planner_test.dart).
    final isOverloaded = CarryOverPlanner.isOverloaded(stale);
    final staleMinutes = stale.fold<int>(
        0, (sum, t) => sum + (t.estimatedMinutes ?? CarryOverPlanner.fallbackMinutes));

    // Diyalog eskiden yalnız "kısaltmak ya da bölmek" ÖNERİYORDU ama hiçbir
    // buton bunu gerçekten yapmıyordu — söz tutulmuyordu. Artık kronik
    // (2+ ertelenmiş) görev varsa bir aksiyon gerçekten süreyi yarıya
    // indiriyor (bkz. _shrinkTargetMinutes), aşırı yüklüyse de "bugüne taşı"
    // yerine "günlere yay" aksiyonu devreye giriyor.
    final moveLabel = isOverloaded ? 'Günlere Yay' : 'Bugüne Taşı';
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.history_rounded,
            color: AppColors.primary, size: 30),
        title: Text(n == 1
            ? 'Önceki günden kalan 1 görev var'
            : 'Önceki günlerden $n görev kaldı'),
        content: Text(
          isOverloaded
              ? 'Bunları bugüne sığdırmak gerçekçi olmaz (~${_fmtHours(staleMinutes)}) '
                  '— önümüzdeki günlere yayalım mı?'
              : (chronic.isEmpty
                  ? 'Tamamlanmamış görevleri bugüne taşıyalım mı?'
                  : (chronic.length == 1
                      ? '"${chronic.first.title}" art arda birkaç kez ertelendi — '
                          'belki süresini kısaltmak ya da daha küçük bir '
                          'parçaya bölmek bugün bitirmeyi kolaylaştırır.'
                      : '${chronic.length} görev art arda birkaç kez ertelendi — '
                          'belki süresini kısaltmak ya da bölmek bugün bitirmeyi '
                          'kolaylaştırır.')),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, null),
            child: const Text('Şimdi Değil'),
          ),
          if (chronic.isNotEmpty)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              onPressed: () => Navigator.pop(dialogContext, 'shrink'),
              child: Text(isOverloaded ? 'Küçült ve Yay' : 'Küçülterek Taşı'),
            ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(dialogContext, 'move'),
            child: Text(moveLabel),
          ),
        ],
      ),
    );

    if (!mounted || action == null) return;

    final shrink = action == 'shrink';
    final today = DateTime(now.year, now.month, now.day);
    final notifier = ref.read(taskProvider.notifier);

    int? minutesFor(TaskModel t) => (shrink && chronic.contains(t))
        ? _shrinkTargetMinutes(t.estimatedMinutes)
        : t.estimatedMinutes;

    // Aşırı yüklü DEĞİLSE eskisi gibi herkes bugüne (ofset 0) — davranış
    // değişmez. Aşırı yüklüyse CarryOverPlanner en öncelikli görevleri
    // bugüne, kapasite dolunca sıradaki gün(ler)e dağıtır.
    final plan = isOverloaded
        ? CarryOverPlanner.distribute(stale,
            minutesFor: (t) => minutesFor(t) ?? CarryOverPlanner.fallbackMinutes)
        : null;

    for (final t in stale) {
      final st = t.scheduledTime;
      final newMinutes = minutesFor(t);
      final offset = plan?.dayOffsetByTaskId[t.id] ?? 0;
      final dueDate = today.add(Duration(days: offset));
      // postponeCount DEĞİL — bu SİSTEMİN otomatik yeniden planlaması,
      // öğrencinin kendi kaydırma jesti değil (bkz. task_model.dart'taki
      // systemRescheduleCount notu). postponeTask'taki artış farklı bir
      // sinyal (gerçek öğrenci jesti) içindir.
      t.systemRescheduleCount += 1;
      notifier.updateTask(
        t,
        title: t.title,
        subjectId: t.subjectId,
        dueDate: dueDate,
        priority: t.priority,
        scheduledTime: st == null
            ? null
            : DateTime(dueDate.year, dueDate.month, dueDate.day, st.hour,
                st.minute),
        estimatedMinutes: newMinutes,
        difficulty: t.difficulty,
      );
    }
    if (mounted) {
      final String msg;
      if (plan != null) {
        msg = '$n görev önümüzdeki ${plan.dayCount} güne yayıldı';
      } else {
        msg = n == 1 ? 'Görev bugüne taşındı' : '$n görev bugüne taşındı';
      }
      AppSnackBar.success(
          context, shrink ? '$msg · süre kısaltıldı' : msg);
    }
  }

  /// Kronik ertelenen bir görevin süresini yarıya indirir (10 dk altına
  /// inmez). Süre hiç girilmemişse (null) küçültecek bir şey yok — olduğu
  /// gibi kalır.
  static int? _shrinkTargetMinutes(int? current) {
    if (current == null) return null;
    return (current / 2).round().clamp(10, current);
  }

  static String _fmtHours(int minutes) {
    final h = minutes / 60;
    return '${h.toStringAsFixed(1)} saat';
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

  static const _weekdays = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];
  static const _months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  static String _todayLabel() {
    final now = DateTime.now();
    return '${now.day} ${_months[now.month - 1]} ${_weekdays[now.weekday - 1]}';
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

  /// Öneri/görev kartından Focus'a geçiş — bağlam ([StudyIntent]) kaynağında
  /// üretilmiş olarak, OLDUĞU GİBİ taşınır (gerekçe dahil). Niyet yoksa
  /// (henüz ne çalışılacağı belli değil) Koç'a gider.
  void _startWorking(StudyIntent? intent, {bool autoStart = false}) {
    // Hiç ders yoksa (onboarding atlandı) tek anlamlı eylem ders eklemek —
    // Koç sohbetine gönderip "Profil'den ekle" demek çıkmaz sokaktı.
    if (intent == null && ref.read(subjectProvider).isEmpty) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const AddSubjectSheet(),
      );
      return;
    }
    if (intent == null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CoachScreen()),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FocusScreen(intent: intent, autoStart: autoStart),
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
    // "Şimdi ne yapmalıyım?" kartı: zamanlı görevler + (önceden hiç
    // görünmeyen) saatsiz bugünkü görevler — bkz. next_task_picker.dart.
    // Sıra mevcut konu kanıtından türer (yeni bir plan üreticisi YOK): güçlü
    // kanıt (deneme zayıf / üst üste zorlandı) sırayı öne çeker, gerisi
    // öğrencinin kendi öncelik/ekleme sırasıdır.
    final evidence = ref.watch(topicEvidenceProvider);
    final activeTask =
        NextTaskPicker.pick(allTasks, now, evidenceByTopic: evidence);
    final remainingTasks = NextTaskPicker.remaining(allTasks, now,
        exclude: activeTask, evidenceByTopic: evidence);

    ref.listen<int>(taskCompletionEventProvider, (previous, next) {
      if (previous == null || next <= previous) return;
      // Düz "Görev tamamlandı!" yerine gerçek bağlam — öğrenci neyi
      // başardığını (hangi ders, bu hafta kaçıncı oturum, bugünkü ilerleme,
      // sırada ne var) anında görsün. Büyük hedef kutlaması
      // (goalReachedEventProvider) ayrı ve zaten var; bu, ARA adımların da
      // bir anlamı olduğunu gösteriyor, sadece sonuncusunun değil.
      // `ref.read` ile TAZE veri — build anındaki değil, olayın
      // gerçekleştiği andaki durum.
      final completed = ref.read(lastCompletedTaskProvider);
      final freshToday = ref.read(todayTasksProvider);
      final doneToday = freshToday.where((t) => t.isCompleted).length;
      final totalToday = freshToday.length;

      final bits = <String>[];

      // Ders bazlı bağlam: bu hafta bu dersten kaçıncı oturum — "sadece
      // görev bitti" değil, dersin kendi birikimi görünür oluyor.
      if (completed?.subjectId != null) {
        final subjectName = ref
            .read(subjectProvider)
            .where((s) => s.id == completed!.subjectId)
            .firstOrNull
            ?.name;
        if (subjectName != null) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final monday = today.subtract(Duration(days: today.weekday - 1));
          final weekCount = ref
              .read(taskProvider)
              .where((t) =>
                  t.isCompleted &&
                  t.subjectId == completed!.subjectId &&
                  !taskCompletionDay(t).isBefore(monday))
              .length;
          bits.add(weekCount > 1
              ? 'bu hafta $weekCount. $subjectName oturumun'
              : '$subjectName tamamlandı');
        }
      }

      if (totalToday > 0) bits.add('$doneToday/$totalToday bugünkü görev');

      // Sıradaki adım: bugün kalan görevlerden (az önce bitirilen hariç)
      // zamanı/önceliği en önde olan — döngü "ne yaptım"da bitmesin, "şimdi
      // ne yapmalıyım"a bağlansın.
      final remainingToday = _sortedBySchedule(
        freshToday.where((t) => !t.isCompleted && t.id != completed?.id).toList(),
      );
      if (remainingToday.isNotEmpty) {
        bits.add('sırada: ${remainingToday.first.title}');
      }

      AppSnackBar.success(
        context,
        bits.isEmpty ? 'Görev tamamlandı!' : bits.join(' · '),
        duration: const Duration(seconds: 3),
      );
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

    final todayCompleted = todayTasks.where((t) => t.isCompleted).length;
    final todayTotal = todayTasks.length;

    final focusThisWeekMin = ref.watch(focusThisWeekMinutesProvider);
    final thisWeekCompleted = ref.watch(tasksCompletedThisWeekProvider);

    // GOAL → GAP (Faz 10) — Home'un "nerede duruyorum" rozeti, tek kaynaktan
    // (bkz. goal_gap_provider.dart).
    final goalGap = ref.watch(primaryGoalGapProvider);

    // Görev yokken öneri motoru (tek çalıştırıcı — Home/İstatistik/Koç aynı
    // girdilerle, bkz. study_recommendation.dart).
    final topSuggestion = activeTask == null
        ? runStudyAdvisor(ref.watch, limit: 1).firstOrNull
        : null;

    // Karttaki eylemin niyeti: görev (gerekçesi canlı kanıttan/planlanırken
    // yazılandan) ya da öneri (gerekçe + işaret ettiği konu). Focus bunu
    // olduğu gibi alır.
    final StudyIntent? cardIntent = activeTask != null
        ? intentForTask(ref.watch, activeTask)
        : (topSuggestion == null
            ? null
            : intentForSuggestion(ref.watch, topSuggestion));
    final activeTopicName = activeTask?.topicId == null
        ? null
        : ref
            .watch(topicProvider)
            .where((t) => t.id == activeTask!.topicId)
            .firstOrNull
            ?.name;
    // Gerekçe HER ZAMAN gerçek bir kaynaktan: konu kanıtı / planlanırken yazılan
    // / öneri motorunun somut nedeni. Hiçbiri yoksa görev için dürüst tek cümle
    // ("planındaki sıradaki çalışma"); öneri için hiçbir şey (jenerik
    // "dengeli ilerle" gibi sahte kişiselleştirme gösterilmez).
    final activeReason = cardIntent?.reason ??
        (activeTask != null ? 'Bugünkü planında sıradaki çalışma.' : null);
    final StudyIntent? startIntent = cardIntent?.copyWith(reason: activeReason);
    final todayStudyBase = TodayStudy.compute(
      tasks: allTasks,
      loggedMinutes: ref.watch(focusTodayMinutesProvider),
      now: now,
    );
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
          // 2026-09-19: Mentora referansı düz #F8FAFC zemin — renkli
          // bulanık "aurora" leke efekti "premium beyaz kart" diliyle
          // çelişiyor, açık temada kapatıldı. Koyu temada (referans
          // verilmedi) önceki atmosfer korundu.
          if (AppColors.isDark) const Positioned.fill(child: _AuroraBackground()),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 110),
              children: [
                AppHeader(
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
                const SizedBox(height: 34),
                // Gerçek çalışma süresi burada, Stats'a gitmeden: yazılmış odak
                // dakikaları + devam eden seansın henüz yazılmamış kısmı. Plan
                // (tahmini) ayrı gösterilir; XP/görev sayısı ASLA dakika değil.
                ValueListenableBuilder<Box>(
                  valueListenable: HiveBoxes.focusAnchor.listenable(),
                  builder: (context, box, _) {
                    final raw = box.get('current');
                    final live = raw is Map
                        ? FocusAnchorMath.unloggedMinutes(raw,
                            nowMs: DateTime.now().millisecondsSinceEpoch)
                        : 0;
                    final study = TodayStudy(
                      actualMinutes: todayStudyBase.actualMinutes + live,
                      plannedMinutes: todayStudyBase.plannedMinutes,
                    );
                    return AppTitleBlock(
                      eyebrow: _HomeScreenState._todayLabel(),
                      title: '${_greeting(stats.userName)} 👋',
                      subtitle:
                          todayStudyLine(study, hasTasksToday: todayTotal > 0),
                    );
                  },
                ),
                // Dün "Bugünü kapat"ta yazılmış tek cümlelik niyet varsa —
                // sabah nazik bir hatırlatma (yesterdayIntentProvider zaten
                // vardı, hiç okunmuyordu). Yalnız bir metin satırı — yeni
                // bir kart/aksiyon değil, "bunu unutmadım" hissi yeter.
                if (ref.watch(yesterdayIntentProvider) case final intent?) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Dün dediğin: "$intent"',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (stats.examDate != null || goalGap != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (stats.examDate != null)
                        ExamCountdownChip(examDate: stats.examDate!),
                      if (goalGap != null) GoalGapChip(goalGap: goalGap),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                const _ActiveFocusBanner(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('Bugünün Odağı', style: AppTextStyles.heading3),
                    TapScale(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TasksScreen()),
                      ),
                      child: Text(
                        'Tümünü gör',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _FocusRowCard(
                  task: activeTask,
                  subject: activeSubject,
                  suggestion: topSuggestion,
                  topicName: activeTopicName,
                  reason: activeReason,
                  nextUpTitle: remainingTasks.firstOrNull?.title,
                  allDoneToday: todayTotal > 0 && todayCompleted == todayTotal,
                  hasAnySubject: subjects.isNotEmpty,
                  minutes: startIntent?.targetMinutes ?? kDefaultFocusMinutes,
                  onStart: () => _startWorking(startIntent, autoStart: true),
                  onAskCoach: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CoachScreen()),
                  ),
                ),
                const SizedBox(height: 26),
                // Tek seferlik ipucu şeridi — hasSeenTaskHints alanı zaten
                // vardı (yedeklemede bile taşınıyordu) ama hiçbir ekran
                // okumuyordu. Görev listesinden hemen önce, ilk kullanıcı
                // kaydırma/dokunma jestlerini keşfetmeden önce görsün diye.
                if (!stats.hasSeenTaskHints && activeTask != null)
                  const _TaskHintStrip(),
                if (remainingTasks.isNotEmpty) ...[
                  SectionHeader(
                    // "Önerilen sıra" YALNIZ sıra gerçekten bir sinyale
                    // (kanıt/öncelik/gerekçe) dayanıyorsa; değilse öğrencinin
                    // kendi sırası — sahte kesinlik yok.
                    title: NextTaskPicker.isRecommendedOrder(
                            [if (activeTask != null) activeTask, ...remainingTasks],
                            evidenceByTopic: evidence)
                        ? 'Önerilen sıra'
                        : 'Bugün Kalanlar',
                    trailing: '${remainingTasks.length} çalışma',
                  ),
                  const SizedBox(height: 12),
                  ...remainingTasks.map((task) {
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
                        // Satıra dokunmak o çalışmayı BAŞLATMA niyetidir ("başka
                        // görevi seç"); düzenleme/silme uzun basış, erteleme
                        // kaydırma ile (TaskSwipeActions).
                        child: _UpcomingSessionRow(
                          task: task,
                          subject: subject,
                          reason: reasonForTask(ref.watch, task),
                          onTap: () => _startWorking(
                              intentForTask(ref.read, task)),
                        ),
                      ),
                    );
                  }),
                ] else if (activeTask == null && todayTotal == 0) ...[
                  const SectionHeader(title: 'Bugün Kalanlar'),
                  const SizedBox(height: 12),
                  EmptyStateCard(
                    icon: Icons.event_available_outlined,
                    message: todayTotal > 0
                        ? 'Bugünkü görevlerin tamam.'
                        : 'Bugün için planlı görev yok.',
                  ),
                ],
                // "Bugünü kapat" — yalnız GERÇEK bir "bugün için bitti"
                // sinyali varken (günlük hedefe ulaşıldı) ve bugün henüz
                // kapatılmadıysa. Modal/popup DEĞİL, sessiz tek satır.
                if (todayCompleted > 0 &&
                    todayCompleted >= stats.dailyGoal &&
                    ref.watch(todayCloseoutProvider) == null) ...[
                  const SizedBox(height: 20),
                  _DailyCloseoutPrompt(
                    onTap: () => showDailyCloseoutSheet(context),
                  ),
                ],
                // Puan/seri kartı bilerek eylem kartının ALTINDA: en gürültülü
                // (koyu, büyük) kart "ne yapmalıyım" sorusunun önüne geçmesin.
                const SizedBox(height: 26),
                _PointsStreakCard(
                  totalXp: ref.watch(rankProvider).xp,
                  streak: stats.currentStreak,
                  weeklyCompleted: thisWeekCompleted,
                  weeklyGoal: stats.dailyGoal * 7,
                ),

                if (subjects.isNotEmpty) ...[
                  const SizedBox(height: 26),
                  const SectionHeader(title: 'Ders Kısayolları'),
                  const SizedBox(height: 12),
                  _SubjectShortcuts(
                    subjects: subjects,
                    onTap: (s) => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SubjectTopicsScreen(
                          subjectId: s.id,
                          subjectName: s.name,
                        ),
                      ),
                    ),
                  ),
                ],
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
        // Unutulmuş seansın arka planda "sayan" süresi sınırlanır (bkz.
        // FocusAnchorMath) — banner da Focus'un kaydedeceği süreyi göstersin.
        final elapsedSec = mode == 'pomodoro'
            ? committedSec + DateTime.now().difference(segStart).inSeconds
            : FocusAnchorMath.creditedWorkSec(raw,
                nowMs: DateTime.now().millisecondsSinceEpoch);

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
        // Serbest seansta "kaç dakikadır odaktasın" (gerçek, kırpılmış süre);
        // Pomodoro'da blokta kalan süre.
        final timeText = remainingSec != null
            ? '${_fmt(remainingSec)} kaldı'
            : '${elapsedSec ~/ 60} dk odaktasın';

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

/// Figma'daki koyu "TOPLAM PUAN" kartı — rütbe XP'sini toplam puan olarak,
/// seriyi bir rozet pili, haftalık tamamlanan görev sayısını ince bir
/// ilerleme çubuğuyla gösterir. Sabit koyu — sayfa açık/koyu temada olsun
/// bu kart hep aynı (bilinçli tema-bağımsız vurgu, Apple Fitness/Duolingo
/// tarzı "hep koyu" özet kartlarıyla aynı fikir).
class _PointsStreakCard extends StatelessWidget {
  final int totalXp;
  final int streak;
  final int weeklyCompleted;
  final int weeklyGoal;

  const _PointsStreakCard({
    required this.totalXp,
    required this.streak,
    required this.weeklyCompleted,
    required this.weeklyGoal,
  });

  static String _thousands(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final ratio =
        weeklyGoal <= 0 ? 0.0 : (weeklyCompleted / weeklyGoal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.heroDark,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOPLAM PUAN',
                      style: AppTextStyles.eyebrow.copyWith(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _thousands(totalXp),
                      style: AppTextStyles.heading1
                          .copyWith(color: Colors.white, fontSize: 32),
                    ),
                  ],
                ),
              ),
              if (streak > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.heroDarkChip,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Text(
                        '$streak günlük seri',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Haftalık görev',
                style: AppTextStyles.caption
                    .copyWith(color: Colors.white.withValues(alpha: 0.55)),
              ),
              Text(
                '$weeklyCompleted / $weeklyGoal görev',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 7,
              child: Stack(
                children: [
                  // Figma'da bu iz koyu kartın üstünde yarı saydam değil,
                  // açık/dolgun bir gri — piksel örneklemesiyle düzeltildi.
                  Container(color: Colors.white.withValues(alpha: 0.85)),
                  FractionallySizedBox(
                    widthFactor: ratio,
                    child: Container(color: AppColors.progressOrange),
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

/// Home'un özü: "şimdi ne yapmalıyım, neden, ne kadar, nasıl başlarım" tek
/// kartta. Öncelik: sürüyor/yaklaşan/geciken zamanlı görev > önerilen sıradaki
/// saatsiz görev > StudyAdvisor önerisi > boş durum. Tek dominant eylem
/// "Başla": ders/konu/süre/görev/gerekçe niyetle taşınır, sayaç çalışır durumda
/// açılır — öğrenci dört beş karar vermez. Kartın tamamı da aynı eylemdir.
class _FocusRowCard extends StatelessWidget {
  final TaskModel? task;
  final SubjectModel? subject;
  final StudySuggestion? suggestion;
  final String? topicName;
  final String? reason;

  /// Bittiğinde sırada ne var — "bunu yapınca ne olacak?" sorusunun cevabı.
  final String? nextUpTitle;
  final bool allDoneToday;
  final bool hasAnySubject;

  /// Başla'nın açacağı seansın süresi (dk).
  final int minutes;
  final VoidCallback onStart;
  final VoidCallback onAskCoach;

  const _FocusRowCard({
    required this.task,
    required this.subject,
    required this.suggestion,
    required this.topicName,
    required this.reason,
    required this.nextUpTitle,
    required this.allDoneToday,
    required this.hasAnySubject,
    required this.minutes,
    required this.onStart,
    required this.onAskCoach,
  });

  @override
  Widget build(BuildContext context) {
    final hasTarget = task != null || suggestion != null;
    final tint =
        subject != null ? Color(subject!.colorValue) : AppColors.eyebrowRose;

    final title = task?.title ??
        suggestion?.topicName ??
        suggestion?.subjectName ??
        (allDoneToday ? 'Bugünkü planın tamam' : 'Bugün için plan yok');

    // Ne / ne kadar: "Matematik · Bölünebilme · 25 dk".
    final meta = !hasTarget
        ? null
        : task != null
            ? [
                subject?.name ?? 'Derssiz',
                if (topicName != null) topicName!,
                '$minutes dk',
              ].join(' · ')
            : [
                if (suggestion!.topicName != null) suggestion!.subjectName,
                '$minutes dk',
              ].join(' · ');

    // Neden: yalnız gerçek bir sinyal varsa; yoksa satır çizilmez.
    final why = hasTarget
        ? reason
        : (allDoneToday
            ? 'Bir şey daha eklemek istersen Koç yardım eder.'
            : (hasAnySubject
                ? 'Bir görev planlamadın — hadi başlayalım.'
                : 'Önce bir ders ekle, sonra plan kur.'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TapScale(
          onTap: onStart,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.heading3,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (meta != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    meta,
                    style: AppTextStyles.caption.copyWith(
                      color: tint,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (why != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    why,
                    style: AppTextStyles.bodySecondary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (hasTarget) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [AppColors.glow(AppColors.primary)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded,
                            color: AppColors.onColor(AppColors.primary),
                            size: 22),
                        const SizedBox(width: 6),
                        Text(
                          'Başla',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.onColor(AppColors.primary),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (nextUpTitle != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Sonra: $nextUpTitle',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        if (hasTarget) ...[
          const SizedBox(height: 10),
          TapScale(
            onTap: onAskCoach,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_outlined,
                      size: 14, color: AppColors.vibrantViolet),
                  const SizedBox(width: 6),
                  Text(
                    'Koç\'a danış',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.vibrantViolet,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Figma'daki "Ders kısayolları" — derse dokununca doğrudan o dersin konu
/// listesine gider. SubjectModel'de ayrı bir ikon alanı yok, ders adından
/// yaygın YKS derslerine göre bir Material ikonu türetiliyor.
class _SubjectShortcuts extends StatelessWidget {
  final List<SubjectModel> subjects;
  final ValueChanged<SubjectModel> onTap;

  const _SubjectShortcuts({required this.subjects, required this.onTap});

  static IconData _iconFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('mat') || n.contains('geometri')) {
      return Icons.calculate_outlined;
    }
    if (n.contains('fizik')) return Icons.bolt_outlined;
    if (n.contains('kimya')) return Icons.science_outlined;
    if (n.contains('biyoloji')) return Icons.eco_outlined;
    if (n.contains('tarih')) return Icons.account_balance_outlined;
    if (n.contains('coğrafya')) return Icons.public_outlined;
    if (n.contains('felsefe') || n.contains('mantık')) {
      return Icons.psychology_outlined;
    }
    if (n.contains('din')) return Icons.mosque_outlined;
    if (n.contains('türkçe') || n.contains('edebiyat')) {
      return Icons.menu_book_outlined;
    }
    if (n.contains('ingilizce') || n.contains('yabancı')) {
      return Icons.language_outlined;
    }
    return Icons.school_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final shown = subjects.take(6).toList();
    final tileWidth = (MediaQuery.of(context).size.width - 40 - 20) / 3;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: shown.map((s) {
        final color = Color(s.colorValue);
        return TapScale(
          onTap: () => onTap(s),
          child: Container(
            width: tileWidth,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              // Figma'da ikon holder (beyaz daire) YOK — ikon doğrudan
              // pastel zeminin üstünde duruyor, piksel karşılaştırmasıyla
              // düzeltildi.
              color: AppColors.tonal(color),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(_iconFor(s.name), color: color, size: 26),
                const SizedBox(height: 10),
                Text(
                  s.name,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Görev listesinden önce, tek seferlik gösterilen ince ipucu şeridi —
/// kaydırma/dokunma jestlerini (TaskSwipeActions + TaskTile'daki daire)
/// ilk kullanıcı keşfetmeden önce söylüyor. Kapatılınca (ya da bir daha
/// hiç) görünmez — bkz. UserStatsModel.hasSeenTaskHints.
class _TaskHintStrip extends ConsumerWidget {
  const _TaskHintStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.tonal(AppColors.primary),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Görevi tamamlamak için daireye dokun; ertelemek için sağa, '
              'silmek için sola kaydır.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          TapScale(
            onTap: () =>
                ref.read(statsProvider.notifier).markTaskHintsSeen(),
            child: Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bugünkü hedefe ulaşıldığında, Home'un en altında beliren tek satırlık
/// "bugünü kapat" daveti — zaten var olan [showDailyCloseoutSheet]'i açar
/// (bkz. daily_closeout_sheet.dart). Modal değil, bildirim değil; sayfayı
/// kaydırmayan biri hiç görmez, görüp dokunmayan biri hiçbir şey kaybetmez —
/// kapatınca da (bkz. todayCloseoutProvider) kendiliğinden kaybolur.
class _DailyCloseoutPrompt extends StatelessWidget {
  final VoidCallback onTap;
  const _DailyCloseoutPrompt({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceVariant),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(
          children: [
            Icon(Icons.nightlight_outlined, size: 18, color: AppColors.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Bugünkü hedefine ulaştın — bugünü kapat',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// "Odak Trendi" kartı — seri gün sayısı + son 14 günün odak dakikası
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
        border: Border.all(color: AppColors.border),
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
                    'ODAK TRENDİ',
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

/// Günün geri kalanındaki bir çalışma satırı: ders rozeti + başlık + (varsa)
/// gerçek gerekçe + süre/saat. Dokunmak o çalışmayı başlatır. Swipe ile
/// tamamla/ertele/sil (TaskSwipeActions, task_tile.dart ile paylaşılan).
class _UpcomingSessionRow extends StatelessWidget {
  final TaskModel task;
  final SubjectModel? subject;
  final String? reason;
  final VoidCallback onTap;

  const _UpcomingSessionRow({
    required this.task,
    required this.subject,
    required this.reason,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tint = subject != null ? Color(subject!.colorValue) : AppColors.primary;
    final scheduled = task.scheduledTime;
    final minutes = task.estimatedMinutes ?? kDefaultFocusMinutes;

    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: AppTextStyles.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (reason != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      reason!,
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              scheduled != null
                  ? '${_HomeScreenState._hhmm(scheduled)} · $minutes dk'
                  : '$minutes dk',
              style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
            ),
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
