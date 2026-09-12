import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'deneme_model.dart';
import 'deneme_provider.dart';
import 'deneme_screen.dart' show ExamTypeToggle;
import 'tap_scale.dart';
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

  _SectionInput({
    String name = '',
    int correct = 0,
    int wrong = 0,
    int blank = 0,
  })  : name = TextEditingController(text: name),
        correct = TextEditingController(text: correct == 0 ? '' : '$correct'),
        wrong = TextEditingController(text: wrong == 0 ? '' : '$wrong'),
        blank = TextEditingController(text: blank == 0 ? '' : '$blank');

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

  void _save() {
    final validSections = _sections
        .where((s) => s.name.text.trim().isNotEmpty)
        .map((s) => DenemeSectionScore(
              subject: s.name.text.trim(),
              correct: int.tryParse(s.correct.text.trim()) ?? 0,
              wrong: int.tryParse(s.wrong.text.trim()) ?? 0,
              blank: int.tryParse(s.blank.text.trim()) ?? 0,
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
      notifier.addEntry(
        examType: _type,
        name: trimmedName,
        date: _date,
        sections: validSections,
      );
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
                          const Icon(Icons.calendar_today_outlined,
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
                                const Icon(Icons.check,
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
                        const Icon(Icons.add_circle_outline,
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

class _SectionCard extends StatelessWidget {
  final _SectionInput input;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _SectionCard({
    required this.input,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
                child: const Padding(
                  padding: EdgeInsets.all(4),
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
