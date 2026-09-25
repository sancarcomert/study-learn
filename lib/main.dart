import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'backup_service.dart';
import 'hive_boxes.dart';
import 'notification_service.dart';
import 'widget_service.dart';

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

  // Günde bir kez cihaza sessiz yerel yedek (best-effort — açılışı bloke
  // etmez, hata durumunda hiçbir şey yapmaz). docs/rakip_analizi §6 A1.
  unawaited(BackupService.writeDailySnapshot());

  // Ana ekran widget'ını güncel tut (best-effort). docs/rakip_analizi §6 B1.
  unawaited(WidgetService.sync());

  // Bildirim kurulumu başarısız olsa bile uygulama AÇILMALI (yalnız hatırlatma
  // çalışmaz) — bu satır önceden korumasızdı, bir platform hatası beyaz ekran
  // demekti.
  try {
    await NotificationService.instance.initialize();
  } catch (e, st) {
    debugPrint('Bildirim kurulumu başarısız (devam ediliyor): $e\n$st');
  }
  await initializeDateFormatting('tr_TR', null);
  runApp(
    const ProviderScope(
      child: StudyPlannerApp(),
    ),
  );
}