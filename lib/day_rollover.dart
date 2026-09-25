import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Takvim günü değiştiğinde (gece yarısı geçildi ya da uygulama ertesi gün
/// öne geldi) artar. "Bugün" / "bu hafta" gibi saate bağlı türetilmiş
/// provider'lar bunu izler ve kendiliğinden yeniden hesaplanır — aksi halde
/// uygulama bellekte açık kaldıkça dünün görevleri "bugün" görünürdü.
final dayRolloverProvider = StateProvider<int>((ref) => 0);
