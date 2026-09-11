import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/deneme_model.dart';

/// P0-9 — deneme/net takibi. Soru bankası YOK, yalnızca skor.
void main() {
  group('DenemeSectionScore.net', () {
    test('ÖSYM formülü: doğru - yanlış/4', () {
      final s = DenemeSectionScore(subject: 'Matematik', correct: 30, wrong: 8);
      expect(s.net, closeTo(28.0, 0.001)); // 30 - 8/4 = 28
    });

    test('boş net etkilemez', () {
      final s =
          DenemeSectionScore(subject: 'Türkçe', correct: 20, wrong: 4, blank: 16);
      expect(s.net, closeTo(19.0, 0.001)); // 20 - 4/4 = 19
      expect(s.total, 40);
    });

    test('hepsi boş → net 0', () {
      final s = DenemeSectionScore(subject: 'Fen Bilimleri', blank: 20);
      expect(s.net, 0);
      expect(s.total, 20);
    });

    test('yanlış 4\'ün katı değilse ondalıklı net', () {
      final s = DenemeSectionScore(subject: 'Sosyal Bilimler', correct: 10, wrong: 3);
      expect(s.net, closeTo(9.25, 0.001)); // 10 - 3/4 = 9.25
    });
  });

  group('DenemeEntry toplamları', () {
    test('bölümlerin net toplamı', () {
      final e = DenemeEntry(
        id: '1',
        examType: 'TYT',
        date: DateTime(2026, 9, 1),
        sections: [
          DenemeSectionScore(subject: 'Türkçe', correct: 35, wrong: 4, blank: 1),
          DenemeSectionScore(
              subject: 'Sosyal Bilimler', correct: 15, wrong: 3, blank: 2),
          DenemeSectionScore(subject: 'Matematik', correct: 25, wrong: 8, blank: 7),
          DenemeSectionScore(
              subject: 'Fen Bilimleri', correct: 12, wrong: 4, blank: 4),
        ],
      );
      // 35-1 + 15-0.75 + 25-2 + 12-1 = 34 + 14.25 + 23 + 11 = 82.25
      expect(e.totalNet, closeTo(82.25, 0.001));
      expect(e.totalCorrect, 87);
      expect(e.totalWrong, 19);
      expect(e.totalBlank, 14);
      expect(e.totalQuestions, 120); // TYT toplam soru sayısı
    });

    test('bölüm yoksa toplamlar 0', () {
      final e = DenemeEntry(
        id: '2',
        examType: 'AYT',
        date: DateTime(2026, 9, 1),
        sections: const [],
      );
      expect(e.totalNet, 0);
      expect(e.totalQuestions, 0);
    });

    test('isim boşsa null muamelesi görür (ekranın kendi mantığı) ama '
        'model isim verildiği gibi tutar', () {
      final e = DenemeEntry(
        id: '3',
        examType: 'TYT',
        name: '3D Yayınları Deneme 5',
        date: DateTime(2026, 9, 10),
        sections: [DenemeSectionScore(subject: 'Türkçe', correct: 40)],
      );
      expect(e.name, '3D Yayınları Deneme 5');
      expect(e.totalNet, 40);
    });
  });
}
