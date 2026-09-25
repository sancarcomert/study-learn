import 'nlu_entities.dart';
import 'nlu_phrase_matcher.dart';
import 'nlu_slots.dart';

/// "Biraz ağır yap", "artır", "1 saat daha ekle", "2 saat yerine 3 saat yap"
/// gibi ÖNCEKİ plana/öneriye referans veren kısa düzeltme cümleleri.
///
/// Bu katman yalnız "mevcut plan üzerinde şu değişiklik istendi" der; planı
/// kendisi üretmez — Coach mevcut PlanBuilder/NLU cevabını yeni süreyle yeniden
/// çalıştırır. Cümlenin neye referans verdiğine (plan var mı?) Coach karar verir.
enum NluModifierType {
  increase,
  decrease,
  replace,
  remove,
  extend,
  shorten,
  easier,
  harder,
  intensityUp,
  intensityDown,
}

enum NluAmount { small, medium, large, explicit }

class NluModifier {
  final NluModifierType type;
  final NluAmount amount;

  /// Açık sayı (dakika): [absolute] ise HEDEF süre ("3 saat yap" → 180),
  /// değilse fark büyüklüğü ("1 saat daha ekle" → 60). Yoksa null.
  final int? minutes;
  final bool absolute;

  /// "2 saat YERİNE 3 saat" cümlesindeki eski süre.
  final int? fromMinutes;

  /// Kaldırılacak/değiştirilecek şey anıldıysa (ör. "fizik çıkar") ders adı.
  final String? targetSubjectName;
  final String? targetSubjectId;

  /// "az önceki planı", "o planı", "son planı" — bağlam bayat olsa bile ona
  /// açıkça referans var.
  final bool explicitReference;

  /// Cümlede başka içerik yok ("artır", "azalt") — referans yoksa açıklama iste.
  final bool isBare;

  const NluModifier({
    required this.type,
    required this.amount,
    this.minutes,
    this.absolute = false,
    this.fromMinutes,
    this.targetSubjectName,
    this.targetSubjectId,
    this.isBare = false,
    this.explicitReference = false,
  });

  /// Süreyi büyütür mü (+), küçültür mü (−)? Kaldırma/değiştirme yönsüzdür.
  int get direction => switch (type) {
        NluModifierType.increase ||
        NluModifierType.extend ||
        NluModifierType.harder ||
        NluModifierType.intensityUp =>
          1,
        NluModifierType.decrease ||
        NluModifierType.shorten ||
        NluModifierType.easier ||
        NluModifierType.intensityDown =>
          -1,
        _ => 0,
      };

  /// Yeni süre: açık hedef > açık fark > oransal adım. Yönsüz düzeltmede null.
  int? apply(int current) {
    if (absolute && minutes != null) return minutes;
    final dir = direction;
    if (dir == 0) return null;
    final step = minutes ?? relativeStep(current, amount);
    return current + dir * step;
  }

  /// Küçük/orta/büyük adım: mevcut sürenin ~%20/35/50'si, 5 dk'ya yuvarlı.
  static int relativeStep(int current, NluAmount amount) {
    final (ratio, floor) = switch (amount) {
      NluAmount.small => (0.20, 10),
      NluAmount.large => (0.50, 30),
      _ => (0.35, 15),
    };
    final raw = (current * ratio / 5).round() * 5;
    return raw < floor ? floor : raw;
  }

  @override
  String toString() => 'Modifier(${type.name}/${amount.name}, minutes: $minutes'
      '${absolute ? ' abs' : ''}${fromMinutes != null ? ', from $fromMinutes' : ''}'
      '${targetSubjectName != null ? ', $targetSubjectName' : ''}'
      '${isBare ? ', bare' : ''})';
}

class NluModifierParser {
  const NluModifierParser._();

  static final _planWord = RegExp(
      r'\b(plan|program|gorev|bugun|gunu|gun|liste|yuk|calisma|gunluk|haftalik)\w*');
  static final _deictic = RegExp(r'\b(bu|bunu|su|sunu|onu|o)\b');

  // --- Hedef/istek cümlesi dışlamaları --------------------------------
  static final _explicitRef = RegExp(
      r'\b(?:az once\w*|onceki|son|yaptigin|hazirladigin|onerdigin|verdigin|o|su)\s+(?:\w+\s+)?(?:plan|program|oneri)\w*');

  static final _struggleGel = RegExp(r'\bgel(?:iyor|iyo|ir|mez|miyor)\b');
  static final _infinitive = RegExp(
      r'(?:art(?:t)?ir|azalt|dusur|kisalt|uzat|yukselt)(?:ma|mak|mam|maya|iyor)|artiram|azaltam');
  static final _goalObject = RegExp(
      r'\b(?:net|puan|motivasyon|hiz|verim|konsantrasyon|basari|odak)\w*\s+(?:\w+\s+)?(?:art(?:t)?ir|yukselt|dusur|azalt)');

