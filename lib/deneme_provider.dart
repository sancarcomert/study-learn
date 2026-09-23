import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'deneme_model.dart';
import 'deneme_repository.dart';
import 'subject_provider.dart';
import 'topic_model.dart';
import 'topic_provider.dart';

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
                weakTopicIds: List.of(s.weakTopicIds),
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

/// Tüm denemeler (TYT+AYT birlikte) üzerinden en düşük ortalama nete sahip
/// bölüm adı — Çalışma Koçu/Ana Sayfa önerisine "deneme netlerinde en zayıf
/// olduğun ders" sinyali olarak beslenir (bkz. study_advisor.dart). Deneme
/// Takip'i yalnız bir grafik olmaktan çıkarıp günlük plana etki eder hâle
/// getirir. En az 2 farklı bölüm verisi yoksa null — "en zayıf" tek
/// bölümden anlamlı değil.
final weakestDenemeSubjectNameProvider = Provider<String?>((ref) {
  final all = ref.watch(denemeProvider);
  final sums = <String, double>{};
  final counts = <String, int>{};
  for (final e in all) {
    for (final s in e.sections) {
      sums[s.subject] = (sums[s.subject] ?? 0) + s.net;
      counts[s.subject] = (counts[s.subject] ?? 0) + 1;
    }
  }
  if (sums.length < 2) return null;
  final sorted = sums.entries.map((e) => MapEntry(e.key, e.value / counts[e.key]!)).toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  return sorted.first.key;
});

/// Deneme netleri GERİLEMEKTE olan ders adları — "en zayıf ortalama" tek
/// başına yeterli değil: bir ders hep 20 net alıp sabit kalıyorsa zayıf ama
/// ilerlemiyor değil, 25→20→15'e düşüyorsa gerçek bir gerileme. En az 3
/// deneme verisi olan (tarihe göre ilk yarı ortalaması ile ikinci yarı
/// ortalaması arasında >=1 net düşüş) bölümler işaretlenir. Statik
/// [weakestDenemeSubjectNameProvider]'ın YANINDA, ondan BAĞIMSIZ bir sinyal
/// (StudyAdvisor'a ayrı puanla geçilir — bkz. worseningDenemeSubjectIdsProvider).
final worseningDenemeSubjectNamesProvider = Provider<Set<String>>((ref) {
  final all = ref.watch(denemeProvider);
  final sorted = List<DenemeEntry>.from(all)
    ..sort((a, b) => a.date.compareTo(b.date));
  final bySubject = <String, List<double>>{};
  for (final e in sorted) {
    for (final s in e.sections) {
      bySubject.putIfAbsent(s.subject, () => []).add(s.net);
    }
  }
  final result = <String>{};
  for (final entry in bySubject.entries) {
    final nets = entry.value;
    if (nets.length < 3) continue;
    final mid = nets.length ~/ 2;
    final firstHalfAvg =
        nets.sublist(0, mid).reduce((a, b) => a + b) / mid;
    final secondHalfAvg =
        nets.sublist(mid).reduce((a, b) => a + b) / (nets.length - mid);
    if (secondHalfAvg < firstHalfAvg - 1.0) result.add(entry.key);
  }
  return result;
});

/// [worseningDenemeSubjectNamesProvider]'ın adlarını gerçek [SubjectModel.id]
/// ile eşler — [weakestDenemeSubjectIdProvider] ile aynı isim-eşleme deseni.
final worseningDenemeSubjectIdsProvider = Provider<Set<String>>((ref) {
  final names = ref.watch(worseningDenemeSubjectNamesProvider);
  if (names.isEmpty) return const {};
  final subjects = ref.watch(subjectProvider);
  final result = <String>{};
  for (final s in subjects) {
    if (names.any((n) => n.toLowerCase() == s.name.toLowerCase())) {
      result.add(s.id);
    }
  }
  return result;
});

