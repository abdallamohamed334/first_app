import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loqma/core/services/loqma_image_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:loqma/features/auth/presentation/pages/login_page.dart';

class CharityProfilePage extends StatefulWidget {
  const CharityProfilePage({super.key});

  @override
  State<CharityProfilePage> createState() => _CharityProfilePageState();
}

class _CharityProfilePageState extends State<CharityProfilePage> {
  static const _green = Color(0xFF006C48);
  static const _deepGreen = Color(0xFF001E15);
  static const _background = Color(0xFFF8FAFA);

  late Future<Map<String, dynamic>> _future;
  final _imagePicker = ImagePicker();
  final _imageStorage = loqmaImageStorageService();
  XFile? _selectedImage;
  bool _loggingOut = false;
  bool _uploadingImage = false;

  @override
  void initState() {
    super.initState();
    _future = _loadProfile();
  }

  Future<Map<String, dynamic>> _loadProfile() async {
    final client = Supabase.instance.client;
    final authId = client.auth.currentUser?.id;
    if (authId == null || authId.isEmpty) {
      throw Exception('انتهت الجلسة الحالية');
    }

    final user = await client
        .from('users')
        .select('user_type, name, email, phone, avatar_url')
        .eq('id', authId)
        .maybeSingle();
    final role = user?['user_type']?.toString().trim().toLowerCase();
    if (role != 'charity') {
      throw Exception('هذه الصفحة متاحة لحسابات الجمعيات فقط');
    }

    final charity = await client
        .from('charities')
        .select(
          'id, name, logo, image_url, logo_url, description, phone, email, address, status, is_verified',
        )
        .eq('user_id', authId)
        .maybeSingle();
    if (charity == null) {
      throw Exception('لا توجد جمعية مرتبطة بهذا الحساب');
    }

    return {
      'user': Map<String, dynamic>.from(user ?? const {}),
      'charity': Map<String, dynamic>.from(charity),
    };
  }

  Future<void> _pickAndSaveLogo() async {
    if (_uploadingImage) return;
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 86,
        maxWidth: 1400,
      );
      if (!mounted || image == null) return;
      setState(() {
        _selectedImage = image;
        _uploadingImage = true;
      });
      final url = await _imageStorage.uploadCharityLogo(image);
      final authId = Supabase.instance.client.auth.currentUser?.id;
      if (authId == null || authId.isEmpty) {
        throw StateError('انتهت الجلسة الحالية');
      }
      await Supabase.instance.client
          .from('charities')
          .update({'logo': url, 'logo_url': url, 'image_url': url}).eq(
              'user_id', authId);
      if (!mounted) return;
      setState(() {
        _uploadingImage = false;
        _future = _loadProfile();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('تم تحديث صورة الجمعية بنجاح'),
            behavior: SnackBarBehavior.floating),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('تعذر رفع صورة الجمعية، حاول مرة أخرى'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريدين تسجيل الخروج من حساب الجمعية؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _loggingOut = true;
    });
    try {
      await Supabase.instance.client.auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove('auth_token'),
        prefs.remove('user_id'),
        prefs.remove('user_type'),
        prefs.remove('business_id'),
        prefs.remove('business_type'),
        prefs.remove('restaurant_id'),
        prefs.remove('charity_id'),
      ]);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loggingOut = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('تعذر تسجيل الخروج، حاول مرة أخرى'),
            backgroundColor: Color(0xFFB54747),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _refresh() async {
    final next = _loadProfile();
    if (!mounted) return;
    setState(() {
      _future = next;
    });
    try {
      await next;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _background,
          foregroundColor: _deepGreen,
          elevation: 0,
          title: const Text(
            'ملف الجمعية',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(
              onPressed: _refresh,
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: _green),
              );
            }
            if (snapshot.hasError) {
              return _errorState(snapshot.error.toString());
            }
            final data = snapshot.data!;
            return _content(data['charity'] as Map<String, dynamic>);
          },
        ),
      ),
    );
  }

  Widget _content(Map<String, dynamic> charity) {
    final name = _text(charity['name'], fallback: 'الجمعية');
    final logo = _firstImage(charity);
    final description = _text(
      charity['description'],
      fallback: 'نعمل على دعم المجتمع وتوصيل التبرعات إلى مستحقيها.',
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_deepGreen, _green],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            children: [
              _logo(logo, 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Icon(
                          charity['is_verified'] == true
                              ? Icons.verified_rounded
                              : Icons.pending_outlined,
                          color: const Color(0xFF97F2C3),
                          size: 17,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          charity['is_verified'] == true
                              ? 'جمعية موثقة'
                              : 'قيد التحقق',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _uploadingImage ? null : _pickAndSaveLogo,
          icon: _uploadingImage
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.photo_camera_outlined),
          label: Text(
              _uploadingImage ? 'جارٍ رفع الصورة...' : 'تغيير صورة الجمعية'),
        ),
        const SizedBox(height: 16),
        _section(
          title: 'عن الجمعية',
          child: Text(
            description,
            style: const TextStyle(
              color: Color(0xFF52675D),
              height: 1.6,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _section(
          title: 'بيانات التواصل',
          child: Column(
            children: [
              _infoRow(
                  Icons.location_on_outlined, 'العنوان', charity['address']),
              _infoRow(Icons.phone_outlined, 'الهاتف', charity['phone']),
              _infoRow(
                  Icons.email_outlined, 'البريد الإلكتروني', charity['email']),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: _loggingOut ? null : _logout,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF0CACA)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFFFFE7E7),
                    foregroundColor: const Color(0xFFB54747),
                    child: _loggingOut
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.logout_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _loggingOut ? 'جارٍ تسجيل الخروج...' : 'تسجيل الخروج',
                      style: const TextStyle(
                        color: Color(0xFFB54747),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_left_rounded,
                      color: Color(0xFFB54747)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1E8E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _deepGreen,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, dynamic value) {
    final text = _text(value, fallback: 'غير متاح');
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Icon(icon, color: _green, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFF7A8A83), fontSize: 10)),
                const SizedBox(height: 2),
                Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _deepGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _logo(String value, double size) {
    if (value.isEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: const Color(0x4097F2C3),
        child: const Icon(Icons.volunteer_activism_rounded,
            color: Colors.white, size: 31),
      );
    }
    return ClipOval(
      child: Image.network(
        value,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => CircleAvatar(
          radius: size / 2,
          backgroundColor: const Color(0x4097F2C3),
          child: const Icon(Icons.volunteer_activism_rounded,
              color: Colors.white, size: 31),
        ),
      ),
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: _green, size: 54),
            const SizedBox(height: 13),
            Text(
              message.replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _deepGreen, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  String _firstImage(Map<String, dynamic> row) {
    for (final key in ['image_url', 'logo_url', 'logo']) {
      final value = row[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}
