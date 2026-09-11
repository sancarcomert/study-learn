import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/plan_parser.dart';
import 'package:study_planner/subject_model.dart';

SubjectModel _sub(String name) => SubjectModel(
      id: 'id-$name',
      name: name,
      colorValue: 0,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  // Sabit referans: 2026-09-10 Perşembe.
  final now = DateTime(2026, 9, 10, 14, 0);
  final subjects = [_sub('Matematik'), _sub('Fizik'), _sub('Paragraf')];

  group('süre', () {
    test('"2 saat" → 120 dk', () {
      final p = PlanParser.parse('2 saat matematik', subjects: subjects, now: now);
      expect(p.durationMinutes, 120);
    });

    test('"45 dk" → 45', () {
      final p = PlanParser.parse('45 dk paragraf', subjects: subjects, now: now);
      expect(p.durationMinutes, 45);
    });

    test('"1.5 saat" → 90', () {
      final p = PlanParser.parse('1.5 saat fizik', subjects: subjects, now: now);
      expect(p.durationMinutes, 90);
    });

    test('"yarım saat" → 30', () {
      final p =
          PlanParser.parse('yarım saat türev', subjects: subjects, now: now);
      expect(p.durationMinutes, 30);
    });

    test('"bir buçuk saat" → 90', () {
      final p = PlanParser.parse('bir buçuk saat kimya',
          subjects: subjects, now: now);
      expect(p.durationMinutes, 90);
    });
  });

  group('tarih', () {
    test('"yarın" → +1 gün', () {
      final p = PlanParser.parse('yarın matematik', subjects: subjects, now: now);
      expect(p.date, DateTime(2026, 9, 11));
    });

    test('"bugün" → aynı gün', () {
      final p = PlanParser.parse('bugün fizik', subjects: subjects, now: now);
      expect(p.date, DateTime(2026, 9, 10));
    });

    test('"öbür gün" → +2 gün', () {
      final p =
          PlanParser.parse('öbür gün paragraf', subjects: subjects, now: now);
      expect(p.date, DateTime(2026, 9, 12));
    });

    test('"3 gün sonra" → +3 gün', () {
      final p = PlanParser.parse('3 gün sonra deneme',
          subjects: subjects, now: now);
      expect(p.date, DateTime(2026, 9, 13));
    });

    test('"pazartesi" → bir sonraki pazartesi (bugün perşembe)', () {
      final p =
          PlanParser.parse('pazartesi matematik', subjects: subjects, now: now);
      expect(p.date, DateTime(2026, 9, 14));
    });

    test('haftanın aynı günü → +7 (bugün değil)', () {
      final p =
          PlanParser.parse('perşembe fizik', subjects: subjects, now: now);
      expect(p.date, DateTime(2026, 9, 17));
    });

    test('"cumartesi" "cuma" içinde geçse de doğru gün', () {
      final p =
          PlanParser.parse('cumartesi tekrar', subjects: subjects, now: now);
      expect(p.date, DateTime(2026, 9, 12));
    });
  });

  group('saat', () {
    test('"15:30" → 15:30', () {
      final p = PlanParser.parse('yarın 15:30 matematik',
          subjects: subjects, now: now);
      expect(p.hour, 15);
      expect(p.minute, 30);
    });

    test('"saat 3" → 15:00 (çalışma bağlamı öğleden sonra)', () {
      final p =
          PlanParser.parse('saat 3 fizik', subjects: subjects, now: now);
      expect(p.hour, 15);
      expect(p.minute, 0);
    });

    test('"sabah 9" ipucu → 09:00', () {
      final p = PlanParser.parse('sabah 9 tekrar', subjects: subjects, now: now);
      expect(p.hour, 9);
    });

    test('"akşam 8" → 20:00', () {
      final p =
          PlanParser.parse('akşam 8 paragraf', subjects: subjects, now: now);
      expect(p.hour, 20);
    });

    test('"akşam 1 saat" → saat değil, süre (60 dk), gün-bölümü 19:00', () {
      final p = PlanParser.parse('akşam 1 saat matematik',
          subjects: subjects, now: now);
      expect(p.durationMinutes, 60);
      expect(p.hour, 19);
    });

    test('"3 saat 15 dk" saat sanılmaz (süre yakalanır)', () {
      final p = PlanParser.parse('3 saat 15 dk matematik',
          subjects: subjects, now: now);
      expect(p.hour, isNull);
      expect(p.durationMinutes, 180);
    });

    test('"1.5 saat" saat sanılmaz', () {
      final p =
          PlanParser.parse('1.5 saat fizik', subjects: subjects, now: now);
      expect(p.hour, isNull);
      expect(p.durationMinutes, 90);
    });
  });

  group('tekrar', () {
    test('"her gün" → daily', () {
      final p = PlanParser.parse('her gün 20 dk kelime',
          subjects: subjects, now: now);
      expect(p.recurrence, 'daily');
      expect(p.durationMinutes, 20);
    });

    test('"her hafta" → weekly', () {
      final p = PlanParser.parse('her hafta deneme çöz',
          subjects: subjects, now: now);
      expect(p.recurrence, 'weekly');
    });

    test('"her pazartesi" → weekly + o güne tarih', () {
      final p = PlanParser.parse('her pazartesi paragraf',
          subjects: subjects, now: now);
      expect(p.recurrence, 'weekly');
      expect(p.date, DateTime(2026, 9, 14));
    });
  });

  group('ders', () {
    test('kullanıcının ders adı birebir eşleşir', () {
      final p = PlanParser.parse('fizik dalga konusu',
          subjects: subjects, now: now);
      expect(p.subjectId, 'id-Fizik');
      expect(p.subjectName, 'Fizik');
    });

    test('anahtar kelimeyle tahmin (türev → Matematik)', () {
      final p = PlanParser.parse('yarın türev çalışacağım',
          subjects: subjects, now: now);
      expect(p.subjectId, 'id-Matematik');
    });

    test('tahmin edilen ders kullanıcıda yoksa sadece ad taşınır', () {
      final p = PlanParser.parse('fotosentez tekrarı',
          subjects: subjects, now: now);
      expect(p.subjectId, isNull);
      expect(p.subjectName, 'Biyoloji');
    });
  });

  group('başlık temizliği', () {
    test('tarih/süre/filler çıkarılır', () {
      final p = PlanParser.parse('yarın 2 saat matematik türev çalışacağım',
          subjects: subjects, now: now);
      expect(p.title.toLowerCase(), contains('türev'));
      expect(p.title.toLowerCase(), isNot(contains('yarın')));
      expect(p.title.toLowerCase(), isNot(contains('saat')));
      expect(p.title.toLowerCase(), isNot(contains('çalışacağım')));
    });

    test('geriye içerik kalmazsa ders adına düşer', () {
      final p =
          PlanParser.parse('yarın 1 saat matematik', subjects: subjects, now: now);
      expect(p.title, 'Matematik');
    });

    test('girdinin tamamı sinyalse başlık boş (ham metne düşmez)', () {
      // "2 saat yarın" tamamen süre + tarih — ortada başlık yok.
      final p =
          PlanParser.parse('2 saat yarın', subjects: subjects, now: now);
      expect(p.durationMinutes, 120);
      expect(p.title, isEmpty);
    });

    test('konuşma dili fillerları çıkarılır', () {
      final p = PlanParser.parse(
          'matematik türev çalışmak istiyorum programa ekle',
          subjects: subjects,
          now: now);
      expect(p.subjectName, 'Matematik');
      expect(p.title.toLowerCase(), contains('türev'));
      expect(p.title.toLowerCase(), isNot(contains('istiyorum')));
      expect(p.title.toLowerCase(), isNot(contains('programa')));
    });
  });

  group('bu akşam / bu sabah → bugün', () {
    test('"bu akşam" → aynı gün', () {
      final p =
          PlanParser.parse('bu akşam fizik', subjects: subjects, now: now);
      final today = DateTime(now.year, now.month, now.day);
      expect(p.date, today);
    });

    test('"bu sabah 1 saat" → bugün + süre, saat değil', () {
      final p = PlanParser.parse('bu sabah 1 saat kimya',
          subjects: subjects, now: now);
      expect(p.date, DateTime(now.year, now.month, now.day));
      expect(p.durationMinutes, 60);
    });
  });

  group('boş / sinyalsiz', () {
    test('boş girdi', () {
      final p = PlanParser.parse('   ', subjects: subjects, now: now);
      expect(p.hasSignal, isFalse);
    });

    test('sadece düz metin → sinyal yok, başlık korunur', () {
      final p = PlanParser.parse('deneme sınavı analizi',
          subjects: subjects, now: now);
      expect(p.hasSignal, isFalse);
      expect(p.title, 'deneme sınavı analizi');
    });
  });

  group('canlı vurgulama (spans)', () {
    test('tarih + süre + ders ayrı span olarak işaretlenir', () {
      final p = PlanParser.parse('yarın 2 saat matematik',
          subjects: subjects, now: now);
      expect(p.spans, hasLength(3));
      expect(p.spans[0].kind, PlanSpanKind.date);
      expect(p.spans[0].start, 0);
      expect(p.spans[0].end, 5);
      expect(p.spans[1].kind, PlanSpanKind.duration);
      expect(p.spans[2].kind, PlanSpanKind.subject);
      expect(p.spans[2].start, 13);
      expect(p.spans[2].end, 22);
    });

    test('büyük/küçük harf farkı span konumunu bozmaz', () {
      const input = 'Yarın Matematik çalışacağım';
      final p = PlanParser.parse(input, subjects: subjects, now: now);
      final dateSpan =
          p.spans.firstWhere((s) => s.kind == PlanSpanKind.date);
      expect(
        input.substring(dateSpan.start, dateSpan.end).toLowerCase(),
        'yarın',
      );
    });

    test('sinyalsiz girdide span yok', () {
      final p = PlanParser.parse('deneme sınavı analizi',
          subjects: subjects, now: now);
      expect(p.spans, isEmpty);
    });
  });
}
