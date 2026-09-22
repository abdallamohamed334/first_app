// lib/features/marketplace/data/models/marketplace_offer_model.dart

import '../../domain/entities/marketplace_offer.dart';

class MarketplaceOfferModel extends MarketplaceOffer {
  const MarketplaceOfferModel({
    required super.marketplaceOfferId,
    required super.sourceType,
    required super.sourceId,
    required super.categoryId,
    required super.categorySlug,
    super.categoryNameAr,
    required super.title,
    super.description,
    required super.quantity,
    super.remainingQuantity,
    super.price,
    super.originalPrice,
    super.image,
    required super.images,
    super.pickupLocation,
    super.latitude,
    super.longitude,
    super.distanceMeters,
    super.ownerId,
    super.ownerName,
    super.ownerAvatar,
    super.itemCondition,
    required super.status,
    super.createdAt,
  });

  factory MarketplaceOfferModel.fromMap(
    Map<String, dynamic> map,
  ) {
    // ─────────────────────────────────────────────────────────
    // Parse images
    // ─────────────────────────────────────────────────────────

    final rawImages = map['images'];

    final parsedImages = <String>[];

    if (rawImages is List) {
      for (final item in rawImages) {
        if (item == null) continue;
        final value = item.toString().trim();
        if (value.isNotEmpty && value != 'null') {
          parsedImages.add(value);
        }
      }
    }

    final image = map['image']?.toString();

    if (image != null &&
        image.isNotEmpty &&
        image != 'null' &&
        !parsedImages.contains(image)) {
      parsedImages.insert(0, image);
    }

    // ─────────────────────────────────────────────────────────
    // Parse date
    // ─────────────────────────────────────────────────────────

    DateTime? createdAt;

    final rawCreatedAt = map['created_at'];

    if (rawCreatedAt != null) {
      createdAt = DateTime.tryParse(rawCreatedAt.toString());
    }

    // ─────────────────────────────────────────────────────────
    // Parse numbers safely
    // ─────────────────────────────────────────────────────────

    int parseInt(dynamic value, {int fallback = 0}) {
      if (value == null) return fallback;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? fallback;
    }

    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    // ─────────────────────────────────────────────────────────
    // Title / description with fallback
    // ─────────────────────────────────────────────────────────

    final rawTitle = map['title']?.toString().trim() ?? '';

    final rawDescription = map['description']?.toString().trim();

    // ─────────────────────────────────────────────────────────
    // Owner info (with fallback for missing owner_id)
    // ─────────────────────────────────────────────────────────

    final ownerId = map['owner_id']?.toString().trim();

    final ownerName = map['owner_name']?.toString().trim();

    final ownerAvatar = map['owner_avatar']?.toString().trim();

    // ─────────────────────────────────────────────────────────
    // Build model
    // ─────────────────────────────────────────────────────────

    return MarketplaceOfferModel(
      marketplaceOfferId: map['marketplace_offer_id']?.toString() ?? '',
      sourceType: map['source_type']?.toString() ?? '',
      sourceId: map['source_id']?.toString() ?? '',
      categoryId: map['category_id']?.toString() ?? '',
      categorySlug: map['category_slug']?.toString() ?? '',
      categoryNameAr: map['category_name_ar']?.toString(),
      title: rawTitle.isEmpty ? 'عرض' : rawTitle,
      description: (rawDescription == null || rawDescription.isEmpty)
          ? null
          : rawDescription,
      quantity: parseInt(map['quantity']),
      remainingQuantity: map['remaining_quantity'] != null
          ? parseInt(map['remaining_quantity'])
          : null,
      price: parseDouble(map['price']),
      originalPrice: map['original_price']?.toString(),
      image: image,
      images: parsedImages,
      pickupLocation: map['pickup_location']?.toString(),
      latitude: parseDouble(map['latitude']),
      longitude: parseDouble(map['longitude']),
      distanceMeters: parseDouble(map['distance_meters']),
      ownerId: (ownerId == null || ownerId.isEmpty) ? null : ownerId,
      ownerName: (ownerName == null || ownerName.isEmpty) ? null : ownerName,
      ownerAvatar:
          (ownerAvatar == null || ownerAvatar.isEmpty) ? null : ownerAvatar,
      itemCondition: map['item_condition']?.toString(),
      status: map['status']?.toString() ?? 'active',
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'marketplace_offer_id': marketplaceOfferId,
      'source_type': sourceType,
      'source_id': sourceId,
      'category_id': categoryId,
      'category_slug': categorySlug,
      'category_name_ar': categoryNameAr,
      'title': title,
      'description': description,
      'quantity': quantity,
      'remaining_quantity': remainingQuantity,
      'price': price,
      'original_price': originalPrice,
      'image': image,
      'images': images,
      'pickup_location': pickupLocation,
      'latitude': latitude,
      'longitude': longitude,
      'distance_meters': distanceMeters,
      'owner_id': ownerId,
      'owner_name': ownerName,
      'owner_avatar': ownerAvatar,
      'item_condition': itemCondition,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
