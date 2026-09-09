import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'hive_boxes.dart';
import 'notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fontlar (Lora + Plus Jakarta Sans) uygulamaya asset olarak gömülü.
  // Çalışma anında fonts.gstatic.com'dan indirmeyi tamamen kapatıyoruz —
  // internet yokken google_fonts'un fırlattığı unhandled exception'lar
  // arayüzü (özellikle dialog dokunuşlarını) bozuyordu.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      const ['google_fonts', 'Lora'],
      await rootBundle.loadString('assets/fonts/OFL-Lora.txt'),
    );
    yield LicenseEntryWithLineBreaks(
      const ['google_fonts', 'Plus Jakarta Sans'],
      await rootBundle.loadString('assets/fonts/OFL-PlusJakartaSans.txt'),
    );
  });

  await HiveBoxes.init();
  await NotificationService.instance.initialize();
  await initializeDateFormatting('tr_TR', null);
  runApp(
    const ProviderScope(
      child: StudyPlannerApp(),
    ),
  );
}