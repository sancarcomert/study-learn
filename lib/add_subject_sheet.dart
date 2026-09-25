import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'stats_provider.dart';
import 'subject_model.dart';
import 'subject_provider.dart';
import 'tap_scale.dart';
import 'topic_catalog.dart';
import 'topic_provider.dart';
import 'widgets/app_buttons.dart';
import 'widgets/app_snackbar.dart';
import 'widgets/eyebrow.dart';

/// Konu kataloğunun tanıdığı 12 YKS dersi (topic_catalog.dart ile birebir
/// aynı liste, görüntü için düzgün yazımla) — "Ders Ekle" ekranına hazır
/// çip olarak eklenir. Onboarding'de yalnızca ilk (tek) ders için 5 çip
/// vardı; ikinci/üçüncü/... dersler için hiç kısayol yoktu, kullanıcı
/// hepsini elle yazmak zorundaydı. Almanca bilinçli olarak dışarıda —
/// kataloğu yok, eklense "Yaygın konuları ekle" boş kalırdı.
const List<String> _catalogSubjects = [
  'Matematik',
  'Geometri',
  'Fizik',
  'Kimya',
  'Biyoloji',
  'Türkçe',
  'Edebiyat',
  'Tarih',
  'Coğrafya',
  'Felsefe',
  'İngilizce',
  'Din Kültürü',
];

class AddSubjectSheet extends ConsumerStatefulWidget {
  final SubjectModel? subjectToEdit;

  const AddSubjectSheet({super.key, this.subjectToEdit});

  @override
  ConsumerState<AddSubjectSheet> createState() => _AddSubjectSheetState();
}

class _AddSubjectSheetState extends ConsumerState<AddSubjectSheet> {
  final _controller = TextEditingController();
  Color _selectedColor = AppColors.subjectPalette.first;

  bool get _isEditing => widget.subjectToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final subject = widget.subjectToEdit!;
      _controller.text = subject.name;
      _selectedColor = Color(subject.colorValue);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      AppSnackBar.error(context, 'Ders adı boş olamaz');
      return;
    }
    if (name.length > 30) {
      AppSnackBar.error(context, 'Ders adı çok uzun (en fazla 30 karakter)');
      return;
    } // boş isimle ders eklenmesin

    // Aynı adlı ikinci bir ders (elle yazılınca) deneme/öneri eşlemesini ve
    // konu listelerini çiftler — hazır-ders çipleri zaten buna izin vermiyor.
    final lower = name.toLowerCase();
    final duplicate = ref.read(subjectProvider).any((s) =>
        s.name.trim().toLowerCase() == lower &&
        s.id != widget.subjectToEdit?.id);
    if (duplicate) {
      AppSnackBar.error(context, '"$name" zaten var');
      return;
    }

    if (_isEditing) {
      ref.read(subjectProvider.notifier).updateSubject(
            widget.subjectToEdit!.id,
            name,
            _selectedColor.toARGB32(),
          );
    } else {
      ref
          .read(subjectProvider.notifier)
          .addSubject(name, _selectedColor.toARGB32());
    }
    Navigator.of(context).pop();
  }

  /// Hazır ders çipine dokununca tek adımda ekler — sheet açık kalır ki
  /// kullanıcı art arda birkaç ders daha ekleyebilsin (bir YKS öğrencisi
  /// genelde tek seferde 5+ ders ekliyor). Renk, mevcut ders sayısına göre
  /// paletten sırayla verilir; boş isim/30 karakter kontrolüne gerek yok,
  /// isimler sabit ve kısa.
  ///
  /// Konular da AYNI anda, sınıfa göre kümülatif olarak eklenir (P0-11) —
  /// önceden yalnız boş bir ders oluşturuluyordu, konuları görmek için
  /// kullanıcının ayrıca o dersin içine girip "Yaygın konuları ekle"ye
  /// BİR KEZ DAHA basması gerekiyordu. "Hazır ders, konu listesi hazır
  /// gelir" vaadiyle tutarlı olması için bu ikinci adım kaldırıldı.
  void _addFromChip(String name) {
    final subjects = ref.read(subjectProvider);
    final color = AppColors
        .subjectPalette[subjects.length % AppColors.subjectPalette.length];
    ref.read(subjectProvider.notifier).addSubject(name, color.toARGB32());

    final created = ref
        .read(subjectProvider)
        .where((s) => s.name == name)
        .lastOrNull;
    final catalog = TopicCatalog.forSubject(
      name,
      maxGrade: TopicCatalog.maxGradeFor(ref.read(statsProvider).gradeLevel),
    );
    if (created != null && catalog.isNotEmpty) {
      ref.read(topicProvider.notifier).addMany(created.id, catalog);
    }

    AppSnackBar.success(context, '"$name" eklendi — konuları hazır');
  }

  @override
  Widget build(BuildContext context) {
    // Klavye açıldığında sheet'in klavyenin altında kalmaması için
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Dersi Düzenle' : 'Yeni Ders',
              style: AppTextStyles.heading2,
            ),
            if (!_isEditing) ...[
              const SizedBox(height: 20),
              const Eyebrow(text: 'HAZIR DERSLER'),
              const SizedBox(height: 4),
              Text(
                'Konu listesi hazır gelir, tek dokunuşla ekle.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 10),
              Builder(builder: (context) {
                final existing = ref
                    .watch(subjectProvider)
                    .map((s) => s.name.trim().toLowerCase())
                    .toSet();
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _catalogSubjects.map((name) {
                    final added = existing.contains(name.toLowerCase());
                    return TapScale(
                      onTap: added ? null : () => _addFromChip(name),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: added
                              ? AppColors.tonal(AppColors.textSecondary)
                              : AppColors.tonal(AppColors.primary),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (added) ...[
                              Icon(Icons.check_rounded,
                                  size: 14, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              name,
                              style: AppTextStyles.body.copyWith(
                                color: added
                                    ? AppColors.textMuted
                                    : AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              }),
              const SizedBox(height: 20),
              const Eyebrow(text: 'YA DA KENDİN YAZ'),
              const SizedBox(height: 10),
            ] else
              const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Örn. Matematik'),
            ),
            const SizedBox(height: 20),
            const Eyebrow(text: 'RENK SEÇ'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              children: AppColors.subjectPalette.map((color) {
                final isSelected =
                    color.toARGB32() == _selectedColor.toARGB32();
                return TapScale(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: AppColors.textPrimary, width: 3)
                          : null,
                      boxShadow:
                          isSelected ? [AppColors.glow(color)] : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: _isEditing ? 'Kaydet' : 'Dersi Ekle',
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}