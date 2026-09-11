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
