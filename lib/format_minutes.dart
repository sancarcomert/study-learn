/// Dakikayı kısa, okunur metne çevirir: "45 dk", "2 sa", "1 sa 15 dk".
/// Stats, Plan ve Home aynı biçimi kullansın diye tek yerde (önceden iki ayrı
/// kopya vardı).
String formatMinutes(int minutes) {
  if (minutes <= 0) return '0 dk';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m dk';
  if (m == 0) return '$h sa';
  return '$h sa $m dk';
}
