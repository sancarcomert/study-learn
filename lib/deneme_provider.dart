import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'deneme_model.dart';
import 'deneme_repository.dart';

const _uuid = Uuid();

final denemeRepositoryProvider = Provider<DenemeRepository>((ref) {
  return DenemeRepository();
});

class DenemeNotifier extends StateNotifier<List<DenemeEntry>> {
  final DenemeRepository _repository;

  DenemeNotifier(this._repository) : super(_repository.getAll());

  void _reload() => state = _repository.getAll();

  void addEntry({
    required String examType,
    String? name,
    required DateTime date,
    required List<DenemeSectionScore> sections,
  }) {
    final trimmedName = name?.trim();
    _repository.add(DenemeEntry(
      id: _uuid.v4(),
      examType: examType,
      name: (trimmedName == null || trimmedName.isEmpty) ? null : trimmedName,
      date: date,
      sections: sections,
    ));
    _reload();
  }

  void updateEntry(DenemeEntry entry) {
    _repository.update(entry);
    _reload();
  }

  /// Siler ve "Geri Al" için bir kopyasını döndürür (kutudan silinen nesne
  /// artık kullanılamaz — `TaskNotifier.deleteTask` ile aynı desen).
  DenemeEntry? deleteEntry(String id) {
    final index = state.indexWhere((e) => e.id == id);
    if (index == -1) return null;

    final original = state[index];
    final snapshot = DenemeEntry(
      id: original.id,
      examType: original.examType,
      name: original.name,
      date: original.date,
      sections: original.sections
          .map((s) => DenemeSectionScore(
                subject: s.subject,
                correct: s.correct,
                wrong: s.wrong,
                blank: s.blank,
              ))
          .toList(),
    );

    _repository.delete(id);
    _reload();
    return snapshot;
  }

  void restoreEntry(DenemeEntry entry) {
    _repository.add(entry);
    _reload();
  }
}

final denemeProvider =
    StateNotifierProvider<DenemeNotifier, List<DenemeEntry>>((ref) {
  final repo = ref.watch(denemeRepositoryProvider);
  return DenemeNotifier(repo);
});

/// Belirli bir sınav türünün ("TYT"/"AYT") kayıtları, tarihe göre artan
/// sırada — trend grafiği kronolojik akmalı.
final denemeByTypeProvider =
    Provider.family<List<DenemeEntry>, String>((ref, examType) {
  final all = ref.watch(denemeProvider);
  return all.where((e) => e.examType == examType).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
});

/// En son eklenen deneme (varsa) — Home/İstatistik özet kartı için.
final latestDenemeProvider = Provider<DenemeEntry?>((ref) {
  final all = ref.watch(denemeProvider); // zaten tarihe göre azalan sıralı
  return all.isEmpty ? null : all.first;
});

/// Bir sınav türü için özet: ortalama net, en iyi net, deneme sayısı.
/// Ham kayıt listesini "nerede duruyorum" bilgisine çevirir — Deneme
/// Takip'in analiz katmanı.
class DenemeSummary {
  final double average;
  final double best;
  final int count;
  const DenemeSummary({required this.average, required this.best, required this.count});
}

final denemeSummaryProvider =
    Provider.family<DenemeSummary?, String>((ref, examType) {
  final entries = ref.watch(denemeByTypeProvider(examType));
  if (entries.isEmpty) return null;
  final nets = entries.map((e) => e.totalNet).toList();
  final avg = nets.reduce((a, b) => a + b) / nets.length;
  final best = nets.reduce((a, b) => a > b ? a : b);
  return DenemeSummary(average: avg, best: best, count: entries.length);
});

/// Bölüm bazında ortalama net — bir sınav türü için tüm denemelerdeki aynı
/// isimli bölümlerin ortalaması, en düşükten en yükseğe sıralı. Ham log'u
/// "hangi derste zayıfım" içgörüsüne çevirir.
final denemeSubjectAveragesProvider =
    Provider.family<List<MapEntry<String, double>>, String>((ref, examType) {
  final entries = ref.watch(denemeByTypeProvider(examType));
  final sums = <String, double>{};
  final counts = <String, int>{};
  for (final e in entries) {
    for (final s in e.sections) {
      sums[s.subject] = (sums[s.subject] ?? 0) + s.net;
      counts[s.subject] = (counts[s.subject] ?? 0) + 1;
    }
  }
  final result = sums.entries
      .map((e) => MapEntry(e.key, e.value / counts[e.key]!))
      .toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  return result;
});
