import 'package:home_widget/home_widget.dart';

import 'hive_boxes.dart';

/// Ana ekran widget'ını besleyen tek kaynak (docs/rakip_analizi §6 B1).
/// Sınav geri sayımı + bugünkü görev ilerlemesi. Hive kutularını doğrudan
/// okur (repository'lerle aynı biçimde) — hiçbir provider'a dokunmaz.
///
/// Yerel/pasif: widget kendi başına Flutter çalıştırmaz; biz uygun anlarda
/// (`main` açılışında, uygulama arka plana alınırken) veriyi
/// SharedPreferences'a yazıp native provider'ı tetikliyoruz.
class WidgetService {
  WidgetService._();

  static const String _androidProvider = 'PusulaWidgetProvider';

  static Future<void> sync() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // --- Sınav geri sayımı ---
      final examDate = HiveBoxes.stats.get('main')?.examDate;
      String countdown = '';
      if (examDate != null) {
        final target = DateTime(examDate.year, examDate.month, examDate.day);
        final days = target.difference(today).inDays;
        countdown = switch (days) {
          > 0 => 'Sınava $days gün',
          0 => 'Sınav bugün',
          _ => '',
        };
      }

      // --- Bugünkü görevler ---
      final todays = HiveBoxes.tasks.values.where((t) =>
          t.dueDate.year == today.year &&
          t.dueDate.month == today.month &&
          t.dueDate.day == today.day);
      final total = todays.length;
      final done = todays.where((t) => t.isCompleted).length;

      final String tasksLine;
      if (total == 0) {
        tasksLine = 'Bugüne görev eklenmedi';
      } else if (done >= total) {
        tasksLine = 'Bugün tamam · $done/$total';
      } else {
        tasksLine = 'Bugün $done/$total görev';
      }

      await HomeWidget.saveWidgetData<bool>(
          'has_countdown', countdown.isNotEmpty);
      await HomeWidget.saveWidgetData<String>('countdown', countdown);
      await HomeWidget.saveWidgetData<String>('tasks', tasksLine);
      await HomeWidget.saveWidgetData<int>(
          'progress', total == 0 ? 0 : (done / total * 100).round());

      await HomeWidget.updateWidget(androidName: _androidProvider);
    } catch (_) {
      // Widget güncellemesi best-effort — uygulama akışını asla etkilemez.
    }
  }
}
