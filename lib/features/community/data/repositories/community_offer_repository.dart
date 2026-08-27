import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityOfferRepository {
  final SupabaseClient _client;

  CommunityOfferRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getActiveCharities() async {
    final rows = await _client
        .from('charities')
        .select(
            'id, name, logo, address, phone, email, description, latitude, longitude, rating, is_verified')
        .eq('status', 'active')
        .eq('is_verified', true)
        .order('name');

    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createOffer({
    required String title,
    required String description,
    required String category,
    required String listingType,
    required String itemCondition,
    required int quantity,
    required double price,
    required String pickupLocation,
    required List<XFile> images,
    String? charityId,
    double? latitude,
    double? longitude,
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw Exception('يجب تسجيل الدخول أولًا');
    }

    final cleanTitle = title.trim();
    final cleanDescription = description.trim();
    final cleanLocation = pickupLocation.trim();

    if (cleanTitle.length < 3) {
      throw Exception('اكتب عنوانًا واضحًا للعرض');
    }
    if (cleanDescription.length < 10) {
      throw Exception('اكتب وصفًا أوضح للعرض');
    }
    if (!['clothing', 'furniture'].contains(category)) {
      throw Exception('يسمح للمستخدم العادي بإضافة الملابس أو الأثاث فقط');
    }
    if (!['donation', 'symbolic_sale', 'charity_donation']
        .contains(listingType)) {
      throw Exception('نوع العرض غير صحيح');
    }
    if (!['new', 'very_good', 'good', 'needs_repair'].contains(itemCondition)) {
      throw Exception('حالة العرض غير صحيحة');
    }
    if (quantity <= 0) {
      throw Exception('الكمية يجب أن تكون أكبر من صفر');
    }
    if (cleanLocation.isEmpty) {
      throw Exception('أدخل مكان الاستلام');
    }
    if (listingType == 'charity_donation' && charityId == null) {
      throw Exception('يجب اختيار الجمعية');
    }
    if (listingType != 'charity_donation' && charityId != null) {
      throw Exception('لا يمكن ربط عرض البيع أو التبرع العام بجمعية');
    }
    if (listingType == 'symbolic_sale' && price <= 0) {
      throw Exception('أدخل سعرًا أكبر من صفر');
    }
    if (listingType != 'symbolic_sale' && price != 0) {
      throw Exception('سعر التبرع يجب أن يكون صفرًا');
    }

    final uploadedUrls = <String>[];
    try {
      for (final image in images) {
        uploadedUrls.add(await _uploadImage(image, authUser.id));
      }

      final payload = <String, dynamic>{
        'owner_id': authUser.id,
        'charity_id': charityId,
        'title': cleanTitle,
        'description': cleanDescription,
        'category': category,
        'listing_type': listingType,
        'item_condition': itemCondition,
        'quantity': quantity,
        'price': listingType == 'symbolic_sale' ? price : 0,
        'image': uploadedUrls.isEmpty ? null : uploadedUrls.first,
        'images': uploadedUrls,
        'pickup_location': cleanLocation,
        'latitude': latitude,
        'longitude': longitude,
        'status': 'available',
      };

      final inserted = await _client
          .from('community_offers')
          .insert(payload)
          .select()
          .single();

      final result = Map<String, dynamic>.from(inserted);
      return _withSignedImageUrls(result);
    } catch (error) {
      await _removeUploadedFiles(uploadedUrls);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getOffers({
    String? category,
    String? listingType,
  }) async {
    var query = _client.from('community_offers').select('''
          id,
          owner_id,
          charity_id,
          title,
          description,
          category,
          listing_type,
          item_condition,
          quantity,
          price,
          image,
          images,
          pickup_location,
          latitude,
          longitude,
          status,
          created_at,
          expires_at
        ''').inFilter('status', [
      'available',
      'requested',
      'accepted',
      'reserved',
    ]).neq('listing_type', 'charity_donation');

    if (category != null && category != 'all') {
      query = query.eq('category', category);
    }
    if (listingType != null &&
        listingType != 'all' &&
        listingType != 'charity_donation') {
      query = query.eq('listing_type', listingType);
    }

    final rows = await query.order('created_at', ascending: false);
    final result = <Map<String, dynamic>>[];

    for (final rawRow in (rows as List)) {
      final row = Map<String, dynamic>.from(rawRow as Map);
      // Keep the exclusion at the client boundary as a second safety net.
      if (row['listing_type']?.toString().trim() == 'charity_donation') {
        continue;
      }
      result.add(await _withSignedImageUrls(row));
    }

    return result;
  }

  Future<String> _uploadImage(XFile image, String userId) async {
    final bytes = await image.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('إحدى الصور فارغة أو تالفة');
    }

    final extension = _extension(image.name);
    final path = '$userId/${DateTime.now().microsecondsSinceEpoch}.$extension';

    await _client.storage.from('community-offers').uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(
            contentType: _contentType(extension),
            upsert: false,
          ),
        );

    // نخزن المسار فقط، ولا نخزن Public URL داخل قاعدة البيانات.
    return path;
  }

  String _storagePath(String value) {
    final trimmed = value.trim();
    if (!trimmed.startsWith('http')) return trimmed;

    const markers = <String>[
      '/storage/v1/object/public/community-offers/',
      '/storage/v1/object/sign/community-offers/',
      '/storage/v1/object/authenticated/community-offers/',
    ];

    for (final marker in markers) {
      final index = trimmed.indexOf(marker);
      if (index >= 0) {
        return Uri.decodeComponent(trimmed.substring(index + marker.length));
      }
    }

    return trimmed;
  }

  Future<String?> _signedImageUrl(dynamic value) async {
    if (value == null) return null;
    final path = _storagePath(value.toString());
    if (path.isEmpty) return null;

    try {
      return await _client.storage
          .from('community-offers')
          .createSignedUrl(path, 3600);
    } catch (error) {
      print('COMMUNITY OFFER SIGNED IMAGE ERROR: $error');
      return null;
    }
  }

  Future<Map<String, dynamic>> _withSignedImageUrls(
    Map<String, dynamic> row,
  ) async {
    final result = Map<String, dynamic>.from(row);

    final imageUrl = await _signedImageUrl(result['image']);
    result['image'] = imageUrl;

    final rawImages = result['images'];
    if (rawImages is List) {
      final signedImages = <String>[];
      for (final rawImage in rawImages) {
        final signed = await _signedImageUrl(rawImage);
        if (signed != null && signed.isNotEmpty) signedImages.add(signed);
      }
      result['images'] = signedImages;
    } else {
      result['images'] = imageUrl == null ? <String>[] : <String>[imageUrl];
    }

    return result;
  }

  Future<void> _removeUploadedFiles(List<String> paths) async {
    final storagePaths =
        paths.map(_storagePath).where((path) => path.isNotEmpty).toList();

    if (storagePaths.isEmpty) return;

    try {
      await _client.storage.from('community-offers').remove(storagePaths);
    } catch (_) {
      // Do not hide the original upload/database error.
    }
  }

  String _extension(String name) {
    final value = name.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'webp'].contains(value) ? value : 'jpg';
  }

  String _contentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