/// GERÇEK bir deneme sonucunda öğrencinin kendi işaretlediği yanlış-konular
/// (bkz. DenemeSectionScore.weakTopicIds, add_deneme_screen.dart) —
/// subjectId → {ad, id} listesi. Davranışsal (süre bazlı)
/// `difficultTopicNamesBySubjectProvider`'dan (task_provider.dart) TAMAMEN
/// AYRI bir sinyal: biri "bu konu beklenenden uzun sürdü" (davranış,
/// tahmin), bu ise "bu konudan GERÇEK bir sınavda yanlış yaptım" (akademik
/// sonuç, kanıt) — ikisi asla birleştirilmez.
///
/// Yalnız her dersin EN SON girilen bölümü sayılır (eskiden yeniye işlenir,
/// son yazan kazanır) — böylece öğrenci bir konuyu çalışıp yeni bir
/// denemede aynı konuyu artık yanlış işaretlemezse, o konu OTOMATİK olarak
/// bu listeden düşer. Ayrı bir "iyileşti" bayrağı gerekmez, takip sonucu
/// (follow-up result) kendiliğinden yansır.
final examWeakTopicsBySubjectProvider =
    Provider<Map<String, List<({String name, String id})>>>((ref) {
  final entries = List<DenemeEntry>.from(ref.watch(denemeProvider))
    ..sort((a, b) => a.date.compareTo(b.date));
  final subjects = ref.watch(subjectProvider);
  final topics = ref.watch(topicProvider);
  final topicById = {for (final t in topics) t.id: t};
  final subjectIdByName = {
    for (final s in subjects) s.name.toLowerCase(): s.id,
  };

  final latestWeakIds = <String, List<String>>{};
  for (final e in entries) {
    for (final section in e.sections) {
      final subjectId = subjectIdByName[section.subject.trim().toLowerCase()];
      if (subjectId == null) continue;
      latestWeakIds[subjectId] = section.weakTopicIds;
    }
  }

  final result = <String, List<({String name, String id})>>{};
  latestWeakIds.forEach((subjectId, topicIds) {
    final resolved = topicIds
        .map((id) => topicById[id])
        .whereType<TopicModel>()
        .map((t) => (name: t.name, id: t.id))
        .toList();
    if (resolved.isNotEmpty) result[subjectId] = resolved;
  });
  return result;
});

/// [examWeakTopicsBySubjectProvider]'ın yalnız ADLARI — StudyAdvisor'ın
/// gerekçe metni id'ye ihtiyaç duymaz (bkz. difficultTopicsBySubject ile
/// aynı şekil).
final examWeakTopicNamesBySubjectProvider =
    Provider<Map<String, List<String>>>((ref) {
  final withIds = ref.watch(examWeakTopicsBySubjectProvider);
  return withIds
      .map((key, value) => MapEntry(key, value.map((t) => t.name).toList()));
});

/// [examWeakTopicsBySubjectProvider]'ın düz konu-id kümesi — topic-seviyesi
/// rozet (bkz. topic_evidence_provider.dart) "bu konu id'si şu an GERÇEK bir
/// denemede zayıf mı" diye tek bir küme sorgular.
final currentWeakTopicIdSetProvider = Provider<Set<String>>((ref) {
  final bySubject = ref.watch(examWeakTopicsBySubjectProvider);
  return {
    for (final list in bySubject.values) for (final t in list) t.id,
  };
});

/// TEK KAYNAK (Faz 1 — topic evidence rozetleri) — subjectId → o dersin her
/// denemedeki weakTopicId kümesi, kronolojik. [resolvedWeakTopicIdsBySubject
/// Provider], [newlyWeakTopicIdsBySubjectProvider] VE bunların ad-bazlı
/// türevleri (aşağıda) hepsi BURADAN türer — aynı kıyas iki kez yazılmaz.
final _weakTopicIdSetsBySubjectProvider =
    Provider<Map<String, List<Set<String>>>>((ref) {
  final entries = List<DenemeEntry>.from(ref.watch(denemeProvider))
    ..sort((a, b) => a.date.compareTo(b.date));
  final subjects = ref.watch(subjectProvider);
  final subjectIdByName = {
    for (final s in subjects) s.name.toLowerCase(): s.id,
  };

  final bySubject = <String, List<Set<String>>>{};
  for (final e in entries) {
    for (final section in e.sections) {
      final subjectId = subjectIdByName[section.subject.trim().toLowerCase()];
      if (subjectId == null) continue;
      bySubject
          .putIfAbsent(subjectId, () => [])
          .add(section.weakTopicIds.toSet());
    }
  }
  return bySubject;
});

