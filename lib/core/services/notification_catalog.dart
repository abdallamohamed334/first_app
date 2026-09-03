/// Arabic notification vocabulary shared by Flutter screens and FCM taps.
///
/// Reference IDs are used only for in-app routing. Do not put names, phone
/// numbers, emails, passwords, addresses, or auth tokens in notification data.
enum LoqmaNotificationType {
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

  const LoqmaNotificationType(this.value);

  final String value;

  static LoqmaNotificationType? fromValue(String? value) {
    final normalized = value?.trim().toLowerCase();
    for (final type in values) {
      if (type.value == normalized) return type;
    }
    return null;
  }
}

class LoqmaNotificationMessage {
  const LoqmaNotificationMessage({
    required this.type,
    required this.title,
    required this.body,
    this.screen,
    this.referenceId,
    this.referenceType,
  });

  final LoqmaNotificationType type;
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

  factory LoqmaNotificationMessage.fromData(Map<String, dynamic> data) {
    final type = LoqmaNotificationType.fromValue(data['type']?.toString()) ??
        LoqmaNotificationType.donationViewed;

    return LoqmaNotificationMessage(
      type: type,
      title: _safeText(data['title']) ?? _defaultTitle(type),
      body: _safeText(data['body']) ?? _defaultBody(type),
      screen: _safeText(data['screen']),
      referenceId: _safeReference(data['reference_id']),
      referenceType: _safeText(data['reference_type']),
    );
  }

  static LoqmaNotificationMessage create({
    required LoqmaNotificationType type,
    String? referenceId,
    String? referenceType,
  }) {
    return LoqmaNotificationMessage(
      type: type,
      title: _defaultTitle(type),
      body: _defaultBody(type),
      screen: _defaultScreen(type),
      referenceId: _safeReference(referenceId),
      referenceType: _safeText(referenceType),
    );
  }

  static String _defaultTitle(LoqmaNotificationType type) {
    switch (type) {
      case LoqmaNotificationType.donationCreated:
        return 'عرض جديد على لقمة';
      case LoqmaNotificationType.donationViewed:
        return 'تفاصيل العرض';
      case LoqmaNotificationType.donationAccepted:
        return 'تم قبول طلبك';
      case LoqmaNotificationType.donationCancelled:
        return 'تم إلغاء الطلب';
      case LoqmaNotificationType.donationExpired:
        return 'انتهى العرض';
      case LoqmaNotificationType.requestReceived:
        return 'طلب جديد على عرضك';
      case LoqmaNotificationType.requestAccepted:
        return 'تم قبول الطلب';
      case LoqmaNotificationType.requestRejected:
        return 'تم رفض الطلب';
      case LoqmaNotificationType.requestExpired:
        return 'انتهت مهلة الطلب';
      case LoqmaNotificationType.pickupReady:
        return 'الطلب جاهز للاستلام';
      case LoqmaNotificationType.pickupCompleted:
        return 'تم استلام الطلب';
      case LoqmaNotificationType.charityDonationReceived:
        return 'تبرع جديد للجمعية';
      case LoqmaNotificationType.institutionOfferRequested:
        return 'طلب جديد على عرض المؤسسة';
      case LoqmaNotificationType.institutionRequestAccepted:
        return 'تم قبول طلب المؤسسة';
      case LoqmaNotificationType.institutionRequestReady:
        return 'العرض جاهز للاستلام';
      case LoqmaNotificationType.institutionRequestCompleted:
        return 'اكتمل طلب المؤسسة';
    }
  }

  static String _defaultBody(LoqmaNotificationType type) {
    switch (type) {
      case LoqmaNotificationType.donationCreated:
        return 'يوجد عرض جديد متاح بالقرب منك.';
      case LoqmaNotificationType.donationViewed:
        return 'يمكنك فتح تفاصيل العرض من التطبيق.';
      case LoqmaNotificationType.donationAccepted:
        return 'تم قبول طلبك. افتح التطبيق لمعرفة الخطوة التالية.';
      case LoqmaNotificationType.donationCancelled:
        return 'تم إلغاء الطلب وتحديث حالة العرض.';
      case LoqmaNotificationType.donationExpired:
        return 'انتهت مهلة العرض أو لم يعد متاحًا.';
      case LoqmaNotificationType.requestReceived:
        return 'يوجد مستخدم مهتم بأحد عروضك.';
      case LoqmaNotificationType.requestAccepted:
        return 'تم قبول طلبك. راجع تفاصيل الاستلام من التطبيق.';
      case LoqmaNotificationType.requestRejected:
        return 'تعذر قبول الطلب هذه المرة.';
      case LoqmaNotificationType.requestExpired:
        return 'انتهت مهلة الطلب وعادت الكمية المتاحة.';
      case LoqmaNotificationType.pickupReady:
        return 'أصبح الطلب جاهزًا للاستلام.';
      case LoqmaNotificationType.pickupCompleted:
        return 'تم تسجيل اكتمال الاستلام بنجاح.';
      case LoqmaNotificationType.charityDonationReceived:
        return 'وصل تبرع جديد ويحتاج إلى المتابعة.';
      case LoqmaNotificationType.institutionOfferRequested:
        return 'يوجد طلب جديد على أحد عروضك.';
      case LoqmaNotificationType.institutionRequestAccepted:
        return 'تم قبول طلبك من المؤسسة.';
      case LoqmaNotificationType.institutionRequestReady:
        return 'العرض جاهز، راجع كود الاستلام داخل التطبيق.';
      case LoqmaNotificationType.institutionRequestCompleted:
        return 'تم إكمال طلب العرض بنجاح.';
    }
  }

  static String _defaultScreen(LoqmaNotificationType type) {
    switch (type) {
      case LoqmaNotificationType.donationCreated:
      case LoqmaNotificationType.donationViewed:
        return 'offers';
      case LoqmaNotificationType.requestReceived:
      case LoqmaNotificationType.institutionOfferRequested:
        return 'requests';
      case LoqmaNotificationType.charityDonationReceived:
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
