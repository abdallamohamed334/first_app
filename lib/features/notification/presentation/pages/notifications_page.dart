import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loqma/features/donation/presentation/pages/offer_details_page.dart';
import 'package:loqma/features/community/presentation/pages/community_my_requests_page.dart';
import 'package:loqma/core/services/supabase_service.dart';
import '../bloc/notification_bloc.dart';
import '../bloc/notification_event.dart';
import '../bloc/notification_state.dart';
import '../../domain/entities/notification.dart';

class NotificationsPage extends StatefulWidget {
  final String userId;

  const NotificationsPage({super.key, required this.userId});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    context.read<NotificationBloc>().add(
          LoadNotifications(widget.userId),
        );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // فتح تفاصيل عرض الطعام أو صفحة طلبات المجتمع حسب نوع الإشعار.
  Future<void> _handleNotificationTap(
      BuildContext context, AppNotification notification) async {
    final typeName = notification.type.name;
    final referenceType = notification.referenceType ?? '';
    final isCommunityRequest = referenceType == 'offer_request' ||
        referenceType == 'community_request' ||
        typeName == 'offerRequest' ||
        typeName == 'requestAccepted' ||
        typeName == 'requestRejected' ||
        typeName == 'deliveryCompleted';

    if (isCommunityRequest) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const CommunityMyRequestsPage(),
        ),
      );
      if (!mounted) return;
      context.read<NotificationBloc>().add(
            LoadNotifications(widget.userId),
          );
      return;
    }

    if (notification.type != NotificationType.newOffer) return;

    final referenceId = notification.referenceId;
    if (referenceId == null) return;

    try {
      final supabase = SupabaseService().client;
      final response = await supabase
          .from('food_offers')
          .select('*, restaurants(name, address, logo, phone)')
          .eq('id', referenceId)
          .maybeSingle();

      if (response == null || !mounted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('العرض غير موجود')),
          );
        }
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OfferDetailsPage(
            offer: {
              'id': response['id'],
              'title': response['title'] ?? 'عرض بدون عنوان',
              'description': response['description'] ?? '',
              'quantity': response['quantity'] ?? 0,
              'food_type': response['food_type'] ?? '',
              'expiry_time': response['expiry_time']?.toString() ??
                  DateTime.now().toIso8601String(),
              'pickup_before': response['pickup_before']?.toString() ??
                  DateTime.now().toIso8601String(),
              'pickup_location': response['pickup_location'] ?? '',
              'latitude': response['latitude'],
              'longitude': response['longitude'],
              'image': response['image'],
              'status': response['status'] ?? 'available',
              'restaurant_id': response['restaurant_id'],
              'charity_id': response['charity_id'],
              'created_at': response['created_at']?.toString() ??
                  DateTime.now().toIso8601String(),
              'updated_at': response['updated_at']?.toString() ??
                  DateTime.now().toIso8601String(),
              'restaurants':
                  response['restaurants'] ?? {'name': 'مطعم غير معروف'},
              'images': response['images'] ??
                  (response['image'] != null ? [response['image']] : []),
            },
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر فتح الإشعار: $e')),
        );
      }
    }
  }

  // ✅ دالة حذف الإشعار
  Future<void> _deleteNotification(String notificationId) async {
    try {
      final supabase = SupabaseService().client;
      await supabase.from('notifications').delete().eq('id', notificationId);

      print('✅ Notification deleted: $notificationId');

      // ✅ تحديث القائمة
      context.read<NotificationBloc>().add(
            LoadNotifications(widget.userId),
          );
    } catch (e) {
      print('❌ Delete error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'الإشعارات',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              context.read<NotificationBloc>().add(
                    LoadNotifications(widget.userId),
                  );
            },
          ),
          BlocBuilder<NotificationBloc, NotificationState>(
            builder: (context, state) {
              if (state.unreadCount > 0) {
                return IconButton(
                  icon: const Icon(Icons.done_all_rounded),
                  onPressed: () {
                    context.read<NotificationBloc>().add(
                          MarkAllNotificationsAsRead(widget.userId),
                        );
                  },
                );
              }
              return const SizedBox();
            },
          ),
        ],
      ),
      body: BlocBuilder<NotificationBloc, NotificationState>(
        builder: (context, state) {
          if (state is NotificationLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (state is NotificationError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'حدث خطأ: ${state.message}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<NotificationBloc>().add(
                            LoadNotifications(widget.userId),
                          );
                    },
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          if (state is NotificationLoaded) {
            if (state.notifications.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_off_outlined,
                      size: 80,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد إشعارات',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ستظهر الإشعارات هنا عند وصولها',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<NotificationBloc>().add(
                      LoadNotifications(widget.userId),
                    );
              },
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                itemCount: state.notifications.length,
                itemBuilder: (context, index) {
                  final notification = state.notifications[index];
                  return Dismissible(
                    key: Key(notification.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(
                        Icons.delete_rounded,
                        color: Colors.red,
                        size: 32,
                      ),
                    ),
                    onDismissed: (_) {
                      _deleteNotification(notification.id);
                    },
                    child: NotificationCard(
                      notification: notification,
                      onTap: () {
                        if (!notification.isRead) {
                          context.read<NotificationBloc>().add(
                                MarkNotificationAsRead(notification.id),
                              );
                        }
                        _handleNotificationTap(context, notification);
                      },
                    ),
                  );
                },
              ),
            );
          }

          return const SizedBox();
        },
      ),
    );
  }
}

// ✅ ✅ ✅ كارد الإشعارات المصمم بشكل جميل
class NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        elevation: 2,
        shadowColor: Colors.black.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: notification.isRead
                ? (isDark ? Colors.grey.shade900 : Colors.white)
                : (isDark ? Colors.blue.shade900 : Colors.blue.shade50),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notification.isRead
                  ? Colors.transparent
                  : (isDark ? Colors.blue.shade700 : Colors.blue.shade200),
              width: 1.5,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ أيقونة الإشعار
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        notification.type.icon,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // ✅ المحتوى
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: notification.isRead
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                  color: notification.isRead
                                      ? colorScheme.onSurface
                                      : colorScheme.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!notification.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.body,
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color:
                                  colorScheme.onSurfaceVariant.withAlpha(150),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatTimeAgo(notification.createdAt),
                              style: TextStyle(
                                fontSize: 11,
                                color:
                                    colorScheme.onSurfaceVariant.withAlpha(150),
                              ),
                            ),
                            const Spacer(),
                            // ✅ نوع الإشعار
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withAlpha(15),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                _getNotificationTypeLabel(notification.type),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
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
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) {
      return 'منذ ${difference.inDays} يوم';
    } else if (difference.inHours > 0) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inMinutes > 0) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else {
      return 'الآن';
    }
  }

  String _getNotificationTypeLabel(NotificationType type) {
    switch (type) {
      case NotificationType.newOffer:
        return 'عرض جديد';
      case NotificationType.offerRequest:
        return 'طلب عرض';
      case NotificationType.requestAccepted:
        return 'تم القبول';
      case NotificationType.requestRejected:
        return 'تم الرفض';
      case NotificationType.offerExpiring:
        return 'عرض على وشك الانتهاء';
      case NotificationType.deliveryAssigned:
        return 'توصيل';
      case NotificationType.deliveryCompleted:
        return 'تم التوصيل';
      case NotificationType.newMessage:
        return 'رسالة';
      case NotificationType.pointsEarned:
        return 'نقاط';
      case NotificationType.rewardAvailable:
        return 'مكافأة';
      case NotificationType.system:
        return 'نظام';
    }
  }
}
