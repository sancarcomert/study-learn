import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'subject_model.dart';
import 'subject_repository.dart';

const _uuid = Uuid();

// Repository'e her yerden aynı şekilde erişebilmek için bir provider
final subjectRepositoryProvider = Provider<SubjectRepository>((ref) {
  return SubjectRepository();
});

// Ekranların "izleyeceği" asıl veri: ders listesi
class SubjectNotifier extends StateNotifier<List<SubjectModel>> {
  final SubjectRepository _repository;

  // Başlangıçta Hive'da zaten kayıtlı dersleri yüklüyoruz
  SubjectNotifier(this._repository) : super(_repository.getAllSubjects());

  void addSubject(String name, int colorValue) {
    final newSubject = SubjectModel(
      id: _uuid.v4(),
      name: name,
      colorValue: colorValue,
      createdAt: DateTime.now(),
    );
    _repository.addSubject(newSubject);

    // state'i yeniden atamak, bunu izleyen TÜM ekranların otomatik
    // yenilenmesini sağlar - Riverpod'un sihri burada.
    state = _repository.getAllSubjects();
  }

  void deleteSubject(String id) {
    _repository.deleteSubject(id);
    state = _repository.getAllSubjects();
  }
}

final subjectProvider =
    StateNotifierProvider<SubjectNotifier, List<SubjectModel>>((ref) {
  final repository = ref.watch(subjectRepositoryProvider);
  return SubjectNotifier(repository);
});