  // --- Fiil kökleri -----------------------------------------------------
  static final _vIncrease =
      RegExp(r'\b(?:art(?:t)?ir(?!ma)|cogalt|yukselt)\w*');
  static final _vExtend = RegExp(r'\buzat(?!ma)\w*|\bgenislet\w*');
  static final _vIntUp =
      RegExp(r'\b(?:yogunlastir|agirlastir|sikistir|siklastir)\w*');
  static final _vHarder = RegExp(r'\bzorlastir\w*');
  static final _vDecrease = RegExp(r'\b(?:azalt(?!ma)|dusur(?!me)|eksilt)\w*');
  static final _vShorten = RegExp(r'\bkisalt\w*');
  static final _vIntDown = RegExp(r'\bhafiflet\w*');
  static final _vEasier = RegExp(r'\bkolaylastir\w*');
  static final _vRemove = RegExp(r'\b(?:cikar|kaldir|sil)(?!ma)\w*');

  static final _imperative = RegExp(
      r'\b(?:yap|yapsana|yapalim|yapar misin|olsun|olsa|et|koy|ver|olur mu|yeter)\b');
  static final _evaluative = RegExp(
      r'\b(?:olmus|olmussun|olmuş|oldu|geldi|gelmis|yapmissin|yapmis|cikmis|kalmis)\b');

  static final _small =
      RegExp(r'\b(?:biraz|birazcik|azicik|azcik|hafifce|bi tik)\b');
  static final _large =
      RegExp(r'\b(?:cok|epey|iyice|bayagi|fazlasiyla|oldukca)\b');

