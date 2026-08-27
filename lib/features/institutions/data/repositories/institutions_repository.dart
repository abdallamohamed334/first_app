import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:loqma/core/services/supabase_service.dart';
import '../../domain/entities/institution.dart';
import '../../domain/entities/institution_offer.dart';

class InstitutionsRepository {
  final SupabaseClient _client;

  InstitutionsRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService().client;

  Future<Institution> getMine() async {
    final authUser = _client.auth.currentUser;
    final userId = authUser?.id;
    print('[InstitutionDebug] auth.uid=${userId ?? 'null'}');
    print('[InstitutionDebug] auth.email=${authUser?.email ?? 'null'}');

    if (userId == null || userId.isEmpty) {
      print('[InstitutionDebug] STOP: no active auth session');
      throw const FormatException('يجب تسجيل الدخول أولًا');
    }

    try {
      final userRow = await _client
          .from('users')
          .select('id, user_type, is_active')
          .eq('id', userId)
          .maybeSingle();
      print(
          '[InstitutionDebug] users row=${userRow == null ? 'NULL' : 'FOUND'}');
      if (userRow != null) {
        print('[InstitutionDebug] users.user_type=${userRow['user_type']}');
        print('[InstitutionDebug] users.is_active=${userRow['is_active']}');
      }

      final rows = await _client
          .from('institutions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true)
          .limit(2);
      print('[InstitutionDebug] institutions rows=${rows.length}');
      if (rows.isNotEmpty) {
        final first = Map<String, dynamic>.from(rows.first as Map);
        print('[InstitutionDebug] institution.id=${first['id']}');
        print('[InstitutionDebug] institution.name=${first['name']}');
        print(
            '[InstitutionDebug] institution_type=${first['institution_type']}');
        print('[InstitutionDebug] institution.status=${first['status']}');
      }
      if (rows.isEmpty) {
        throw const FormatException('لا توجد مؤسسة مرتبطة بهذا الحساب');
      }
      return Institution.fromJson(Map<String, dynamic>.from(rows.first as Map));
    } on FormatException {
      print(
          '[InstitutionDebug] FORMAT: no institution match or invalid session');
      rethrow;
    } on PostgrestException catch (error) {
      print('[InstitutionDebug] POSTGREST code=${error.code}');
      print('[InstitutionDebug] POSTGREST message=${error.message}');
      print('[InstitutionDebug] POSTGREST details=${error.details}');
      throw FormatException(_friendlyInstitutionError(error));
    } catch (error) {
      print('[InstitutionDebug] UNKNOWN error=$error');
      throw const FormatException('تعذر الاتصال ببيانات المؤسسة حاليًا');
    }
  }

  String _friendlyInstitutionError(PostgrestException error) {
    final text = '${error.code} ${error.message}'.toLowerCase();
    if (text.contains('permission') ||
        text.contains('row-level security') ||
        text.contains('rls')) {
      return 'لا توجد صلاحية لقراءة بيانات المؤسسة. راجع سياسة القراءة الخاصة بالمؤسسات.';
    }
    if (text.contains('column') || text.contains('does not exist')) {
      return 'بيانات المؤسسة غير متوافقة مع نسخة قاعدة البيانات الحالية.';
    }
    return 'تعذر تحميل بيانات المؤسسة حاليًا';
  }

  Future<Institution> updateMine({
    String? name,
    String? institutionType,
    String? phone,
    String? city,
    String? address,
    String? description,
    String? logoUrl,
    String? coverImageUrl,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const FormatException('يجب تسجيل الدخول أولًا');
    }

    final data = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String()
    };
    void put(String key, String? value) {
      if (value != null) data[key] = value.trim();
    }

    put('name', name);
    put('institution_type', institutionType);
    put('phone', phone);
    put('city', city);
    put('address', address);
    put('description', description);
    put('logo_url', logoUrl);
    put('cover_image_url', coverImageUrl);

    final row = await _client
        .from('institutions')
        .update(data)
        .eq('user_id', userId)
        .select()
        .single();
    return Institution.fromJson(Map<String, dynamic>.from(row));
  }

