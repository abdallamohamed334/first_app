// lib/features/provider/presentation/pages/provider_edit_profile_page.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:loqma/features/provider/data/repositories/service_provider_repository.dart';

class ProviderEditProfilePage extends StatefulWidget {
  const ProviderEditProfilePage({super.key});

  @override
  State<ProviderEditProfilePage> createState() =>
      _ProviderEditProfilePageState();
}

class _ProviderEditProfilePageState extends State<ProviderEditProfilePage> {
  static const _bg = Color(0xFFF4F8F6);
  static const _primary = Color(0xFF0B7650);
  static const _blue = Color(0xFF3679C8);
  static const _ink = Color(0xFF123F31);
  static const _inkSoft = Color(0xFF315A45);
  static const _cardBg = Colors.white;
  static const _error = Color(0xFFD64545);

  /// ✅ الحد الأقصى لصور الأعمال
  static const int _maxPortfolioImages = 10;

  final _repo = ServiceProviderRepository();
  final _picker = ImagePicker();

  // Controllers
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _expCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _priceFromCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  Map<String, dynamic>? _provider;
  List<String> _skills = [];
  List<String> _serviceAreas = [];
  String? _pricingType = 'market';
  bool _acceptsInstallments = false;

  // Images
  String? _profileImageUrl;
  String? _coverImageUrl;
  List<String> _portfolioImages = [];
  XFile? _newProfileImage;
  XFile? _newCoverImage;
  final List<XFile> _newPortfolioImages = [];
  final List<String> _removedPortfolioUrls = [];

  final _newSkillCtrl = TextEditingController();
  final _newAreaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _expCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    _whatsappCtrl.dispose();
    _websiteCtrl.dispose();
    _priceFromCtrl.dispose();
    _newSkillCtrl.dispose();
    _newAreaCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final result = await _repo.getCurrentProvider();
    if (!mounted) return;

