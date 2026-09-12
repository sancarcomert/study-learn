import 'hive_boxes.dart';
import 'topic_model.dart';

/// Konuların Hive kalıcılığı — `SubjectRepository` / `TaskRepository` ile
/// aynı desen. Kendi box'ı (`topics`) var; mevcut kutulara dokunmaz.
class TopicRepository {
  final _box = HiveBoxes.topics;

  List<TopicModel> getAll() => _box.values.toList();

  Future<void> add(TopicModel topic) => _box.put(topic.id, topic);

  Future<void> update(TopicModel topic) {
    topic.updatedAt = DateTime.now();
    return topic.save();
  }

  Future<void> delete(String id) => _box.delete(id);

  /// Bir ders silindiğinde onun konularını da temizler.
  Future<void> deleteForSubject(String subjectId) async {
    final ids = _box.values
        .where((t) => t.subjectId == subjectId)
        .map((t) => t.key)
        .toList();
    await _box.deleteAll(ids);
  }
}
