import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'hive_boxes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveBoxes.init();
  await initializeDateFormatting('tr_TR', null); // Türkçe ay/gün isimleri için
  runApp(const StudyPlannerApp());
}