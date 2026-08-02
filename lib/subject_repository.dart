import 'hive_boxes.dart';
import 'subject_model.dart';

class SubjectRepository {
  List<SubjectModel> getAllSubjects() {
    return HiveBoxes.subjects.values.toList();
  }

  Future<void> addSubject(SubjectModel subject) async {
    // Hive'da her kayıt bir "key" (anahtar) ile saklanır, biz subject'in
    // kendi id'sini key olarak kullanıyoruz - böylece kolayca bulup silebiliriz.
    await HiveBoxes.subjects.put(subject.id, subject);
  }

  Future<void> deleteSubject(String id) async {
    await HiveBoxes.subjects.delete(id);
  }
}