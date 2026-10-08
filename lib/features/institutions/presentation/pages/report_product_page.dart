// lib/features/institutions/presentation/pages/report_product_page.dart

import 'package:flutter/material.dart';
import 'package:loqma/features/institutions/data/repositories/institutions_repository.dart';

class ReportProductPage extends StatefulWidget {
  final String offerId;

  const ReportProductPage({super.key, required this.offerId});

  @override
  State<ReportProductPage> createState() => _ReportProductPageState();
}

class _ReportProductPageState extends State<ReportProductPage> {
  final _repository = InstitutionsRepository();
  final _descriptionController = TextEditingController();
  String _selectedType = 'expired';
  bool _isSubmitting = false;

  // ✅ أيقونات مضمونة في فلاتر
  final List<Map<String, dynamic>> _complaintTypes = [
    {
      'value': 'expired',
      'label': 'منتهي الصلاحية',
      'icon': Icons.history_toggle_off
    },
    {'value': 'damaged', 'label': 'تالف', 'icon': Icons.warning_amber_rounded},
    {
      'value': 'wrong_product',
      'label': 'منتج مختلف',
      'icon': Icons.swap_horiz_rounded
    },
    {
      'value': 'bad_quality',
      'label': 'جودة سيئة',
      'icon': Icons.verified_outlined
    },
    {'value': 'other', 'label': 'أخرى', 'icon': Icons.more_horiz},
  ];

  // ✅ ألوان مودرن
  static const _primary = Color(0xFF0B7650);
  static const _primaryDark = Color(0xFF123F31);
  static const _background = Color(0xFFF7FAF9);
  static const _surface = Color(0xFFFFFFFF);
  static const _muted = Color(0xFF71837C);
  static const _error = Color(0xFFD64545);
  static const _border = Color(0xFFE0E3E2);

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      await _repository.addProductComplaint(
        offerId: widget.offerId,
        complaintType: _selectedType,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال الشكوى بنجاح'),
          backgroundColor: _primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر إرسال الشكوى. حاول مرة أخرى.'),
            backgroundColor: _error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          title: const Text(
            'الإبلاغ عن منتج',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          centerTitle: true,
          backgroundColor: _background,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Hero Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primary, Color(0xFF2BAA76)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.flag_rounded, color: Colors.white, size: 40),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'هل واجهت مشكلة؟',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'أبلغنا وسنساعدك في حل المشكلة بأسرع وقت.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ✅ اختيار نوع المشكلة
              const Text(
                'ما نوع المشكلة؟',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _primaryDark,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _complaintTypes.map((type) {
                  final selected = _selectedType == type['value'];
                  return ChoiceChip(
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _selectedType = type['value'] as String),
                    selectedColor: _primary,
                    backgroundColor: _surface,
                    side: BorderSide(
                      color: selected ? _primary : _border,
                    ),
                    // ✅ وضع الأيقونة جوه الـ label
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          type['icon'] as IconData,
                          size: 18,
                          color: selected ? Colors.white : _primaryDark,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          type['label'] as String,
                          style: TextStyle(
                            color: selected ? Colors.white : _primaryDark,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // ✅ وصف المشكلة
              const Text(
                'وصف المشكلة (اختياري)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _primaryDark,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'اكتب تفاصيل المشكلة هنا...',
                  hintStyle: const TextStyle(color: _muted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _primary, width: 1.5),
                  ),
                  filled: true,
                  fillColor: _surface,
                ),
              ),

              const SizedBox(height: 28),

              // ✅ زر الإرسال
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _isSubmitting ? 'جاري الإرسال...' : 'إرسال الشكوى',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
