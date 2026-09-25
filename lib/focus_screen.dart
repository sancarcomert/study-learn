import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'focus_anchor.dart';
import 'focus_history_screen.dart';
import 'focus_session_model.dart';
import 'focus_session_provider.dart';
import 'hive_boxes.dart';
import 'notification_service.dart';
import 'stats_provider.dart';
import 'study_events.dart';
import 'study_intent.dart';
import 'subject_provider.dart';
import 'task_provider.dart';
import 'tap_scale.dart';
import 'topic_evidence.dart';
import 'topic_evidence_provider.dart';
import 'topic_model.dart';
import 'topic_provider.dart';
import 'widgets/eyebrow.dart';
import 'widgets/app_snackbar.dart';

/// Odak seansı — iki mod:
/// - **Serbest:** açık uçlu kronometre (sayar), hedef sadece görsel.
/// - **Pomodoro:** çalışma bloğu → 5 dk mola döngüsü, 4 turda bir 15 dk
///   uzun mola. Her tamamlanan çalışma bloğu anında `focusMinutes`'a yazılır.
///
/// Süre her yerde DUVAR-SAATİ farkıyla hesaplanır (tick sayarak değil) —
/// arka plan / jank'te kaymaz. Bağımlılık yok, bildirim/ses yok (v1).
class FocusScreen extends ConsumerStatefulWidget {
  /// Çalışmanın bağlamı: ne, neden, ne kadar, hangi görev/konu (bkz.
  /// [StudyIntent]). Kaynağı (Home önerisi, görev, konu, Koç) üretir, Focus
  /// yeniden türetmez — öneri gerekçesi ekranlar arasında kaybolmaz.
  final StudyIntent intent;

  // Koç'un "Pomodoro Başlat" hızlı aksiyonundan gelen giriş — verilirse
  // ekran Serbest yerine doğrudan Pomodoro modunda açılır.
  final bool initialPomodoro;

  /// true ise ekran açılır açılmaz sayaç BAŞLAR — Home'daki "Başla" gibi
  /// açık bir başlatma jestinden gelindiğinde öğrenci bir kez daha "Başlat"a
  /// basmak zorunda kalmasın. Devam eden bir seans geri yüklendiyse etkisizdir.
  final bool autoStart;