  /// Bir modifier ise onu, değilse null döndürür. Cümlenin bir plana referans
  /// verip vermediğine BURADA karar verilmez (Coach'un işi).
  static NluModifier? parse(String raw, {NluEntityIndex? index}) {
    final p = NluPrepared.of(raw, index ?? NluEntityIndex.fixed);
    final f = p.folded;
    if (f.isEmpty) return null;
    final explicitRef = _explicitRef.hasMatch(f);

    // "matematik ağır geliyor" — öğrencinin kendi zorlanması, düzeltme değil.
    if (_struggleGel.hasMatch(f)) return null;
    // "Bana bugün için 1 saatlik plan yap" — YENİ bir plan isteği (plan adı +
    // yapma fiili); düzeltme değil, plan akışı devralır.
    if (!explicitRef &&
        RegExp(r'\b(?:plan|program|takvim)\w*').hasMatch(f) &&
        RegExp(r'\b(?:yap|yapar|yapsana|kur|hazirla|olustur|cikar|ayarla|planla)\w*')
            .hasMatch(f)) {
      return null;
    }
    // "netlerimi artırmak istiyorum" — hedef beyanı.
    if (_infinitive.hasMatch(f) || _goalObject.hasMatch(f)) return null;

    final subject = p.entities.subject;
    final topic = p.entities.topic;
    final hasSubject = subject != null || topic != null;
    final hasPlanWord = _planWord.hasMatch(f);
    final contentTokens =
        p.contentTokens.where((t) => !t.startsWith('_') || hasSubject).length;

    NluModifier make(
      NluModifierType type, {
      NluAmount? amount,
      int? minutes,
      bool absolute = false,
      int? from,
      bool subjectTarget = false,
    }) {
      final amt = minutes != null && !absolute
          ? NluAmount.explicit
          : (amount ?? _amountOf(f));
      return NluModifier(
        type: type,
        amount: amt,
        minutes: minutes,
        absolute: absolute,
        fromMinutes: from,
        targetSubjectName:
            subjectTarget ? (subject?.name ?? topic?.subjectName) : null,
        targetSubjectId:
            subjectTarget ? (subject?.id ?? topic?.subjectId) : null,
        isBare: contentTokens <= 2 && !hasPlanWord,
        explicitReference: explicitRef,
      );
    }

    final numeric = NluSlotExtractor.minutes(raw);

    // 1) "2 saat yerine 3 saat yap"
    final yerine = RegExp(r'^(.*)\byerine\b(.*)$').firstMatch(f);
    if (yerine != null) {
      final left = NluSlotExtractor.minutes(yerine[1]!);
      final right = NluSlotExtractor.minutes(yerine[2]!);
      if (right != null) {
        return make(NluModifierType.replace,
            minutes: right, absolute: true, from: left);
      }
      return hasSubject && !hasPlanWord ? null : make(NluModifierType.replace);
    }

    // Ders/konu anılıyor ve plana dair bir söz yok: modifier değil
    // ("matematiğe 1 saat ver" yeni bir istek). Yalnız "fizik çıkar" istisna.
    final removeVerb = _vRemove.hasMatch(f) &&
        !RegExp(r'\b(?:plan|program)\w*\s+cikar').hasMatch(f);

    // 2) Kaldırma: "şunu çıkar", "fizik çıkar" (süre yoksa)
    if (removeVerb && numeric == null) {
      if (hasSubject || _deictic.hasMatch(f)) {
        return make(NluModifierType.remove, subjectTarget: true);
      }
      return null;
    }

    if (hasSubject && !hasPlanWord) return null;

    // 3) Açık sayı: fark ("1 saat daha ekle", "30 dakika azalt")
    final wantsMore = RegExp(
            r'\bdaha (?:ekle|fazla|cok)\b|\bilave\b|\bekstra\b|\bekle\b|\bartir\w*|\buzat\w*|\bfazla\b')
        .hasMatch(f);
    final wantsLess = RegExp(
            r'\bazalt\w*|\bdusur\w*|\bkisalt\w*|\beksilt\w*|\bcikar\w*|\bdaha az\b|\bkirp\w*')
        .hasMatch(f);
    if (numeric != null) {
      if (wantsLess && !wantsMore) {
        return make(NluModifierType.shorten, minutes: numeric);
      }
      if (wantsMore && !wantsLess) {
        return make(NluModifierType.extend, minutes: numeric);
      }
      // 4) Açık sayı: hedef ("bugün 45 dakika olsun", "3 saat yap")
      if (_imperative.hasMatch(f)) {
        return make(NluModifierType.replace, minutes: numeric, absolute: true);
      }
      return null;
    }

    // 5) Fiil kökleri
    if (_vIntUp.hasMatch(f)) return make(NluModifierType.intensityUp);
    if (_vHarder.hasMatch(f)) return make(NluModifierType.harder);
    if (_vExtend.hasMatch(f)) return make(NluModifierType.extend);
    if (_vIncrease.hasMatch(f)) return make(NluModifierType.increase);
    if (_vIntDown.hasMatch(f)) return make(NluModifierType.intensityDown);
    if (_vEasier.hasMatch(f)) return make(NluModifierType.easier);
    if (_vShorten.hasMatch(f)) return make(NluModifierType.shorten);
    if (_vDecrease.hasMatch(f)) return make(NluModifierType.decrease);

    // 6) "daha fazla / biraz daha çalışayım / biraz daha ekle / daha az"
    final hasVerbHint = _imperative.hasMatch(f) ||
        RegExp(r'\b(?:calisayim|calisalim|ekle|koy|ver)\b').hasMatch(f);
    final bareMore =
        RegExp(r'^(?:biraz |cok |bir az )?daha (?:fazla|cok)$').hasMatch(f);
    if (RegExp(r'\bdaha (?:fazla|cok|ekle)\b|\bbiraz daha (?:calis|ekle)')
            .hasMatch(f) &&
        (hasVerbHint || bareMore)) {
      return make(NluModifierType.increase);
    }
    if (RegExp(r'\bdaha az\b').hasMatch(f) &&
        (hasVerbHint || contentTokens <= 3)) {
      return make(NluModifierType.decrease);
    }

    // 7) Sıfatlar: ağır/yoğun/zor (+), hafif/kolay (−) — istek mi, değerlendirme mi?
    final heavy = RegExp(r'\b(?:agir|yogun|fazla|dolu)\b').hasMatch(f);
    final hard = RegExp(r'\bzor\b').hasMatch(f);
    final light = RegExp(r'\bhafif\b').hasMatch(f);
    final easy = RegExp(r'\bkolay\b').hasMatch(f);
    if (heavy || hard || light || easy) {
      // "biraz daha ağır" — karşılaştırma kalıbı da bir istektir.
      final imperative = _imperative.hasMatch(f) ||
          RegExp(r'\bdaha (?:agir|yogun|zor|hafif|kolay)\b').hasMatch(f);
      final evaluative = _evaluative.hasMatch(f);
      // Bağlam: plan sözcüğü, işaret sözcüğü ("bu/bunu") ya da açık istek/
      // değerlendirme kalıbı. Salt "zor" gibi tek sözcük değil.
      final anchored =
          hasPlanWord || _deictic.hasMatch(f) || imperative || evaluative;
      if (!anchored) return null;
      if (!imperative && !evaluative) {
        // "bu çok ağır" — deiktik + sıfat: değerlendirme.
        if (!_deictic.hasMatch(f) && !hasPlanWord) return null;
      }
      final polarityHeavy = heavy || hard; // "ağır" tarafı
      // İstek ("ağır yap/olsun") → o yöne; değerlendirme ("ağır olmuş") →
      // tersine ("çok ağır olmuş" = hafiflet).
      final up = imperative ? polarityHeavy : !polarityHeavy;
      final soft = hard || easy; // zor/kolay: zorluk; ağır/hafif: yoğunluk
      if (up) {
        return make(
            soft ? NluModifierType.harder : NluModifierType.intensityUp);
      }
      return make(
          soft ? NluModifierType.easier : NluModifierType.intensityDown);
    }
    return null;
  }

  static NluAmount _amountOf(String f) {
    if (_small.hasMatch(f)) return NluAmount.small;
    if (_large.hasMatch(f)) return NluAmount.large;
    return NluAmount.medium;
  }
}
