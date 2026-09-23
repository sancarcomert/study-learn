import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'focus_session_provider.dart';
import 'stats_provider.dart';
import 'task_provider.dart';
import 'topic_evidence.dart';
import 'topic_evidence_provider.dart';
import 'topic_progress.dart';
import 'topic_provider.dart';

const _uuid = Uuid();

/// Çalışma OLAYLARININ tek giriş kapısı. Ekranlar birkaç ilgisiz provider'ı
/// kendileri değiştirmez ("Bitir'e basınca şunu da şunu da yap"); gerçek-dünya
/// olayını buraya bildirir, sonuçlar (kalıcı kayıt → türetilmiş öneri/ekran)
/// buradan yayılır.
///
/// Kavramlar (bkz. ayrıca TopicProgress):
/// - NİYET: "şunu çalışmak istiyorum" (StudyIntent). Hiçbir şeyi değiştirmez.
/// - ETKİNLİK: gerçekten zaman harcandı ([recordFocusActivity]) — ölçülmüş
///   süre. Konuyu "çalışıldı" yapar; "öğrendi" DEMEZ.
/// - KANIT: çalışmanın nasıl geçtiğine dair sinyal ([finishFocusRun]'ın
///   `feeling`i) ya da gerçek bir deneme sonucu.
/// - SONUÇ: performansın değişmesi — yalnız yeni bir denemeden gelir.
class StudyEvents {
  final Ref _ref;
  StudyEvents(this._ref);

  /// Yeni bir Focus çalışması (run) kimliği. Aynı çalışmanın tüm dilimleri
  /// (Pomodoro blokları, arka plana alma checkpoint'leri) bunu paylaşır —
  /// "bir çalışma = bir olay".
  String newRunId() => _uuid.v4();

  /// Focus'ta ÖLÇÜLMÜŞ bir çalışma dilimi. Kaydeder (FocusSession), toplam odak
  /// süresini günceller ve konu bağlıysa konuya BİR çalışma olayı işler —
  /// olay anahtarı çalışmanın kimliği olduğundan, çok dilimli bir çalışma
  /// konuyu tek adımdan fazla ilerletmez. [minutes] < 1 ise hiçbir şey olmaz
  /// (ölçülmüş etkinlik yok). Döndürür: yazılan dilimin id'si.
  String? recordFocusActivity({
    required String runId,
    required int minutes,
    required String mode,
    String? subjectId,
    String? topicId,
    String? taskId,
    String? note,
  }) {
    final id = _ref.read(focusSessionProvider.notifier).log(
          minutes: minutes,
          mode: mode,
          subjectId: subjectId,
          topicId: topicId,
          taskId: taskId,
          runId: runId,
          note: note,
        );
    if (id == null) return null;
    _ref.read(statsProvider.notifier).addFocusMinutes(minutes);
    if (topicId != null) {
      _ref
          .read(topicProvider.notifier)
          .recordStudyActivity(topicId, TopicProgress.focusRunKey(runId));
    }
    return id;
  }

  /// Öğrenci çalışmayı bitirdi. [feeling] (bkz. FocusFeeling) çalışmanın
  /// dilimlerine yazılır — sonraki öneri/rozet/plan bundan türer. [completeTask]
  /// true ise bağlı görev tamamlanır; harcanan süre ve (konu zaten bu
  /// çalışmayla sayıldığı için) konu ilerlemesi görev tamamlama kuralından
  /// çıkar (bkz. TaskNotifier.toggleTaskCompletion), burada tekrar hesaplanmaz.
  Future<FocusRunResult> finishFocusRun({
    required String runId,
    String? topicId,
    String? taskId,
    int? feeling,
    bool completeTask = false,
  }) async {
    final before = topicId == null
        ? DifficultySignal.none
        : (_ref.read(topicDifficultyProvider)[topicId] ?? DifficultySignal.none);

    if (feeling != null) {
      _ref.read(focusSessionProvider.notifier).setFeelingForRun(runId, feeling);
    }

    var taskCompleted = false;
    if (completeTask && taskId != null) {
      await _ref.read(taskProvider.notifier).completeTask(taskId);
      taskCompleted = true;
    }

    final after = topicId == null
        ? DifficultySignal.none
        : (_ref.read(topicDifficultyProvider)[topicId] ?? DifficultySignal.none);

    return FocusRunResult(
      answered: feeling != null,
      taskCompleted: taskCompleted,
      difficultyBefore: before,
      difficultyAfter: after,
    );
  }
}

/// [StudyEvents.finishFocusRun]'ın sonucu — öğrenciye söylenecek cümle bunu
/// yansıtır (gerçekten olan şeyi anlatır, olmayacak bir söz vermez).
class FocusRunResult {
  final bool answered;
  final bool taskCompleted;
  final DifficultySignal difficultyBefore;
  final DifficultySignal difficultyAfter;

  const FocusRunResult({
    required this.answered,
    required this.taskCompleted,
    required this.difficultyBefore,
    required this.difficultyAfter,
  });
}

final studyEventsProvider = Provider<StudyEvents>((ref) => StudyEvents(ref));
