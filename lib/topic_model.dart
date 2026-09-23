import 'package:hive/hive.dart';

part 'topic_model.g.dart';

/// Bir konunun çalışılma durumu. Bilinçli olarak 3 durum: "soru çözüldü" gibi
/// soru-bankası çağrıştıran bir aşama YOK (kesin kapsam sınırı).
@HiveType(typeId: 6)
enum TopicStatus {
  @HiveField(0)
  notStarted,

  @HiveField(1)
  studied,

  @HiveField(2)
  reviewed,
}

/// Bir derse ait tek bir konu. Mevcut `SubjectModel`'e DOKUNULMADI — konular
/// ayrı bir Hive box'ında, `subjectId` ile derse bağlı tutulur. Böylece eski
/// kayıtlarda migration riski yok.
@HiveType(typeId: 7)
class TopicModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String subjectId;

  @HiveField(2)
  String name;

  @HiveField(3)
  TopicStatus status;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  DateTime? updatedAt;

  /// Bu konunun durumunu ilerletmiş çalışma OLAYLARININ anahtarları (bkz.
  /// TopicProgress). Aynı gerçek-dünya olayı ikinci kez geldiğinde (ör. Focus
  /// seansı + o seansla tamamlanan görev) durum bir daha ilerlemesin diye —
  /// idempotentlik burada, veride durur; arayüz bayrağında değil. Eski
  /// kayıtlarda boş liste (hiç olay kaydedilmemiş) — doğru.
  @HiveField(6, defaultValue: <String>[])
  List<String> activityKeys;

  TopicModel({
    required this.id,
    required this.subjectId,
    required this.name,
    this.status = TopicStatus.notStarted,
    required this.createdAt,
    this.updatedAt,
    List<String>? activityKeys,
  }) : activityKeys = activityKeys ?? [];

  /// Silinmeden önce alınan, HiveObject'ten bağımsız tam kopya ("Geri Al"
  /// için). Kopyalama TEK yerde durur: alan eklendiğinde (ör. [activityKeys])
  /// elle yazılmış ayrı kopyalardan biri unutulup veri sessizce kaybolmasın.
  TopicModel copy() => TopicModel(
        id: id,
        subjectId: subjectId,
        name: name,
        status: status,
        createdAt: createdAt,
        updatedAt: updatedAt,
        activityKeys: List.of(activityKeys),
      );

  /// "Bitmiş" sayılır mı — kapsama yüzdesinde pay.
  bool get isCovered =>
      status == TopicStatus.studied || status == TopicStatus.reviewed;
}
