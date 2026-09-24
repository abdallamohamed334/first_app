// lib/features/auth/presentation/pages/complete_profile_page.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loqma/core/models/user_model.dart';
import 'package:loqma/core/services/storage_service.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'location_picker_page.dart';

// ✅ Import صفحات الـ Home
import 'package:loqma/features/userhome/presentation/pages/user_home_page.dart'
    as user_home;
import 'package:loqma/features/institutions/presentation/pages/institutions_home_page.dart';

class CompleteProfilePage extends StatefulWidget {
  final UserModel user;
  final String role;

  const CompleteProfilePage({
    super.key,
    required this.user,
    required this.role,
  });

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  final _supabase = SupabaseService();
  final _storage = StorageService.instance;
  final _picker = ImagePicker();

  XFile? _avatarFile;
  String? _avatarUrl;
  String? _selectedCity;
  bool _saving = false;

  // ✅ إحداثيات الموقع
  double? _lat;
  double? _lng;

  // ── ألوان
  static const _bg = Color(0xFFF5F8F6);
  static const _primary = Color(0xFF0B7650);
  static const _primaryLight = Color(0xFF25B77C);
  static const _darkGreen = Color(0xFF123F31);
  static const _red = Color(0xFFD64545);

  static const _cities = [
    'طنطا',
    'القاهرة',
    'الجيزة',
    'الإسكندرية',
    'المنصورة',
    'بورسعيد',
    'السويس',
    'الإسماعيلية',
    'أسوان',
    'الأقصر',
    'أسيوط',
    'الفيوم',
    'بني سويف',
    'المنيا',
    'سوهاج',
    'قنا',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.user.name ?? '';
    _emailCtrl.text = widget.user.email ?? '';
    _avatarUrl = widget.user.avatarUrl;
    _selectedCity = widget.user.city;
    if (_selectedCity != null && !_cities.contains(_selectedCity)) {
      _selectedCity = null;
    }
    _lat = widget.user.lat;
    _lng = widget.user.lng;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ الحل: نفس أسلوب OtpVerifyPage — Navigator بدل GoRouter
  // ═══════════════════════════════════════════════════════════
  void _navigateToHome() {
    // المؤسسة → InstitutionsHome
    if (widget.role == 'institution') {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const InstitutionsHomePage(),
        ),
        (route) => false, // ← يمسح كل الـ routes القديمة
      );
      return;
    }

