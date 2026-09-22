/// Arabic notification vocabulary shared by Flutter screens and FCM taps.
///
/// Reference IDs are used only for in-app routing. Do not put names, phone
/// numbers, emails, passwords, addresses, or auth tokens in notification data.
enum loqmaNotificationType {
  donationCreated('donation_created'),
  donationViewed('donation_viewed'),
  donationAccepted('donation_accepted'),
  donationCancelled('donation_cancelled'),
  donationExpired('donation_expired'),
  requestReceived('request_received'),
  requestAccepted('request_accepted'),
  requestRejected('request_rejected'),
  requestExpired('request_expired'),
  pickupReady('pickup_ready'),
  pickupCompleted('pickup_completed'),
  charityDonationReceived('charity_donation_received'),
  institutionOfferRequested('institution_offer_requested'),
  institutionRequestAccepted('institution_request_accepted'),
  institutionRequestReady('institution_request_ready'),
  institutionRequestCompleted('institution_request_completed');

  const loqmaNotificationType(this.value);

  final String value;

  static loqmaNotificationType? fromValue(String? value) {
    final normalized = value?.trim().toLowerCase();
    for (final type in values) {
      if (type.value == normalized) return type;
    }
    return null;
  }
}

class loqmaNotificationMessage {
  const loqmaNotificationMessage({
    required this.type,
    required this.title,
    required this.body,
    this.screen,
    this.referenceId,
    this.referenceType,
  });

  final loqmaNotificationType type;
  final String title;
  final String body;
  final String? screen;
  final String? referenceId;
  final String? referenceType;

  Map<String, String> toData() {
    final result = <String, String>{'type': type.value};
    _put(result, 'screen', screen);
    _put(result, 'reference_id', referenceId);
    _put(result, 'reference_type', referenceType);
    return result;
  }

  factory loqmaNotificationMessage.fromData(Map<String, dynamic> data) {
    final type = loqmaNotificationType.fromValue(data['type']?.toString()) ??
        loqmaNotificationType.donationViewed;

    return loqmaNotificationMessage(
      type: type,
      title: _safeText(data['title']) ?? _defaultTitle(type),
      body: _safeText(data['body']) ?? _defaultBody(type),
      screen: _safeText(data['screen']),
      referenceId: _safeReference(data['reference_id']),
      referenceType: _safeText(data['reference_type']),
    );
  }

  static loqmaNotificationMessage create({
    required loqmaNotificationType type,
    String? referenceId,
    String? referenceType,
  }) {
    return loqmaNotificationMessage(
      type: type,
      title: _defaultTitle(type),
      body: _defaultBody(type),
      screen: _defaultScreen(type),
      referenceId: _safeReference(referenceId),
      referenceType: _safeText(referenceType),
    );
  }

  static String _defaultTitle(loqmaNotificationType type) {
    switch (type) {
      case loqmaNotificationType.donationCreated:
        return 'عرض جديد على جُود';
      case loqmaNotificationType.donationViewed:
        return 'تفاصيل العرض';
      case loqmaNotificationType.donationAccepted:
        return 'تم قبول طلبك';
      case loqmaNotificationType.donationCancelled:
        return 'تم إلغاء الطلب';
      case loqmaNotificationType.donationExpired:
        return 'انتهى العرض';
      case loqmaNotificationType.requestReceived:
        return 'طلب جديد على عرضك';
      case loqmaNotificationType.requestAccepted:
        return 'تم قبول الطلب';
      case loqmaNotificationType.requestRejected:
        return 'تم رفض الطلب';
      case loqmaNotificationType.requestExpired:
        return 'انتهت مهلة الطلب';
      case loqmaNotificationType.pickupReady:
        return 'الطلب جاهز للاستلام';
      case loqmaNotificationType.pickupCompleted:
        return 'تم استلام الطلب';
      case loqmaNotificationType.charityDonationReceived:
        return 'تبرع جديد للجمعية';
      case loqmaNotificationType.institutionOfferRequested:
        return 'طلب جديد على عرض المؤسسة';
      case loqmaNotificationType.institutionRequestAccepted:
        return 'تم قبول طلب المؤسسة';
      case loqmaNotificationType.institutionRequestReady:
        return 'العرض جاهز للاستلام';
      case loqmaNotificationType.institutionRequestCompleted:
        return 'اكتمل طلب المؤسسة';
    }
  }

  static String _defaultBody(loqmaNotificationType type) {
    switch (type) {
      case loqmaNotificationType.donationCreated:
        return 'يوجد عرض جديد متاح بالقرب منك.';
      case loqmaNotificationType.donationViewed:
        return 'يمكنك فتح تفاصيل العرض من التطبيق.';
      case loqmaNotificationType.donationAccepted:
        return 'تم قبول طلبك. افتح التطبيق لمعرفة الخطوة التالية.';
      case loqmaNotificationType.donationCancelled:
        return 'تم إلغاء الطلب وتحديث حالة العرض.';
      case loqmaNotificationType.donationExpired:
        return 'انتهت مهلة العرض أو لم يعد متاحًا.';
      case loqmaNotificationType.requestReceived:
        return 'يوجد مستخدم مهتم بأحد عروضك.';
      case loqmaNotificationType.requestAccepted:
        return 'تم قبول طلبك. راجع تفاصيل الاستلام من التطبيق.';
      case loqmaNotificationType.requestRejected:
        return 'تعذر قبول الطلب هذه المرة.';
      case loqmaNotificationType.requestExpired:
        return 'انتهت مهلة الطلب وعادت الكمية المتاحة.';
      case loqmaNotificationType.pickupReady:
        return 'أصبح الطلب جاهزًا للاستلام.';
      case loqmaNotificationType.pickupCompleted:
        return 'تم تسجيل اكتمال الاستلام بنجاح.';
      case loqmaNotificationType.charityDonationReceived:
        return 'وصل تبرع جديد ويحتاج إلى المتابعة.';
      case loqmaNotificationType.institutionOfferRequested:
        return 'يوجد طلب جديد على أحد عروضك.';
      case loqmaNotificationType.institutionRequestAccepted:
        return 'تم قبول طلبك من المؤسسة.';
      case loqmaNotificationType.institutionRequestReady:
        return 'العرض جاهز، راجع كود الاستلام داخل التطبيق.';
      case loqmaNotificationType.institutionRequestCompleted:
        return 'تم إكمال طلب العرض بنجاح.';
    }
  }

  static String _defaultScreen(loqmaNotificationType type) {
    switch (type) {
      case loqmaNotificationType.donationCreated:
      case loqmaNotificationType.donationViewed:
        return 'offers';
      case loqmaNotificationType.requestReceived:
      case loqmaNotificationType.institutionOfferRequested:
        return 'requests';
      case loqmaNotificationType.charityDonationReceived:
        return 'charity_donations';
      default:
        return 'request_details';
    }
  }

  static void _put(Map<String, String> target, String key, String? value) {
    final clean = _safeText(value);
    if (clean != null) target[key] = clean;
  }

  static String? _safeReference(dynamic value) {
    final clean = _safeText(value);
    if (clean == null || clean.length > 80) return null;
    return clean;
  }

  static String? _safeText(dynamic value) {
    final clean = value?.toString().trim();
    if (clean == null || clean.isEmpty || clean.length > 120) return null;

    final lower = clean.toLowerCase();
    if (clean.contains('@') ||
        lower.contains('token') ||
        lower.contains('password') ||
        lower.contains('secret') ||
        lower.contains('http://') ||
        lower.contains('https://')) {
      return null;
    }
    return clean;
  }
}
