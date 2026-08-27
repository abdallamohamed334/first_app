import 'dart:async';

import 'package:flutter/material.dart';

class RestaurantOperationFeedback {
  static OverlayEntry? _activeEntry;
  static Timer? _timer;

  static void success(BuildContext context, String message, {String? title}) {
    _show(context, message,
        isSuccess: true, title: title ?? 'تمت العملية بنجاح');
  }

  static void error(BuildContext context, Object error, {String? title}) {
    _show(context, _arabicError(error),
        isSuccess: false, title: title ?? 'تعذر تنفيذ العملية');
  }

  static void failureMessage(BuildContext context, String message,
      {String? title}) {
    _show(context, message,
        isSuccess: false, title: title ?? 'تعذر تنفيذ العملية');
  }

  static void _show(BuildContext context, String message,
      {required bool isSuccess, required String title}) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _timer?.cancel();
    _activeEntry?.remove();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _TopOperationPopup(
        title: title,
        message: message,
        isSuccess: isSuccess,
        onClose: () {
          if (entry.mounted) entry.remove();
          if (identical(_activeEntry, entry)) _activeEntry = null;
        },
      ),
    );
    _activeEntry = entry;
    overlay.insert(entry);
    _timer = Timer(const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
      if (identical(_activeEntry, entry)) _activeEntry = null;
    });
  }

  static String _arabicError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('invalid') && raw.contains('code')) {
      return 'كود الاستلام غير صحيح أو منتهي.';
    }
    if (raw.contains('already') || raw.contains('duplicate')) {
      return 'تم تنفيذ هذه العملية من قبل.';
    }
    if (raw.contains('not found') || raw.contains('غير موجود')) {
      return 'العنصر المطلوب غير موجود أو لم يعد متاحًا.';
    }
    if (raw.contains('permission') ||
        raw.contains('forbidden') ||
        raw.contains('unauthorized')) {
      return 'ليس لديك صلاحية لتنفيذ هذه العملية.';
    }
    if (raw.contains('expired') || raw.contains('منتهي')) {
      return 'انتهت صلاحية هذا العرض أو الطلب.';
    }
    if (raw.contains('network') ||
        raw.contains('socket') ||
        raw.contains('timeout')) {
      return 'تعذر الاتصال بالخادم. تحقق من الإنترنت وحاول مرة أخرى.';
    }
    if (raw.contains('validation') ||
        raw.contains('required') ||
        raw.contains('check constraint')) {
      return 'راجع البيانات المدخلة وتأكد من اكتمالها وصحتها.';
    }
    if (raw.contains('restaurant') && raw.contains('active')) {
      return 'لا يوجد مطعم نشط مرتبط بهذا الحساب.';
    }
    if (raw.contains('charity')) {
      return 'تعذر التعامل مع الجمعية المختارة حاليًا.';
    }
    return 'حدث خطأ غير متوقع. حاول مرة أخرى.';
  }
}

class _TopOperationPopup extends StatefulWidget {
  final String title;
  final String message;
  final bool isSuccess;
  final VoidCallback onClose;
  const _TopOperationPopup(
      {required this.title,
      required this.message,
      required this.isSuccess,
      required this.onClose});

  @override
  State<_TopOperationPopup> createState() => _TopOperationPopupState();
}

class _TopOperationPopupState extends State<_TopOperationPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 280))
    ..forward();
  late final Animation<Offset> _slide =
      Tween(begin: const Offset(0, -1.15), end: Offset.zero).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.isSuccess ? const Color(0xFF0B7650) : const Color(0xFFBA1A1A);
    final soft =
        widget.isSuccess ? const Color(0xFFEAF8F0) : const Color(0xFFFFE5E1);
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 14,
      right: 14,
      child: SafeArea(
        bottom: false,
        child: SlideTransition(
          position: _slide,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
              decoration: BoxDecoration(
                  color: soft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: .35)),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x26000000),
                        blurRadius: 18,
                        offset: Offset(0, 7))
                  ]),
              child: Row(children: [
                Container(
                    width: 39,
                    height: 39,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                    child: Icon(
                        widget.isSuccess
                            ? Icons.check_rounded
                            : Icons.close_rounded,
                        color: Colors.white,
                        size: 24)),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(widget.title,
                          style: TextStyle(
                              color: color,
                              fontSize: 14,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(widget.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFF34443D),
                              fontSize: 12,
                              height: 1.35))
                    ])),
                IconButton(
                    onPressed: widget.onClose,
                    icon: Icon(Icons.close_rounded, color: color, size: 19),
                    tooltip: 'إغلاق'),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