  Future<String> uploadInstitutionImage({
    required Uint8List bytes,
    required String fileExtension,
    bool cover = false,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const FormatException('يجب تسجيل الدخول أولًا');
    }
    final safeExtension = fileExtension.replaceAll('.', '').toLowerCase();
    final path =
        '$userId/${cover ? 'cover' : 'logo'}_${DateTime.now().millisecondsSinceEpoch}.$safeExtension';
    await _client.storage.from('institution-images').uploadBinary(
          path,
          bytes,
          fileOptions:
              FileOptions(upsert: true, contentType: 'image/$safeExtension'),
        );
    return _client.storage.from('institution-images').getPublicUrl(path);
  }

  Future<List<Map<String, dynamic>>> listPublicOffers() async {
    final rows = await _client
        .from('institution_offers_core')
        .select('''
          *,
          institutions(id, name, institution_type, logo_url),
          institution_offer_pricing(*),
          institution_offer_inventory(*),
          institution_offer_pickup(*),
          institution_offer_media(*)
        ''')
        .eq('status', 'active')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: false);

    return _maps(rows)
        .map(_flattenNormalizedOffer)
        .where((offer) =>
            offer['status'] == 'active' &&
            _asInt(offer['remaining_quantity']) > 0)
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> listMyOffers(String institutionId) async {
    final cleanInstitutionId = institutionId.trim();
    if (cleanInstitutionId.isEmpty) {
      throw const FormatException('معرف المؤسسة غير موجود');
    }

    final merged = <String, Map<String, dynamic>>{};

    try {
      final normalizedRows = await _client
          .from('institution_offers_core')
          .select('''
            *,
            institutions(id, name, institution_type, logo_url),
            institution_offer_pricing(*),
            institution_offer_inventory(*),
            institution_offer_pickup(*),
            institution_offer_media(*)
          ''')
          .eq('institution_id', cleanInstitutionId)
          .order('created_at', ascending: false);

      for (final row in normalizedRows) {
        final normalized = _flattenNormalizedOffer(
          Map<String, dynamic>.from(row as Map),
        );
        final id = normalized['id']?.toString();
        if (id != null && id.isNotEmpty) merged[id] = normalized;
      }
    } on PostgrestException catch (error) {
      // The normalized tables may not be applied yet; legacy fallback below
      // keeps existing institution accounts usable during migration.
      print(
          '[InstitutionDebug] normalized listMyOffers skipped: ${error.code} ${error.message}');
    }

    try {
      final legacyRows = await _client
          .from('institution_offers')
          .select('*, institutions(id, name, institution_type, logo_url)')
          .eq('institution_id', cleanInstitutionId)
          .order('created_at', ascending: false);
      for (final row in _maps(legacyRows)) {
        final id = row['id']?.toString();
        if (id != null && id.isNotEmpty) {
          merged.putIfAbsent(id, () => row);
        }
      }
    } on PostgrestException catch (error) {
      if (merged.isEmpty) rethrow;
      print(
          '[InstitutionDebug] legacy listMyOffers skipped: ${error.code} ${error.message}');
    }

    final result = merged.values.toList(growable: false)
      ..sort((a, b) => _dateOf(b).compareTo(_dateOf(a)));
    print('[InstitutionDebug] listMyOffers normalized=${merged.length}');
    return result;
  }

  Map<String, dynamic> _flattenNormalizedOffer(Map<String, dynamic> row) {
    final pricing = _nestedMap(row['institution_offer_pricing']);
    final inventory = _nestedMap(row['institution_offer_inventory']);
    final pickup = _nestedMap(row['institution_offer_pickup']);
    final media = _nestedMaps(row['institution_offer_media']);

    final images = media
        .map((item) => item['public_url']?.toString().trim() ?? '')
        .where((url) => url.isNotEmpty)
        .toList(growable: false);

    return {
      'id': row['id'],
      'institution_id': row['institution_id'],
      'title': row['title'],
      'description': row['description'],
      'category': row['category'] ?? 'other',
      'quantity': inventory['quantity'] ?? 0,
      'remaining_quantity': inventory['remaining_quantity'] ?? 0,
      'symbolic_price': pricing['symbolic_price'] ?? 0,
      'original_price': pricing['original_price'],
      'images': images,
      'pickup_location': pickup['location_text'] ?? pickup['address'],
      'pickup_before': pickup['pickup_before'],
      'expires_at': row['expires_at'],
      'status': row['status'] ?? 'active',
      'created_at': row['created_at'],
      'updated_at': row['updated_at'] ?? row['created_at'],
      'institutions': row['institutions'],
    };
  }