    // مقدم خدمة / مستخدم → UserHome
    // (لأن providerHome حاليًا = UserHome)
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const user_home.UserHomePage(),
      ),
      (route) => false,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🗺️ فتح خريطة تحديد الموقع
  // ═══════════════════════════════════════════════════════════
  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          initialLat: _lat,
          initialLng: _lng,
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _lat = (result['lat'] as num?)?.toDouble();
      _lng = (result['lng'] as num?)?.toDouble();
    });
  }

  // ═══════════════════════════════════════════════════════════
  // Pick Avatar
  // ═══════════════════════════════════════════════════════════
  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 800,
      );
      if (picked == null) return;
      if (!mounted) return;
      setState(() => _avatarFile = picked);
    } catch (e) {
      debugPrint('❌ pickAvatar error: $e');
      _showError('تعذر اختيار الصورة');
    }
  }

  void _showAvatarSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'اختار صورة',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _darkGreen,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading:
                      const Icon(Icons.camera_alt_rounded, color: _primary),
                  title: const Text('الكاميرا'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _pickAvatar(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading:
                      const Icon(Icons.photo_library_rounded, color: _primary),
                  title: const Text('معرض الصور'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _pickAvatar(ImageSource.gallery);
                  },
                ),
                if (_avatarFile != null || _avatarUrl != null)
                  ListTile(
                    leading: const Icon(Icons.delete_rounded, color: _red),
                    title:
                        const Text('مسح الصورة', style: TextStyle(color: _red)),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      setState(() {
                        _avatarFile = null;
                        _avatarUrl = null;
                      });
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Save
  // ═══════════════════════════════════════════════════════════
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCity == null || _selectedCity!.isEmpty) {
      _showError('اختار المدينة');
      return;
    }
    if (_lat == null || _lng == null) {
      _showError('حدّد موقعك على الخريطة علشان نعرضلك العروض القريبة');
      return;
    }

    setState(() => _saving = true);

    try {
      String? avatarUrl = _avatarUrl;
      if (_avatarFile != null) {
        try {
          avatarUrl = await _storage.uploadAvatar(
            userId: widget.user.id,
            imageFile: _avatarFile!,
          );
        } catch (e) {
          debugPrint('⚠️ Avatar upload failed: $e');
        }
      }

      await _supabase.updateProfile(
        userId: widget.user.id,
        name: _nameCtrl.text.trim(),
        phone: widget.user.phone,
        city: _selectedCity,
        address:
            _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        avatarUrl: avatarUrl,
        lat: _lat,
        lng: _lng,
      );

      final emailInput = _emailCtrl.text.trim();
      if (emailInput.isNotEmpty) {
        try {
          await _supabase.client
              .from('users')
              .update({'email': emailInput}).eq('id', widget.user.id);
        } catch (e) {
          debugPrint('⚠️ Email update failed: $e');
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم حفظ بياناتك، أهلًا بيك في جُود!'),
          backgroundColor: _primary,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      // ✅ التوجيه بـ Navigator (بدل context.go)
      debugPrint(
          '🔴 [CompleteProfile] navigating to home, role=${widget.role}');
      _navigateToHome();
    } catch (e) {
      debugPrint('❌ CompleteProfile error: $e');
      if (mounted) _showError('تعذر حفظ البيانات، حاول تاني');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
  }

  // ═══════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: SafeArea(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  children: [
                    // ── Top Bar
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_primary, _primaryLight],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'جُود',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: _primary.withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded,
                                  color: _primary, size: 14),
                              SizedBox(width: 5),
                              Text(
                                'تم التحقق',
                                style: TextStyle(
                                  color: _primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'كمّل بياناتك',
                      style: TextStyle(
                        color: _darkGreen,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'خطوة أخيرة قبل ما تبدأ',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.55),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 28),

                    _buildAvatarPicker(),
                    const SizedBox(height: 28),

                    // ── الاسم
                    _buildLabel('الاسم *'),
                    _buildField(
                      controller: _nameCtrl,
                      hint: 'اكتب اسمك',
                      icon: Icons.person_rounded,
                      validator: (v) => (v?.trim().length ?? 0) < 3
                          ? 'الاسم 3 أحرف على الأقل'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // ── المدينة
                    _buildLabel('المدينة *'),
                    _buildCityDropdown(),
                    const SizedBox(height: 16),

                    // ── الموقع
                    _buildLabel('موقعك على الخريطة *'),
                    _buildLocationField(),
                    const SizedBox(height: 16),

                    // ── الإيميل
                    _buildLabel('الإيميل (اختياري)'),
                    _buildField(
                      controller: _emailCtrl,
                      hint: 'example@mail.com',
                      icon: Icons.alternate_email_rounded,
                      keyboard: TextInputType.emailAddress,
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return null;
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(t)) {
                          return 'إيميل غير صحيح';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── العنوان
                    _buildLabel('العنوان (اختياري)'),
                    _buildField(
                      controller: _addressCtrl,
                      hint: 'شارع البحر، طنطا',
                      icon: Icons.location_on_rounded,
                    ),
                    const SizedBox(height: 16),

                    // ── نبذة
                    _buildLabel('نبذة عنك (اختياري)'),
                    _buildField(
                      controller: _bioCtrl,
                      hint: 'اكتب نبذة قصيرة عنك',
                      icon: Icons.info_outline_rounded,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 28),

                    // ── Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          disabledBackgroundColor:
                              _primary.withValues(alpha: 0.5),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_rounded, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'ابدأ رحلتك',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Widgets
  // ═══════════════════════════════════════════════════════════
  Widget _buildLocationField() {
    final hasLocation = _lat != null && _lng != null;

    return InkWell(
      onTap: _openLocationPicker,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasLocation
                ? _primary.withValues(alpha: 0.5)
                : const Color(0xFFE2ECE7),
            width: hasLocation ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.map_rounded,
                color: _primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasLocation
                        ? 'تم تحديد الموقع ✅'
                        : 'اختار موقعك على الخريطة',
                    style: TextStyle(
                      color: hasLocation ? _primary : _darkGreen,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasLocation
                        ? '${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}'
                        : 'علشان نعرضلك العروض القريبة منك',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              hasLocation
                  ? Icons.edit_location_alt_rounded
                  : Icons.arrow_back_ios_new_rounded,
              color: _primary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarPicker() {
    return GestureDetector(
      onTap: _showAvatarSheet,
      child: Column(
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _primary, width: 3),
              boxShadow: [
                BoxShadow(
                  color: _primary.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipOval(
              child: _avatarFile != null
                  ? Image.file(File(_avatarFile!.path), fit: BoxFit.cover)
                  : (_avatarUrl != null && _avatarUrl!.isNotEmpty
                      ? Image.network(
                          _avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _avatarPlaceholder(),
                        )
                      : _avatarPlaceholder()),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: _primary.withValues(alpha: 0.25)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.camera_alt_rounded, color: _primary, size: 14),
                SizedBox(width: 5),
                Text(
                  'أضف صورة',
                  style: TextStyle(
                    color: _primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      color: _primary.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: const Icon(Icons.person_rounded, color: _primary, size: 52),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          text,
          style: const TextStyle(
            color: _darkGreen,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboard,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: _darkGreen, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.black.withValues(alpha: 0.35),
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: _primary, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2ECE7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2ECE7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _red),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildCityDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2ECE7)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCity,
          isExpanded: true,
          dropdownColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          hint: Row(
            children: [
              const Icon(Icons.location_city_rounded,
                  color: _primary, size: 20),
              const SizedBox(width: 10),
              Text(
                'اختار مدينتك',
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.35),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _primary),
          items: _cities.map((c) {
            return DropdownMenuItem<String>(
              value: c,
              child: Text(
                c,
                style: const TextStyle(
                  color: _darkGreen,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }).toList(),
          onChanged: (v) => setState(() => _selectedCity = v),
        ),
      ),
    );
  }
}
