import 'package:loqma/features/notification/domain/entities/notification.dart';

class NotificationModel extends AppNotification {
  const NotificationModel({
    required super.id,
    required super.userId,
    required super.title,
    required super.body,
    required super.type,
    super.referenceId,
    super.referenceType,
    required super.isRead,
    required super.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: _typeFromString(json['type'] as String),
      referenceId: json['reference_id'] as String?,
      referenceType: json['reference_type'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'body': body,
      'type': _typeToString(type),
      'reference_id': referenceId,
      'reference_type': referenceType,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static NotificationType _typeFromString(String value) {
    switch (value) {
      case 'new_offer':
        return NotificationType.newOffer;
      case 'offer_request':
        return NotificationType.offerRequest;
      case 'request_accepted':
        return NotificationType.requestAccepted;
      case 'request_rejected':
        return NotificationType.requestRejected;
      case 'offer_expiring':
        return NotificationType.offerExpiring;
      case 'delivery_assigned':
        return NotificationType.deliveryAssigned;
      case 'delivery_completed':
        return NotificationType.deliveryCompleted;
      case 'new_message':
        return NotificationType.newMessage;
      case 'points_earned':
        return NotificationType.pointsEarned;
      case 'reward_available':
        return NotificationType.rewardAvailable;
      default:
        return NotificationType.system;
    }
  }

  static String _typeToString(NotificationType type) {
    switch (type) {
      case NotificationType.newOffer:
        return 'new_offer';
      case NotificationType.offerRequest:
        return 'offer_request';
      case NotificationType.requestAccepted:
        return 'request_accepted';
      case NotificationType.requestRejected:
        return 'request_rejected';
      case NotificationType.offerExpiring:
        return 'offer_expiring';
      case NotificationType.deliveryAssigned:
        return 'delivery_assigned';
      case NotificationType.deliveryCompleted:
        return 'delivery_completed';
      case NotificationType.newMessage:
        return 'new_message';
      case NotificationType.pointsEarned:
        return 'points_earned';
      case NotificationType.rewardAvailable:
        return 'reward_available';
      case NotificationType.system:
        return 'system';
    }
  }
}
