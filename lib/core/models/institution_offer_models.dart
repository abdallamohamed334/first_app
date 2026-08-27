class InstitutionOfferCore {
  final String id;
  final String institutionId;
  final String title;
  final String description;
  final String category;
  final DateTime expiresAt;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InstitutionOfferCore({
    required this.id,
    required this.institutionId,
    required this.title,
    required this.description,
    required this.category,
    required this.expiresAt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InstitutionOfferCore.fromJson(Map<String, dynamic> json) {
    final created = _date(json['created_at']) ?? DateTime.now().toUtc();
    return InstitutionOfferCore(
      id: _text(json['id']),
      institutionId: _text(json['institution_id']),
      title: _text(json['title'], fallback: 'عرض بدون اسم'),
      description: _text(json['description']),
      category: _text(json['category'], fallback: 'other'),
      expiresAt: _date(json['expires_at']) ?? DateTime.now().toUtc(),
      status: _text(json['status'], fallback: 'active'),
      createdAt: created,
      updatedAt: _date(json['updated_at']) ?? created,
    );
  }
}

class InstitutionOfferPricing {
  final String offerId;
  final double symbolicPrice;
  final double? originalPrice;
  final String currency;

  const InstitutionOfferPricing({
    required this.offerId,
    required this.symbolicPrice,
    this.originalPrice,
    required this.currency,
  });

  double? get discountPercent {
    if (originalPrice == null || originalPrice! <= 0) return null;
    return (((originalPrice! - symbolicPrice) / originalPrice!) * 100)
        .clamp(0, 100)
        .toDouble();
  }

  factory InstitutionOfferPricing.fromJson(Map<String, dynamic> json) {
    return InstitutionOfferPricing(
      offerId: _text(json['offer_id']),
      symbolicPrice: _double(json['symbolic_price']),
      originalPrice: _nullableDouble(json['original_price']),
      currency: _text(json['currency'], fallback: 'EGP'),
    );
  }
}

class InstitutionOfferInventory {
  final String offerId;
  final int quantity;
  final int remainingQuantity;
  final int reservedQuantity;
  final String? unitLabel;

  const InstitutionOfferInventory({
    required this.offerId,
    required this.quantity,
    required this.remainingQuantity,
    required this.reservedQuantity,
    this.unitLabel,
  });

  bool get isSoldOut => remainingQuantity <= 0;

  factory InstitutionOfferInventory.fromJson(Map<String, dynamic> json) {
    return InstitutionOfferInventory(
      offerId: _text(json['offer_id']),
      quantity: _int(json['quantity']),
      remainingQuantity: _int(json['remaining_quantity']),
      reservedQuantity: _int(json['reserved_quantity']),
      unitLabel: _nullableText(json['unit_label']),
    );
  }
}

class InstitutionOfferMedia {
  final String id;
  final String offerId;
  final String publicUrl;
  final String? storagePath;
  final int sortOrder;
  final bool isPrimary;

  const InstitutionOfferMedia({
    required this.id,
    required this.offerId,
    required this.publicUrl,
    this.storagePath,
    required this.sortOrder,
    required this.isPrimary,
  });

  factory InstitutionOfferMedia.fromJson(Map<String, dynamic> json) {
    return InstitutionOfferMedia(
      id: _text(json['id']),
      offerId: _text(json['offer_id']),
      publicUrl: _text(json['public_url']),
      storagePath: _nullableText(json['storage_path']),
      sortOrder: _int(json['sort_order']),
      isPrimary: json['is_primary'] == true,
    );
  }
}

class InstitutionOfferPickup {
  final String offerId;
  final String? city;
  final String? address;
  final String? locationText;
  final DateTime? pickupBefore;
  final double? latitude;
  final double? longitude;

  const InstitutionOfferPickup({
    required this.offerId,
    this.city,
    this.address,
    this.locationText,
    this.pickupBefore,
    this.latitude,
    this.longitude,
  });

  factory InstitutionOfferPickup.fromJson(Map<String, dynamic> json) {
    return InstitutionOfferPickup(
      offerId: _text(json['offer_id']),
      city: _nullableText(json['city']),
      address: _nullableText(json['address']),
      locationText: _nullableText(json['location_text']),
      pickupBefore: _date(json['pickup_before']),
      latitude: _nullableDouble(json['latitude']),
      longitude: _nullableDouble(json['longitude']),
    );
  }
}

class InstitutionOfferStatusEvent {
  final String id;
  final String offerId;
  final String? fromStatus;
  final String toStatus;
  final String? actorUserId;
  final String? note;
  final DateTime createdAt;

  const InstitutionOfferStatusEvent({
    required this.id,
    required this.offerId,
    this.fromStatus,
    required this.toStatus,
    this.actorUserId,
    this.note,
    required this.createdAt,
  });

  factory InstitutionOfferStatusEvent.fromJson(Map<String, dynamic> json) {
    return InstitutionOfferStatusEvent(
      id: _text(json['id']),
      offerId: _text(json['offer_id']),
      fromStatus: _nullableText(json['from_status']),
      toStatus: _text(json['to_status']),
      actorUserId: _nullableText(json['actor_user_id']),
      note: _nullableText(json['note']),
      createdAt: _date(json['created_at']) ?? DateTime.now().toUtc(),
    );
  }
}

class InstitutionOfferAggregate {
  final InstitutionOfferCore core;
  final InstitutionOfferPricing pricing;
  final InstitutionOfferInventory inventory;
  final List<InstitutionOfferMedia> media;
  final InstitutionOfferPickup pickup;
  final List<InstitutionOfferStatusEvent> events;

  const InstitutionOfferAggregate({
    required this.core,
    required this.pricing,
    required this.inventory,
    required this.media,
    required this.pickup,
    this.events = const [],
  });

  bool get isAvailable =>
      core.status == 'active' &&
      !inventory.isSoldOut &&
      DateTime.now().toUtc().isBefore(core.expiresAt.toUtc()) &&
      (pickup.pickupBefore == null ||
          DateTime.now().toUtc().isBefore(pickup.pickupBefore!.toUtc()));
}

String _text(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _nullableText(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

int _int(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _double(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _nullableDouble(dynamic value) {
  if (value == null) return null;
  final parsed = double.tryParse(value.toString());
  return parsed;
}

DateTime? _date(dynamic value) {
  if (value is DateTime) return value;
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : DateTime.tryParse(text);
}
