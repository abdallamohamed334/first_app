// lib/features/community/presentation/pages/volunteer_donations_tracking_page.dart

import 'package:flutter/material.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/charity/presentation/pages/volunteer_donation_detail_page.dart';

class VolunteerDonationsTrackingPage extends StatefulWidget {
  const VolunteerDonationsTrackingPage({super.key});

  @override
  State<VolunteerDonationsTrackingPage> createState() =>
      _VolunteerDonationsTrackingPageState();
}

class _VolunteerDonationsTrackingPageState
    extends State<VolunteerDonationsTrackingPage> {
  static const _green = Color(0xFF0B7650);
  static const _darkGreen = Color(0xFF123F31);
  static const _background = Color(0xFFF6FAF8);

  List<Map<String, dynamic>> _donations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDonations();
  }

  Future<void> _loadDonations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = SupabaseService().client.auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _error = 'يجب تسجيل الدخول أولاً';
        });
        return;
      }

      final response = await SupabaseService()
          .client
          .from('charity_donation_requests')
          .select('''
            *,
            charities:charity_id (id, name, logo),
            users:donor_id (id, name, phone)
          ''')
          .eq('volunteer_id', user.id)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> donations = [];
      for (var item in response) {
        final charity = item['charities'] as Map<String, dynamic>?;
        final donor = item['users'] as Map<String, dynamic>?;

        donations.add({
          'id': item['id'],
          'title': item['title'] ?? 'تبرع',
          'description': item['description'] ?? '',
          'quantity': item['quantity'] ?? 1,
          'images':
              item['images'] is List ? List<String>.from(item['images']) : [],
          'pickup_address': item['pickup_address'] ?? '',
          'pickup_city': item['pickup_city'] ?? '',
          'charity_name': charity?['name'] ?? 'جمعية خيرية',
          'charity_logo': charity?['logo'],
          'donor_name': donor?['name'] ?? 'متبرع',
          'donor_phone': donor?['phone'],
          'status': item['status']?.toString() ?? 'volunteer_assigned',
          'created_at': item['created_at'],
          'updated_at': item['updated_at'],
          'volunteer_accepted_at': item['volunteer_accepted_at'],
          'donor_pickup_confirmed_at': item['donor_pickup_confirmed_at'],
          'charity_received_at': item['charity_received_at'],
          'completed_at': item['completed_at'],
        });
      }

      setState(() {
        _donations = donations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'فشل تحميل التبرعات: $e';
        _isLoading = false;
      });
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'volunteer_assigned':
        return '⏳ في انتظار تأكيد المتبرع';
      case 'donor_ready':
        return '✅ المتبرع جاهز - تواصل معه';
      case 'picked_up_from_donor':
        return '📦 تم الاستلام من المتبرع';
      case 'in_transit':
        return '🚗 في الطريق للجمعية';
      case 'completed':
        return '🎉 تم التوصيل بنجاح';
      case 'cancelled':
        return '❌ تم الإلغاء';
      default:
        return '🔄 جاري التحديث';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'volunteer_assigned':
        return const Color(0xFFF59E0B);
      case 'donor_ready':
        return const Color(0xFF3B82F6);
      case 'picked_up_from_donor':
        return const Color(0xFF8B5CF6);
      case 'in_transit':
        return const Color(0xFFEC4899);
      case 'completed':
        return _green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  int _getStepIndex(String status) {
    const steps = [
      'volunteer_assigned',
      'donor_ready',
      'picked_up_from_donor',
      'in_transit',
      'completed'
    ];
    return steps.indexOf(status);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          title: const Text('تبرعاتي كمتطوع'),
          backgroundColor: Colors.white,
          foregroundColor: _darkGreen,
          elevation: 0,
          actions: [
            IconButton(
              onPressed: _loadDonations,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث',
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _green),
            SizedBox(height: 16),
            Text(
              'جاري تحميل تبرعاتك...',
              style: TextStyle(
                color: _darkGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _darkGreen,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadDonations,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_donations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.volunteer_activism_rounded,
                size: 64,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                'مفيش تبرعات متطوع فيها حالياً',
                style: TextStyle(
                  color: _darkGreen,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'روح قسم "تبرعات محتاجاك توصلها" واختار تبرع توصلّه',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_forward_ios_rounded),
                label: const Text('روح للرئيسية'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: _green,
      onRefresh: _loadDonations,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: _donations.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _buildDonationCard(_donations[index]);
        },
      ),
    );
  }

  Widget _buildDonationCard(Map<String, dynamic> donation) {
    final status = donation['status']?.toString() ?? 'volunteer_assigned';
    final title = donation['title']?.toString() ?? 'تبرع';
    final charityName = donation['charity_name']?.toString() ?? 'جمعية خيرية';
    final donorName = donation['donor_name']?.toString() ?? 'متبرع';
    final quantity = donation['quantity']?.toString() ?? '1';
    final images = donation['images'] as List? ?? [];
    final imageUrl = images.isNotEmpty ? images.first.toString() : null;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VolunteerDonationDetailPage(donation: donation),
          ),
        ).then((_) => _loadDonations());
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _statusColor(status).withAlpha(30),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(6),
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
                // ✅ صورة
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 60,
                    height: 60,
                    color: const Color(0xFFE8F5EE),
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.volunteer_activism_rounded,
                              color: _green,
                              size: 28,
                            ),
                          )
                        : const Icon(
                            Icons.volunteer_activism_rounded,
                            color: _green,
                            size: 28,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _darkGreen,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$charityName • $donorName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF71837C),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _statusColor(status).withAlpha(15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _statusColor(status).withAlpha(40),
                              ),
                            ),
                            child: Text(
                              _statusLabel(status),
                              style: TextStyle(
                                color: _statusColor(status),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$quantity وحدة',
                            style: const TextStyle(
                              color: Color(0xFF71837C),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_back_ios_rounded,
                  size: 14,
                  color: Color(0xFF71837C),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // ✅ Timeline مبسط
            _buildSimpleTimeline(status),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleTimeline(String status) {
    const steps = [
      ('تم الحجز', Icons.handshake_rounded),
      ('المتبرع جاهز', Icons.check_circle_outline_rounded),
      ('استلمت التبرع', Icons.inventory_2_rounded),
      ('في الطريق', Icons.local_shipping_rounded),
      ('وصل للجمعية', Icons.verified_rounded),
    ];

    final currentStep = _getStepIndex(status);
    final activeIndex = currentStep >= 0 ? currentStep : 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(steps.length, (index) {
        final isActive = index <= activeIndex;
        final isLast = index == steps.length - 1;

        return Expanded(
          child: Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isActive ? _green : Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isActive ? Icons.check_rounded : steps[index].$2,
                      size: 12,
                      color: isActive ? Colors.white : Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    steps[index].$1,
                    style: TextStyle(
                      fontSize: 7,
                      color: isActive ? _darkGreen : Colors.grey.shade400,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    color: index < activeIndex ? _green : Colors.grey.shade200,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
