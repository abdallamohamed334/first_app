class InstitutionOfferRequest {
  final String id;
  final String offerId;
  final String requesterId;
  final int quantity;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? offer;

  const InstitutionOfferRequest({
    required this.id,
    required this.offerId,
    required this.requesterId,
    required this.quantity,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.offer,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isReadyForPickup => status == 'ready_for_pickup';
  bool get isCompleted => status == 'completed';

  factory InstitutionOfferRequest.fromJson(Map<String, dynamic> json) {
    final offer = _offerMap(json['institution_offers_core']) ??
        _offerMap(json['institution_offers']) ??
        _offerMap(json['offer']);

    return InstitutionOfferRequest(
      id: _text(json['id']),
      offerId: _text(json['offer_id']),
      requesterId: _text(json['requester_id']),
      quantity: _int(json['quantity'], fallback: 1),
      status: _text(json['status'], fallback: 'pending'),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
      offer: offer,
    );
  }

  static Map<String, dynamic>? _offerMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List) {
      for (final item in value) {
        if (item is Map) return Map<String, dynamic>.from(item);
      }
    }
    return null;
  }

  static String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null' ? fallback : text;
  }

  static int _int(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static DateTime? _date(dynamic value) {
    if (value is DateTime) return value;
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : DateTime.tryParse(text);
  }
}
