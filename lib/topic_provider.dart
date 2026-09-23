import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'topic_model.dart';
import 'topic_repository.dart';

const _uuid = Uuid();

final topicRepositoryProvider = Provider<TopicRepository>((ref) {
  return TopicRepository();
});

class TopicNotifier extends StateNotifier<List<TopicModel>> {
  final TopicRepository _repository;

  TopicNotifier(this._repository) : super(_repository.getAll());

  void _reload() => state = _repository.getAll();

  /// Tek konu ekler. Aynı derste aynı adlı konu varsa sessizce atlar.
  void addTopic(String subjectId, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final exists = state.any((t) =>
        t.subjectId == subjectId &&
        t.name.toLowerCase() == trimmed.toLowerCase());
    if (exists) return;

    _repository.add(TopicModel(
      id: _uuid.v4(),
      subjectId: subjectId,
      name: trimmed,
      createdAt: DateTime.now(),
    ));
    _reload();
  }

  /// Katalogdan toplu ekleme — zaten var olanları atlar, kaç yeni eklendiğini
  /// döndürür.
  int addMany(String subjectId, Iterable<String> names) {
    final existing = state
        .where((t) => t.subjectId == subjectId)
        .map((t) => t.name.toLowerCase())
        .toSet();
    var added = 0;
    for (final raw in names) {
      final name = raw.trim();
      if (name.isEmpty || existing.contains(name.toLowerCase())) continue;
      _repository.add(TopicModel(
        id: _uuid.v4(),
        subjectId: subjectId,
        name: name,
        createdAt: DateTime.now(),
      ));
      existing.add(name.toLowerCase());
      added++;
    }
    if (added > 0) _reload();
    return added;
  }

  void cycleStatus(String id) {
    final topic = state.firstWhere((t) => t.id == id);
    topic.status = topic.nextStatus;
    topic.updatedAt = DateTime.now();
    _repository.update(topic);
    _reload();
  }

  void setStatus(String id, TopicStatus status) {
    final topic = state.firstWhere((t) => t.id == id);
    topic.status = status;
    topic.updatedAt = DateTime.now();
    _repository.update(topic);
    _reload();
  }

  // Geri Al akışı için: silmeden önce alanların bağımsız bir kopyasını
  // döndürür (silinen HiveObject'in kendisi kullanılamaz — box'tan
  // silindikten sonra artık geçerli değildir). null dönerse konu zaten
  // yok demektir. Desen task_provider.dart'taki deleteTask ile aynı.
  TopicModel? deleteTopic(String id) {
    final index = state.indexWhere((t) => t.id == id);
    if (index == -1) return null;

    final original = state[index];
    final snapshot = TopicModel(
      id: original.id,
      subjectId: original.subjectId,
      name: original.name,
      status: original.status,
      createdAt: original.createdAt,
      updatedAt: original.updatedAt,
    );

    _repository.delete(id);
    _reload();

    return snapshot;
  }

  // "Geri Al" ile deleteTopic'in döndürdüğü kopyayı aynı id ile geri ekler.
  void restoreTopic(TopicModel topic) {
    _repository.add(topic);
    _reload();
  }

  void deleteForSubject(String subjectId) {
    _repository.deleteForSubject(subjectId);
    _reload();
  }
}

final topicProvider =
    StateNotifierProvider<TopicNotifier, List<TopicModel>>((ref) {
  final repo = ref.watch(topicRepositoryProvider);
  return TopicNotifier(repo);
});

/// Belirli bir dersin konuları (oluşturulma sırasına göre).
final topicsForSubjectProvider =
    Provider.family<List<TopicModel>, String>((ref, subjectId) {
  final all = ref.watch(topicProvider);
  return all.where((t) => t.subjectId == subjectId).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
});

/// Ders başına {bitmiş, toplam} — grafik ve öneri motoru için.
class TopicCoverage {
  final int covered;
  final int total;
  const TopicCoverage(this.covered, this.total);

  double get ratio => total == 0 ? 0 : covered / total;
  int get percent => (ratio * 100).round();
  bool get hasTopics => total > 0;
}

final coverageBySubjectProvider =
    Provider<Map<String, TopicCoverage>>((ref) {
  final all = ref.watch(topicProvider);
  final map = <String, List<TopicModel>>{};
  for (final t in all) {
    map.putIfAbsent(t.subjectId, () => []).add(t);
  }
  return map.map((subjectId, topics) => MapEntry(
        subjectId,
        TopicCoverage(topics.where((t) => t.isCovered).length, topics.length),
      ));
});

/// "Tekrar" (reviewed) işaretli ama 14+ gündür dokunulmamış (ya da hiç
/// `updatedAt` alanı yazılmadan reviewed'a geçmiş — eski kayıt) konusu olan
/// dersler. `reviewed`, `studied`'ten farklı bir durum olarak var oluyordu
/// ama hiçbir yerde `studied`'ten ayrı muamele görmüyordu (kapsamda ikisi de
/// eşit ağırlık) — bu, StudyAdvisor'a "tekrar zamanı geldi" sinyali veren
/// ilk gerçek kullanım alanı.
final staleReviewSubjectIdsProvider = Provider<Set<String>>((ref) {
  final all = ref.watch(topicProvider);
  final now = DateTime.now();
  final result = <String>{};
  for (final t in all) {
    if (t.status != TopicStatus.reviewed) continue;
    final last = t.updatedAt;
    final isStale = last == null || now.difference(last).inDays >= 14;
    if (isStale) result.add(t.subjectId);
  }
  return result;
});
