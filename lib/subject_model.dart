import 'package:hive/hive.dart';

part 'subject_model.g.dart';

@HiveType(typeId: 0)
class SubjectModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int colorValue;

  @HiveField(3)
  DateTime createdAt;

  SubjectModel({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.createdAt,
  });
}