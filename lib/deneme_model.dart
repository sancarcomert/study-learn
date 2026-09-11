import 'package:hive/hive.dart';

part 'deneme_model.g.dart';

/// Bir denemenin tek bölümü (ör. TYT Türkçe, AYT Matematik). Soru bankası
/// YOK — soru içeriği hiç tutulmaz, yalnızca doğru/yanlış/boş sayısı.
/// P0-9 — deneme/net takibi, kesin kapsam sınırının (soru çözme) dışında.
@HiveType(typeId: 10)
class DenemeSectionScore {
  @HiveField(0)
  String subject;

  @HiveField(1)
  int correct;

  @HiveField(2)
  int wrong;

  @HiveField(3)
  int blank;

  DenemeSectionScore({
    required this.subject,
    this.correct = 0,
    this.wrong = 0,
    this.blank = 0,
  });

  /// ÖSYM formülü: her 4 yanlış 1 doğruyu götürür.
  double get net => correct - wrong / 4.0;

  int get total => correct + wrong + blank;
}

/// Tek bir deneme sınavı kaydı — TYT ya da AYT, tarih + bölüm bazlı
/// doğru/yanlış/boş. Ayrı Hive box'ında (`denemeler`, typeId 11); mevcut
/// modellere (task/subject/stats/topic) dokunulmadı.
@HiveType(typeId: 11)
class DenemeEntry extends HiveObject {
  @HiveField(0)
  String id;

  /// "TYT" | "AYT"
  @HiveField(1)
  String examType;

  @HiveField(2)
  String? name;

  @HiveField(3)
  DateTime date;

  @HiveField(4)
  List<DenemeSectionScore> sections;

  DenemeEntry({
    required this.id,
    required this.examType,
    this.name,
    required this.date,
    required this.sections,
  });

  double get totalNet => sections.fold(0.0, (sum, s) => sum + s.net);
  int get totalCorrect => sections.fold(0, (sum, s) => sum + s.correct);
  int get totalWrong => sections.fold(0, (sum, s) => sum + s.wrong);
  int get totalBlank => sections.fold(0, (sum, s) => sum + s.blank);
  int get totalQuestions => sections.fold(0, (sum, s) => sum + s.total);
}
