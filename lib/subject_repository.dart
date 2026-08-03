import 'hive_boxes.dart';
import 'subject_model.dart';

class SubjectRepository {
 List<SubjectModel> getAllSubjects() {
  final list = HiveBoxes.subjects.values.toList();

  print("HIVE SUBJECT SAYISI: ${list.length}");
  print("HIVE SUBJECTLAR: ${list.map((e) => e.name).toList()}");

  return list;
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