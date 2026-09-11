import 'hive_boxes.dart';
import 'deneme_model.dart';

/// Deneme kayıtlarının Hive kalıcılığı — `TopicRepository` ile aynı desen.
/// Kendi box'ı (`denemeler`); mevcut kutulara dokunmaz.
class DenemeRepository {
  final _box = HiveBoxes.denemeler;

  List<DenemeEntry> getAll() =>
      _box.values.toList()..sort((a, b) => b.date.compareTo(a.date));

  Future<void> add(DenemeEntry entry) => _box.put(entry.id, entry);

  Future<void> update(DenemeEntry entry) => entry.save();

  Future<void> delete(String id) => _box.delete(id);
}
