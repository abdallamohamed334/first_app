import 'package:flutter/material.dart';
import '../../domain/entities/notification.dart';

class NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    final borderColor = isUnread ? Colors.green.shade200 : Colors.grey.shade300;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Semantics(
        button: true,
        label: '${notification.title}. ${notification.body}',
        onTap: onTap,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUnread ? Colors.green.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildIcon(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          textAlign: TextAlign.start,
                          style: TextStyle(
                            fontWeight:
                                isUnread ? FontWeight.bold : FontWeight.w500,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.body,
                          textAlign: TextAlign.start,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _timeAgo(notification.createdAt),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isUnread) ...[
                    const SizedBox(width: 8),
                    const Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: SizedBox(
                        width: 8,
                        height: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    late final IconData icon;
    late final Color color;

    switch (notification.type) {
      case NotificationType.newOffer:
        icon = Icons.fastfood;
        color = Colors.orange;
        break;
      case NotificationType.offerRequest:
        icon = Icons.mark_email_unread;
        color = Colors.blue;
        break;
      case NotificationType.requestAccepted:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case NotificationType.requestRejected:
        icon = Icons.cancel;
        color = Colors.red;
        break;
      case NotificationType.offerExpiring:
        icon = Icons.warning_amber_rounded;
        color = Colors.amber.shade800;
        break;
      case NotificationType.deliveryAssigned:
        icon = Icons.delivery_dining;
        color = Colors.purple;
        break;
      case NotificationType.deliveryCompleted:
        icon = Icons.task_alt;
        color = Colors.teal;
        break;
      case NotificationType.newMessage:
        icon = Icons.chat_bubble;
        color = Colors.indigo;
        break;
      case NotificationType.pointsEarned:
        icon = Icons.star;
        color = Colors.amber.shade800;
        break;
      case NotificationType.rewardAvailable:
        icon = Icons.card_giftcard;
        color = Colors.pink;
        break;
      case NotificationType.system:
        icon = Icons.info;
        color = Colors.grey;
        break;
    }

    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(icon, color: color, size: 20),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);

    if (diff.isNegative || diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
