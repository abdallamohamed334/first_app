// lib/features/community/presentation/pages/offer_details_myoffers_page.dart

import 'package:flutter/material.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/community/presentation/pages/user_profile_page.dart';

class OfferDetailsMyOffersPage extends StatefulWidget {
  final Map<String, dynamic> offer;
  final VoidCallback? onOfferUpdated;

  const OfferDetailsMyOffersPage({
    super.key,
    required this.offer,
    this.onOfferUpdated,
  });

  @override
  State<OfferDetailsMyOffersPage> createState() =>
      _OfferDetailsMyOffersPageState();
}

class _OfferDetailsMyOffersPageState extends State<OfferDetailsMyOffersPage> {
  final SupabaseService _supabase = SupabaseService();
  bool _isLoading = false;
  String? _busyRequestId;
  String? _primaryImageUrl;
  List<String> _images = [];

  static const Color _primary = Color(0xFF005B3C);
  static const Color _primaryContainer = Color(0xFF0B7650);
  static const Color _secondaryContainer = Color(0xFFBEEDD8);
  static const Color _surface = Color(0xFFF7FAF9);
  static const Color _surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color _onSurface = Color(0xFF181C1C);
  static const Color _onSurfaceVariant = Color(0xFF3F4942);
  static const Color _onPrimary = Color(0xFFFFFFFF);
  static const Color _errorColor = Color(0xFFBA1A1A);
  static const Color _errorContainer = Color(0xFFFFDAD6);
  static const Color _onErrorContainer = Color(0xFF93000A);
  static const Color _outlineVariant = Color(0xFFBEC9C0);

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    try {
      List<String> imageUrls = [];
      String? primaryUrl;

      // ✅ 1. حاول تجيب من widget.offer['images']
      final offerImages = widget.offer['images'] as List? ?? [];
      if (offerImages.isNotEmpty) {
        for (var img in offerImages) {
          final url = img.toString();
          if (url.isNotEmpty) {
            final fullUrl = _getFullImageUrl(url);
            if (fullUrl.isNotEmpty) {
              imageUrls.add(fullUrl);
              if (primaryUrl == null) {
                primaryUrl = fullUrl;
              }
            }
          }
        }
        print('✅ Found ${imageUrls.length} images from offer.images');
      }

      // ✅ 2. لو مفيش صور، حاول تجيب من widget.offer['image']
      if (imageUrls.isEmpty) {
        final offerImage = widget.offer['image']?.toString() ?? '';
        if (offerImage.isNotEmpty) {
          final fullUrl = _getFullImageUrl(offerImage);
          if (fullUrl.isNotEmpty) {
            imageUrls.add(fullUrl);
            primaryUrl = fullUrl;
            print('✅ Using offer.image: $fullUrl');
          }
        }
      }

      // ✅ 3. لو مفيش صور، استخدم أيقونة افتراضية
      if (imageUrls.isEmpty) {
        print('⚠️ No images found, using placeholder');
        primaryUrl = null;
      }

      if (mounted) {
        setState(() {
          _images = imageUrls;
          _primaryImageUrl = primaryUrl;
        });
      }

      print('✅ Final: ${_images.length} images, primary: $_primaryImageUrl');
    } catch (e) {
      print('❌ Error loading images: $e');
      if (mounted) {
        setState(() {
          _primaryImageUrl = null;
          _images = [];
        });
      }
    }
  }

  String _getFullImageUrl(String imagePath) {
    if (imagePath.isEmpty) return '';

    // لو الرابط بالفعل كامل
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }

    // لو الرابط file:///
    if (imagePath.startsWith('file:///')) {
      return '';
    }

    // ✅ بناء الرابط من Supabase Storage
    // الصورة مخزنة في Bucket باسم community-offers
    final baseUrl =
        'https://gsrhoqdtcyfdmvgahqvl.supabase.co/storage/v1/object/public/community-offers/';

    // لو الـ path يبدأ بـ / نشيله
    String cleanPath = imagePath;
    if (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }

    return '$baseUrl$cleanPath';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _surface,
        appBar: _buildAppBar(),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeader(),
            ),
            SliverToBoxAdapter(
              child: _buildContent(),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: _onSurface,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _secondaryContainer,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
          padding: EdgeInsets.zero,
        ),
      ),
      title: const Text(
        'تفاصيل العرض',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _onSurface,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildHeader() {
    final image = _primaryImageUrl ?? '';
    final status = (widget.offer['status'] ?? 'available').toString();
    final title = (widget.offer['title'] ?? 'عرض مجتمعي').toString();
    final requester = widget.offer['requester'] as Map? ?? {};
    final name = requester['name']?.toString() ?? 'مستخدم';
    final createdAt = widget.offer['created_at']?.toString() ?? '';

    return Stack(
      children: [
        Container(
          height: 260,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryContainer, _primary],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            image: image.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(image),
                    fit: BoxFit.cover,
                    colorFilter: const ColorFilter.mode(
                      Colors.black26,
                      BlendMode.darken,
                    ),
                    onError: (exception, stackTrace) {
                      print('❌ Error loading image: $exception');
                    },
                  )
                : null,
          ),
          child: image.isEmpty
              ? const Center(
                  child: Icon(
                    Icons.image_outlined,
                    color: _onPrimary,
                    size: 64,
                  ),
                )
              : null,
        ),
        Positioned(
          top: 80,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusColor(status),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              _getStatusLabel(status),
              style: const TextStyle(
                color: _onPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          right: 16,
          left: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _onPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _onPrimary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          color: _onPrimary,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserProfilePage(
                                  userId: requester['id']?.toString() ?? '',
                                  userName: name,
                                  userAvatar:
                                      requester['avatar_url']?.toString() ?? '',
                                ),
                              ),
                            );
                          },
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: _onPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _onPrimary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          color: _onPrimary,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(createdAt),
                          style: const TextStyle(
                            color: _onPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final description = (widget.offer['description'] ?? '').toString();
    final requests = _getRequests();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(),
          const SizedBox(height: 16),
          if (description.isNotEmpty) _buildDescription(description),
          const SizedBox(height: 16),
          _buildDetailsGrid(),
          const SizedBox(height: 16),
          _buildRequestsSection(requests),
          const SizedBox(height: 16),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final totalRequests = _getRequests().length;
    final pending = _getPendingCount();
    final status = (widget.offer['status'] ?? 'available').toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildInfoItem(
              'الحالة', _getStatusLabel(status), _getStatusColor(status)),
          const SizedBox(width: 16),
          _buildInfoItem('الطلبات', '$totalRequests', _primary),
          const SizedBox(width: 16),
          _buildInfoItem(
            'جديد',
            '$pending',
            pending > 0 ? const Color(0xFFB36B12) : _onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription(String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📝 وصف العرض',
            style: TextStyle(
              color: _onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: _onSurfaceVariant,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📋 تفاصيل إضافية',
            style: TextStyle(
              color: _onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildDetailItem(
                Icons.category_outlined,
                'التصنيف',
                widget.offer['category'] ?? 'ملابس',
              ),
              const SizedBox(width: 12),
              _buildDetailItem(
                Icons.location_on_outlined,
                'الموقع',
                widget.offer['pickup_location'] ??
                    widget.offer['location'] ??
                    'غير محدد',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildDetailItem(
                Icons.calendar_today_outlined,
                'تاريخ الإضافة',
                _formatDate(widget.offer['created_at']?.toString() ?? ''),
              ),
              const SizedBox(width: 12),
              _buildDetailItem(
                Icons.access_time_outlined,
                'آخر تحديث',
                _formatDate(widget.offer['updated_at']?.toString() ?? ''),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _outlineVariant),
        ),
        child: Row(
          children: [
            Icon(icon, color: _primaryContainer, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: _onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsSection(List<Map<String, dynamic>> requests) {
    if (requests.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Column(
          children: [
            Icon(Icons.inbox_rounded, color: _onSurfaceVariant, size: 48),
            SizedBox(height: 8),
            Text(
              'لا توجد طلبات على هذا العرض',
              style: TextStyle(
                color: _onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '👥 طلبات المستخدمين',
            style: TextStyle(
              color: _onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...requests.map((request) => _buildRequestTile(request)),
        ],
      ),
    );
  }

  Widget _buildRequestTile(Map<String, dynamic> request) {
    final status = (request['status'] ?? 'pending').toString();
    final requester = request['requester'] as Map? ?? {};
    final name = requester['name']?.toString() ?? 'مستخدم';
    final avatar = requester['avatar_url']?.toString() ?? '';
    final message = (request['message'] ?? '').toString().trim();
    final requestId = request['id'].toString();
    final busy = _busyRequestId == requestId;
    final isPending = status == 'pending';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfilePage(
              userId: request['user_id']?.toString() ?? '',
              userName: name,
              userAvatar: avatar,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPending ? const Color(0xFFFFF0DA) : _outlineVariant,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _secondaryContainer,
                  backgroundImage:
                      avatar.isNotEmpty ? NetworkImage(avatar) : null,
                  child: avatar.isEmpty
                      ? const Icon(
                          Icons.person_outline_rounded,
                          color: _primaryContainer,
                          size: 20,
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: _onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          if (isPending) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0DA),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'جديد',
                                style: TextStyle(
                                  color: Color(0xFFB36B12),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (message.isNotEmpty)
                        Text(
                          message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                _buildStatusBadge(status),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : () => _rejectRequest(requestId),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _errorColor,
                        side: const BorderSide(color: Color(0xFFF5C6C6)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _errorColor,
                              ),
                            )
                          : const Text('رفض'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: busy ? null : () => _acceptRequest(requestId),
                      style: FilledButton.styleFrom(
                        backgroundColor: _primaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _onPrimary,
                              ),
                            )
                          : const Text('قبول'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final colors = {
      'pending': (const Color(0xFFB36B12), const Color(0xFFFFF0DA)),
      'accepted': (const Color(0xFF3679C8), const Color(0xFFEAF2FF)),
      'completed': (_primary, _secondaryContainer),
      'rejected': (_errorColor, _errorContainer),
    };
    final pair = colors[status] ?? (_primary, _secondaryContainer);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: pair.$2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _getStatusLabel(status),
        style: TextStyle(
          color: pair.$1,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final status = (widget.offer['status'] ?? 'available').toString();
    if (status == 'completed' || status == 'rejected') {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: _isLoading ? null : _deleteOffer,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _onPrimary,
                    ),
                  )
                : const Icon(Icons.delete_outline, size: 18),
            label: Text(_isLoading ? 'جاري الحذف...' : 'حذف العرض'),
            style: FilledButton.styleFrom(
              backgroundColor: _errorColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteOffer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: _errorColor, size: 28),
            SizedBox(width: 8),
            Text(
              'حذف العرض',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: const Text(
          'هل أنت متأكد من حذف هذا العرض؟\nلا يمكن التراجع عن هذا الإجراء.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(
              foregroundColor: _onSurfaceVariant,
            ),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _errorColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف العرض'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final offerId = widget.offer['id'].toString();
      await _supabase.deleteOffer(offerId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم حذف العرض بنجاح'),
          backgroundColor: _primaryContainer,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );

      if (widget.onOfferUpdated != null) {
        widget.onOfferUpdated!();
      }

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ تعذر حذف العرض: ${e.toString()}'),
          backgroundColor: _errorColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptRequest(String requestId) async {
    setState(() => _busyRequestId = requestId);
    try {
      await _supabase.acceptOfferRequest(requestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم قبول الطلب بنجاح'),
          backgroundColor: _primaryContainer,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (widget.onOfferUpdated != null) {
        widget.onOfferUpdated!();
      }
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ تعذر قبول الطلب: ${e.toString()}'),
          backgroundColor: _errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyRequestId = null);
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: _errorColor),
            SizedBox(width: 8),
            Text('رفض الطلب'),
          ],
        ),
        content: const Text('هل أنت متأكد من رفض طلب هذا المستخدم؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(
              foregroundColor: _onSurfaceVariant,
            ),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _errorColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('رفض الطلب'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _busyRequestId = requestId);
    try {
      await _supabase.rejectOfferRequest(requestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ تم رفض الطلب'),
          backgroundColor: _errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (widget.onOfferUpdated != null) {
        widget.onOfferUpdated!();
      }
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ تعذر رفض الطلب: ${e.toString()}'),
          backgroundColor: _errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyRequestId = null);
    }
  }

  List<Map<String, dynamic>> _getRequests() {
    final requests = widget.offer['requests'];
    if (requests is! List) return [];
    return requests.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  int _getPendingCount() {
    return _getRequests().where((r) => r['status'] == 'pending').length;
  }

  String _formatDate(String date) {
    if (date.isEmpty) return '--';
    try {
      final parsed = DateTime.parse(date);
      final now = DateTime.now();
      final diff = now.difference(parsed);
      if (diff.inDays > 0) return 'منذ ${diff.inDays} يوم';
      if (diff.inHours > 0) return 'منذ ${diff.inHours} ساعة';
      if (diff.inMinutes > 0) return 'منذ ${diff.inMinutes} دقيقة';
      return 'الآن';
    } catch (_) {
      return date.substring(0, 10);
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'available':
        return 'متاح';
      case 'pending':
        return 'جديد';
      case 'accepted':
        return 'مقبول';
      case 'completed':
        return 'مكتمل';
      case 'rejected':
        return 'مرفوض';
      default:
        return 'متاح';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return _primaryContainer;
      case 'pending':
        return const Color(0xFFB36B12);
      case 'accepted':
        return const Color(0xFF3679C8);
      case 'completed':
        return _primary;
      case 'rejected':
        return _errorColor;
      default:
        return _primaryContainer;
    }
  }
}
