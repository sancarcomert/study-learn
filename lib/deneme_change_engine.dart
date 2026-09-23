import 'deneme_model.dart';
import 'goal_gap_engine.dart';

/// İki deneme arasında bir dersin net farkı — [DenemeChangeEngine.
/// mostChangedSubject] çıktısı.
class SubjectNetChange {
  final String subjectName;

  /// Yeni net - eski net. Pozitif = iyileşme.
  final double delta;

  const SubjectNetChange({required this.subjectName, required this.delta});
}

/// DENEME → SONUÇ → RE-EVALUATION (Faz 2/9) — bir deneme kaydedildiğinde
/// "ne değişti?" sorusuna kısa/somut bir cümleyle cevap üreten saf çekirdek.
/// Hiçbir provider'a dokunmaz, hiçbir şey yazmaz — yalnız zaten hesaplanmış
/// sinyalleri (GoalGap, konu listeleri) okunabilir bir metne çevirir.
///
/// Sahte/motivasyonel dolgu YOK: bir kıyas mümkün değilse (ilk deneme,
/// hedef yok, anlamlı fark yok) o bölüm sessizce atlanır; hiçbiri mümkün
/// değilse [summarize] null döner — çağıran taraf (add_deneme_screen.dart)
/// o zaman hiçbir "ne değişti" mesajı göstermez.
class DenemeChangeEngine {
  const DenemeChangeEngine._();

  /// Bu eşiğin altındaki farklar doğal dalgalanma sayılır, "değişim" değil
  /// (StatsInsightEngine'deki gürültü eşikleriyle aynı prensip).
  static const double noiseThreshold = 0.5;

  /// [current] ile [previous] (aynı tür, bu kayıttan önceki son deneme)
  /// arasında, İKİSİNDE DE ORTAK bulunan derslerden en büyük mutlak net
  /// farkına sahip olanı. [previous] null ise (ilk deneme) null.
  static SubjectNetChange? mostChangedSubject(
    DenemeEntry current,
    DenemeEntry? previous,
  ) {
    if (previous == null) return null;
    final previousBySubject = <String, double>{
      for (final s in previous.sections) s.subject.trim().toLowerCase(): s.net,
    };
    SubjectNetChange? best;
    for (final s in current.sections) {
      final key = s.subject.trim().toLowerCase();
      final prevNet = previousBySubject[key];
      if (prevNet == null) continue;
      final delta = s.net - prevNet;
      if (delta.abs() < noiseThreshold) continue;
      if (best == null || delta.abs() > best.delta.abs()) {
        best = SubjectNetChange(subjectName: s.subject.trim(), delta: delta);
      }
    }
    return best;
  }

  /// Tek/iki cümlelik "ne değişti?" özeti. Öncelik sırası:
  /// 1) GOAL → GAP değişimi ya da hedefe yeni ulaşıldıysa (en anlamlı sinyal
  ///    — öğrencinin belirlediği hedefle doğrudan ilgili).
  /// 2) Hedef yoksa/gap değişmediyse, en çok değişen ders neti.
  /// 3) İyileşen (artık zayıf işaretli olmayan) bir konu.
  /// 4) Bu denemede yeni zayıf çıkan bir konu.
  /// Uygun bir sinyal yoksa null (ör. tamamen ilk deneme, hiç kıyas yok).
  static String? summarize({
    GoalGap? goalGap,
    SubjectNetChange? mostChangedSubject,
    Map<String, List<String>> resolvedSubjectTopics = const {},
    Map<String, List<String>> newlyWeakSubjectTopics = const {},
  }) {
    final parts = <String>[];

    if (goalGap != null && goalGap.hasTarget && goalGap.hasResult) {
      final change = goalGap.gapChange;
      final previousGap = goalGap.previousGap;
      if (goalGap.reached && previousGap != null && previousGap > 0) {
        // Bu deneme ile hedefe İLK KEZ ulaşıldı (önceki deneme henüz
        // ulaşmamıştı) — en güçlü, tek seferlik gerçek.
        parts.add('Bu denemeyle ${goalGap.examType} hedefine ulaştın.');
      } else if (change != null && change.abs() >= noiseThreshold) {
        parts.add(change > 0
            ? 'Hedefe kalan fark ${_fmt(previousGap!)} netten '
                '${_fmt(goalGap.gap!)} nete indi.'
            : 'Hedefe kalan fark ${_fmt(previousGap!)} netten '
                '${_fmt(goalGap.gap!)} nete çıktı.');
      }
    }

    if (parts.isEmpty && mostChangedSubject != null) {
      final s = mostChangedSubject;
      final sign = s.delta > 0 ? '+' : '';
      parts.add('${s.subjectName}\'te önceki denemene göre '
          '$sign${_fmt(s.delta)} net.');
    }

    if (resolvedSubjectTopics.isNotEmpty) {
      final topic = resolvedSubjectTopics.values.first.first;
      parts.add('"$topic" artık son denemendeki zayıf konu olarak görünmüyor.');
    } else if (newlyWeakSubjectTopics.isNotEmpty && parts.length < 2) {
      final topic = newlyWeakSubjectTopics.values.first.first;
      parts.add('"$topic" bu denemede yeni bir zayıf konu olarak işaretlendi.');
    }

    if (parts.isEmpty) return null;
    return parts.take(2).join(' ');
  }

  static String _fmt(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
