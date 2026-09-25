import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'deneme_change_engine.dart';
import 'deneme_model.dart';
import 'deneme_provider.dart';
import 'deneme_screen.dart' show ExamTypeToggle;
import 'goal_gap_provider.dart';
import 'rank_system.dart';
import 'stats_provider.dart';
import 'subject_provider.dart';
import 'subject_topics_screen.dart';
import 'tap_scale.dart';
import 'topic_model.dart';
import 'topic_provider.dart';
import 'widgets/app_buttons.dart';
import 'widgets/app_snackbar.dart';
import 'widgets/eyebrow.dart';

/// Tek bir bölümün (ör. "TYT Türkçe") düzenlenebilir girişi. Sadece skor —
/// soru içeriği asla tutulmaz.
class _SectionInput {
  final TextEditingController name;
  final TextEditingController correct;
  final TextEditingController wrong;
  final TextEditingController blank;

  // Bu bölümde GERÇEKTEN yanlış yapılan konuların id'leri (Konu Takip'ten,
  // opsiyonel) — bkz. DenemeSectionScore.weakTopicIds. Soru içeriği DEĞİL,
  // yalnızca "hangi konudan yanlış yaptım" işareti.
  final Set<String> weakTopicIds;

  _SectionInput({
    String name = '',
    int correct = 0,
    int wrong = 0,
    int blank = 0,
    List<String> weakTopicIds = const [],
  })  : name = TextEditingController(text: name),
        correct = TextEditingController(text: correct == 0 ? '' : '$correct'),
        wrong = TextEditingController(text: wrong == 0 ? '' : '$wrong'),
        blank = TextEditingController(text: blank == 0 ? '' : '$blank'),
        weakTopicIds = Set<String>.from(weakTopicIds);

  int _n(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  double get net => _n(correct) - _n(wrong) / 4.0;

  void dispose() {
    name.dispose();
    correct.dispose();
    wrong.dispose();
    blank.dispose();
  }
}

/// Deneme ekle/düzenle. [entryToEdit] verilirse mevcut kaydı günceller.
/// Soru bankası YOK — yalnızca doğru/yanlış/boş girişi, kesin kapsam
/// sınırının dışında kalır.
class AddDenemeScreen extends ConsumerStatefulWidget {
  final DenemeEntry? entryToEdit;
  const AddDenemeScreen({super.key, this.entryToEdit});

  @override
  ConsumerState<AddDenemeScreen> createState() => _AddDenemeScreenState();
}

class _AddDenemeScreenState extends ConsumerState<AddDenemeScreen> {
  static const _tytSubjects = ['Türkçe', 'Sosyal Bilimler', 'Matematik', 'Fen Bilimleri'];
  static const _aytSubjects = [
    'Matematik', 'Fizik', 'Kimya', 'Biyoloji',
    'Türk Dili ve Edebiyatı', 'Tarih-1', 'Coğrafya-1',
    'Tarih-2', 'Coğrafya-2', 'Felsefe Grubu', 'Din Kültürü', 'Yabancı Dil',
  ];

  late String _type;
  late DateTime _date;
  late TextEditingController _nameController;
  final List<_SectionInput> _sections = [];

  bool get _isEditing => widget.entryToEdit != null;

