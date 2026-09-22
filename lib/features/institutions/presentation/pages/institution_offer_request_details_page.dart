import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/institution_offers_repository.dart';
import '../../domain/entities/institution_offer_request.dart';

class InstitutionOfferRequestDetailsPage extends StatefulWidget {
  final InstitutionOfferRequest request;
  final InstitutionOffersRepository? repository;

  const InstitutionOfferRequestDetailsPage({
    super.key,
    required this.request,
    this.repository,
  });

  @override
  State<InstitutionOfferRequestDetailsPage> createState() =>
      _InstitutionOfferRequestDetailsPageState();
}

class _InstitutionOfferRequestDetailsPageState
    extends State<InstitutionOfferRequestDetailsPage> {
  late final InstitutionOffersRepository _repository;
  late InstitutionOfferRequest _request;

  bool _loading = false;

  @override
  void initState() {
    super.initState();

    _repository = widget.repository ?? InstitutionOffersRepository();

    _request = widget.request;
  }

  // ============================================================
  // Helpers
  // ============================================================

  Map<String, dynamic> get _offer {
    return _request.offer ?? <String, dynamic>{};
  }

  String get _title {
    final value = _offer['title']?.toString().trim();

    if (value == null || value.isEmpty) {
      return 'عرض غذائي';
    }

    return value;
  }

  String get _description {
    final value = _offer['description']?.toString().trim();

    if (value == null || value.isEmpty) {
      return 'لا يوجد وصف للعرض';
    }

    return value;
  }

  String get _category {
    final value = _offer['category']?.toString().trim();

    if (value == null || value.isEmpty) {
      return 'أخرى';
    }

    return value;
  }

  String get _pickupLocation {
    final value = _offer['pickup_location']?.toString().trim();

    if (value == null || value.isEmpty) {
      return 'لم يتم تحديد مكان الاستلام';
    }

    return value;
  }

  String get _symbolicPrice {
    final value = _offer['symbolic_price'];

    if (value == null) {
      return '0';
    }

    if (value is num) {
      return value % 1 == 0 ? value.toInt().toString() : value.toString();
    }

    return value.toString();
  }

  List<String> _getImages() {
    final images = _offer['images'];

    if (images is List) {
      return images
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    if (images is String) {
      final value = images.trim();

      if (value.isEmpty) {
        return [];
      }

      return [value];
    }

    return [];
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'قيد المراجعة';

      case 'accepted':
        return 'مقبول';

      case 'ready_for_pickup':
        return 'جاهز للاستلام';

      case 'picked_up':
        return 'تم الاستلام';

      case 'completed':
        return 'مكتمل';

      case 'rejected':
        return 'مرفوض';

      case 'cancelled':
        return 'ملغي';

      case 'expired':
        return 'منتهي';

      default:
        return status;
    }
  }

  Color _statusColor(String status, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (status) {
      case 'pending':
        return Colors.orange;

      case 'accepted':
        return Colors.blue;

      case 'ready_for_pickup':
        return Colors.indigo;

      case 'picked_up':
        return Colors.teal;

      case 'completed':
        return Colors.green;

      case 'rejected':
      case 'cancelled':
      case 'expired':
        return Colors.red;

      default:
        return colorScheme.primary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty;

      case 'accepted':
        return Icons.check_circle_outline;

      case 'ready_for_pickup':
        return Icons.inventory_2_outlined;

      case 'picked_up':
        return Icons.local_shipping_outlined;

      case 'completed':
        return Icons.done_all;

      case 'rejected':
        return Icons.close;

      case 'cancelled':
        return Icons.cancel_outlined;

      case 'expired':
        return Icons.timer_off_outlined;

      default:
        return Icons.info_outline;
    }
  }

  // ============================================================
  // Request status update
  // ============================================================

// ============================================================
// Request status update
// ============================================================

  Future<void> _updateStatus(String status) async {
    if (_loading) return;

    setState(() {
      _loading = true;
    });

    try {
      await _repository.updateOfferRequest(
        requestId: _request.id,
        accept: status == 'accepted',
      );

      if (!mounted) return;

      setState(() {
        _request = _copyRequestWithStatus(status);
      });

      _showMessage(
        status == 'accepted' ? 'تم قبول الطلب بنجاح' : 'تم رفض الطلب بنجاح',
        success: true,
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;

      _showMessage(
        e.message.isNotEmpty ? e.message : 'حدث خطأ أثناء تحديث الطلب',
        success: false,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        success: false,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  InstitutionOfferRequest _copyRequestWithStatus(String status) {
    return InstitutionOfferRequest.fromJson({
      'id': _request.id,
      'offer_id': _request.offerId,
      'requester_id': _request.requesterId,
      'quantity': _request.quantity,
      'status': status,
      'created_at': _request.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'institution_offers': _offer,
    });
  }

  // ============================================================
  // Accept
  // ============================================================

  Future<void> _showAcceptConfirmation() async {
    if (_loading) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'قبول الطلب',
            textAlign: TextAlign.right,
          ),
          content: const Text(
            'هل أنت متأكد من قبول هذا الطلب؟',
            textAlign: TextAlign.right,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('قبول الطلب'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    await _updateStatus('accepted');
  }

  // ============================================================
  // Reject
  // ============================================================

  Future<void> _showRejectConfirmation() async {
    if (_loading) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'رفض الطلب',
            textAlign: TextAlign.right,
          ),
          content: const Text(
            'هل أنت متأكد من رفض هذا الطلب؟',
            textAlign: TextAlign.right,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('رفض الطلب'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    await _updateStatus('rejected');
  }

  // ============================================================
  // Prepare request
  // ============================================================

  Future<void> _prepareForPickup() async {
    if (_loading) return;

    setState(() {
      _loading = true;
    });

    try {
      await _repository.markOfferRequestReady(_request.id);

      if (!mounted) return;

      setState(() {
        _request = _copyRequestWithStatus('ready_for_pickup');
      });

      _showMessage(
        'تم تجهيز الطلب للاستلام',
        success: true,
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;

      _showMessage(
        e.message.isNotEmpty ? e.message : 'حدث خطأ أثناء تجهيز الطلب',
        success: false,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        success: false,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // Verify Pickup Code (NEW)
  // ============================================================

  Future<void> _verifyPickupCode() async {
    if (_loading) return;

    print('📌🔴 _verifyPickupCode START');

    final code = await _showPickupCodeDialog();

    if (code == null) {
      print('📌🔴 _verifyPickupCode: code is null');
      return;
    }

    print('📌🔴 _verifyPickupCode: code=$code');
    print('📌🔴 _verifyPickupCode: requestId=${_request.id}');

    setState(() => _loading = true);

    try {
      final result = await _repository.verifyOfferRequestPickupCode(
        requestId: _request.id,
        code: code,
      );

      print('📌🔴 _verifyPickupCode: result=$result');

      if (result['success'] == true) {
        setState(() {
          _request = _copyRequestWithStatus('picked_up');
        });

        _showMessage(
          '✅ تم تأكيد الاستلام بنجاح',
          success: true,
        );

        Navigator.of(context).pop(true);
      } else {
        _showMessage(
          result['error'] ?? result['message'] ?? 'فشل التحقق من الكود',
          success: false,
        );
      }
    } catch (e) {
      print('❌ _verifyPickupCode error: $e');
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        success: false,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<String?> _showPickupCodeDialog() async {
    final controller = TextEditingController();
    String? errorText;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            'تحقق من كود الاستلام',
            textAlign: TextAlign.right,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'أدخل كود الاستلام المكون من 6 أرقام',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 13, color: Color(0xFF71837C)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF123F31),
                ),
                onChanged: (_) {
                  if (errorText != null) {
                    setDialogState(() => errorText = null);
                  }
                },
                decoration: InputDecoration(
                  hintText: '000000',
                  counterText: '',
                  errorText: errorText,
                  filled: true,
                  fillColor: const Color(0xFFF4F8F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF0B7650)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final code = controller.text.trim();
                if (code.length == 6) {
                  Navigator.pop(context, code);
                } else {
                  setDialogState(() => errorText = 'أدخل 6 أرقام');
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0B7650),
              ),
              child: const Text('تحقق'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Complete request
  // ============================================================

  Future<void> _completeRequest() async {
    if (_loading) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'إكمال الطلب',
            textAlign: TextAlign.right,
          ),
          content: const Text(
            'هل تم استلام الطلب بالفعل وتريد تسجيله كمكتمل؟',
            textAlign: TextAlign.right,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('إكمال الطلب'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      await _repository.completeRequest(_request.id);

      if (!mounted) return;

      setState(() {
        _request = _copyRequestWithStatus('completed');
      });

      _showMessage(
        'تم إكمال الطلب بنجاح',
        success: true,
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;

      _showMessage(
        e.message.isNotEmpty ? e.message : 'حدث خطأ أثناء إكمال الطلب',
        success: false,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        success: false,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // Message
  // ============================================================

  void _showMessage(
    String message, {
    required bool success,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.right,
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final images = _getImages();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل الطلب'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _OfferGallery(
                  images: images,
                  title: _title,
                ),
                const SizedBox(height: 16),
                _OfferHeader(
                  title: _title,
                  category: _category,
                  price: _symbolicPrice,
                  quantity: _request.quantity,
                ),
                const SizedBox(height: 16),
                _StatusCard(
                  status: _request.status,
                  label: _statusLabel(_request.status),
                  color: _statusColor(
                    _request.status,
                    context,
                  ),
                  icon: _statusIcon(_request.status),
                ),
                const SizedBox(height: 20),
                _RequestProgress(
                  status: _request.status,
                ),
                const SizedBox(height: 20),
                _RequestInfoCard(
                  request: _request,
                ),
                const SizedBox(height: 16),
                _OfferInfoCard(
                  description: _description,
                  pickupLocation: _pickupLocation,
                  offer: _offer,
                ),
                const SizedBox(height: 24),
                _buildActions(),
                const SizedBox(height: 8),
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Actions
  // ============================================================

  Widget _buildActions() {
    switch (_request.status) {
      case 'pending':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: _loading ? null : _showAcceptConfirmation,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('قبول الطلب'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _loading ? null : _showRejectConfirmation,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              icon: const Icon(Icons.close),
              label: const Text('رفض الطلب'),
            ),
          ],
        );

      case 'accepted':
        return FilledButton.icon(
          onPressed: _loading ? null : _prepareForPickup,
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('تجهيز الطلب للاستلام'),
        );

      case 'ready_for_pickup':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _NoticeCard(
              icon: Icons.pin_outlined,
              title: 'في انتظار كود الاستلام',
              message:
                  'الطلب جاهز للاستلام. اطلب من المستخدم إظهار كود الاستلام المكون من 6 أرقام ثم تحقّق منه من خلال الزر أدناه.',
              color: Colors.indigo,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _verifyPickupCode,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.verified_user_outlined),
              label: Text(
                _loading ? 'جارٍ التحقق...' : '🔑 تحقق من كود الاستلام',
              ),
            ),
          ],
        );

      case 'picked_up':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _NoticeCard(
              icon: Icons.check_circle_outline,
              title: 'تم استلام الطلب',
              message:
                  'تم التحقق من كود الاستلام بنجاح. يمكنك الآن تسجيل الطلب كمكتمل.',
              color: Colors.teal,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _completeRequest,
              icon: const Icon(Icons.done_all),
              label: const Text('إكمال الطلب'),
            ),
          ],
        );

      case 'completed':
        return const _NoticeCard(
          icon: Icons.done_all,
          title: 'الطلب مكتمل',
          message: 'تم استلام الطلب وإكمال العملية بنجاح.',
          color: Colors.green,
        );

      case 'rejected':
        return const _NoticeCard(
          icon: Icons.close,
          title: 'تم رفض الطلب',
          message: 'تم رفض هذا الطلب.',
          color: Colors.red,
        );

      case 'cancelled':
        return const _NoticeCard(
          icon: Icons.cancel_outlined,
          title: 'الطلب ملغي',
          message: 'تم إلغاء هذا الطلب.',
          color: Colors.red,
        );

      case 'expired':
        return const _NoticeCard(
          icon: Icons.timer_off_outlined,
          title: 'الطلب منتهي',
          message: 'انتهت صلاحية هذا الطلب.',
          color: Colors.red,
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

// ================================================================
// Offer Gallery
// ================================================================

class _OfferGallery extends StatefulWidget {
  final List<String> images;
  final String title;

  const _OfferGallery({
    required this.images,
    required this.title,
  });

  @override
  State<_OfferGallery> createState() => _OfferGalleryState();
}

class _OfferGalleryState extends State<_OfferGallery> {
  final PageController _controller = PageController();

  int _currentIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return Container(
        height: 230,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: const Center(
          child: Icon(
            Icons.fastfood_outlined,
            size: 70,
          ),
        ),
      );
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 230,
            width: double.infinity,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final imageUrl = widget.images[index];

                return Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) {
                    return Container(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 60,
                        ),
                      ),
                    );
                  },
                  loadingBuilder: (
                    context,
                    child,
                    loadingProgress,
                  ) {
                    if (loadingProgress == null) {
                      return child;
                    }

                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  },
                );
              },
            ),
          ),
        ),
        if (widget.images.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.images.length,
              (index) {
                final active = index == _currentIndex;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 3,
                  ),
                  width: active ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: active
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

// ================================================================
// Offer Header
// ================================================================

class _OfferHeader extends StatelessWidget {
  final String title;
  final String category;
  final String price;
  final int quantity;

  const _OfferHeader({
    required this.title,
    required this.category,
    required this.price,
    required this.quantity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _SmallChip(
                  icon: Icons.category_outlined,
                  label: category,
                ),
                const SizedBox(width: 8),
                _SmallChip(
                  icon: Icons.inventory_2_outlined,
                  label: 'الكمية: $quantity',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.payments_outlined,
                  size: 21,
                ),
                const SizedBox(width: 8),
                Text(
                  'السعر الرمزي: $price جنيه',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// Status Card
// ================================================================

class _StatusCard extends StatelessWidget {
  final String status;
  final String label;
  final Color color;
  final IconData icon;

  const _StatusCard({
    required this.status,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withAlpha(64),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withAlpha(38),
            foregroundColor: color,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// Request Progress
// ================================================================

class _RequestProgress extends StatelessWidget {
  final String status;

  const _RequestProgress({
    required this.status,
  });

  int get _currentStep {
    switch (status) {
      case 'pending':
        return 0;

      case 'accepted':
        return 1;

      case 'ready_for_pickup':
        return 2;

      case 'picked_up':
        return 3;

      case 'completed':
        return 4;

      default:
        return -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentStep;

    if (current < 0) {
      return const SizedBox.shrink();
    }

    const steps = [
      (
        title: 'طلب',
        icon: Icons.receipt_long_outlined,
      ),
      (
        title: 'قبول',
        icon: Icons.check_circle_outline,
      ),
      (
        title: 'تجهيز',
        icon: Icons.inventory_2_outlined,
      ),
      (
        title: 'استلام',
        icon: Icons.local_shipping_outlined,
      ),
      (
        title: 'إكمال',
        icon: Icons.done_all,
      ),
    ];

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'حالة الطلب',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: List.generate(
                steps.length,
                (index) {
                  final completed = index <= current;

                  return Expanded(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: completed
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                          foregroundColor: completed ? Colors.white : null,
                          child: Icon(
                            steps[index].icon,
                            size: 20,
                            color: completed ? Colors.white : null,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          steps[index].title,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                completed ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// Request Info
// ================================================================

class _RequestInfoCard extends StatelessWidget {
  final InstitutionOfferRequest request;

  const _RequestInfoCard({
    required this.request,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'بيانات الطلب',
      icon: Icons.person_outline,
      children: [
        _InfoRow(
          icon: Icons.tag,
          title: 'رقم الطلب',
          value: request.id,
        ),
        _InfoRow(
          icon: Icons.person_outline,
          title: 'معرف المستخدم',
          value: request.requesterId,
        ),
        _InfoRow(
          icon: Icons.shopping_bag_outlined,
          title: 'الكمية المطلوبة',
          value: request.quantity.toString(),
        ),
        _InfoRow(
          icon: Icons.schedule_outlined,
          title: 'تاريخ الطلب',
          value: _formatDate(request.createdAt!),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();

    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month/$year - $hour:$minute';
  }
}

// ================================================================
// Offer Info
// ================================================================

class _OfferInfoCard extends StatelessWidget {
  final String description;
  final String pickupLocation;
  final Map<String, dynamic> offer;

  const _OfferInfoCard({
    required this.description,
    required this.pickupLocation,
    required this.offer,
  });

  @override
  Widget build(BuildContext context) {
    final pickupTime = offer['pickup_time']?.toString().trim();

    final pickupNotes = offer['pickup_notes']?.toString().trim();

    return _SectionCard(
      title: 'تفاصيل العرض',
      icon: Icons.fastfood_outlined,
      children: [
        _InfoRow(
          icon: Icons.description_outlined,
          title: 'الوصف',
          value: description,
        ),
        _InfoRow(
          icon: Icons.location_on_outlined,
          title: 'مكان الاستلام',
          value: pickupLocation,
        ),
        if (pickupTime != null && pickupTime.isNotEmpty)
          _InfoRow(
            icon: Icons.access_time_outlined,
            title: 'وقت الاستلام',
            value: pickupTime,
          ),
        if (pickupNotes != null && pickupNotes.isNotEmpty)
          _InfoRow(
            icon: Icons.notes_outlined,
            title: 'ملاحظات الاستلام',
            value: pickupNotes,
          ),
      ],
    );
  }
}

// ================================================================
// Section Card
// ================================================================

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ================================================================
// Info Row
// ================================================================

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// Small Chip
// ================================================================

class _SmallChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SmallChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// Notice Card
// ================================================================

class _NoticeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;

  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withAlpha(51),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: const TextStyle(
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
