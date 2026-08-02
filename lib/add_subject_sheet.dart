import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'subject_provider.dart';

class AddSubjectSheet extends ConsumerStatefulWidget {
  const AddSubjectSheet({super.key});

  @override
  ConsumerState<AddSubjectSheet> createState() => _AddSubjectSheetState();
}

class _AddSubjectSheetState extends ConsumerState<AddSubjectSheet> {
  final _controller = TextEditingController();
  Color _selectedColor = AppColors.subjectPalette.first;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

 void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ders adı boş olamaz')),
      );
      return;
    }
    if (name.length > 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ders adı çok uzun (max 30 karakter)')),
      );
      return;
    } // boş isimle ders eklenmesin

    ref.read(subjectProvider.notifier).addSubject(name, _selectedColor.value);
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
            Text('Yeni Ders', style: AppTextStyles.heading2),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Örn. Matematik'),
            ),
            const SizedBox(height: 20),
            Text('Renk seç', style: AppTextStyles.bodySecondary),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              children: AppColors.subjectPalette.map((color) {
                final isSelected = color.value == _selectedColor.value;
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                child: const Text('Dersi Ekle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}