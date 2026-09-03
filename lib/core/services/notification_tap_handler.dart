import 'dart:async';

import 'notification_catalog.dart';

typedef LoqmaNotificationNavigation = FutureOr<void> Function(
  LoqmaNotificationMessage notification,
);

/// Converts an FCM payload into the app's notification model and delegates
/// navigation to the app router without knowing route names itself.
class LoqmaNotificationTapHandler {
  LoqmaNotificationTapHandler({
    required this.onNavigate,
    this.onOpened,
  });

  final LoqmaNotificationNavigation onNavigate;
  final FutureOr<void> Function(LoqmaNotificationMessage notification)?
      onOpened;

  Future<void> handle({
    required Map<String, dynamic> data,
    String? title,
    String? body,
  }) async {
    final normalized = <String, dynamic>{
      ...data,
      if (title != null && title.trim().isNotEmpty) 'title': title,
      if (body != null && body.trim().isNotEmpty) 'body': body,
    };

    final notification = LoqmaNotificationMessage.fromData(normalized);
    await onOpened?.call(notification);
    await onNavigate(notification);
  }
}

/// Small adapter for routers that need a simple route decision first.
///
/// Keep the actual route strings in the app's router layer, not in the FCM
/// service. This avoids coupling push delivery to navigation implementation.
class LoqmaNotificationRouteIntent {
  const LoqmaNotificationRouteIntent({
    required this.screen,
    this.referenceId,
    this.referenceType,
  });

  final String screen;
  final String? referenceId;
  final String? referenceType;

  factory LoqmaNotificationRouteIntent.fromNotification(
    LoqmaNotificationMessage notification,
  ) {
    return LoqmaNotificationRouteIntent(
      screen: notification.screen ?? 'request_details',
      referenceId: notification.referenceId,
      referenceType: notification.referenceType,
    );
  }
}
