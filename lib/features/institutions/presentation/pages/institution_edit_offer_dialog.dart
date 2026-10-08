// lib/features/institutions/presentation/pages/institution_edit_offer_dialog.dart

import 'package:flutter/material.dart';
import 'package:loqma/features/institutions/data/repositories/institution_offers_repository.dart';

class InstitutionEditOfferDialog extends StatefulWidget {
  final Map<String, dynamic> offer;
  final InstitutionOffersRepository repository;

  const InstitutionEditOfferDialog({
    super.key,
    required this.offer,
    required this.repository,
  });

  @override
  State<InstitutionEditOfferDialog> createState() =>
      _InstitutionEditOfferDialogState();
}

class _InstitutionEditOfferDialogState
    extends State<InstitutionEditOfferDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  late final TextEditingController _originalPriceController;
  late final TextEditingController _pickupLocationController;
  late final TextEditingController _pickupNotesController;
  late final TextEditingController _contactPhoneController;

  String _category = 'food';
  String _condition = 'good';
  bool _isHalal = true;
  bool _isVegetarian = false;
  bool _requiresRefrigeration = false;
  bool _isLoading = false;
  bool _hasRequests = false;

  static const _primary = Color(0xFF0B7650);
  static const _primaryDark = Color(0xFF123F31);
  static const _surfaceVariant = Color(0xFFE8F0EC);
  static const _muted = Color(0xFF71837C);
  static const _accent = Color(0xFFE28B00);
  static const _error = Color(0xFFD64545);

  final List<Map<String, dynamic>> _categories = [
    {'id': 'food', 'label': '🍽️ وجبات'},
    {'id': 'bakery', 'label': '🥖 مخبوزات'},
    {'id': 'dessert', 'label': '🍰 حلويات'},
    {'id': 'fruit', 'label': '🍎 فواكه'},
    {'id': 'drink', 'label': '🥤 مشروبات'},
    {'id': 'meat', 'label': '🥩 لحوم'},
    {'id': 'other', 'label': '📦 أخرى'},
  ];

  final List<Map<String, dynamic>> _conditions = [
    {'id': 'new', 'label': 'جديد', 'color': _primary},
    {'id': 'very_good', 'label': 'ممتاز', 'color': const Color(0xFF3679C8)},
    {'id': 'good', 'label': 'جيد', 'color': const Color(0xFFB77700)},
    {
      'id': 'needs_repair',
      'label': 'يحتاج إصلاح',
      'color': const Color(0xFFD64545)
    },
  ];

  @override
  void initState() {
    super.initState();
    final offer = widget.offer;

    final reservedQuantity = (offer['reserved_quantity'] as num?)?.toInt() ?? 0;
    _hasRequests = reservedQuantity > 0;

    _titleController =
        TextEditingController(text: offer['title']?.toString() ?? '');
    _descriptionController =
        TextEditingController(text: offer['description']?.toString() ?? '');
    _quantityController =
        TextEditingController(text: offer['quantity']?.toString() ?? '1');
    _priceController =
        TextEditingController(text: offer['symbolic_price']?.toString() ?? '0');
    _originalPriceController =
        TextEditingController(text: offer['original_price']?.toString() ?? '');
    _pickupLocationController =
        TextEditingController(text: offer['pickup_location']?.toString() ?? '');
    _pickupNotesController =
        TextEditingController(text: offer['pickup_notes']?.toString() ?? '');
    _contactPhoneController =
        TextEditingController(text: offer['contact_phone']?.toString() ?? '');
    _category = offer['category']?.toString() ?? 'food';
    _condition = offer['food_condition']?.toString() ?? 'good';
    _isHalal = offer['is_halal'] ?? true;
    _isVegetarian = offer['is_vegetarian'] ?? false;
    _requiresRefrigeration = offer['requires_refrigeration'] ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    _pickupLocationController.dispose();
    _pickupNotesController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  String _normalizeDigits(String value) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    var result = value;
    for (var i = 0; i < 10; i++) {
      result = result.replaceAll(arabic[i], '$i');
      result = result.replaceAll(persian[i], '$i');
    }
    return result.trim();
  }

  Future<void> _saveChanges() async {
    if (_isLoading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final quantity = int.tryParse(_normalizeDigits(_quantityController.text));
    final symbolicPrice = double.tryParse(
      _normalizeDigits(_priceController.text).replaceAll(',', '.'),
    );
    final originalText = _originalPriceController.text.trim();
    final originalPrice = originalText.isEmpty
        ? null
        : double.tryParse(_normalizeDigits(originalText).replaceAll(',', '.'));

    if (quantity == null || quantity <= 0) {
      _showError('الكمية يجب أن تكون أكبر من صفر');
      return;
    }
    if (symbolicPrice == null || symbolicPrice < 0) {
      _showError('السعر الرمزي غير صحيح');
      return;
    }
    if (originalPrice != null && symbolicPrice > originalPrice) {
      _showError('السعر الرمزي لا يمكن أن يكون أكبر من السعر الأصلي');
      return;
    }

    if (_hasRequests) {
      final originalQuantity =
          int.tryParse(widget.offer['quantity']?.toString() ?? '0') ?? 0;
      final originalPriceValue =
          double.tryParse(widget.offer['symbolic_price']?.toString() ?? '0') ??
              0;

      if (quantity != originalQuantity) {
        _showError('⚠️ لا يمكن تغيير الكمية لأن هناك طلبات على هذا العرض');
        return;
      }
      if (symbolicPrice != originalPriceValue) {
        _showError('⚠️ لا يمكن تغيير السعر لأن هناك طلبات على هذا العرض');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      await widget.repository.updateOffer(
        offerId: widget.offer['id'].toString(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _category,
        quantity: quantity,
        symbolicPrice: symbolicPrice,
        originalPrice: originalPrice,
        pickupLocation: _pickupLocationController.text.trim().isEmpty
            ? null
            : _pickupLocationController.text.trim(),
        pickupNotes: _pickupNotesController.text.trim().isEmpty
            ? null
            : _pickupNotesController.text.trim(),
        contactPhone: _contactPhoneController.text.trim().isEmpty
            ? null
            : _contactPhoneController.text.trim(),
        foodType: _category,
        foodCondition: _condition,
        isHalal: _isHalal,
        isVegetarian: _isVegetarian,
        requiresRefrigeration: _requiresRefrigeration,
      );

      if (!mounted) return;
      Navigator.pop(context, {'updated': true});
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleStatus() async {
    if (_isLoading) return;

    final currentStatus = widget.offer['status']?.toString() ?? 'active';
    final isActive = currentStatus == 'active' || currentStatus == 'available';

    setState(() => _isLoading = true);

    try {
      await widget.repository.toggleOfferStatus(
        offerId: widget.offer['id'].toString(),
        active: !isActive,
      );

      if (!mounted) return;
      Navigator.pop(context, {
        'toggled': true,
        'is_active': !isActive,
      });
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelOffer() async {
    if (_isLoading) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('⚠️ تأكيد الإلغاء'),
        content: Text(
          _hasRequests
              ? 'هذا العرض عليه طلبات معلقة!\n'
                  'سيتم إلغاء العرض وجميع الطلبات المعلقة.\n\n'
                  'هل أنت متأكد؟'
              : 'هل أنت متأكد من إلغاء هذا العرض؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      await widget.repository.cancelOffer(
        widget.offer['id'].toString(),
      );

      if (!mounted) return;
      Navigator.pop(context, {'cancelled': true});
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentStatus = widget.offer['status']?.toString() ?? 'active';
    final isActive = currentStatus == 'active' || currentStatus == 'available';
    final isCancelled = currentStatus == 'cancelled';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ العنوان
                Row(
                  children: [
                    const Icon(Icons.edit_outlined, color: _primary),
                    const SizedBox(width: 10),
                    const Text(
                      'تعديل العرض',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: _primaryDark,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'إغلاق',
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'قم بتحديث بيانات العرض حسب رغبتك',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
                const SizedBox(height: 18),

                // ✅ حالة العرض الحالية
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isActive
                        ? _primary.withValues(alpha: 0.08)
                        : _error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive ? _primary : _error,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isActive
                            ? Icons.check_circle_rounded
                            : Icons.block_rounded,
                        color: isActive ? _primary : _error,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isActive
                              ? '✅ العرض متاح حالياً للعملاء'
                              : isCancelled
                                  ? '🚫 هذا العرض ملغي'
                                  : '⏸️ العرض متوقف مؤقتاً',
                          style: TextStyle(
                            color: isActive ? _primary : _error,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ✅ تنبيه وجود طلبات
                if (_hasRequests) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _accent.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: _accent,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '⚠️ يوجد طلبات على هذا العرض، لا يمكن تعديل الكمية أو السعر',
                            style: TextStyle(
                              color: _accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // ✅ حقول التعديل
                _buildTextField(
                  controller: _titleController,
                  label: 'اسم العرض',
                  hint: 'مثال: سلة معجنات متنوعة',
                  icon: Icons.inventory_2_outlined,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _descriptionController,
                  label: 'وصف العرض',
                  hint: 'اكتب محتويات العرض وحالته...',
                  icon: Icons.description_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _priceController,
                        label: 'السعر الرمزي',
                        hint: '0.00',
                        icon: Icons.payments_outlined,
                        numeric: true,
                        enabled: !_hasRequests,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        controller: _originalPriceController,
                        label: 'السعر الأصلي',
                        hint: 'اختياري',
                        icon: Icons.sell_outlined,
                        numeric: true,
                        requiredField: false,
                        enabled: !_hasRequests,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _quantityController,
                        label: 'الكمية',
                        hint: '1',
                        icon: Icons.layers_outlined,
                        numeric: true,
                        enabled: !_hasRequests,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        controller: _contactPhoneController,
                        label: 'رقم التواصل',
                        hint: 'اختياري',
                        icon: Icons.phone_outlined,
                        requiredField: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _pickupLocationController,
                  label: 'موقع الاستلام',
                  hint: 'عنوان الفرع أو الموقع',
                  icon: Icons.location_on_outlined,
                  requiredField: false,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _pickupNotesController,
                  label: 'ملاحظات الاستلام',
                  hint: 'تعليمات إضافية للمستلم...',
                  icon: Icons.info_outline,
                  maxLines: 2,
                  requiredField: false,
                ),

                const SizedBox(height: 16),
                const Divider(color: Color(0xFFE2EEE8)),
                const SizedBox(height: 12),

                // ✅ التصنيفات
                const Text(
                  'التصنيف',
                  style: TextStyle(
                    color: _primaryDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _categories.map((cat) {
                    final isSelected = _category == cat['id'];
                    return FilterChip(
                      selected: isSelected,
                      onSelected: (_) => setState(() => _category = cat['id']),
                      label: Text(
                        cat['label'],
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? Colors.white : _primaryDark,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      backgroundColor: _surfaceVariant,
                      selectedColor: _primary,
                      checkmarkColor: Colors.white,
                      side: BorderSide(
                        color: isSelected ? _primary : const Color(0xFFDCEBE3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 8),

                // ✅ حالة المنتج
                const Text(
                  'حالة المنتج',
                  style: TextStyle(
                    color: _primaryDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _conditions.map((cond) {
                    final isSelected = _condition == cond['id'];
                    return FilterChip(
                      selected: isSelected,
                      onSelected: (_) =>
                          setState(() => _condition = cond['id']),
                      label: Text(
                        cond['label'],
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? Colors.white : _primaryDark,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      backgroundColor: _surfaceVariant,
                      selectedColor: cond['color'],
                      checkmarkColor: Colors.white,
                      side: BorderSide(
                        color: isSelected
                            ? cond['color']
                            : const Color(0xFFDCEBE3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 8),

                // ✅ خيارات إضافية
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildToggleChip(
                      label: 'حلال',
                      value: _isHalal,
                      onChanged: (v) => setState(() => _isHalal = v),
                    ),
                    _buildToggleChip(
                      label: 'نباتي',
                      value: _isVegetarian,
                      onChanged: (v) => setState(() => _isVegetarian = v),
                    ),
                    _buildToggleChip(
                      label: 'يحتاج تبريد',
                      value: _requiresRefrigeration,
                      onChanged: (v) =>
                          setState(() => _requiresRefrigeration = v),
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                const Divider(color: Color(0xFFE2EEE8)),
                const SizedBox(height: 14),

                // ✅ أزرار الإجراءات
                if (!isCancelled) ...[
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _isLoading ? null : _saveChanges,
                          style: FilledButton.styleFrom(
                            backgroundColor: _primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: _isLoading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_rounded, size: 18),
                          label: Text(
                            _isLoading ? 'جاري الحفظ...' : 'حفظ التغييرات',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _toggleStatus,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isActive ? _accent : _primary,
                            side: BorderSide(
                              color: isActive ? _accent : _primary,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: Icon(
                            isActive
                                ? Icons.pause_circle_outline_rounded
                                : Icons.play_circle_outline_rounded,
                            size: 18,
                          ),
                          label: Text(
                            isActive ? 'إيقاف مؤقت' : 'تشغيل',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _cancelOffer,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade700),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text(
                        'إلغاء العرض نهائياً',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _error.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: _error),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'هذا العرض ملغي ولا يمكن تعديله',
                            style: TextStyle(
                              color: _error,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleChip({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return FilterChip(
      selected: value,
      onSelected: onChanged,
      label: Text(
        label,
        style: TextStyle(
          color: value ? Colors.white : _primaryDark,
          fontWeight: value ? FontWeight.w800 : FontWeight.w600,
          fontSize: 11,
        ),
      ),
      backgroundColor: _surfaceVariant,
      selectedColor: _primary,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: value ? _primary : const Color(0xFFDCEBE3),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool numeric = false,
    bool requiredField = true,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      enabled: enabled,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
      textInputAction:
          maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(
          icon,
          color: enabled ? _muted : _muted.withValues(alpha: 0.4),
          size: 20,
        ),
        filled: true,
        fillColor:
            enabled ? _surfaceVariant : _surfaceVariant.withValues(alpha: 0.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        labelStyle: TextStyle(
          color: enabled ? _muted : _muted.withValues(alpha: 0.4),
          fontSize: 12,
        ),
        hintStyle: TextStyle(
          color: enabled ? _muted.withAlpha(150) : _muted.withAlpha(60),
          fontSize: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBE4D5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBE4D5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _muted.withValues(alpha: 0.2)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD64545)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD64545), width: 1.5),
        ),
        isDense: true,
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (requiredField && text.isEmpty) return 'هذا الحقل مطلوب';
        if (numeric &&
            text.isNotEmpty &&
            num.tryParse(_normalizeDigits(text).replaceAll(',', '.')) == null) {
          return 'اكتب رقمًا صحيحًا';
        }
        return null;
      },
    );
  }
}
