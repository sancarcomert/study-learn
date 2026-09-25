import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/nlu/nlu_modifier.dart';

typedef T = NluModifierType;
typedef A = NluAmount;

void main() {
  explicitReferenceTests();
  NluModifier? parse(String s) => NluModifierParser.parse(s);

  void expectMod(String text, T type, {A? amount, int? minutes, bool? abs}) {
    final m = parse(text);
    expect(m, isNotNull, reason: '"$text" modifier olmalıydı');
    expect(m!.type, type, reason: '"$text" → $m');
    if (amount != null) expect(m.amount, amount, reason: '"$text" → $m');
    if (minutes != null) expect(m.minutes, minutes, reason: '"$text" → $m');
    if (abs != null) expect(m.absolute, abs, reason: '"$text" → $m');
  }

  group('yoğunluk (kullanıcının örnek cümleleri)', () {
    test('ağırlaştırma', () {
      expectMod('biraz ağır yap', T.intensityUp, amount: A.small);
      expectMod('biraz ağır olsun', T.intensityUp, amount: A.small);
      expectMod('ağırlaştır', T.intensityUp);
      expectMod('daha yoğun yap', T.intensityUp);
      expectMod('yoğunlaştır', T.intensityUp);
      expectMod('bugünü sıkıştır', T.intensityUp);
      expectMod('biraz daha zor olsun', T.harder, amount: A.small);
    });

    test('hafifletme', () {
      expectMod('çok ağır olmuş', T.intensityDown, amount: A.large);
      expectMod('bunu çok ağır yapmışsın', T.intensityDown, amount: A.large);
      expectMod('bu fazla geldi', T.intensityDown);
      expectMod('biraz hafiflet', T.intensityDown, amount: A.small);
      expectMod('planı biraz hafiflet', T.intensityDown, amount: A.small);
      expectMod('daha hafif olsun', T.intensityDown);
      expectMod('biraz daha kolay olsun', T.easier, amount: A.small);
      expectMod('daha kolay bir şey koy', T.easier);
      expectMod('çok fazla oldu', T.intensityDown, amount: A.large);
    });

    test('yazım/ek varyasyonları', () {
      for (final s in [
        'artır',
        'arttır',
        'biraz artır',
        'biraz arttır',
        'artırsana',
        'çoğalt',
        'yükselt',
        'artir'
      ]) {
        expectMod(s, T.increase);
      }
      for (final s in [
        'azalt',
        'düşür',
        'biraz azalt',
        'azaltsana',
        'azalt bunu'
      ]) {
        expectMod(s, T.decrease);
      }
      expectMod('biraz artır', T.increase, amount: A.small);
      expectMod('çok azalt', T.decrease, amount: A.large);
    });

    test('daha fazla / daha az kalıpları', () {
      expectMod('daha fazla yap', T.increase);
      expectMod('biraz daha fazla olsun', T.increase, amount: A.small);
      expectMod('daha fazla çalışayım', T.increase);
      expectMod('biraz daha çalışayım', T.increase, amount: A.small);
      expectMod('biraz daha ekle', T.increase, amount: A.small);
      expectMod('daha az olsun', T.decrease);
    });
  });

  group('sayısal değişiklik', () {
    test('fark', () {
      expectMod('1 saat daha ekle', T.extend, minutes: 60, abs: false);
      expectMod('30 dakika azalt', T.shorten, minutes: 30, abs: false);
      expectMod('yarım saat kısalt', T.shorten, minutes: 30);
      expectMod('45 dk daha fazla olsun', T.extend, minutes: 45);
    });
    test('hedef', () {
      expectMod('2 saat yerine 3 saat yap', T.replace, minutes: 180, abs: true);
      expect(parse('2 saat yerine 3 saat yap')!.fromMinutes, 120);
      expectMod('bugün 45 dakika olsun', T.replace, minutes: 45, abs: true);
      expectMod('3 saat yap', T.replace, minutes: 180, abs: true);
    });
    test('apply: hedef > fark > oransal adım', () {
      expect(parse('2 saat yerine 3 saat yap')!.apply(120), 180);
      expect(parse('1 saat daha ekle')!.apply(60), 120);
      expect(parse('30 dakika azalt')!.apply(90), 60);
      // oransal: küçük %20 (≥10), orta %35 (≥15), büyük %50 (≥30)
      expect(parse('biraz artır')!.apply(60), 70);
      expect(parse('artır')!.apply(60), 80);
      expect(parse('çok artır')!.apply(60), 90);
      expect(parse('biraz hafiflet')!.apply(60), 50);
      expect(parse('çok ağır olmuş')!.apply(60), 30);
      expect(parse('biraz artır')!.apply(15), 25); // küçük adım tabanı 10
    });
  });

  group('kaldırma / değiştirme', () {
    test('remove', () {
      expectMod('şunu çıkar', T.remove);
      expectMod('bunu çıkar', T.remove);
      final m = parse('fizik çıkar')!;
      expect(m.type, T.remove);
      expect(m.targetSubjectName, 'Fizik');
      expect(m.apply(60), isNull);
    });
  });

  group('modifier OLMAYAN cümleler', () {
    test('kişisel zorlanma / hedef beyanı / yeni istek', () {
      for (final s in [
        'Matematik ağır geliyor',
        'fizik çok zor geliyor',
        'matematik zor',
        'ağır geliyor',
        'netlerimi artırmak istiyorum',
        'motivasyonumu artır',
        'netlerimi artır',
        'bugün için plan yap',
        'bana bir plan çıkar',
        'nereden başlayayım',
        'bugün ne çalışayım',
        'bugün sadece 30 dakikam var',
        'yarın 2 saat matematik çalışacağım',
        'matematikte zorlanıyorum',
        'çok fazla konu var',
        'ekle',
        'tamam',
        'asdfgh',
        '',
        'ağır bir hafta geçirdim',
      ]) {
        expect(parse(s), isNull, reason: '"$s" → ${parse(s)}');
      }
    });
  });
}

void explicitReferenceTests() {
  group('açık referans ("az önceki planı …")', () {
    test('işaretlenir; plan-isteği koruması atlanır', () {
      final m = NluModifierParser.parse('az önceki planı biraz artır')!;
      expect(m.type, NluModifierType.increase);
      expect(m.amount, NluAmount.small);
      expect(m.explicitReference, isTrue);

      final h = NluModifierParser.parse('o planı biraz hafiflet')!;
      expect(h.type, NluModifierType.intensityDown);
      expect(h.explicitReference, isTrue);

      final s = NluModifierParser.parse('son planı 2 saat yap')!;
      expect(s.absolute, isTrue);
      expect(s.minutes, 120);
      expect(s.explicitReference, isTrue);
    });

    test('referanssız cümle işaretlenmez; "daha ağır" karşılaştırması çalışır',
        () {
      expect(
          NluModifierParser.parse('biraz artır')!.explicitReference, isFalse);
      final d = NluModifierParser.parse('biraz daha ağır')!;
      expect(d.type, NluModifierType.intensityUp);
      expect(d.amount, NluAmount.small);
      // Yeni plan isteği hâlâ düzeltme DEĞİL.
      expect(NluModifierParser.parse('yarın için 2 saatlik plan yap'), isNull);
    });
  });
}
