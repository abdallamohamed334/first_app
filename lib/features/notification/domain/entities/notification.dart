// ============================================================
// 4️⃣ notification.dart (Entity)
// ============================================================
import 'package:equatable/equatable.dart';

enum NotificationType {
  newOffer('new_offer'),
  offerRequest('offer_request'),
  requestAccepted('request_accepted'),
  requestRejected('request_rejected'),
  offerExpiring('offer_expiring'),
  deliveryAssigned('delivery_assigned'),
  deliveryCompleted('delivery_completed'),
  newMessage('new_message'),
  pointsEarned('points_earned'),
  rewardAvailable('reward_available'),
  system('system');

  final String value;
  const NotificationType(this.value);

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationType.system,
    );
  }

  String get icon {
    switch (this) {
      case NotificationType.newOffer:
        return '🍽️';
      case NotificationType.offerRequest:
        return '📩';
      case NotificationType.requestAccepted:
        return '✅';
      case NotificationType.requestRejected:
        return '❌';
      case NotificationType.offerExpiring:
        return '⚠️';
      case NotificationType.deliveryAssigned:
        return '🚚';
      case NotificationType.deliveryCompleted:
        return '🎉';
      case NotificationType.newMessage:
        return '💬';
      case NotificationType.pointsEarned:
        return '⭐';
      case NotificationType.rewardAvailable:
        return '🎁';
      case NotificationType.system:
        return '📢';
    }
  }
}

class AppNotification extends Equatable {
  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationType type;
  final String? referenceId;
  final String? referenceType;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.referenceId,
    this.referenceType,
    this.isRead = false,
    required this.createdAt,
  });

  AppNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    NotificationType? type,
    String? referenceId,
    String? referenceType,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      referenceId: referenceId ?? this.referenceId,
      referenceType: referenceType ?? this.referenceType,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        title,
        body,
        type,
        referenceId,
        referenceType,
        isRead,
        createdAt,
      ];
}