    result.fold(
      (err) {
        setState(() => _loading = false);
        _snack(err, error: true);
      },
      (provider) {
        setState(() {
          _provider = provider;
          _nameCtrl.text = provider['display_name']?.toString() ?? '';
          _bioCtrl.text = provider['bio']?.toString() ?? '';
          _expCtrl.text = provider['experience_years']?.toString() ?? '0';
          _cityCtrl.text = provider['city']?.toString() ?? '';
          _addressCtrl.text = provider['address']?.toString() ?? '';
          _whatsappCtrl.text = provider['whatsapp']?.toString() ?? '';
          _websiteCtrl.text = provider['website']?.toString() ?? '';
          _priceFromCtrl.text = provider['price_from']?.toString() ?? '';
          _pricingType = provider['pricing_type']?.toString() ?? 'market';
          _acceptsInstallments =
              provider['accepts_installments'] as bool? ?? false;

          _profileImageUrl = provider['profile_image_url']?.toString();
          _coverImageUrl = provider['cover_image_url']?.toString();

          final rawPortfolio = provider['portfolio_images'];
          if (rawPortfolio is List) {
            _portfolioImages = rawPortfolio.map((e) => e.toString()).toList();
          }

          final rawSkills = provider['skills'];
          if (rawSkills is List) {
            _skills = rawSkills.map((e) => e.toString()).toList();
          }

          final rawAreas = provider['service_areas'];
          if (rawAreas is List) {
            _serviceAreas = rawAreas.map((e) => e.toString()).toList();
          }

          _loading = false;
        });
      },
    );
  }

  // ══════════════════════════════════════════════════════════
  // Image Pickers
  // ══════════════════════════════════════════════════════════
  Future<void> _pickProfileImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 800,
      );
      if (picked == null) return;
      setState(() => _newProfileImage = picked);
    } catch (e) {
      _snack('تعذر اختيار الصورة', error: true);
    }
  }

  Future<void> _pickCoverImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (picked == null) return;
      setState(() => _newCoverImage = picked);
    } catch (e) {
      _snack('تعذر اختيار الصورة', error: true);
    }
  }

  Future<void> _pickPortfolioImages() async {
    try {
      final total = _portfolioImages.length + _newPortfolioImages.length;
      // ✅ 10 صور كحد أقصى
      if (total >= _maxPortfolioImages) {
        _snack(
          'يمكنك إضافة $_maxPortfolioImages صور كحد أقصى',
          error: true,
        );
        return;
      }

      final picked = await _picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (picked.isEmpty) return;

      setState(() {
        _newPortfolioImages.addAll(
          picked.take(_maxPortfolioImages - total),
        );
      });
    } catch (e) {
      _snack('تعذر اختيار الصور', error: true);
    }
  }

  void _removeExistingPortfolio(int index) {
    setState(() {
      final url = _portfolioImages.removeAt(index);
      _removedPortfolioUrls.add(url);
    });
  }

  void _removeNewPortfolio(int index) {
    setState(() => _newPortfolioImages.removeAt(index));
  }

  // ══════════════════════════════════════════════════════════
  // Save
  // ══════════════════════════════════════════════════════════
  Future<void> _save() async {
    if (_provider == null) return;

    if (_nameCtrl.text.trim().length < 3) {
      _snack('الاسم 3 أحرف على الأقل', error: true);
      return;
    }

    setState(() => _saving = true);

    final userId =
        _provider!['user_id']?.toString() ?? _provider!['id'].toString();

    try {
      // ✅ رفع صورة البروفايل
      String? newProfileUrl = _profileImageUrl;
      if (_newProfileImage != null) {
        final result = await _repo.uploadProviderImage(
          userId: userId,
          imagePath: _newProfileImage!.path,
          type: 'profile',
        );
        result.fold(
          (err) => throw Exception(err),
          (url) => newProfileUrl = url,
        );
      }

      // ✅ رفع صورة الغلاف
      String? newCoverUrl = _coverImageUrl;
      if (_newCoverImage != null) {
        final result = await _repo.uploadProviderImage(
          userId: userId,
          imagePath: _newCoverImage!.path,
          type: 'cover',
        );
        result.fold(
          (err) => throw Exception(err),
          (url) => newCoverUrl = url,
        );
      }

      // ✅ رفع صور الأعمال الجديدة
      final uploadedPortfolio = <String>[];
      for (final img in _newPortfolioImages) {
        final result = await _repo.uploadProviderImage(
          userId: userId,
          imagePath: img.path,
          type: 'portfolio',
        );
        await result.fold(
          (err) async {},
          (url) async {
            uploadedPortfolio.add(url);
          },
        );
      }

      // ✅ دمج الصور
      final finalPortfolio = [
        ..._portfolioImages,
        ...uploadedPortfolio,
      ];

      // ✅ حفظ البيانات
      final result = await _repo.updateProviderProfile(
        providerId: _provider!['id'].toString(),
        displayName: _nameCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
        experienceYears: int.tryParse(_expCtrl.text.trim()) ?? 0,
        skills: _skills,
        city: _cityCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        serviceAreas: _serviceAreas,
        pricingType: _pricingType,
        priceFrom: double.tryParse(_priceFromCtrl.text.trim()),
        acceptsInstallments: _acceptsInstallments,
        whatsapp: _whatsappCtrl.text.trim(),
        website: _websiteCtrl.text.trim(),
        profileImageUrl: newProfileUrl,
        coverImageUrl: newCoverUrl,
        portfolioImages: finalPortfolio,
      );

      if (!mounted) return;

      result.fold(
        (err) {
          setState(() => _saving = false);
          _snack(err, error: true);
        },
        (updated) {
          setState(() {
            _provider = updated;
            _saving = false;
          });
          _snack('تم حفظ التعديلات ✅');
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) context.pop();
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('تعذر رفع الصور: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg, textDirection: TextDirection.rtl),
          backgroundColor: error ? _error : _primary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _cardBg,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_forward_rounded, color: _ink),
          ),
          title: const Text(
            'تعديل بروفايلي',
            style: TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: _blue),
              )
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildImagesSection(),
                    const SizedBox(height: 16),
                    _buildSection(
                      title: 'المعلومات الأساسية',
                      icon: Icons.person_rounded,
                      children: [
                        _field(
                          controller: _nameCtrl,
                          label: 'الاسم *',
                          hint: 'اسمك اللي هيظهر للناس',
                          icon: Icons.badge_rounded,
                          required: true,
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _cityCtrl,
                          label: 'المدينة *',
                          hint: 'مثال: طنطا',
                          icon: Icons.location_city_rounded,
                          required: true,
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _bioCtrl,
                          label: 'نبذة عنك',
                          hint: 'اكتب نبذة قصيرة عنك وعن شغلك',
                          icon: Icons.info_outline_rounded,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _expCtrl,
                          label: 'سنوات الخبرة',
                          hint: 'مثال: 5',
                          icon: Icons.workspace_premium_rounded,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      title: 'المهارات',
                      icon: Icons.psychology_rounded,
                      children: [
                        _chipsInput(
                          items: _skills,
                          controller: _newSkillCtrl,
                          hint: 'أضف مهارة',
                          onAdd: (value) {
                            if (value.trim().isEmpty) return;
                            if (_skills.contains(value.trim())) return;
                            setState(() => _skills.add(value.trim()));
                            _newSkillCtrl.clear();
                          },
                          onRemove: (value) {
                            setState(() => _skills.remove(value));
                          },
                          color: _blue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      title: 'مناطق الخدمة',
                      icon: Icons.map_rounded,
                      children: [
                        _chipsInput(
                          items: _serviceAreas,
                          controller: _newAreaCtrl,
                          hint: 'أضف منطقة',
                          onAdd: (value) {
                            if (value.trim().isEmpty) return;
                            if (_serviceAreas.contains(value.trim())) return;
                            setState(() => _serviceAreas.add(value.trim()));
                            _newAreaCtrl.clear();
                          },
                          onRemove: (value) {
                            setState(() => _serviceAreas.remove(value));
                          },
                          color: _primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      title: 'العنوان التفصيلي',
                      icon: Icons.location_on_rounded,
                      children: [
                        _field(
                          controller: _addressCtrl,
                          label: 'العنوان',
                          hint: 'العنوان التفصيلي',
                          icon: Icons.home_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      title: 'الأسعار',
                      icon: Icons.payments_rounded,
                      children: [
                        _pricingDropdown(),
                        const SizedBox(height: 12),
                        _field(
                          controller: _priceFromCtrl,
                          label: 'السعر يبدأ من (جنيه)',
                          hint: 'مثال: 100',
                          icon: Icons.attach_money_rounded,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _switchRow(
                          label: 'أقبل الدفع بالتقسيط',
                          value: _acceptsInstallments,
                          onChanged: (v) => setState(
                            () => _acceptsInstallments = v,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      title: 'التواصل',
                      icon: Icons.contact_phone_rounded,
                      children: [
                        _field(
                          controller: _whatsappCtrl,
                          label: 'رقم الواتساب',
                          hint: '01012345678',
                          icon: Icons.chat_rounded,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _websiteCtrl,
                          label: 'الموقع الإلكتروني (اختياري)',
                          hint: 'https://example.com',
                          icon: Icons.language_rounded,
                          keyboardType: TextInputType.url,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_rounded, size: 22),
                        label: Text(
                          _saving ? 'جاري الحفظ...' : 'حفظ التعديلات',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
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

  // ══════════════════════════════════════════════════════════
  // Images Section
  // ══════════════════════════════════════════════════════════
  Widget _buildImagesSection() {
    final currentTotal = _portfolioImages.length + _newPortfolioImages.length;
    final canAddMore = currentTotal < _maxPortfolioImages;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _inkSoft.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: _inkSoft.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library_rounded,
                    color: _blue, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'الصور',
                style: TextStyle(
                  color: _ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Profile Image
          _imageLabel('صورة البروفايل', required: true),
          const SizedBox(height: 8),
          Center(
            child: GestureDetector(
              onTap: _pickProfileImage,
              child: Stack(
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _blue.withValues(alpha: 0.08),
                      border: Border.all(color: _blue, width: 2),
                    ),
                    child: ClipOval(
                      child: _newProfileImage != null
                          ? Image.file(
                              File(_newProfileImage!.path),
                              fit: BoxFit.cover,
                            )
                          : (_profileImageUrl != null &&
                                  _profileImageUrl!.isNotEmpty)
                              ? Image.network(
                                  _profileImageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _imagePlaceholder(Icons.person_rounded),
                                )
                              : _imagePlaceholder(Icons.person_rounded),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Cover Image
          _imageLabel('صورة الغلاف'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickCoverImage,
            child: Container(
              height: 130,
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _blue.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _newCoverImage != null
                    ? Image.file(
                        File(_newCoverImage!.path),
                        fit: BoxFit.cover,
                        width: double.infinity,
                      )
                    : (_coverImageUrl != null && _coverImageUrl!.isNotEmpty)
                        ? Image.network(
                            _coverImageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => _coverPlaceholder(),
                          )
                        : _coverPlaceholder(),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Portfolio
          Row(
            children: [
              Expanded(
                child: _imageLabel(
                  'صور أعمالك (حتى $_maxPortfolioImages صور)',
                ),
              ),
              Text(
                '$currentTotal/$_maxPortfolioImages',
                style: TextStyle(
                  color: canAddMore ? _blue : _error,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // Existing
                ..._portfolioImages.asMap().entries.map((entry) {
                  return _portfolioTile(
                    image: NetworkImage(entry.value),
                    onRemove: () => _removeExistingPortfolio(entry.key),
                  );
                }),

                // New
                ..._newPortfolioImages.asMap().entries.map((entry) {
                  return _portfolioTile(
                    image: FileImage(File(entry.value.path)) as ImageProvider,
                    onRemove: () => _removeNewPortfolio(entry.key),
                    isNew: true,
                  );
                }),

                // Add button
                if (canAddMore)
                  GestureDetector(
                    onTap: _pickPortfolioImages,
                    child: Container(
                      width: 100,
                      height: 100,
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: _blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _blue.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_rounded,
                              color: _blue, size: 28),
                          const SizedBox(height: 4),
                          Text(
                            'أضف صور',
                            style: TextStyle(
                              color: _blue,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageLabel(String text, {bool required = false}) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            color: _ink,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 4),
          const Text(
            '*',
            style: TextStyle(
              color: _error,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ],
    );
  }

  Widget _imagePlaceholder(IconData icon) {
    return Container(
      color: _blue.withValues(alpha: 0.1),
      alignment: Alignment.center,
      child: Icon(icon, color: _blue, size: 42),
    );
  }

  Widget _coverPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wallpaper_rounded,
              color: _blue.withValues(alpha: 0.5), size: 36),
          const SizedBox(height: 6),
          Text(
            'أضف صورة غلاف',
            style: TextStyle(
              color: _blue.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _portfolioTile({
    required ImageProvider image,
    required VoidCallback onRemove,
    bool isNew = false,
  }) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isNew ? _primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image(
              image: image,
              fit: BoxFit.cover,
              width: 100,
              height: 100,
              errorBuilder: (_, __, ___) => Container(
                color: _blue.withValues(alpha: 0.1),
                child: const Icon(Icons.broken_image_outlined, color: _blue),
              ),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  // Shared widgets
  // ══════════════════════════════════════════════════════════
  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _inkSoft.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: _inkSoft.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _blue, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    bool required = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      style: const TextStyle(
        color: _ink,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
          color: _inkSoft.withValues(alpha: 0.4),
          fontSize: 13,
        ),
        labelStyle: TextStyle(
          color: required ? _error : _inkSoft,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: Icon(icon, color: _blue, size: 20),
        filled: true,
        fillColor: _bg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _inkSoft.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _inkSoft.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _blue, width: 1.6),
        ),
      ),
    );
  }

  Widget _chipsInput({
    required List<String> items,
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onAdd,
    required ValueChanged<String> onRemove,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: _inkSoft.withValues(alpha: 0.4),
                    fontSize: 12.5,
                  ),
                  filled: true,
                  fillColor: _bg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _inkSoft.withValues(alpha: 0.12),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _inkSoft.withValues(alpha: 0.12),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: color, width: 1.5),
                  ),
                ),
                onSubmitted: onAdd,
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => onAdd(controller.text),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => onRemove(item),
                      child: Icon(Icons.close_rounded, color: color, size: 14),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _pricingDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _pricingType,
      decoration: InputDecoration(
        labelText: 'نوع التسعير',
        labelStyle: const TextStyle(
          color: _inkSoft,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: const Icon(Icons.tune_rounded, color: _blue, size: 20),
        filled: true,
        fillColor: _bg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _inkSoft.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _inkSoft.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _blue, width: 1.6),
        ),
      ),
      items: const [
        DropdownMenuItem(value: 'market', child: Text('حسب السوق')),
        DropdownMenuItem(value: 'fixed', child: Text('سعر ثابت')),
        DropdownMenuItem(value: 'hourly', child: Text('بالساعة')),
        DropdownMenuItem(value: 'free', child: Text('مجاناً')),
      ],
      onChanged: (v) => setState(() => _pricingType = v),
    );
  }

  Widget _switchRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _inkSoft.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: _primary,
          ),
        ],
      ),
    );
  }
}