  @override
  void initState() {
    super.initState();
    final e = widget.entryToEdit;
    _type = e?.examType ?? 'TYT';
    _date = e?.date ?? DateTime.now();
    _nameController = TextEditingController(text: e?.name ?? '');
    if (e != null) {
      for (final s in e.sections) {
        _sections.add(_SectionInput(
          name: s.subject,
          correct: s.correct,
          wrong: s.wrong,
          blank: s.blank,
          weakTopicIds: s.weakTopicIds,
        ));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final s in _sections) {
      s.dispose();
    }
    super.dispose();
  }

  List<String> get _suggested => _type == 'TYT' ? _tytSubjects : _aytSubjects;

  void _addSection(String name) {
    final exists = _sections
        .any((s) => s.name.text.trim().toLowerCase() == name.toLowerCase());
    if (exists) return;
    setState(() => _sections.add(_SectionInput(name: name)));
  }

  void _addCustomSection() {
    setState(() => _sections.add(_SectionInput()));
  }

  void _removeSection(int index) {
    setState(() {
      _sections[index].dispose();
      _sections.removeAt(index);
    });
  }

  double get _totalNet => _sections.fold(0.0, (sum, s) => sum + s.net);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  /// Resmî YKS soru sayıları — bir bölümde doğru+yanlış+boş bundan fazla
  /// olamaz. Listede olmayan (özel) bölümler için genel tavan 120 (TYT'nin
  /// tamamı). Aşırı bir yazım hatası ("400 doğru") net ortalamalarını, trendi
  /// ve zayıf-ders sinyalini sessizce bozardı.
  static const Map<String, int> _questionCounts = {
    'Türkçe': 40,
    'Sosyal Bilimler': 20,
    'Matematik': 40,
    'Fen Bilimleri': 20,
    'Fizik': 14,
    'Kimya': 13,
    'Biyoloji': 13,
    'Türk Dili ve Edebiyatı': 24,
    'Tarih-1': 10,
    'Coğrafya-1': 6,
    'Tarih-2': 11,
    'Coğrafya-2': 11,
    'Felsefe Grubu': 12,
    'Din Kültürü': 6,
    'Yabancı Dil': 80,
  };

  String? _validateCounts() {
    for (final s in _sections) {
      final name = s.name.text.trim();
      if (name.isEmpty) continue;
      final total = s._n(s.correct) + s._n(s.wrong) + s._n(s.blank);
      final max = _questionCounts[name] ?? 120;
      if (total > max) {
        return '$name bölümünde doğru + yanlış + boş en fazla $max olabilir '
            '(şu an $total).';
      }
    }
    return null;
  }

  void _save() {
    final countError = _validateCounts();
    if (countError != null) {
      AppSnackBar.error(context, countError);
      return;
    }
    final validSections = _sections
        .where((s) => s.name.text.trim().isNotEmpty)
        .map((s) => DenemeSectionScore(
              subject: s.name.text.trim(),
              correct: int.tryParse(s.correct.text.trim()) ?? 0,
              wrong: int.tryParse(s.wrong.text.trim()) ?? 0,
              blank: int.tryParse(s.blank.text.trim()) ?? 0,
              weakTopicIds: s.weakTopicIds.toList(),
            ))
        .toList();

    if (validSections.isEmpty) {
      AppSnackBar.error(context, 'En az bir ders bölümü ekle.');
      return;
    }

    final notifier = ref.read(denemeProvider.notifier);
    final trimmedName = _nameController.text.trim();
    if (_isEditing) {
      final e = widget.entryToEdit!;
      e.examType = _type;
      e.name = trimmedName.isEmpty ? null : trimmedName;
      e.date = _date;
      e.sections = validSections;
      notifier.updateEntry(e);
    } else {
      // Kişisel rekor kontrolü VE "önceki deneme" anlık görüntüsü EKLEMEDEN
      // ÖNCE alınmalı — sonra bakarsak yeni kayıt zaten listede,
      // "önceki"/"en iyi" kendisi olur (bkz. Faz 2/9 — RE-EVALUATION).
      final previousBest = ref.read(denemeSummaryProvider(_type))?.best;
      final priorEntries = ref.read(denemeByTypeProvider(_type)); // artan sıralı
      final previousEntry = priorEntries.isEmpty ? null : priorEntries.last;
      // Yalnız kıyas için — henüz kaydedilmedi, gerçek id'si yok.
      final newEntryForCompare = DenemeEntry(
        id: '',
        examType: _type,
        date: _date,
        sections: validSections,
      );
      final subjectIdByName = {
        for (final s in ref.read(subjectProvider)) s.name.toLowerCase(): s.id,
      };
      final touchedSubjectIds = validSections
          .map((s) => subjectIdByName[s.subject.trim().toLowerCase()])
          .whereType<String>()
          .toSet();

      notifier.addEntry(
        examType: _type,
        name: trimmedName,
        date: _date,
        sections: validSections,
      );

      // Yalnız YENİ kayıtta tetiklenir (düzenlemede değil) — aksi halde
      // aynı deneme ileri-geri düzenlenerek XP çiftlenebilir. İlk deneme
      // (previousBest null) "rekor" sayılmaz, kıyaslanacak bir şey yok.
      int recordBonus = 0;
      if (previousBest != null && _totalNet > previousBest) {
        recordBonus = RankSystem.netImprovementBonus(_totalNet - previousBest);
        if (recordBonus > 0) {
          ref.read(statsProvider.notifier).addBonusXp(recordBonus);
        }
      }

      // RE-EVALUATION (Faz 2/9) — "ne değişti?" GOAL → GAP zincirinin tek
      // kaynağından (goal_gap_provider.dart, addEntry'den SONRA otomatik
      // yeniden hesaplanır) + aynı kayıttan gelen konu/ders sinyallerinden.
      // İkinci bir hesap İCAT EDİLMEZ.
      final goalGap = ref.read(
          _type == 'TYT' ? tytGoalGapProvider : aytGoalGapProvider);
      final mostChanged =
          DenemeChangeEngine.mostChangedSubject(newEntryForCompare, previousEntry);
      final resolved = Map.fromEntries(
        ref.read(resolvedWeakTopicsBySubjectProvider).entries.where(
            (e) => touchedSubjectIds.contains(e.key)),
      );
      final newlyWeak = Map.fromEntries(
        ref.read(newlyWeakTopicsBySubjectProvider).entries.where(
            (e) => touchedSubjectIds.contains(e.key)),
      );
      final changeSummary = DenemeChangeEngine.summarize(
        goalGap: goalGap,
        mostChangedSubject: mostChanged,
        resolvedSubjectTopics: resolved,
        newlyWeakSubjectTopics: newlyWeak,
      );

      if (recordBonus > 0 && changeSummary != null) {
        AppSnackBar.success(
            context, 'Yeni en iyi net! +$recordBonus XP · $changeSummary');
      } else if (recordBonus > 0) {
        AppSnackBar.success(context, 'Yeni en iyi net! +$recordBonus XP');
      } else if (changeSummary != null) {
        AppSnackBar.info(context, changeSummary);
      }
    }
    Navigator.of(context).pop();
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    if (target == today) return 'Bugün';
    const months = [
      'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(_isEditing ? 'Denemeyi Düzenle' : 'Deneme Ekle',
            style: AppTextStyles.heading2),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  ExamTypeToggle(
                    type: _type,
                    onChanged: (t) => setState(() => _type = t),
                  ),
                  const SizedBox(height: 20),
                  const Eyebrow(text: 'TARİH'),
                  const SizedBox(height: 10),
                  TapScale(
                    onTap: _pickDate,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.surfaceVariant),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 18, color: AppColors.secondary),
                          const SizedBox(width: 10),
                          Text(_formatDate(_date), style: AppTextStyles.body),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Eyebrow(text: 'İSİM (OPSİYONEL)'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameController,
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Örn. 3D Yayınları Deneme 5',
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Eyebrow(text: 'BÖLÜMLER'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.surfaceVariant),
                    ),
                    child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _suggested.map((name) {
                      final added = _sections.any((s) =>
                          s.name.text.trim().toLowerCase() ==
                          name.toLowerCase());
                      return TapScale(
                        onTap: added ? null : () => _addSection(name),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: added
                                ? AppColors.tonal(AppColors.textSecondary)
                                : AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (added)
                                Icon(Icons.check,
                                    size: 14, color: AppColors.textMuted),
                              if (added) const SizedBox(width: 4),
                              Text(
                                name,
                                style: AppTextStyles.caption.copyWith(
                                  color: added
                                      ? AppColors.textMuted
                                      : AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._sections.asMap().entries.map((entry) {
                    final i = entry.key;
                    final s = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SectionCard(
                        input: s,
                        onRemove: () => _removeSection(i),
                        onChanged: () => setState(() {}),
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  TapScale(
                    onTap: _addCustomSection,
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Özel ders ekle',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Column(
                children: [
                  if (_sections.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Toplam net', style: AppTextStyles.bodySecondary),
                        Text(
                          _totalNet.toStringAsFixed(2),
                          style: AppTextStyles.heading2
                              .copyWith(color: AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  PrimaryButton(
                      label: 'Kaydet', icon: Icons.check, onPressed: _save),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends ConsumerWidget {
  final _SectionInput input;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _SectionCard({
    required this.input,
    required this.onRemove,
    required this.onChanged,
  });

  /// Bölümün ders adını (serbest metin) kullanıcının GERÇEK ders listesine
  /// eşler — deneme_provider.dart'taki weakestDenemeSubjectIdProvider ile
  /// aynı isim-eşleme deseni. Eşleşme yoksa (ör. "Sosyal Bilimler" gibi bir
  /// TYT bölümü, ayrı bir ders olarak eklenmemişse) konu etiketleme
  /// gösterilmez — yeni bir taksonomi İCAT EDİLMEZ.
  String? _matchSubjectId(WidgetRef ref) {
    final name = input.name.text.trim().toLowerCase();
    if (name.isEmpty) return null;
    for (final s in ref.watch(subjectProvider)) {
      if (s.name.toLowerCase() == name) return s.id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectId = _matchSubjectId(ref);
    final topics = subjectId == null
        ? const <TopicModel>[]
        : ref.watch(topicsForSubjectProvider(subjectId));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: input.name,
                  onChanged: (_) => onChanged(),
                  style:
                      AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Ders adı',
                  ),
                ),
              ),
              TapScale(
                onTap: onRemove,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child:
                      Icon(Icons.close, size: 18, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _NumField(
                      label: 'Doğru',
                      controller: input.correct,
                      color: AppColors.success,
                      onChanged: onChanged)),
              const SizedBox(width: 8),
              Expanded(
                  child: _NumField(
                      label: 'Yanlış',
                      controller: input.wrong,
                      color: AppColors.danger,
                      onChanged: onChanged)),
              const SizedBox(width: 8),
              Expanded(
                  child: _NumField(
                      label: 'Boş',
                      controller: input.blank,
                      color: AppColors.textMuted,
                      onChanged: onChanged)),
            ],
          ),
          if (topics.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Hangi konu(lar)da yanlış yaptın? (opsiyonel)',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: topics.map((t) {
                final selected = input.weakTopicIds.contains(t.id);
                return TapScale(
                  onTap: () {
                    if (selected) {
                      input.weakTopicIds.remove(t.id);
                    } else {
                      input.weakTopicIds.add(t.id);
                    }
                    onChanged();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.tonal(AppColors.danger)
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(14),
                      border: selected
                          ? Border.all(
                              color: AppColors.danger.withValues(alpha: 0.4))
                          : null,
                    ),
                    child: Text(
                      t.name,
                      style: AppTextStyles.caption.copyWith(
                        color: selected
                            ? AppColors.danger
                            : AppColors.textSecondary,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ] else if (subjectId != null) ...[
            // Discovery (Ön-beta) — bu ders GERÇEKTEN eşleşti ama Konu
            // Takip'te hiç konusu yok, bu yüzden yukarıdaki zayıf-konu
            // işaretleme hiç görünmüyor. Sessizce hiçbir şey göstermek
            // yerine, tam bu anın alakalı olduğu yerde tek satırlık bir
            // sonraki adım — yeni bir ekran/akış İCAT EDİLMEDİ, zaten var
            // olan SubjectTopicsScreen'e (+ oradaki "yaygın konuları ekle"
            // kısayoluna) yönlendiriyor.
            const SizedBox(height: 10),
            TapScale(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SubjectTopicsScreen(
                    subjectId: subjectId,
                    subjectName: input.name.text.trim(),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.playlist_add_outlined,
                      size: 15, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Bu ders için konu eklersen sonraki denemede hangi '
                      'konudan yanlış yaptığını işaretleyebilirsin',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Net: ${input.net.toStringAsFixed(2)}',
              style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final Color color;
  final VoidCallback onChanged;

  const _NumField({
    required this.label,
    required this.controller,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption.copyWith(color: color)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          onChanged: (_) => onChanged(),
          style: AppTextStyles.body,
          // Gerçek bir TYT/AYT bölümü hiçbir zaman 2 haneyi (≤99 soru)
          // geçmez — yanlış dokunuşla anlamsız net oluşmasın diye sınır.
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          decoration: InputDecoration(
            isDense: true,
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            filled: true,
            fillColor: AppColors.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            hintText: '0',
          ),
        ),
      ],
    );
  }
}
