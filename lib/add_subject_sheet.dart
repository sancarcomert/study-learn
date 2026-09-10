import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'subject_model.dart';
import 'subject_provider.dart';
import 'widgets/app_buttons.dart';
import 'widgets/app_snackbar.dart';
import 'widgets/eyebrow.dart';

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
      AppSnackBar.error(context, 'Ders adı çok uzun (max 30 karakter)');
      return;
    } // boş isimle ders eklenmesin

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

  @override
  Widget build(BuildContext context) {
    // Klavye açıldığında sheet'in klavyenin altında kalmaması için
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Dersi Düzenle' : 'Yeni Ders',
              style: AppTextStyles.heading2,
            ),
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
                return GestureDetector(
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