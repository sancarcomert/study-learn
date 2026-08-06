import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'hive_boxes.dart';
import 'notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveBoxes.init();
  await NotificationService.instance.initialize();
  await initializeDateFormatting('tr_TR', null);
  runApp(
    const ProviderScope(
      child: StudyPlannerApp(),
    ),
  );
}