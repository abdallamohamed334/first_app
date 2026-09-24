// lib/features/institutions/presentation/pages/institution_profile_page.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/auth/presentation/pages/login_page.dart';
import 'package:loqma/features/institutions/data/repositories/institutions_repository.dart';
import 'package:loqma/features/institutions/domain/entities/institution.dart';

class InstitutionProfilePage extends StatefulWidget {
  final Institution institution;

  const InstitutionProfilePage({
    super.key,
    required this.institution,
  });

  @override
  State<InstitutionProfilePage> createState() => _InstitutionProfilePageState();
}

class _InstitutionProfilePageState extends State<InstitutionProfilePage> {
  final _repository = InstitutionsRepository();
  bool _isLoading = false;
  int _offersCount = 0;
  int _followersCount = 0;
  double _rating = 0.0;

  static const _primary = Color(0xFF0B7650);
  static const _primaryGradient = Color(0xFF1AA66E);
  static const _darkGreen = Color(0xFF123F31);
  static const _background = Color(0xFFF6FAF8);
  static const _surface = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final institutionId = widget.institution.id;

      final offersResponse = await SupabaseService()
          .client
          .from('food_offers')
          .select('id')
          .eq('business_id', institutionId)
          .eq('status', 'available');
      _offersCount = offersResponse.length;

      try {
        final followersResponse = await SupabaseService()
            .client
            .from('institution_followers')
            .select('id')
            .eq('institution_id', institutionId);
        _followersCount = followersResponse.length;
      } catch (_) {
        _followersCount = 0;
      }

      try {
        final ratingsResponse = await SupabaseService()
            .client
            .from('institution_ratings')
            .select('rating')
            .eq('institution_id', institutionId);

        if (ratingsResponse.isNotEmpty) {
          double total = 0;
          for (var item in ratingsResponse) {
            total += (item['rating'] as num?)?.toDouble() ?? 0;
          }
          _rating = total / ratingsResponse.length;
        } else {
          _rating = 0;
        }
      } catch (_) {
        _rating = 0;
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('❌ Error loading stats: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ دالة فتح واتساب للدعم الفني
  Future<void> _openWhatsAppSupport() async {
    const phoneNumber = '201040652783'; // بدون + وبدون أصفار زائدة
    const url = 'https://wa.me/$phoneNumber';
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        // ✅ إذا لم يعمل الرابط، جرب طريقة بديلة
        const fallbackUrl = 'https://api.whatsapp.com/send?phone=$phoneNumber';
        if (await canLaunchUrl(Uri.parse(fallbackUrl))) {
          await launchUrl(Uri.parse(fallbackUrl),
              mode: LaunchMode.externalApplication);
        } else {
          _showSnackBar('تعذر فتح واتساب، يرجى الاتصال على 01040652783',
              error: true);
        }
      }
    } catch (e) {
      _showSnackBar('تعذر فتح واتساب، يرجى الاتصال على 01040652783',
          error: true);
    }
  }