  Map<String, dynamic> _nestedMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return const <String, dynamic>{};
  }

  List<Map<String, dynamic>> _nestedMaps(dynamic value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime _dateOf(Map<String, dynamic> row) {
    return DateTime.tryParse(
          (row['created_at'] ?? row['updated_at'])?.toString() ?? '',
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  Future<List<InstitutionOffer>> listPublicOfferEntities() async {
    final rows = await listPublicOffers();
    return rows.map(InstitutionOffer.fromJson).toList(growable: false);
  }

  Future<List<InstitutionOffer>> listMyOfferEntities(
      String institutionId) async {
    final rows = await listMyOffers(institutionId);
    return rows.map(InstitutionOffer.fromJson).toList(growable: false);
  }

  Future<InstitutionOffer?> getOfferById(String offerId) async {
    final row = await _client.from('institution_offers_core').select('''
          *,
          institutions(id, name, institution_type, logo_url),
          institution_offer_pricing(*),
          institution_offer_inventory(*),
          institution_offer_pickup(*),
          institution_offer_media(*)
        ''').eq('id', offerId.trim()).maybeSingle();
    return row == null
        ? null
        : InstitutionOffer.fromJson(
            _flattenNormalizedOffer(Map<String, dynamic>.from(row)),
          );
  }

  Future<List<Map<String, dynamic>>> listOfferRequestsForInstitution(
    String institutionId,
  ) async {
    if (institutionId.trim().isEmpty) {
      throw const FormatException('معرف المؤسسة غير موجود');
    }
    final offerRows = await _client
        .from('institution_offers_core')
        .select('id, title, description, category, expires_at, status')
        .eq('institution_id', institutionId.trim());

    final offers = _maps(offerRows);
    print(
        '[InstitutionDebug] request-list institutionId=${institutionId.trim()} ownedOffers=${offers.length}');
    final offerIds = offers
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    if (offerIds.isEmpty) return const <Map<String, dynamic>>[];

    final requestRows = await _client
        .from('institution_offer_requests')
        .select('*')
        .inFilter('offer_id', offerIds)
        .order('created_at', ascending: false);
    print('[InstitutionDebug] request-list rows=${requestRows.length}');

    final offersById = <String, Map<String, dynamic>>{
      for (final offer in offers)
        if (offer['id'] != null) offer['id'].toString(): offer,
    };

    return _maps(requestRows).map((request) {
      final result = Map<String, dynamic>.from(request);
      final offerId = result['offer_id']?.toString();
      final offer = offerId == null ? null : offersById[offerId];
      if (offer != null) result['institution_offers_core'] = offer;
      return result;
    }).toList(growable: false);
  }

  Future<Map<String, dynamic>> generateOfferRequestPickupCode(
      String requestId) async {
    return _rpcMap('institution_generate_offer_request_pickup_code', {
      'p_request_id': requestId.trim(),
    });
  }

  Future<Map<String, dynamic>> verifyOfferRequestPickupCode({
    required String requestId,
    required String code,
  }) async {
    return _rpcMap('institution_verify_offer_request_pickup_code', {
      'p_request_id': requestId.trim(),
      'p_code': code.trim(),
    });
  }

  Future<Map<String, dynamic>> completeOfferRequest(String requestId) async {
    return _rpcMap('institution_complete_offer_request', {
      'p_request_id': requestId.trim(),
    });
  }

  Future<Map<String, dynamic>> markOfferRequestReady(String requestId) async {
    final cleanRequestId = requestId.trim();
    if (cleanRequestId.isEmpty) {
      throw const FormatException('معرف الطلب غير موجود');
    }
    final result = await _client.rpc(
      'institution_mark_offer_request_ready',
      params: {'p_request_id': cleanRequestId},
    );
    if (result is Map) return Map<String, dynamic>.from(result);
    throw const FormatException('تعذر تجهيز الطلب للاستلام');
  }

  Future<Map<String, dynamic>> updateOfferRequest({
    required String requestId,
    required bool accept,
  }) async {
    return _rpcMap('institution_update_offer_request', {
      'p_request_id': requestId,
      'p_accept': accept,
    });
  }

  Future<String> createNormalizedOffer({
    required String institutionId,
    required String title,
    required String description,
    required String category,
    required int quantity,
    required double symbolicPrice,
    double? originalPrice,
    required List<String> images,
    String? city,
    String? address,
    String? pickupLocation,
    required DateTime expiresAt,
    DateTime? pickupBefore,
    String currency = 'EGP',
  }) async {
    final result = await _client.rpc(
      'institution_create_normalized_offer',
      params: {
        'p_institution_id': institutionId.trim(),
        'p_title': title.trim(),
        'p_description': description.trim(),
        'p_category': category.trim().isEmpty ? 'other' : category.trim(),
        'p_quantity': quantity,
        'p_symbolic_price': symbolicPrice,
        'p_original_price': originalPrice,
        'p_currency': currency,
        'p_images': images,
        'p_city': city?.trim(),
        'p_address': address?.trim(),
        'p_location_text': pickupLocation?.trim(),
        'p_expires_at': expiresAt.toUtc().toIso8601String(),
        'p_pickup_before': pickupBefore?.toUtc().toIso8601String(),
      },
    );
    if (result is String && result.isNotEmpty) return result;
    throw const FormatException('تعذر إنشاء العرض في قاعدة البيانات');
  }

  Future<Map<String, dynamic>> createOffer({
    required String institutionId,
    required String title,
    required String description,
    required String category,
    required int quantity,
    required double symbolicPrice,
    double? originalPrice,
    required List<String> images,
    String? pickupLocation,
    required DateTime expiresAt,
    DateTime? pickupBefore,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const FormatException('يجب تسجيل الدخول أولًا');
    }
    if (institutionId.trim().isEmpty) {
      throw const FormatException(
          'معرف المؤسسة غير موجود. أعد فتح صفحة المؤسسة');
    }

    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) throw const FormatException('اكتب اسم العرض');
    if (quantity <= 0)
      throw const FormatException('الكمية يجب أن تكون أكبر من صفر');
    if (symbolicPrice < 0) throw const FormatException('السعر غير صحيح');

    final ownedInstitution = await _client
        .from('institutions')
        .select('id, status')
        .eq('id', institutionId.trim())
        .eq('user_id', userId)
        .maybeSingle();
    if (ownedInstitution == null) {
      throw const FormatException('هذه المؤسسة غير مرتبطة بحساب الدخول الحالي');
    }
    if (ownedInstitution['status']?.toString() != 'active') {
      throw const FormatException('حساب المؤسسة غير نشط حاليًا');
    }

    final row = await _client
        .from('institution_offers')
        .insert({
          'institution_id': institutionId.trim(),
          'title': cleanTitle,
          'description': description.trim(),
          'category': category.trim().isEmpty ? 'other' : category.trim(),
          'quantity': quantity,
          'remaining_quantity': quantity,
          'symbolic_price': symbolicPrice,
          'original_price': originalPrice,
          'images': images,
          'pickup_location': pickupLocation?.trim(),
          'expires_at': expiresAt.toUtc().toIso8601String(),
          'pickup_before': pickupBefore?.toUtc().toIso8601String(),
          'status': 'active',
        })
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<List<Map<String, dynamic>>> listActiveCharities() async {
    final rows = await _client
        .from('charities')
        .select('id, name, logo, image_url, logo_url, address, description')
        .eq('status', 'active')
        .eq('is_verified', true)
        .order('name');
    return _maps(rows);
  }

  Future<List<Map<String, dynamic>>> listMyCharityDonations(
    String institutionId,
  ) async {
    final rows = await _client
        .from('institution_charity_donations')
        .select('*, charities(id, name, logo, image_url, logo_url)')
        .eq('institution_id', institutionId)
        .order('created_at', ascending: false);
    return _maps(rows);
  }

  Future<Map<String, dynamic>> createCharityDonation({
    required String institutionId,
    required String charityId,
    required String itemTitle,
    required String description,
    required int quantity,
    required String itemCondition,
    required List<String> images,
  }) async {
    final cleanTitle = itemTitle.trim();
    if (cleanTitle.isEmpty) throw const FormatException('اكتب اسم التبرع');
    if (quantity <= 0)
      throw const FormatException('الكمية يجب أن تكون أكبر من صفر');

    final row = await _client
        .from('institution_charity_donations')
        .insert({
          'institution_id': institutionId,
          'charity_id': charityId,
          'item_title': cleanTitle,
          'description': description.trim(),
          'quantity': quantity,
          'item_condition': itemCondition.trim(),
          'images': images,
          'status': 'pending',
        })
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> acceptDonation({
    required String donationId,
    required bool accept,
  }) async {
    return _rpcMap('institution_accept_charity_donation', {
      'p_donation_id': donationId,
      'p_accept': accept,
    });
  }

  Future<Map<String, dynamic>> assignVolunteer({
    required String donationId,
    required String volunteerId,
    required String volunteerName,
    required String volunteerPhone,
  }) async {
    return _rpcMap('institution_assign_charity_volunteer', {
      'p_donation_id': donationId,
      'p_volunteer_id': volunteerId,
      'p_volunteer_name': volunteerName.trim(),
      'p_volunteer_phone': volunteerPhone.trim(),
    });
  }

  Future<Map<String, dynamic>> markReady(String donationId) async =>
      _rpcMap('institution_mark_ready', {'p_donation_id': donationId});

  Future<Map<String, dynamic>> markVolunteerDeparted(String donationId) async =>
      _rpcMap(
          'institution_mark_volunteer_departed', {'p_donation_id': donationId});

  Future<Map<String, dynamic>> generatePickupCode(String donationId) async =>
      _rpcMap(
          'institution_generate_pickup_code', {'p_donation_id': donationId});

  Future<Map<String, dynamic>> verifyPickupCode({
    required String donationId,
    required String code,
  }) async =>
      _rpcMap('institution_verify_pickup_code', {
        'p_donation_id': donationId,
        'p_code': code.trim(),
      });

  Future<Map<String, dynamic>> confirmArrival(String donationId) async =>
      _rpcMap('institution_confirm_arrival', {'p_donation_id': donationId});

  Future<List<Map<String, dynamic>>> listMyNotifications() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const FormatException('يجب تسجيل الدخول أولًا');
    }
    final institution = await _client
        .from('institutions')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();
    final institutionId = institution?['id']?.toString();
    if (institutionId == null || institutionId.isEmpty) {
      throw const FormatException('لا توجد مؤسسة مرتبطة بهذا الحساب');
    }
    final rows = await _client
        .from('institution_notifications')
        .select()
        .eq('institution_id', institutionId)
        .order('created_at', ascending: false);
    return _maps(rows);
  }

  Future<int> countUnreadNotifications() async {
    final rows = await listMyNotifications();
    return rows.where((row) => row['is_read'] != true).length;
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const FormatException('يجب تسجيل الدخول أولًا');
    }
    final institution = await _client
        .from('institutions')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();
    final institutionId = institution?['id']?.toString();
    if (institutionId == null || institutionId.isEmpty) {
      throw const FormatException('لا توجد مؤسسة مرتبطة بهذا الحساب');
    }
    await _client
        .from('institution_notifications')
        .update({'is_read': true})
        .eq('id', notificationId)
        .eq('institution_id', institutionId);
  }

  Future<void> markAllNotificationsAsRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const FormatException('يجب تسجيل الدخول أولًا');
    }
    final institution = await _client
        .from('institutions')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();
    final institutionId = institution?['id']?.toString();
    if (institutionId == null || institutionId.isEmpty) {
      throw const FormatException('لا توجد مؤسسة مرتبطة بهذا الحساب');
    }
    await _client
        .from('institution_notifications')
        .update({'is_read': true})
        .eq('institution_id', institutionId)
        .eq('is_read', false);
  }

  Future<Map<String, dynamic>> _rpcMap(
    String function,
    Map<String, dynamic> params,
  ) async {
    final result = await _client.rpc(function, params: params);
    if (result is Map) return Map<String, dynamic>.from(result);
    throw const FormatException('استجابة غير صالحة من الخادم');
  }

  static List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }
}
