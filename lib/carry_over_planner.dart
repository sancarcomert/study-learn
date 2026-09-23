import 'task_model.dart';

/// Kaçırılmış (bugünden önceki, tamamlanmamış) görevleri gerçekçi biçimde
/// günlere dağıtır — bkz. home_screen._maybeShowCarryOverPrompt. Hepsini
/// bugüne DAYATMAK yerine ("yığın" — DODOM spec §14), günlük gerçekçi bir
/// kapasiteyi aşan kısmı sıradaki gün(ler)e kaydırır. Saf: TaskModel'leri
/// okur, hangi gün ofsetine (0 = bugün) düştüklerini döndürür, hiçbir şey
/// yazmaz/provider'a dokunmaz — PlanBuilder/StudyAdvisor ile aynı desen.
class CarryOverPlan {
  /// taskId → gün ofseti (0 = bugün, 1 = yarın, ...).
  final Map<String, int> dayOffsetByTaskId;

  /// Kaç farklı güne yayıldığı (yalnız fiilen kullanılan günler).
  final int dayCount;

  const CarryOverPlan({
    required this.dayOffsetByTaskId,
    required this.dayCount,
  });
}

class CarryOverPlanner {
  const CarryOverPlanner._();

  /// Bir günde gerçekçi kabul edilen tahmini çalışma süresi — bu sınırın
  /// üstü "bugüne sığmaz" sayılır. PlanBuilder'ın enerji bazlı blok
  /// sürelerinden bağımsız, sabit bir günlük tavan (3 saat).
  static const int realisticDailyMinutes = 180;

  /// Süresi olmayan (estimatedMinutes null) bir görevin kapasite
  /// hesabındaki varsayılan ağırlığı.
  static const int fallbackMinutes = 20;

  /// Bu görev listesi tek günde gerçekçi şekilde bitirilemeyecek kadar
  /// kalabalık mı? Tek görev asla "aşırı yüklü" sayılmaz (bölünecek bir
  /// şey yok).
  static bool isOverloaded(List<TaskModel> tasks) {
    if (tasks.length <= 1) return false;
    final total = tasks.fold<int>(
        0, (sum, t) => sum + (t.estimatedMinutes ?? fallbackMinutes));
    return total > realisticDailyMinutes;
  }

  /// Görevleri önceliğe göre (yüksek önce) sıralayıp güne göre açgözlü
  /// (greedy) doldurur — bir gün kapasiteyi aşınca sıradaki göreve bir
  /// sonraki gün ofseti atanır. En fazla 6 gün ileri gider (7. günde ne
  /// kalırsa kalsın oraya yığılır — sonsuz uzamasın diye).
  ///
  /// [minutesFor] verilirse (ör. kronik görev küçültüldüğünde gerçek/küçültülmüş
  /// süreyi döndürmesi için) o kullanılır, yoksa `task.estimatedMinutes`.
  static CarryOverPlan distribute(
    List<TaskModel> tasks, {
    int Function(TaskModel task)? minutesFor,
  }) {
    final ordered = List<TaskModel>.from(tasks)
      ..sort((a, b) => b.priority.index.compareTo(a.priority.index));

    final dayMinutes = <int, int>{};
    final result = <String, int>{};

    for (final t in ordered) {
      final minutes = minutesFor?.call(t) ?? t.estimatedMinutes ?? fallbackMinutes;
      var offset = 0;
      // Yalnız gün BOŞ DEĞİLKEN (dayMinutes[offset] > 0) ve eklenince tavanı
      // aşıyorsa sıradaki güne geç. Boş bir güne her zaman yerleştir — aksi
      // halde tek başına tavanı aşan bir görev (ör. 200 dk > 180 dk) hangi
      // güne bakılırsa bakılsın "sığmıyor" sayılıp doğrudan 6. güne
      // sıçrardı, aradaki boş günler hiç kullanılmazdı.
      while ((dayMinutes[offset] ?? 0) > 0 &&
          (dayMinutes[offset] ?? 0) + minutes > realisticDailyMinutes &&
          offset < 6) {
        offset++;
      }
      dayMinutes[offset] = (dayMinutes[offset] ?? 0) + minutes;
      result[t.id] = offset;
    }

    return CarryOverPlan(
      dayOffsetByTaskId: result,
      dayCount: dayMinutes.keys.length,
    );
  }
}