  void _showSnackBar(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: error ? const Color(0xFFD64545) : _primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج من حساب المؤسسة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child:
                const Text('إلغاء', style: TextStyle(color: Color(0xFF71837C))),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await SupabaseService().client.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر تسجيل الخروج. حاول مرة أخرى'),
            backgroundColor: Color(0xFFD64545),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final institution = widget.institution;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          title: const Text(
            'ملف المؤسسة',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          foregroundColor: _darkGreen,
          elevation: 0,
          actions: [
            PopupMenuButton<String>(
              tooltip: 'المزيد',
              onSelected: (value) {
                if (value == 'logout') _logout();
              },
              icon: const Icon(Icons.more_vert_rounded),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, color: Color(0xFFD64545)),
                      SizedBox(width: 10),
                      Text('تسجيل الخروج',
                          style: TextStyle(color: Color(0xFFD64545))),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: _primary),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildHeaderCard(institution),
                    const SizedBox(height: 16),
                    _buildInfoCard(institution),
                    const SizedBox(height: 16),
                    _buildStatusCard(institution),
                    const SizedBox(height: 16),
                    _buildActionsCard(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  // ============================================================
  // ✅ بطاقة الهيدر مع الصورة والاسم والإحصائيات الحقيقية
  // ============================================================
  Widget _buildHeaderCard(Institution institution) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, _primaryGradient],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _primary.withAlpha(40),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // ✅ الشعار
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child:
                  institution.logoUrl != null && institution.logoUrl!.isNotEmpty
                      ? Image.network(
                          institution.logoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildLogoPlaceholder(),
                        )
                      : _buildLogoPlaceholder(),
            ),
          ),
          const SizedBox(height: 14),
          // ✅ اسم المؤسسة
          Text(
            institution.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          // ✅ نوع النشاط
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getTypeLabel(institution.type),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // ✅ الإحصائيات الحقيقية
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                'التقييم',
                _rating > 0 ? '${_rating.toStringAsFixed(1)} ★' : 'لا يوجد',
                Icons.star_rounded,
              ),
              _buildStatItem(
                'المتابعون',
                _followersCount > 0 ? '$_followersCount' : '0',
                Icons.people_rounded,
              ),
              _buildStatItem(
                'العروض',
                _offersCount > 0 ? '$_offersCount' : '0',
                Icons.local_offer_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withAlpha(180), size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withAlpha(160),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildLogoPlaceholder() {
    return Container(
      color: const Color(0xFFE8F5EE),
      child: const Icon(
        Icons.business_rounded,
        color: _primary,
        size: 40,
      ),
    );
  }

  // ============================================================
  // ✅ بطاقة المعلومات
  // ============================================================
  Widget _buildInfoCard(Institution institution) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: _primary, size: 20),
              SizedBox(width: 8),
              Text(
                'معلومات المؤسسة',
                style: TextStyle(
                  color: _darkGreen,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _infoRow(Icons.phone_outlined, 'رقم الهاتف',
              institution.phone ?? 'غير محدد'),
          _infoRow(Icons.location_city_outlined, 'المدينة',
              institution.city ?? 'غير محدد'),
          _infoRow(Icons.location_on_outlined, 'العنوان',
              institution.address ?? 'غير محدد'),
          _infoRow(Icons.description_outlined, 'نبذة',
              institution.description ?? 'لا يوجد وصف'),
          _infoRow(Icons.email_outlined, 'البريد الإلكتروني',
              institution.email ?? 'غير محدد'),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF71837C), size: 18),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF71837C),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _darkGreen,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ✅ بطاقة الحالة
  // ============================================================
  Widget _buildStatusCard(Institution institution) {
    final isVerified = institution.isVerified ?? false;
    final isActive = institution.isActive ?? false;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_rounded, color: _primary, size: 20),
              SizedBox(width: 8),
              Text(
                'حالة المؤسسة',
                style: TextStyle(
                  color: _darkGreen,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatusChip(
                isVerified ? 'موثقة ✓' : 'غير موثقة',
                isVerified ? _primary : Colors.grey.shade500,
                isVerified ? const Color(0xFFE8F5EE) : Colors.grey.shade100,
              ),
              const SizedBox(width: 8),
              _buildStatusChip(
                isActive ? 'نشطة' : 'غير نشطة',
                isActive ? const Color(0xFF3679C8) : Colors.grey.shade500,
                isActive ? const Color(0xFFE3F0FF) : Colors.grey.shade100,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFE0A3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: Color(0xFFE28B00), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'جميع البيانات معروضة للقراءة فقط. للطلب تغيير أي بيانات يرجى التواصل مع الدعم الفني.',
                    style: TextStyle(
                      color: Color(0xFF704C00),
                      fontSize: 12,
                      height: 1.4,
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

  Widget _buildStatusChip(String label, Color color, Color background) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ✅ بطاقة الإجراءات
  // ============================================================
  Widget _buildActionsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.settings_outlined, color: _primary, size: 20),
              SizedBox(width: 8),
              Text(
                'إجراءات سريعة',
                style: TextStyle(
                  color: _darkGreen,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'عرض رمز QR',
                  color: const Color(0xFF3679C8),
                  onTap: () {
                    _showSnackBar('جاري تجهيز رمز QR للمؤسسة');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  icon: Icons.share_rounded,
                  label: 'مشاركة الملف',
                  color: const Color(0xFFB77700),
                  onTap: () {
                    _showSnackBar('جاري تجهيز رابط المشاركة');
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ✅ زر التواصل مع الدعم الفني (واتساب)
          SizedBox(
            width: double.infinity,
            child: _actionButton(
              icon: Icons.support_agent_rounded,
              label: 'تواصل مع الدعم الفني',
              color: const Color(0xFF25D366), // لون واتساب
              onTap: _openWhatsAppSupport,
              fullWidth: true,
            ),
          ),
          const SizedBox(height: 6),
          // ✅ نص مساعد
          Center(
            child: Text(
              'رقم الدعم: 01040652783',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool fullWidth = false,
  }) {
    return Material(
      color: color.withAlpha(12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(
            mainAxisAlignment:
                fullWidth ? MainAxisAlignment.center : MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ✅ Helper Methods
  // ============================================================
  String _getTypeLabel(String type) {
    const types = <String, String>{
      'bakery': 'مخبز وحلويات',
      'grocery': 'بقالة',
      'game_store': 'محل ألعاب',
      'supermarket': 'سوبر ماركت',
      'cafe': 'كافيه',
      'hotel': 'فندق',
      'other': 'مؤسسة أخرى',
    };
    return types[type] ?? type;
  }
}