  const FocusScreen({
    super.key,
    this.intent = StudyIntent.free,
    this.initialPomodoro = false,
    this.autoStart = false,
  });

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

enum _Mode { free, pomodoro }

enum _Phase { work, shortBreak, longBreak }

class _FocusScreenState extends ConsumerState<FocusScreen>
    with WidgetsBindingObserver {
  Timer? _ticker;
  bool _running = false;
  bool _leaving = false;

  late _Mode _mode = widget.initialPomodoro ? _Mode.pomodoro : _Mode.free;
  late int _blockMin = widget.intent.targetMinutes ?? kDefaultFocusMinutes;

  late final TextEditingController _noteController =
      TextEditingController(text: widget.intent.title ?? '');

  // Ders/konu bağlama — opsiyonel. Niyetten (görev/öneri/konu) önceden seçili
  // gelir; öğrenci isterse çalışma başlamadan değiştirebilir.
  late String? _selectedSubjectId = widget.intent.subjectId;
  late String? _selectedTopicId = widget.intent.topicId;

  // Bağlı görev — niyetten; çalışma süreç ölümünden geri yüklenirse çapadan.
  late String? _taskId = widget.intent.taskId;

  // Bu Focus çalışmasının kimliği: tüm dilimleri (Pomodoro blokları,
  // checkpoint'ler) tek bir "çalışma olayı" olarak bağlar (bkz. StudyEvents).
  late String _runId = ref.read(studyEventsProvider).newRunId();

  // Çalışma geri yüklenirse, niyetteki gerekçe ve BAŞLANGIÇ seçimi (gerekçenin
  // hangi ders/konu için geçerli olduğu) çapadan gelir.
  late String? _intentReason = widget.intent.reason;
  late String? _baseSubjectId = widget.intent.subjectId;
  late String? _baseTopicId = widget.intent.topicId;

  // Serbest'in hedefi sadece görsel/ilerleme çubuğu için — kısa bir mola
  // ya da hızlı bir başlangıç için 5/10 dk da mantıklı. Pomodoro'nun
  // çalışma bloğu tekniğin kendisi gereği (kullanıcı isteğiyle) ayrı ve
  // değişmedi.
  static const List<int> _freeTargetOptions = [5, 10, 15, 25, 30, 45, 60];
  static const List<int> _pomodoroBlockOptions = [15, 25, 30, 45, 60];
  List<int> get _blockOptions =>
      _mode == _Mode.free ? _freeTargetOptions : _pomodoroBlockOptions;
  static const int _shortBreakSec = 5 * 60;
  static const int _longBreakSec = 15 * 60;

  // Serbest mod: yukarı sayan geçen süre. _freeLoggedSec, o ana kadar
  // geçmişe YAZILMIŞ saniye miktarı — uygulama arka plana alınıp işletim
  // sistemi süreci öldürürse (bkz. didChangeAppLifecycleState) elde kalan
  // ilerleme kaybolmasın diye tek seferlik bayrak yerine artan bir sayaç.
  int _freeCommittedSec = 0;
  DateTime? _freeSegStart;
  int _freeLoggedSec = 0;

  // Pomodoro: mevcut fazın geçen süresi + tur sayacı.
  _Phase _phase = _Phase.work;
  int _pomoCycle = 1; // üzerinde çalışılan / son biten çalışma bloğu no'su
  int _phaseAccumSec = 0;
  DateTime? _phaseSegStart;
  // _freeLoggedSec'in Pomodoro karşılığı: bu çalışma fazında o ana kadar
  // geçmişe YAZILMIŞ saniye. _phaseAccumSec (fazın TOPLAM geçen süresi,
  // hedefle karşılaştırılan) ile ayrı tutulur — checkpoint sırasında ikisi
  // aynı olsaydı her arka plana alınışta faz hedefi sıfırdan saymaya
  // başlardı (bkz. _checkpointProgress).
  int _phaseLoggedSec = 0;

  // Bu çalışmada şimdiye kadar KAYDA GEÇEN (ölçülmüş) dakika. Süre yalnız
  // etkinlik kanıtıdır ("şu kadar zaman harcandı"); çalışmanın iyi ya da
  // yeterli olduğunu göstermez — bunu yalnız öğrencinin cevabı ve deneme söyler.
  int _sessionLoggedMin = 0;

  // Serbest hedefi bir kez kutlanır — ticker her saniye çalıştığı için
  // bayrak olmadan aynı dialog defalarca açılırdı.
  bool _freeTargetCelebrated = false;

  @override
  void initState() {
    super.initState();
    _restoreAnchorIfAny();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeRequestExactAlarmPermission();
      // Devam eden bir seans geri yüklendiyse ekranı da canlandır — bildirim
      // yeniden zamanlanmaz, o zaten ilk başladığında OS'e yazılmıştı ve
      // sürecimiz öldürülse bile kendi kendine düşer.
      if (_running) {
        _startTicker();
      } else if (widget.autoStart) {
        _toggleRun();
      }
    });
  }

  // Ders çalışan biri telefonu açık/kilitsiz tutmak istemez — uygulama arka
  // plana alınınca (ekran kapansa, ana ekrana dönülse, hatta işletim
  // sistemi Flutter sürecini bellek için öldürse bile) seans GERÇEKTEN
  // devam etmeli. Bunun için iki şey yapıyoruz:
  // 1) O ana kadarki ilerlemeyi hemen geçmişe yazıyoruz (checkpoint) —
  //    süreç öldürülürse en azından o dakikalar kaybolmasın.
  // 2) Devam eden seansın "çapasını" (hangi modda, ne zaman başladı vb.)
  //    Hive'a yazıyoruz — uygulama yeniden açıldığında (initState) süreç
  //    öldürülmüş olsa bile gerçek duvar-saati farkından kaldığı yerden
  //    devam eder, sıfırlanmaz.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _checkpointProgress();
      if (_running) {
        _leftAt = DateTime.now();
        _elapsedAtLeaveSec = _mode == _Mode.free ? _freeElapsedSec : 0;
        _writeAnchor();
      }
    } else if (state == AppLifecycleState.resumed) {
      _discountUnattendedTime();
    }
  }

  // Uygulama arka plana alındığı an ve o anki geçen süre — geri dönüşte,
  // arka planda geçen sürenin ne kadarının "çalışma" sayılacağını belirlemek
  // için (bkz. FocusAnchorMath).
  DateTime? _leftAt;
  int _elapsedAtLeaveSec = 0;

  /// Uygulama aynı süreçte arka plandan döndüğünde: serbest modda, unutulmuş
  /// zamanlayıcının uzun arka plan süresini "çalışma" saymaz.
  void _discountUnattendedTime() {
    final left = _leftAt;
    _leftAt = null;
    if (left == null || !_running || _mode != _Mode.free) return;
    final segStart = _freeSegStart;
    if (segStart == null) return;
    final uncredited = FocusAnchorMath.uncreditedAwaySec(
      elapsedAtLeaveSec: _elapsedAtLeaveSec,
      awaySec: DateTime.now().difference(left).inSeconds,
      targetSec: _blockMin * 60,
    );
    if (uncredited > 0) {
      setState(() => _freeSegStart = segStart.add(Duration(seconds: uncredited)));
    }
  }

  void _checkpointProgress() {
    if (!_running) return;
    if (_mode == _Mode.free) {
      _flushFreeProgress();
    } else if (_phase == _Phase.work) {
      _commitCurrentWorkBlock();
      // DİKKAT: _phaseAccumSec'i SIFIRLAMIYORUZ — yalnızca canlı segmenti
      // kapatıp aynı toplam üzerinden devam ediyoruz. Sıfırlarsak fazın
      // TOPLAM süresi (hedefle karşılaştırılan _phaseElapsedSec) her arka
      // plana alınışta sıfırdan saymaya başlar; 25 dk'lık bloğun 20.
      // dakikasında biri bildirimlere bakarsa dönüşte tekrar 25 dk
      // bekletilir. Dakikalar zaten _commitCurrentWorkBlock içinde
      // _phaseLoggedSec ile tekrar sayılmadan geçmişe yazıldı.
      _phaseAccumSec = _phaseElapsedSec;
      _phaseSegStart = DateTime.now();
    }
  }

  void _writeAnchor() {
    final segStart = _mode == _Mode.free ? _freeSegStart : _phaseSegStart;
    HiveBoxes.focusAnchor.put('current', {
      'mode': _mode.name,
      'phase': _phase.name,
      'blockMin': _blockMin,
      'pomoCycle': _pomoCycle,
      'committedSec': _mode == _Mode.free ? _freeCommittedSec : _phaseAccumSec,
      'loggedSec': _mode == _Mode.free ? _freeLoggedSec : _phaseLoggedSec,
      'segStartMs': segStart?.millisecondsSinceEpoch,
      'subjectId': _selectedSubjectId,
      'topicId': _selectedTopicId,
      'note': _noteController.text,
      // Çalışmanın kimliği ve bağlamı çapada durur: Home'daki "Odak devam
      // ediyor" bandından dönüldüğünde (ya da süreç öldürülüp yeniden
      // açıldığında) görev bağı, gerekçe ve aynı çalışma olarak devam eder.
      'runId': _runId,
      'taskId': _taskId,
      'reason': _intentReason,
      // Uygulamanın en son ön planda görüldüğü an — unutulmuş bir seansın
      // arka planda "çalıştığı" varsayılan süresini sınırlamak için.
      'lastActiveMs': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void _clearAnchor() => HiveBoxes.focusAnchor.delete('current');

  /// Bir önceki `_FocusScreenState` çalışırken süreç öldürüldüyse (arka
  /// planda), burada bıraktığı çapayı okuyup gerçek duvar-saati farkından
  /// kaldığı yerden devam ettirir. Yalnızca GERÇEKTEN çalışıyorken (segStart
  /// var) yazılmış bir çapa varsa devreye girer — duraklatılmış/bitmiş bir
  /// seansın kurtarılacak bir şeyi yok.
  void _restoreAnchorIfAny() {
    final raw = HiveBoxes.focusAnchor.get('current');
    if (raw is! Map) return;
    final segStartMs = raw['segStartMs'] as int?;
    if (segStartMs == null) return;

    // Yeni ve FARKLI bir çalışma başlatılıyorsa (başka görev/konu/ders) eski
    // seans sessizce geri yüklenmez: ölçülmüş dakikaları kendi bağlamına
    // kaydedilir, yeni niyet kazanır. Aynı bağlam (ya da bağlamsız açılış:
    // Home bandı) ise kaldığı yerden devam eder.
    if (!_anchorMatchesIntent(raw)) {
      _finalizeSupersededRun(raw);
      return;
    }

    final segStart = DateTime.fromMillisecondsSinceEpoch(segStartMs);
    _mode = _Mode.values
        .firstWhere((m) => m.name == raw['mode'], orElse: () => _Mode.free);
    _phase = _Phase.values
        .firstWhere((p) => p.name == raw['phase'], orElse: () => _Phase.work);
    _blockMin = raw['blockMin'] as int? ?? _blockMin;
    _pomoCycle = raw['pomoCycle'] as int? ?? 1;
    _selectedSubjectId = raw['subjectId'] as String?;
    _selectedTopicId = raw['topicId'] as String?;
    _baseSubjectId = _selectedSubjectId;
    _baseTopicId = _selectedTopicId;
    _runId = raw['runId'] as String? ?? _runId;
    _taskId = raw['taskId'] as String? ?? _taskId;
    _intentReason = raw['reason'] as String? ?? _intentReason;
    final note = raw['note'] as String?;
    if (note != null && note.isNotEmpty) _noteController.text = note;

    final committedSec = raw['committedSec'] as int? ?? 0;
    final loggedSec = raw['loggedSec'] as int? ?? 0;
    if (_mode == _Mode.free) {
      _freeCommittedSec = committedSec;
      _freeLoggedSec = loggedSec;
      // Unutulmuş zamanlayıcı: arka planda geçen sürenin yalnız makul kısmı
      // sayılır (bkz. FocusAnchorMath) — segment başlangıcı buna göre ileri
      // alınır, böylece geçen süre zaten kırpılmış görünür.
      final credited = FocusAnchorMath.creditedFreeElapsedSec(
        committedSec: committedSec,
        segStartMs: segStartMs,
        lastActiveMs: raw['lastActiveMs'] as int?,
        nowMs: DateTime.now().millisecondsSinceEpoch,
        targetSec: _blockMin * 60,
      );
      final rawElapsed = committedSec +
          (DateTime.now().millisecondsSinceEpoch - segStartMs) ~/ 1000;
      _freeSegStart = segStart.add(Duration(seconds: rawElapsed - credited));
    } else {
      _phaseAccumSec = committedSec;
      _phaseSegStart = segStart;
      _phaseLoggedSec = loggedSec;
    }
    _running = true;
  }

  /// Çapadaki seans, açılan niyetle aynı bağlamda mı? Görev varsa görev, yoksa
  /// konu, yoksa ders karşılaştırılır; niyet bağlamsızsa (Home bandı, hızlı
  /// Pomodoro) her zaman eşleşir — devam eden seansa dönülür.
  bool _anchorMatchesIntent(Map raw) {
    final i = widget.intent;
    if (i.taskId != null) return raw['taskId'] == i.taskId;
    if (i.topicId != null) return raw['topicId'] == i.topicId;
    if (i.subjectId != null) return raw['subjectId'] == i.subjectId;
    return true;
  }

  /// Yerini yeni bir çalışmaya bırakan seansın ölçülmüş (kırpılmış) dakikalarını
  /// KENDİ bağlamına (görev/konu/ders) kaydeder ve çapayı temizler. Cevap
  /// sorulmaz — öğrenci artık başka bir şeye geçti.
  void _finalizeSupersededRun(Map raw) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final free = raw['mode'] == _Mode.free.name;
    final logged = raw['loggedSec'] as int? ?? 0;
    final elapsedSec = FocusAnchorMath.creditedWorkSec(raw, nowMs: nowMs);

    final minutes = (elapsedSec - logged) ~/ 60;
    // Çapa HEMEN temizlenir (aynı seans iki kez sonlandırılmasın); provider
    // yazımı ise initState içinde YAPILAMAZ (Riverpod yasağı) — ilk kareden
    // sonra, kopyalanmış verilerle yapılır.
    final runId = raw['runId'] as String?;
    final subjectId = raw['subjectId'] as String?;
    final topicId = raw['topicId'] as String?;
    final taskId = raw['taskId'] as String?;
    final note = raw['note'] as String?;
    _cancelCompletionNotification();
    _clearAnchor();
    if (minutes >= 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final events = ref.read(studyEventsProvider);
        events.recordFocusActivity(
          runId: runId ?? events.newRunId(),
          minutes: minutes,
          mode: free ? 'serbest' : 'pomodoro',
          subjectId: subjectId,
          topicId: topicId,
          taskId: taskId,
          note: note,
        );
      });
    }
  }

  void _flushFreeProgress() {
    final totalSec = _freeElapsedSec;
    final deltaMin = (totalSec - _freeLoggedSec) ~/ 60;
    if (deltaMin < 1) return;
    _freeLoggedSec += deltaMin * 60;
    _recordActivity(deltaMin, 'serbest');
  }

  /// Ölçülmüş bir çalışma dilimini olay servisine bildirir. Kayıt, toplam odak
  /// süresi ve konuya çalışma olayı işlenmesi TEK yerde (StudyEvents) olur.
  void _recordActivity(int minutes, String mode) {
    final id = ref.read(studyEventsProvider).recordFocusActivity(
          runId: _runId,
          minutes: minutes,
          mode: mode,
          subjectId: _selectedSubjectId,
          topicId: _selectedTopicId,
          taskId: _taskId,
          note: _noteController.text,
        );
    if (id != null) _sessionLoggedMin += minutes;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  // Odak bitiş bildiriminin arka planda/kapalıyken de tam zamanında
  // düşmesi için Android 12+'ta ayrı bir özel izin gerekiyor
  // (SCHEDULE_EXACT_ALARM) — normal bildirim izninden bağımsız, kullanıcıyı
  // Ayarlar'a yönlendiriyor. Bu yüzden Home'daki bildirim izni akışıyla
  // aynı desen: önce neden istendiğini açıkla, "Ayarları Aç" derse iste.
  // Kullanıcı başına bir kez (ekran her açıldığında değil).
  Future<void> _maybeRequestExactAlarmPermission() async {
    final alreadySeen = ref.read(statsProvider).hasSeenExactAlarmPrompt;
    if (alreadySeen) return;
    if (await NotificationService.instance.hasExactAlarmPermission()) return;
    if (!mounted) return;

    final continueRequested = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.alarm_outlined,
          color: AppColors.primary,
          size: 32,
        ),
        title: const Text('Tam zamanında hatırlatma'),
        content: const Text(
          'Odak seansı bittiğinde uygulama kapalıyken de haber verebilmemiz '
          'için sistemden ek bir izin gerekiyor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Şimdi Değil'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ayarları Aç'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    ref.read(statsProvider.notifier).markExactAlarmPromptSeen();

    if (continueRequested == true) {
      await NotificationService.instance.requestExactAlarmPermission();
    }
  }

  // ---- ortak ----

  int get _freeElapsedSec =>
      _freeCommittedSec +
      (_freeSegStart == null
          ? 0
          : DateTime.now().difference(_freeSegStart!).inSeconds);

  int get _phaseElapsedSec =>
      _phaseAccumSec +
      (_phaseSegStart == null
          ? 0
          : DateTime.now().difference(_phaseSegStart!).inSeconds);

  int get _phaseTargetSec {
    switch (_phase) {
      case _Phase.work:
        return _blockMin * 60;
      case _Phase.shortBreak:
        return _shortBreakSec;
      case _Phase.longBreak:
        return _longBreakSec;
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_mode == _Mode.pomodoro &&
          _running &&
          _phaseElapsedSec >= _phaseTargetSec) {
        _advancePhase(auto: true);
      }
      if (_mode == _Mode.free &&
          _running &&
          !_freeTargetCelebrated &&
          _freeElapsedSec >= _blockMin * 60) {
        _freeTargetCelebrated = true;
        _celebrateFreeTargetReached();
      }
      setState(() {});
    });
  }

  void _toggleRun() {
    if (_running) {
      // duraklat
      if (_mode == _Mode.free) {
        _freeCommittedSec = _freeElapsedSec;
        _freeSegStart = null;
      } else {
        _phaseAccumSec = _phaseElapsedSec;
        _phaseSegStart = null;
      }
      _ticker?.cancel();
      _cancelCompletionNotification();
      _clearAnchor();
      setState(() => _running = false);
    } else {
      final now = DateTime.now();
      if (_mode == _Mode.free) {
        _freeSegStart = now;
      } else {
        _phaseSegStart = now;
      }
      _running = true;
      _startTicker();
      _scheduleCompletionNotification();
      _writeAnchor();
      setState(() {});
    }
  }

  // ---- arka plan bildirimi: bölüm/hedef bitince tek seferlik, exact-mode ----

  void _scheduleCompletionNotification() {
    final int remainingSec;
    final String title;
    final String body;
    if (_mode == _Mode.free) {
      remainingSec = _blockMin * 60 - _freeElapsedSec;
      title = 'Hedefe ulaştın';
      final note = _noteController.text.trim();
      body =
          note.isEmpty ? 'Odak hedefine ulaştın.' : '$note · hedefe ulaştın.';
    } else if (_phase == _Phase.work) {
      remainingSec = _phaseTargetSec - _phaseElapsedSec;
      title = 'Çalışma bloğu bitti';
      body = 'Mola zamanı geldi.';
    } else {
      remainingSec = _phaseTargetSec - _phaseElapsedSec;
      title = 'Mola bitti';
      body = 'Çalışmaya dön';
    }
    if (remainingSec <= 0) return;
    NotificationService.instance.scheduleNotification(
      id: 'focus_session',
      category: NotificationCategory.focusSession,
      title: title,
      body: body,
      dateTime: DateTime.now().add(Duration(seconds: remainingSec)),
      exact: true,
    );
  }

  void _cancelCompletionNotification() {
    NotificationService.instance.cancelNotification(
      'focus_session',
      NotificationCategory.focusSession,
    );
  }

  void _switchMode(_Mode m) {
    if (_running || m == _mode) return;
    _ticker?.cancel();
    _cancelCompletionNotification();
    _clearAnchor();
    setState(() {
      _mode = m;
      _running = false;
      _freeCommittedSec = 0;
      _freeSegStart = null;
      _freeLoggedSec = 0;
      _phase = _Phase.work;
      _pomoCycle = 1;
      _phaseAccumSec = 0;
      _phaseLoggedSec = 0;
      _phaseSegStart = null;
      _freeTargetCelebrated = false;
    });
  }

  // ---- pomodoro faz geçişi ----

  void _commitCurrentWorkBlock() {
    if (_phase != _Phase.work) return;
    // Delta bazlı: bu çağrıdan önce zaten yazılmış (_phaseLoggedSec) kısmı
    // tekrar yazma — checkpoint artık _phaseAccumSec'i sıfırlamadığı için
    // bu metod aynı faz içinde birden çok kez (her checkpoint'te + faz
    // bitiminde) çağrılabilir; delta olmadan her seferinde TÜM fazı yeniden
    // kaydedip dakikaları katlardı.
    final totalSec = math.min(_phaseElapsedSec, _blockMin * 60);
    final deltaMin = (totalSec - _phaseLoggedSec) ~/ 60;
    if (deltaMin >= 1) {
      _phaseLoggedSec += deltaMin * 60;
      _recordActivity(deltaMin, 'pomodoro');
    }
  }

  /// Serbest modun hedefi (bir görevden başlatıldıysa görevin tahmini
  /// süresi) dolunca — önceden burada HİÇBİR şey olmuyordu, saat yeşile
  /// dönüp sessizce saymaya devam ediyordu; kronometrenin bittiği an ile
  /// başlatıldığı görev arasında hiçbir bağlantı yoktu. Artık gerçek bir
  /// an: dokunuşsal geri bildirim + görevi doğrudan tamamlama seçeneği.
  void _celebrateFreeTargetReached() {
    HapticFeedback.heavyImpact();
    final taskId = _taskId;
    final task = taskId == null
        ? null
        : ref.read(taskProvider).where((t) => t.id == taskId).firstOrNull;
    final canCompleteTask = task != null && !task.isCompleted;

    final note = _noteLabel();
    _showFocusCelebration(
      title: 'Hedefe ulaştın',
      body: note == null
          ? '$_blockMin dakikalık hedefini tamamladın.'
          : '$_blockMin dakika · $note',
      actionLabel: canCompleteTask ? 'Görevi Tamamla' : null,
      onAction: canCompleteTask ? () => _completeLinkedTask(task.id) : null,
    );
  }

  /// "Görevi Tamamla" (hedefe ulaşınca): önce o ana kadarki çalışmayı KAYDA
  /// geçirir (görev tamamlama, harcanan süreyi ve "bu çalışma zaten ölçüldü"
  /// bilgisini kayıtlı seanslardan okur), sonra görevi tamamlar. Konu ilerlemesi
  /// bu çalışmadan bir kez sayılır — burada tekrar hesaplanmaz.
  Future<void> _completeLinkedTask(String taskId) async {
    final task =
        ref.read(taskProvider).where((t) => t.id == taskId).firstOrNull;
    if (task == null || task.isCompleted) return;
    _checkpointProgress();
    await ref.read(taskProvider.notifier).completeTask(taskId);
    if (mounted) {
      AppSnackBar.success(context, '"${task.title}" tamamlandı');
    }
  }

  /// Odak tamamlanma anları için tek, paylaşılan görsel dil — koyu yeşil
  /// onay rozeti + net başlık/gövde. Önceki hâlde bu anlar (Pomodoro bloğu
  /// bitişi, Serbest hedefi) ya küçük bir snackbar ya da hiçbir şeydi.
  Future<void> _showFocusCelebration({
    required String title,
    required String body,
    String? actionLabel,
    VoidCallback? onAction,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.tonal(AppColors.success),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_rounded,
              color: AppColors.success, size: 30),
        ),
        title: Text(title, style: AppTextStyles.heading3,
            textAlign: TextAlign.center),
        content: Text(body,
            style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
        actionsAlignment: actionLabel == null
            ? MainAxisAlignment.center
            : MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(actionLabel == null ? 'Tamam' : 'Devam Et'),
          ),
          if (actionLabel != null)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onColor(AppColors.primary),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                onAction?.call();
              },
              child: Text(actionLabel),
            ),
        ],
      ),
    );
  }

  /// [auto] true ise sayaç bittiği için otomatik geçiş; false ise molayı
  /// kullanıcı elle geçti.
  void _advancePhase({bool auto = false}) {
    HapticFeedback.mediumImpact();
    final wasWork = _phase == _Phase.work;

    if (wasWork) {
      _commitCurrentWorkBlock();
      final isLong = _pomoCycle % 4 == 0;
      _phase = isLong ? _Phase.longBreak : _Phase.shortBreak;
      if (mounted) {
        if (auto) {
          // Sayaç gerçekten sıfırlandığı (kullanıcı elle atlamadığı) an —
          // önceden yalnız küçük bir snackbar vardı, "yazıdan ibaret"
          // kalıyordu. Artık gerçek bir dokunuşsal + görsel an.
          final note = _noteLabel();
          _showFocusCelebration(
            title: 'Çalışma bloğu bitti',
            body: '$_blockMin dakika çalıştın'
                '${note == null ? '' : ' · $note'}. '
                '${isLong ? "Uzun mola" : "Mola"} zamanı.',
          );
        } else {
          AppSnackBar.info(
            context,
            isLong ? 'Uzun mola · 15 dk' : 'Mola · 5 dk',
          );
        }
      }
    } else {
      _pomoCycle++;
      _phase = _Phase.work;
      if (mounted && auto) {
        AppSnackBar.info(context, '$_pomoCycle. tur — çalışmaya dön');
      }
    }

    // Gerçek faz geçişi (çalışma↔mola) — burada sıfırlamak doğru, çünkü
    // yeni faz baştan başlıyor ve önceki fazın süresi zaten commit edildi.
    _phaseAccumSec = 0;
    _phaseLoggedSec = 0;
    _phaseSegStart = _running ? DateTime.now() : null;
    if (_running) {
      _scheduleCompletionNotification();
      _writeAnchor();
    } else {
      _cancelCompletionNotification();
    }
    setState(() {});
  }

  // ---- çıkış ----

  /// Bu seansta şimdiye kadar GERÇEKTEN çalışılan dakika. Serbest modda canlı
  /// süre (henüz bir tam dakikaya yuvarlanmamış kısım dahil), Pomodoro'da
  /// yazılmış çalışma blokları toplamı.
  int get _sessionMinutes => _mode == _Mode.free
      ? math.max(_sessionLoggedMin, _freeElapsedSec ~/ 60)
      : _sessionLoggedMin;

  void _saveIfNeeded({bool quiet = false}) {
    _ticker?.cancel();
    _cancelCompletionNotification();
    _clearAnchor();
    if (_mode == _Mode.free) {
      final totalMinutes = _freeElapsedSec ~/ 60;
      _flushFreeProgress();
      _freeCommittedSec = _freeElapsedSec;
      _freeSegStart = null;
      if (totalMinutes >= 1 && !quiet) {
        final note = _noteController.text.trim();
        AppSnackBar.success(
          context,
          note.isEmpty
              ? '$totalMinutes dk odak süresi kaydedildi'
              : '$note · $totalMinutes dk kaydedildi',
        );
      }
    } else {
      // pomodoro: tamamlanan bloklar zaten yazıldı; yalnız mevcut kısmi
      // çalışma bloğunu ekle.
      _commitCurrentWorkBlock();
      _phaseSegStart = null;
    }
    _running = false;
  }

  Future<void> _exit() async {
    if (_leaving) return;
    final messenger = ScaffoldMessenger.of(context);
    // Bu ekranın KENDİ rotası: bitişte kapanan şey mutlaka bu olmalı. Görev
    // Focus'tan tamamlanınca Home hedef kutlaması diyaloğunu bu rotanın ÜSTÜNE
    // açabilir; düz pop() o zaman diyaloğu kapatıp öğrenciyi durmuş bir Focus
    // ekranında bırakırdı.
    final route = ModalRoute.of(context);

    // Sonuç sheet'i yalnız ölçülmüş bir çalışma varsa (≥1 dk) çıkar; 1
    // dakikadan kısa bir "Bitir" hiçbir şey sormaz.
    final hadMinutes = _mode == _Mode.free
        ? _freeElapsedSec >= 60
        : (_sessionLoggedMin +
                (_phase == _Phase.work
                    ? math.max(
                        0,
                        math.min(_phaseElapsedSec, _blockMin * 60) -
                            _phaseLoggedSec)
                    : 0) >=
            60);
    _saveIfNeeded(quiet: hadMinutes);
    if (!mounted) return;

    final sessionMin = _sessionMinutes;
    if (hadMinutes && sessionMin >= 1) {
      final taskId = _taskId;
      final task = taskId == null
          ? null
          : ref.read(taskProvider).where((t) => t.id == taskId).firstOrNull;
      final canComplete = task != null && !task.isCompleted;

      final outcome = await showModalBottomSheet<_FocusOutcome>(
        context: context,
        backgroundColor: AppColors.surface,
        showDragHandle: true,
        builder: (_) => _FocusOutcomeSheet(
          minutes: sessionMin,
          label: _noteLabel(),
          canCompleteTask: canComplete,
          completeTaskByDefault: sessionMin >= _blockMin,
        ),
      );
      if (!mounted) return;

      // Olayı TEK kapıdan bildir: cevap çalışmaya yazılır, görev (istenirse)
      // tamamlanır; öneri/rozet/plan bundan türer.
      final result = await ref.read(studyEventsProvider).finishFocusRun(
            runId: _runId,
            topicId: _selectedTopicId,
            taskId: taskId,
            feeling: outcome?.feeling,
            completeTask: canComplete && (outcome?.completeTask ?? false),
          );

      // Öğrenciye söylenen cümle YALNIZ gerçekten olacak şeyi söyler.
      final message = _outcomeMessage(outcome?.feeling, result);
      if (message != null) {
        messenger.clearSnackBars();
        messenger.showSnackBar(SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(
            message,
            style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
          ),
        ));
      }
    }

    if (!mounted || _leaving) return;
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final r = route;
      if (r != null && r.isActive && !r.isCurrent) {
        r.navigator?.removeRoute(r); // üstte bir diyalog var — onu bozma
      } else {
        Navigator.of(context).pop();
      }
    });
  }

  /// Bitişte öğrenciye söylenecek tek cümle. Konu bağlı değilse "hatırlatırım"
  /// denmez (hatırlatacak bir konu yok); zorlanma zaten "üst üste"ye
  /// dönüştüyse bunu söyler; "normaldi/iyi gitti" yalnız gerçekten bir
  /// zorlanma işaretini kaldırdıysa bunu söyler.
  String? _outcomeMessage(int? feeling, FocusRunResult r) {
    if (feeling == null) return null;
    final hasTopic = _selectedTopicId != null;
    if (feeling == FocusFeeling.hard) {
      if (!hasTopic) return 'Not aldım.';
      return r.difficultyAfter == DifficultySignal.repeated
          ? 'Not aldım. Bu konuda art arda zorlandın — bir sonraki plana bunu da katarım.'
          : 'Not aldım. Bu konuya tekrar bakarken hatırlatırım.';
    }
    if (r.difficultyBefore != DifficultySignal.none &&
        r.difficultyAfter == DifficultySignal.none) {
      return 'Güzel. Bu konu artık zorlandıkların arasında değil.';
    }
    return 'Not aldım.';
  }

  // "Bitir" butonundan FARKLI: kullanıcı sadece geri gidiyor (geri tuşu/
  // nav bar), seansı bilerek bitirmiyor. Önceden PopScope de _exit()'i
  // (dolayısıyla _saveIfNeeded()'i) çağırıyordu — bu, ekrandan çıkılınca
  // seansı SONLANDIRIP çapayı siliyordu; dakika henüz 1'i bulmadıysa
  // (ör. birkaç saniye sonra geri dönülürse) hiçbir iz bile kalmıyor,
  // Focus'a tekrar girince sıfırdan başlıyordu — kullanıcı "sıfırlandı"
  // olarak görüyordu. Artık uygulamanın arka plana alınmasıyla (bkz.
  // didChangeAppLifecycleState) BİREBİR aynı yol: checkpoint + çapa yaz,
  // seansı bitirme. Focus'a (Home/Koç, her neredense) tekrar girildiğinde
  // kaldığı yerden — duvar saatiyle, geçen süre kadar ileriden — devam
  // ediyor; tamamlanma bildirimi de iptal edilmiyor, zamanı gelince düşer.
  //
  // DÜRÜST SÜRTÜNME (kilitleme DEĞİL): anlamlı ilerleme varken geri
  // gidilirse bir kez soruyoruz. Kullanıcı "Devam Et" derse seans aynen
  // sürer; "Çık" derse (ya da hiç sormadan da çıkabileceği hiçbir teknik
  // engel yok) normal şekilde kaydedip çıkar. Bilinçli karar: kullanıcıyı
  // hiçbir şekilde durduramayız/durdurmamalıyız — sadece bir an düşünsün.
  Future<void> _leaveWhileRunning() async {
    if (!mounted || _leaving) return;

    if (_hasUnsavedProgress) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(Icons.timer_outlined, color: AppColors.primary, size: 30),
          // Dürüst metin: ekrandan çıkmak seansı BİTİRMEZ — sayaç arka planda
          // sürer (Ana Sayfa'daki "Odak devam ediyor" bandından dönülür).
          // Bitirmek için "Bitir".
          title: const Text('Sayaç arka planda sürsün mü?'),
          content: const Text(
            'Bu ekrandan çıkmak seansı bitirmez; sayaç çalışmaya devam eder '
            "ve Ana Sayfa'daki bantla geri dönebilirsin. Bitirmek için "
            '"Bitir"e bas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Ekranda Kal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Arka Plana Al'),
            ),
          ],
        ),
      );
      if (leave != true || !mounted) return;
    }

    _checkpointProgress();
    if (_running) _writeAnchor();
    if (!mounted || _leaving) return;
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  bool get _hasUnsavedProgress {
    if (_running) return true;
    if (_mode == _Mode.free) return _freeElapsedSec >= 60;
    return _phase == _Phase.work && _phaseElapsedSec >= 60;
  }

  // ---- görünüm ----

  String _fmt(int totalSec) {
    final s = totalSec.abs();
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  /// Halkanın içinde saatin altında gösterilen ders/konu notu — seçiliyse.
  String? _noteLabel() {
    final subjectId = _selectedSubjectId;
    if (subjectId == null) return null;
    final subject =
        ref.read(subjectProvider).where((s) => s.id == subjectId).firstOrNull;
    if (subject == null) return null;
    if (_selectedTopicId == null) return subject.name;
    final topic = ref
        .read(topicsForSubjectProvider(subjectId))
        .where((t) => t.id == _selectedTopicId)
        .firstOrNull;
    return topic == null ? subject.name : '${subject.name} · ${topic.name}';
  }

  // ---- bağlam kartı (seans öncesi/sırasında "ne + neden") ----

  String? _selectedTopicName() {
    final topicId = _selectedTopicId;
    final subjectId = _selectedSubjectId;
    if (topicId == null || subjectId == null) return null;
    return ref
        .read(topicsForSubjectProvider(subjectId))
        .where((t) => t.id == topicId)
        .firstOrNull
        ?.name;
  }

  String _contextTitle() {
    final note = _noteController.text.trim();
    return _selectedTopicName() ??
        (note.isNotEmpty ? note : (_noteLabel() ?? 'Serbest çalışma'));
  }

  String _contextSubtitle() {
    final subjectName = _selectedSubjectId == null
        ? null
        : ref
            .read(subjectProvider)
            .where((s) => s.id == _selectedSubjectId)
            .firstOrNull
            ?.name;
    return [
      if (subjectName != null && subjectName != _contextTitle()) subjectName,
      '$_blockMin dk',
    ].join(' · ');
  }

  /// "Neden bu?" satırı. Niyetin gerekçesi (öğrenciye Home'da/listede
  /// HANGİ metin gösterildiyse o) öncelikli — bağlam ekranlar arasında
  /// kaybolmasın diye. Öğrenci konuyu değiştirdiyse o gerekçe artık geçerli
  /// değildir; o zaman seçili konunun canlı kanıtı (deneme / çalışma). İkisi
  /// de yoksa null — uydurma gerekçe yok.
  String? _contextReason() {
    final sameSelection = _selectedSubjectId == _baseSubjectId &&
        _selectedTopicId == _baseTopicId;
    if (sameSelection && _intentReason != null) return _intentReason;
    final topicId = _selectedTopicId;
    if (topicId != null) {
      return ref.watch(topicEvidenceProvider)[topicId]?.sentence;
    }
    return null;
  }

  /// Serbest modda hedef süre geçildikten sonra ne kadar fazladan
  /// çalışıldığını gösterir. Önceden hedefe ulaşınca etiket durağan
  /// "hedefe ulaştın" metninde kalıyordu — halka da %100'de sabitlenince
  /// kronometre gerçekte saymaya devam etse bile (asla durmuyor, hedef
  /// sadece görsel bir milestone) her ikisi birden "seans bitti/kilitlendi"
  /// izlenimi veriyordu. Bu etiket saniyede bir arttığı için hâlâ aktif
  /// olduğu görünür.
  String _fmtOverage(int overSec) {
    if (overSec < 60) return '+$overSec sn';
    return '+${overSec ~/ 60} dk';
  }

  String get _phaseLabel {
    switch (_phase) {
      case _Phase.work:
        return 'Çalışma · $_pomoCycle. tur';
      case _Phase.shortBreak:
        return 'Kısa mola';
      case _Phase.longBreak:
        return 'Uzun mola';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBreak = _mode == _Mode.pomodoro && _phase != _Phase.work;

    // ---- ana sayaç metni + ilerleme ----
    final String clock;
    final double progress;
    final bool reached;
    if (_mode == _Mode.free) {
      final e = _freeElapsedSec;
      final target = _blockMin * 60;
      clock = _fmt(e);
      progress = target == 0 ? 0 : (e / target).clamp(0.0, 1.0);
      reached = target > 0 && e >= target;
    } else {
      final remaining = _phaseTargetSec - _phaseElapsedSec;
      clock = _fmt(remaining < 0 ? 0 : remaining);
      progress = _phaseTargetSec == 0
          ? 0
          : (_phaseElapsedSec / _phaseTargetSec).clamp(0.0, 1.0);
      reached = false;
    }

    final accent = isBreak
        ? AppColors.success
        : (reached ? AppColors.success : AppColors.primary);

    return PopScope(
      canPop: _leaving || !_hasUnsavedProgress,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leaveWhileRunning();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Odak', style: AppTextStyles.heading2),
        ),
        body: Stack(
          children: [
            // Home'daki aynı karar (2026-09-19): Mentora referansı düz,
            // renkli bulanık leke efekti olmayan bir açık zemin kullanıyor
            // — bu atmosfer yalnız koyu temada kalıyor, tutarlılık için.
            if (AppColors.isDark) const Positioned.fill(child: _FocusAuroraBackground()),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Eyebrow(text: 'ODAK SEANSI'),
                    const SizedBox(height: 12),

                    // mod seçici
                    _ModeToggle(
                      mode: _mode,
                      enabled: !_running,
                      onChanged: _switchMode,
                    ),

                    const SizedBox(height: 16),
                    // Seans BAŞLAMADAN önce: ne çalışıyorum + neden. Seans
                    // sürerken alanlar gizlenir (dikkat dağıtmasın); bağlam
                    // kartı kalır — öğrenci neye çalıştığını görmeye devam
                    // eder.
                    if (_running)
                      _FocusContextCard(
                        title: _contextTitle(),
                        subtitle: _contextSubtitle(),
                        reason: _contextReason(),
                      )
                    else ...[
                      // Bağlam (ne + kaç dk, varsa neden) seçili bir şey
                      // varken HER ZAMAN görünür; yalnız hiç bağlam yoksa
                      // (serbest çalışma) kart çizilmez.
                      if (_selectedSubjectId != null ||
                          _noteController.text.trim().isNotEmpty) ...[
                        _FocusContextCard(
                          title: _contextTitle(),
                          subtitle: _contextSubtitle(),
                          reason: _contextReason(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Konu seçiliyse "ne çalışıyorum" zaten belli (kart +
                      // çip); serbest not yalnız konu yokken sorulur.
                      if (_selectedTopicId == null) ...[
                        TextField(
                          controller: _noteController,
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'Ne üzerinde çalışıyorsun? (opsiyonel)',
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _SubjectTopicPicker(
                        enabled: !_running,
                        selectedSubjectId: _selectedSubjectId,
                        selectedTopicId: _selectedTopicId,
                        onSubjectChanged: (id) => setState(() {
                          _selectedSubjectId = id;
                          _selectedTopicId = null;
                        }),
                        onTopicChanged: (id) =>
                            setState(() => _selectedTopicId = id),
                      ),
                    ],

                    const SizedBox(height: 32),

                    Center(
                      child: _TimerRing(
                        progress: progress,
                        accent:
                            (isBreak || reached) ? AppColors.success : accent,
                        running: _running,
                        clock: clock,
                        clockColor: (isBreak || reached)
                            ? AppColors.success
                            : AppColors.textPrimary,
                        statusLabel: _mode == _Mode.free
                            ? (reached
                                ? 'hedefi geçtin · ${_fmtOverage(_freeElapsedSec - _blockMin * 60)}'
                                : 'hedef $_blockMin dk')
                            : _phaseLabel,
                        statusColor: (isBreak || reached)
                            ? AppColors.success
                            : AppColors.textMuted,
                        noteLabel: _noteLabel(),
                      ),
                    ),

                    const SizedBox(height: 14),
                    Center(child: _TodayTotalLabel(liveExtraSec: () {
                      if (_mode == _Mode.free) {
                        return _freeElapsedSec - _freeLoggedSec;
                      }
                      return _phase == _Phase.work
                          ? _phaseElapsedSec - _phaseLoggedSec
                          : 0;
                    }())),

                    const SizedBox(height: 32),
                    if (!isBreak)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.surfaceVariant),
                        ),
                        child: Wrap(
                          spacing: 8,
                          alignment: WrapAlignment.center,
                          children: _blockOptions.map((min) {
                            final selected = _blockMin == min;
                            return TapScale(
                              onTap: _running
                                  ? () {}
                                  : () => setState(() {
                                        _blockMin = min;
                                        _freeTargetCelebrated = false;
                                      }),
                              child: Opacity(
                                opacity: _running ? 0.4 : 1,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.primary
                                        : AppColors.tonal(AppColors.primary),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '$min dk',
                                    style: AppTextStyles.body.copyWith(
                                      color: selected
                                          ? AppColors.onColor(
                                              AppColors.primary)
                                          : AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      )
                    else
                      Center(
                        child: TapScale(
                          onTap: () => _advancePhase(auto: false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.tonal(AppColors.success),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Molayı geç',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 40),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _RoundControlButton(
                          label: 'Bitir',
                          icon: Icons.stop_rounded,
                          onTap: _exit,
                        ),
                        const SizedBox(width: 12),
                        _RoundControlButton(
                          // Aksiyona göre renk — başlat=yeşil, duraklat=turuncu
                          // (kullanıcı isteğiyle, referans uygulamalardaki gibi).
                          color: _running
                              ? AppColors.vibrantCoral
                              : AppColors.vibrantMint,
                          main: true,
                          icon: _running ? Icons.pause : Icons.play_arrow,
                          label: _running ? 'Duraklat' : 'Başlat',
                          onTap: _toggleRun,
                        ),
                        const SizedBox(width: 12),
                        _RoundControlButton(
                          label: 'Geçmiş',
                          icon: Icons.history_rounded,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const FocusHistoryScreen()),
                          ),
                        ),
                      ],
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

/// Odak ekranının arkasındaki yumuşak parıltı — Home'daki aurora ile aynı
/// dil (mercan/mor), tek blur geçişi içinde iki leke.
class _FocusAuroraBackground extends StatelessWidget {
  const _FocusAuroraBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: ClipRect(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: Stack(
              children: [
                Positioned(
                  top: -150,
                  left: 60,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.vibrantCoral.withValues(alpha: 0.16),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -120,
                  right: -60,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.vibrantViolet.withValues(alpha: 0.12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sayacın altında "bugün toplam X dk" satırı — odanın "sadece bugünkü an"
/// değil, günün bütünü için bir yer olduğu hissini güçlendirir. Zaten
/// geçmişe yazılmış (focusTodayMinutesProvider) + şu an süren ama henüz
/// commit edilmemiş canlı seansın saniyeleri toplanır, saniyede bir
/// güncellenir (ticker zaten her saniye setState çağırıyor).
class _TodayTotalLabel extends ConsumerWidget {
  final int liveExtraSec;
  const _TodayTotalLabel({required this.liveExtraSec});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedMin = ref.watch(focusTodayMinutesProvider);
    final totalMin = loggedMin + (liveExtraSec > 0 ? liveExtraSec ~/ 60 : 0);
    if (totalMin < 1) return const SizedBox.shrink();
    return Text(
      'Bugün toplam $totalMin dk',
      style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
    );
  }
}

/// Odak sayacının kalbi — konsept tasarımdaki dramatik gradyan halka + ince
/// kadran çizgileri. `progress`/`clock`/`accent` iş mantığından (yukarıdaki
/// State) hesaplanmış hazır değerler olarak gelir; bu widget saf görsel.
class _TimerRing extends StatefulWidget {
  final double progress;
  final String clock;
  final Color clockColor;
  final String statusLabel;
  final Color statusColor;
  final String? noteLabel;
  final Color accent;
  final bool running;

  const _TimerRing({
    required this.progress,
    required this.clock,
    required this.clockColor,
    required this.statusLabel,
    required this.statusColor,
    required this.accent,
    required this.running,
    this.noteLabel,
  });

  @override
  State<_TimerRing> createState() => _TimerRingState();
}

class _TimerRingState extends State<_TimerRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  bool get _shouldAnimate =>
      widget.running &&
      !WidgetsBinding
          .instance.platformDispatcher.accessibilityFeatures.disableAnimations;

  @override
  void initState() {
    super.initState();
    if (_shouldAnimate) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _TimerRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldAnimate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!_shouldAnimate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const double _diameter = 240;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _diameter,
      height: _diameter,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final glowT = widget.running ? _controller.value : 0.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              // nefes alan parıltı
              Container(
                width: 170 + glowT * 16,
                height: 170 + glowT * 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      widget.accent.withValues(alpha: 0.30 + glowT * 0.08),
                      widget.accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              CustomPaint(
                size: const Size(_diameter, _diameter),
                painter: _TickPainter(
                    color: AppColors.textMuted.withValues(alpha: 0.28)),
              ),
              SizedBox(
                width: 210,
                height: 210,
                child: CircularProgressIndicator(
                  value: widget.progress,
                  strokeWidth: 13,
                  strokeCap: StrokeCap.round,
                  backgroundColor: AppColors.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation(widget.accent),
                ),
              ),
              // Halka içindeki metin sabit boyutlu daireye sığmalı: yazı ölçeği
              // sınırlanır (46pt saat 2x'te halkayı taşırıyordu).
              MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.3,
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.statusLabel,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: widget.statusColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.clock,
                    style: AppTextStyles.heading1.copyWith(
                      fontSize: 46,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      color: widget.clockColor,
                    ),
                  ),
                  if (widget.noteLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.noteLabel!,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ],
              ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 12 eşit aralıklı kadran çizgisi (0/90/180/270'te belirgin) — konsept
/// tasarımdaki hassas cihaz hissini veren detay.
class _TickPainter extends CustomPainter {
  final Color color;
  const _TickPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    for (var i = 0; i < 12; i++) {
      final angle = (i * 30) * math.pi / 180;
      final isMajor = i % 3 == 0;
      final outer = radius - 2;
      final inner = outer - (isMajor ? 10 : 6);
      final dx = math.sin(angle);
      final dy = -math.cos(angle);
      final p1 = center + Offset(dx * inner, dy * inner);
      final p2 = center + Offset(dx * outer, dy * outer);
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = color
          ..strokeWidth = isMajor ? 2 : 1.2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TickPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Odak kontrol satırındaki dairesel buton — konsept tasarımın 3'lü
/// (ikincil/ana/ikincil) düzeni. Ana buton daha büyük + gradyan + parıltı.
class _RoundControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool main;

  const _RoundControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.main = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = main ? 76.0 : 56.0;
    final fg =
        color == null ? AppColors.textSecondary : AppColors.onColor(color!);
    return TapScale(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: color == null
                  ? null
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color!, color!.withValues(alpha: 0.75)],
                    ),
              color: color == null ? AppColors.surface : null,
              border: color == null
                  ? Border.all(color: AppColors.surfaceVariant)
                  : null,
              boxShadow: color == null
                  ? AppColors.softShadow
                  : [
                      ...AppColors.cardShadow,
                      AppColors.glow(color!),
                    ],
            ),
            child: Icon(icon, size: main ? 30 : 22, color: fg),
          ),
          const SizedBox(height: 8),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

/// Ders/konu bağlama — opsiyonel. Ders başlıkla (görevden başlatıldıysa
/// önceden seçili), konu yalnız o dersin konusu varsa görünür. Seçilirse
/// seans bitince Konu Takip'te otomatik işaretlenir + geçmişte "Matematik ·
/// 45 dk" gibi anlamlı görünür (bkz. focus_history_screen).
class _SubjectTopicPicker extends ConsumerWidget {
  final bool enabled;
  final String? selectedSubjectId;
  final String? selectedTopicId;
  final ValueChanged<String?> onSubjectChanged;
  final ValueChanged<String?> onTopicChanged;

  const _SubjectTopicPicker({
    required this.enabled,
    required this.selectedSubjectId,
    required this.selectedTopicId,
    required this.onSubjectChanged,
    required this.onTopicChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectProvider);
    if (subjects.isEmpty) return const SizedBox.shrink();

    final topics = selectedSubjectId == null
        ? const <TopicModel>[]
        : ref.watch(topicsForSubjectProvider(selectedSubjectId!));

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(
                  label: 'Derssiz',
                  selected: selectedSubjectId == null,
                  color: AppColors.textSecondary,
                  onTap: () => onSubjectChanged(null),
                ),
                for (final s in subjects)
                  _chip(
                    label: s.name,
                    selected: selectedSubjectId == s.id,
                    color: Color(s.colorValue),
                    onTap: () => onSubjectChanged(s.id),
                  ),
              ],
            ),
            if (topics.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in topics)
                    _chip(
                      label: t.name,
                      selected: selectedTopicId == t.id,
                      color: AppColors.primary,
                      onTap: () =>
                          onTopicChanged(selectedTopicId == t.id ? null : t.id),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: selected ? AppColors.onColor(color) : color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final _Mode mode;
  final bool enabled;
  final ValueChanged<_Mode> onChanged;

  const _ModeToggle({
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _seg('Serbest', _Mode.free),
            _seg('Pomodoro', _Mode.pomodoro),
          ],
        ),
      ),
    );
  }

  Widget _seg(String label, _Mode value) {
    final selected = mode == value;
    return Expanded(
      child: TapScale(
        onTap: enabled ? () => onChanged(value) : null,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(
              color: selected
                  ? AppColors.onColor(AppColors.primary)
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}


/// Seans bitince tek sheet'ten dönen cevap.
class _FocusOutcome {
  final int? feeling; // FocusFeeling.* ya da null (atlandı)
  final bool completeTask;
  const _FocusOutcome({this.feeling, this.completeTask = false});
}

/// "Ne çalışıyorum, neden, ne kadar" — seans öncesi ve sırasında üstte duran
/// sakin bir kart. [reason] null ise satır hiç çizilmez.
class _FocusContextCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? reason;

  const _FocusContextCard({
    required this.title,
    required this.subtitle,
    this.reason,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceVariant),
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
          const SizedBox(height: 2),
          Text(subtitle, style: AppTextStyles.bodySecondary),
          if (reason != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.insights_outlined,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reason!,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// "Nasıl geçti?" — 1 dokunuş. Bir seçenek seçilince sheet kapanır; bağlı
/// görev varsa altta ayrı, tek satırlık "görevi tamamlandı say" seçeneği.
class _FocusOutcomeSheet extends StatefulWidget {
  final int minutes;
  final String? label;
  final bool canCompleteTask;
  final bool completeTaskByDefault;

  const _FocusOutcomeSheet({
    required this.minutes,
    required this.label,
    required this.canCompleteTask,
    required this.completeTaskByDefault,
  });

  @override
  State<_FocusOutcomeSheet> createState() => _FocusOutcomeSheetState();
}

class _FocusOutcomeSheetState extends State<_FocusOutcomeSheet> {
  late bool _complete = widget.completeTaskByDefault;

  void _done(int? feeling) => Navigator.pop(
        context,
        _FocusOutcome(
          feeling: feeling,
          completeTask: widget.canCompleteTask && _complete,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.minutes} dk çalıştın',
                style: AppTextStyles.heading3),
            if (widget.label != null) ...[
              const SizedBox(height: 2),
              Text(widget.label!, style: AppTextStyles.bodySecondary),
            ],
            const SizedBox(height: 16),
            Text('Nasıl geçti?', style: AppTextStyles.eyebrow),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _feelingButton(FocusFeeling.hard),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _feelingButton(FocusFeeling.ok),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child:
                      _feelingButton(FocusFeeling.great),
                ),
              ],
            ),
            if (widget.canCompleteTask) ...[
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _complete,
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() => _complete = v ?? false),
                title: Text('Görevi tamamlandı say',
                    style: AppTextStyles.body),
              ),
            ],
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () => _done(null),
                child: Text(
                  'Şimdilik geç',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feelingButton(int feeling) {
    return TapScale(
      onTap: () => _done(feeling),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.tonal(AppColors.primary),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(FocusFeeling.emoji(feeling),
                style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            Text(
              FocusFeeling.label(feeling),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