/// "İyileşme anı" (Faz 8) — bir dersin ÖNCEKİ denemede zayıf işaretli olup
/// SON denemede artık işaretli OLMADIĞI konu id'leri. En az 2 deneme verisi
/// olmayan dersler için boş küme.
final resolvedWeakTopicIdsBySubjectProvider =
    Provider<Map<String, Set<String>>>((ref) {
  final bySubject = ref.watch(_weakTopicIdSetsBySubjectProvider);
  final result = <String, Set<String>>{};
  bySubject.forEach((subjectId, weakSets) {
    if (weakSets.length < 2) return;
    final diff =
        weakSets[weakSets.length - 2].difference(weakSets.last);
    if (diff.isNotEmpty) result[subjectId] = diff;
  });
  return result;
});

/// [resolvedWeakTopicIdsBySubjectProvider]'ın AYNASI — bir dersin ÖNCEKİ
/// denemede zayıf işaretli OLMAYIP SON denemede yeni zayıf çıkan konu
/// id'leri.
final newlyWeakTopicIdsBySubjectProvider =
    Provider<Map<String, Set<String>>>((ref) {
  final bySubject = ref.watch(_weakTopicIdSetsBySubjectProvider);
  final result = <String, Set<String>>{};
  bySubject.forEach((subjectId, weakSets) {
    if (weakSets.length < 2) return;
    final diff =
        weakSets.last.difference(weakSets[weakSets.length - 2]);
    if (diff.isNotEmpty) result[subjectId] = diff;
  });
  return result;
});

/// Tüm derslerdeki resolved konu id'lerinin düz kümesi — topic-seviyesi
/// rozet (bkz. topic_evidence_provider.dart) hangi dersi taşıdığını bilmek
/// zorunda kalmadan "bu konu id'si iyileşti mi" diye tek bir küme sorgular.
final resolvedWeakTopicIdSetProvider = Provider<Set<String>>((ref) {
  final bySubject = ref.watch(resolvedWeakTopicIdsBySubjectProvider);
  return {for (final ids in bySubject.values) ...ids};
});

/// [resolvedWeakTopicIdSetProvider]'ın aynası — yeni zayıf konu id'leri.
final newlyWeakTopicIdSetProvider = Provider<Set<String>>((ref) {
  final bySubject = ref.watch(newlyWeakTopicIdsBySubjectProvider);
  return {for (final ids in bySubject.values) ...ids};
});

/// [resolvedWeakTopicIdsBySubjectProvider]'ın AD bazlı görünümü — Stats/Coach/
/// add_deneme_screen'in gösterdiği metin id'ye değil isme ihtiyaç duyar.
/// Aynı id kümesinden türer, ikinci bir kıyas YAPILMAZ.
final resolvedWeakTopicsBySubjectProvider =
    Provider<Map<String, List<String>>>((ref) {
  final byIds = ref.watch(resolvedWeakTopicIdsBySubjectProvider);
  final topicById = {for (final t in ref.watch(topicProvider)) t.id: t};
  final result = <String, List<String>>{};
  byIds.forEach((subjectId, ids) {
    final names =
        ids.map((id) => topicById[id]?.name).whereType<String>().toList();
    if (names.isNotEmpty) result[subjectId] = names;
  });
  return result;
});

/// [newlyWeakTopicIdsBySubjectProvider]'ın AD bazlı görünümü — bkz. yukarıdaki
/// aynı not.
final newlyWeakTopicsBySubjectProvider =
    Provider<Map<String, List<String>>>((ref) {
  final byIds = ref.watch(newlyWeakTopicIdsBySubjectProvider);
  final topicById = {for (final t in ref.watch(topicProvider)) t.id: t};
  final result = <String, List<String>>{};
  byIds.forEach((subjectId, ids) {
    final names =
        ids.map((id) => topicById[id]?.name).whereType<String>().toList();
    if (names.isNotEmpty) result[subjectId] = names;
  });
  return result;
});

/// [weakestDenemeSubjectNameProvider]'ın adını kullanıcının kendi ders
/// listesindeki gerçek bir [SubjectModel.id]'sine eşler (büyük/küçük harf
/// duyarsız, "Türkçe" ≠ "Türk Dili ve Edebiyatı" gibi tam eşleşmeyenler
/// eşlenmez — yanlış derse öneri gitmesin). Eşleşme yoksa null.
final weakestDenemeSubjectIdProvider = Provider<String?>((ref) {
  final name = ref.watch(weakestDenemeSubjectNameProvider);
  if (name == null) return null;
  final subjects = ref.watch(subjectProvider);
  for (final s in subjects) {
    if (s.name.toLowerCase() == name.toLowerCase()) return s.id;
  }
  return null;
});
