import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loqma/features/notification/domain/entities/notification.dart';

OverlayEntry? _activeNotificationEntry;
Timer? _notificationDismissTimer;

void showInAppNotificationBanner(
  BuildContext context,
  AppNotification notification, {
  VoidCallback? onTap,
}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  _notificationDismissTimer?.cancel();
  _activeNotificationEntry?.remove();

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _InAppNotificationBanner(
      notification: notification,
      onTap: () {
        entry.remove();
        _activeNotificationEntry = null;
        onTap?.call();
      },
      onDismiss: () {
        entry.remove();
        _activeNotificationEntry = null;
      },
    ),
  );

  _activeNotificationEntry = entry;
  overlay.insert(entry);
  _notificationDismissTimer = Timer(const Duration(seconds: 6), () {
    if (entry.mounted) entry.remove();
    if (identical(_activeNotificationEntry, entry)) {
      _activeNotificationEntry = null;
    }
  });
}

class _InAppNotificationBanner extends StatefulWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _InAppNotificationBanner({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_InAppNotificationBanner> createState() =>
      _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<_InAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..forward();
    _slide =
        Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + 10;
    final notification = widget.notification;

    return Positioned(
      top: top,
      left: 14,
      right: 14,
      child: SafeArea(
        bottom: false,
        child: SlideTransition(
          position: _slide,
          child: FadeTransition(
            opacity: _fade,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 74),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF123F31),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 22,
                        offset: Offset(0, 9),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF25B77C).withAlpha(45),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(notification.type.icon,
                            style: const TextStyle(fontSize: 23)),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _message(notification),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  height: 1.25),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: widget.onDismiss,
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white70, size: 19),
                        tooltip: 'إغلاق',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _message(AppNotification notification) {
    final type = notification.type.name;
    if (type == 'requestAccepted') {
      return 'الجمعية قبلت تبرعك وستبدأ خطوات الاستلام.';
    }
    if (type == 'requestRejected') {
      return 'الجمعية اعتذرت عن استقبال هذا التبرع.';
    }
    if (type == 'deliveryCompleted') return 'تم تسجيل اكتمال عملية التبرع.';
    return notification.body.isEmpty
        ? 'اضغط لفتح متابعة التبرع.'
        : notification.body;
  }
}
