import 'package:flutter/material.dart' show TimeOfDay;

/// Görev ekleme "NE ZAMAN" seçeneklerinin türü.
enum WhenKind {
  /// Şimdi başlıyorum — bugün, saat = şu an.
  now,

  /// 30 dakika sonra (5 dk'ya yukarı yuvarlanmış).
  in30,

  /// 1 saat sonra (5 dk'ya yukarı yuvarlanmış).
  in60,

  /// Bugün, ama belirli bir saat yok — "bugün daha sonra" (bilerek saatsiz).
  laterToday,

  /// Yarın, saatsiz.
  tomorrow,

  /// Öğrencinin seçtiği tam gün (+ isteğe bağlı saat).
  custom,
}

/// Bir görevin ne zaman yapılacağı — SUNUMDAN bağımsız, saf bir değer.
/// "Göreli" seçenekler (şimdi / 30 dk sonra…) seçildikleri anın saatine değil,
/// görev KAYDEDİLDİĞİ anın saatine göre çözülür ([dueDay]/[scheduledAt] `now`
/// alır): ekran uzun süre açık kalsa da geçmişe kalan bir saat üretilmez.
class TaskWhen {
  final WhenKind kind;
  final DateTime? customDay;
  final TimeOfDay? customTime;

  const TaskWhen(this.kind, {this.customDay, this.customTime});

  /// Bugün, saatsiz — yeni görevin varsayılanı.
  static const TaskWhen laterToday = TaskWhen(WhenKind.laterToday);

  factory TaskWhen.custom(DateTime day, TimeOfDay? time) => TaskWhen(
        WhenKind.custom,
        customDay: DateTime(day.year, day.month, day.day),
        customTime: time,
      );

  /// Mevcut bir görevin (düzenleme) tarih/saatinden, öğrencinin gördüğü
  /// seçeneğe döner: bugün+saatsiz → "bugün daha sonra", yarın+saatsiz →
  /// "yarın", diğer her şey tam özel gün/saat.
  factory TaskWhen.fromExisting(
      DateTime dueDate, DateTime? scheduled, DateTime now) {
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final today = DateTime(now.year, now.month, now.day);
    if (scheduled == null && due == today) return laterToday;
    if (scheduled == null && due == today.add(const Duration(days: 1))) {
      return const TaskWhen(WhenKind.tomorrow);
    }
    return TaskWhen.custom(
      due,
      scheduled == null
          ? null
          : TimeOfDay(hour: scheduled.hour, minute: scheduled.minute),
    );
  }

  /// Görevin ait olduğu gün (saat sıfır).
  DateTime dueDay(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    switch (kind) {
      case WhenKind.now:
      case WhenKind.laterToday:
        return today;
      case WhenKind.in30:
      case WhenKind.in60:
        final at = scheduledAt(now)!;
        return DateTime(at.year, at.month, at.day);
      case WhenKind.tomorrow:
        return today.add(const Duration(days: 1));
      case WhenKind.custom:
        return customDay ?? today;
    }
  }

  /// Zamanlanmış başlangıç; saatsiz seçeneklerde null.
  DateTime? scheduledAt(DateTime now) {
    switch (kind) {
      case WhenKind.now:
        return DateTime(now.year, now.month, now.day, now.hour, now.minute);
      case WhenKind.in30:
        return TaskTimeOptions.roundUpTo5(now.add(const Duration(minutes: 30)));
      case WhenKind.in60:
        return TaskTimeOptions.roundUpTo5(now.add(const Duration(minutes: 60)));
      case WhenKind.laterToday:
      case WhenKind.tomorrow:
        return null;
      case WhenKind.custom:
        final day = customDay;
        final time = customTime;
        if (day == null || time == null) return null;
        return DateTime(day.year, day.month, day.day, time.hour, time.minute);
    }
  }

  bool get isTimed =>
      kind == WhenKind.now ||
      kind == WhenKind.in30 ||
      kind == WhenKind.in60 ||
      (kind == WhenKind.custom && customTime != null);

  @override
  bool operator ==(Object other) =>
      other is TaskWhen &&
      other.kind == kind &&
      other.customDay == customDay &&
      other.customTime == customTime;

  @override
  int get hashCode => Object.hash(kind, customDay, customTime);
}

/// Bir anın ([now]) sunabileceği seçenekler ve etiketleri.
class TaskTimeOptions {
  const TaskTimeOptions._();

  static String hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static const _months = [
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];

  /// [now] için geçerli hazır seçenekler, sırayla. Gece yarısını aşacak
  /// göreli seçenekler (ör. 23:40'ta "1 saat sonra") sunulmaz — geçmişe ya da
  /// başka güne kayan öneri yok. "Özel" her zaman ayrıca sunulur (bkz.
  /// [WhenKind.custom]).
  static List<WhenKind> available(DateTime now) {
    bool sameDay(DateTime d) =>
        d.year == now.year && d.month == now.month && d.day == now.day;
    return [
      WhenKind.now,
      if (sameDay(roundUpTo5(now.add(const Duration(minutes: 30)))))
        WhenKind.in30,
      if (sameDay(roundUpTo5(now.add(const Duration(minutes: 60)))))
        WhenKind.in60,
      WhenKind.laterToday,
      WhenKind.tomorrow,
    ];
  }

  /// Çip etiketi — göreli seçeneklerde çözülmüş saati de gösterir
  /// ("30 dk sonra · 21:35"): öğrenci ne seçtiğini görür.
  static String label(TaskWhen w, DateTime now) {
    switch (w.kind) {
      case WhenKind.now:
        return 'Şimdi';
      case WhenKind.in30:
        return '30 dk sonra · ${_hhmmOf(w.scheduledAt(now)!)}';
      case WhenKind.in60:
        return '1 saat sonra · ${_hhmmOf(w.scheduledAt(now)!)}';
      case WhenKind.laterToday:
        return 'Bugün daha sonra';
      case WhenKind.tomorrow:
        return 'Yarın';
      case WhenKind.custom:
        final day = w.customDay;
        if (day == null) return 'Özel';
        final today = DateTime(now.year, now.month, now.day);
        final dayLabel = day == today
            ? 'Bugün'
            : (day == today.add(const Duration(days: 1))
                ? 'Yarın'
                : '${day.day} ${_months[day.month - 1]}');
        final t = w.customTime;
        return t == null ? '$dayLabel · saatsiz' : '$dayLabel · ${hhmm(t)}';
    }
  }

  static String _hhmmOf(DateTime d) =>
      hhmm(TimeOfDay(hour: d.hour, minute: d.minute));

  static DateTime roundUpTo5(DateTime d) {
    final base = DateTime(d.year, d.month, d.day, d.hour, d.minute);
    final rem = base.minute % 5;
    return rem == 0 ? base : base.add(Duration(minutes: 5 - rem));
  }
}
