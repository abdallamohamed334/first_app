// lib/features/business/presentation/pages/add_offer_page.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loqma/core/services/loqma_image_storage_service.dart';
import 'package:loqma/core/services/supabase_service.dart';

class AddOfferPage extends StatefulWidget {
  final String businessId;

  const AddOfferPage({
    super.key,
    required this.businessId,
  });

  @override
  State<AddOfferPage> createState() => _AddOfferPageState();
}

class _AddOfferPageState extends State<AddOfferPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController();
  final _foodTypeController = TextEditingController();
  final _pickupLocationController = TextEditingController();

  final _imagePicker = ImagePicker();
  final _imageStorage = LoqmaImageStorageService();
  XFile? _selectedImage;
  bool _isLoading = false;
  bool _isHalal = false;
  bool _isVegetarian = false;
  bool _requiresRefrigeration = false;
  String? _selectedCondition = 'fresh';
  String? _selectedPackaging = 'box';

  final List<String> _conditions = ['fresh', 'good', 'acceptable'];
  final List<String> _packagingTypes = ['box', 'bag', 'container', 'other'];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _foodTypeController.dispose();
    _pickupLocationController.dispose();
    super.dispose();
  }

  Future<void> _submitOffer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabase = SupabaseService();

      // ✅ حساب وقت الانتهاء (بعد 4 ساعات من الآن)
      final expiryTime = DateTime.now().add(const Duration(hours: 4));

      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl =
            await _imageStorage.uploadRestaurantOfferImage(_selectedImage!);
      }

      // ✅ ✅ ✅ استخدم business_id فقط (مش restaurant_id)
      final data = {
        'business_id': widget.businessId, // ✅ business_id فقط
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'quantity': int.parse(_quantityController.text),
        'food_type': _foodTypeController.text.trim(),
        'pickup_location': _pickupLocationController.text.trim(),
        'expiry_time': expiryTime.toIso8601String(),
        'status': 'available',
        'is_halal': _isHalal,
        'is_vegetarian': _isVegetarian,
        'requires_refrigeration': _requiresRefrigeration,
        'food_condition': _selectedCondition,
        'packaging': _selectedPackaging,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'image': imageUrl,
        'images': imageUrl == null ? <String>[] : <String>[imageUrl],
      };

      // ✅ ✅ ✅ تأكد من أن البيانات مفيش فيها restaurant_id
      print('📌 Data being sent: $data');
      print('📌 Keys: ${data.keys}');

      final response = await supabase.client
          .from('food_offers')
          .insert(data)
          .select()
          .single();

      print('✅ Offer created: $response');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم إضافة العرض بنجاح!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('❌ Error creating offer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ حدث خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('➕ إضافة عرض جديد'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ عنوان العرض
              _buildTextField(
                controller: _titleController,
                label: 'عنوان العرض *',
                hint: 'مثال: وجبات أرز ودجاج',
                icon: Icons.title,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال عنوان العرض';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ✅ الوصف
              _buildTextField(
                controller: _descriptionController,
                label: 'الوصف',
                hint: 'وصف تفصيلي للوجبات...',
                icon: Icons.description,
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // ✅ الكمية
              _buildTextField(
                controller: _quantityController,
                label: 'الكمية *',
                hint: 'عدد الوجبات المتاحة',
                icon: Icons.food_bank,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال الكمية';
                  }
                  if (int.tryParse(value) == null) {
                    return 'الرجاء إدخال رقم صحيح';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ✅ نوع الطعام
              _buildTextField(
                controller: _foodTypeController,
                label: 'نوع الطعام',
                hint: 'مثال: وجبات رئيسية',
                icon: Icons.restaurant_menu,
              ),
              const SizedBox(height: 16),

              // ✅ موقع الاستلام
              _buildTextField(
                controller: _pickupLocationController,
                label: 'موقع الاستلام *',
                hint: 'طنطا - شارع البحر',
                icon: Icons.location_on,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال موقع الاستلام';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildImagePickerCard(),
              const SizedBox(height: 16),

              // ✅ وقت الانتهاء (تلقائي)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '⏰ وقت الانتهاء',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            'بعد 4 ساعات من الآن',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ✅ خيارات إضافية
              const Text(
                'خيارات إضافية',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // ✅ Checkboxes
              _buildCheckbox(
                value: _isHalal,
                onChanged: (value) => setState(() => _isHalal = value!),
                label: 'حلال',
                icon: Icons.check_circle,
                color: Colors.green,
              ),
              _buildCheckbox(
                value: _isVegetarian,
                onChanged: (value) => setState(() => _isVegetarian = value!),
                label: 'نباتي',
                icon: Icons.eco,
                color: Colors.lightGreen,
              ),
              _buildCheckbox(
                value: _requiresRefrigeration,
                onChanged: (value) =>
                    setState(() => _requiresRefrigeration = value!),
                label: 'يحتاج تبريد',
                icon: Icons.ac_unit,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),

              // ✅ حالة الطعام
              const Text(
                'حالة الطعام',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _conditions.map((condition) {
                  final isSelected = _selectedCondition == condition;
                  return ChoiceChip(
                    label: Text(_getConditionLabel(condition)),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedCondition = condition);
                    },
                    selectedColor: Colors.green,
                    backgroundColor: Colors.grey.shade100,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // ✅ نوع التغليف
              const Text(
                'نوع التغليف',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _packagingTypes.map((packaging) {
                  final isSelected = _selectedPackaging == packaging;
                  return ChoiceChip(
                    label: Text(_getPackagingLabel(packaging)),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedPackaging = packaging);
                    },
                    selectedColor: Colors.green,
                    backgroundColor: Colors.grey.shade100,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // ✅ أزرار
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitOffer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'إضافة العرض',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ============ Widgets ============

  Future<void> _pickOfferImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 84,
        maxWidth: 1400,
      );
      if (!mounted || image == null) return;
      setState(() => _selectedImage = image);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر اختيار صورة الوجبة، حاول مرة أخرى')),
      );
    }
  }

  Widget _buildImagePickerCard() {
    return InkWell(
      onTap: _isLoading ? null : _pickOfferImage,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: _selectedImage == null
            ? const Column(
                children: [
                  Icon(Icons.add_photo_alternate_rounded,
                      size: 42, color: Colors.green),
                  SizedBox(height: 8),
                  Text('إضافة صورة الوجبة',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Text('الصورة ستظهر في كروت العروض وتفاصيل العرض'),
                ],
              )
            : FutureBuilder<Uint8List>(
                future: _selectedImage!.readAsBytes(),
                builder: (_, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox(
                        height: 120,
                        child: Center(child: CircularProgressIndicator()));
                  }
                  return Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(snapshot.data!,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover),
                      ),
                      const SizedBox(height: 8),
                      const Text('اضغط لتغيير الصورة'),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  Widget _buildCheckbox({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      title: Text(label),
      secondary: Icon(icon, color: color),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: color,
    );
  }

  String _getConditionLabel(String condition) {
    switch (condition) {
      case 'fresh':
        return 'طازج';
      case 'good':
        return 'جيد';
      case 'acceptable':
        return 'مقبول';
      default:
        return condition;
    }
  }

  String _getPackagingLabel(String packaging) {
    switch (packaging) {
      case 'box':
        return 'علبة';
      case 'bag':
        return 'كيس';
      case 'container':
        return 'وعاء';
      case 'other':
        return 'أخرى';
      default:
        return packaging;
    }
  }
}
