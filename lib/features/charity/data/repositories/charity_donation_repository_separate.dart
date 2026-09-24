// lib/features/charity/data/repositories/charity_donation_repository_separate.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SeparateCharityDonationRepository {
  final SupabaseClient _client;

  SeparateCharityDonationRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  String _friendly(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    if (text.contains('status') || text.contains('الانتقال')) {
      return 'لا يمكن تنفيذ هذه الخطوة من الحالة الحالية';
    }
    if (text.contains('كود')) return text;
    return text;
  }

  Future<String> _currentUserId() async {
    final id = _client.auth.currentUser?.id;
    if (id == null || id.isEmpty) throw Exception('يجب تسجيل الدخول أولًا');
    return id;
  }

  Future<String> _currentCharityId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const FormatException('يجب تسجيل الدخول أولًا');
    }
    final row = await _client
        .from('charities')
        .select('id')
        .eq('user_id', userId)
        .eq('status', 'active')
        .maybeSingle();
    final id = row?['id']?.toString().trim() ?? '';
    if (id.isEmpty) {
      throw const FormatException('لا توجد جمعية نشطة مرتبطة بالحساب');
    }
    return id;
  }

  String _storagePathFromValue(String value) {
    final trimmed = value.trim();
    if (!trimmed.startsWith('http')) return trimmed;
    final markers = <String>[
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

  Future<List<String>> _signedDonationImages(dynamic raw) async {
    if (raw is! List) return const [];
    final paths = raw
        .whereType<String>()
        .map(_storagePathFromValue)
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty && path != 'null')
        .toList();
    if (paths.isEmpty) return const [];
    final signed = <String>[];
    for (final path in paths) {
      try {
        signed.add(await _client.storage
            .from('community-offers')
            .createSignedUrl(path, 3600));
      } catch (_) {
        // الصورة قديمة أو محذوفة من Storage؛ نتجاهلها ونستخدم صورة بديلة في الواجهة.
      }
    }
    return signed;
  }

  Future<List<String>> uploadDonationImages(
    List<XFile> images, {
    String? charityId,
  }) async {
    final userId = await _currentUserId();
    final cleanCharityId = charityId?.trim();
    final folder = cleanCharityId == null || cleanCharityId.isEmpty
        ? '$userId/legacy'
        : '$userId/$cleanCharityId';
    final paths = <String>[];

    try {
      for (final image in images) {
        final bytes = await image.readAsBytes();
        if (bytes.isEmpty) throw Exception('إحدى الصور فارغة أو تالفة');

        final extension = _imageExtension(image.name);
        final path =
            '$folder/${DateTime.now().microsecondsSinceEpoch}.$extension';

        await _client.storage.from('community-offers').uploadBinary(
              path,
              Uint8List.fromList(bytes),
              fileOptions: FileOptions(
                contentType: _contentType(extension),
                upsert: false,
              ),
            );

        debugPrint('✅ DIRECT DONATION IMAGE UPLOADED: $path');
        paths.add(path);
      }
      return paths;
    } catch (_) {
      rethrow;
    }
  }

  String _imageExtension(String name) {
    final ext = name.split('.').last.toLowerCase();
    return {'jpg', 'jpeg', 'png', 'webp'}.contains(ext) ? ext : 'jpg';
  }

  String _contentType(String ext) => switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };

  Future<Map<String, dynamic>> createDonation({
    required String charityId,
    required String title,
    required String description,
    required String category,
    required int quantity,
    required String condition,
    required String pickupAddress,
    required String donorPhone,
    String? donorNotes,
    List<String> images = const [],
  }) async {
    final donorId = await _currentUserId();
    if (title.trim().length < 3) throw Exception('اكتب عنوانًا واضحًا للتبرع');
    final row = await _client
        .from('charity_donation_requests')
        .insert({
          'donor_id': donorId,
          'charity_id': charityId,
          'title': title.trim(),
          'description': description.trim(),
          'category': category,
          'quantity': quantity,
          'condition': condition,
          'pickup_address': pickupAddress.trim(),
          'donor_phone': donorPhone.trim(),
          'donor_notes': donorNotes?.trim(),
          'images': images,
          'status': 'pending',
        })
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<List<Map<String, dynamic>>> getMyDonations() async {
    final userId = await _currentUserId();
    final rows = await _client.from('charity_donation_requests').select('''
      id, title, description, category, quantity, condition, images,
      pickup_address, donor_phone, donor_notes, charity_notes, status,
      pickup_token, pickup_token_expires_at, donor_pickup_confirmed_at, accepted_at,
      completed_at, created_at, updated_at,
      volunteer_type, volunteer_name, volunteer_phone,
      delivery_type, open_to_independent_volunteers,
      charities:charity_id (id, name, logo, address, phone, email, is_verified)
    ''').eq('donor_id', userId).order('created_at', ascending: false);
    final result = <Map<String, dynamic>>[];
    for (final rawRow in (rows as List)) {
      final row = Map<String, dynamic>.from(rawRow as Map);
      row['images'] = await _signedDonationImages(row['images']);
      result.add(row);
    }
    return result;
  }

  Future<String> _charityIdForCurrentUser() async {
    final userId = await _currentUserId();
    final row = await _client
        .from('charities')
        .select('id, status')
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) throw Exception('لا توجد جمعية مرتبطة بالحساب');
    if (row['status']?.toString() != 'active') {
      throw Exception('حساب الجمعية ما زال قيد المراجعة');
    }
    return row['id'].toString();
  }

  Future<String> _myCharityId() async => _charityIdForCurrentUser();

  Future<List<Map<String, dynamic>>> getMyCharityVolunteers() async {
    final charityId = await _myCharityId();
    final rows = await _client.rpc('list_my_charity_volunteers', params: {
      'p_charity_id': charityId,
    });
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Map<String, dynamic> _mapFromRpc(dynamic result) {
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    if (result is List && result.isNotEmpty && result.first is Map) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    throw Exception('استجابة غير متوقعة من الخادم');
  }

  Future<List<Map<String, dynamic>>> getCharityVolunteers(
      {bool includeInactive = true}) async {
    final charityId = await _myCharityId();
    final rows = await _client.rpc('list_my_charity_volunteers_manage',
        params: {'p_charity_id': charityId});
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createCharityVolunteer(
      {required String name, required String phone}) async {
    final result = await _client.rpc('create_my_charity_volunteer',
        params: {'p_name': name.trim(), 'p_phone': phone.trim()});
    return _mapFromRpc(result);
  }

  Future<Map<String, dynamic>> updateCharityVolunteer(
      {required String id,
      required String name,
      required String phone,
      required String status}) async {
    final result = await _client.rpc('update_my_charity_volunteer', params: {
      'p_volunteer_id': id,
      'p_name': name.trim(),
      'p_phone': phone.trim(),
      'p_status': status
    });
    return _mapFromRpc(result);
  }

  Future<void> deleteCharityVolunteer(String id) async {
    await _client
        .rpc('delete_my_charity_volunteer', params: {'p_volunteer_id': id});
  }

  Future<List<Map<String, dynamic>>> getCharityDonations() async {
    final charityId = await _charityIdForCurrentUser();
    final rows = await _client.from('charity_donation_requests').select('''
      id, donor_id, charity_id, title, description, category, quantity, condition,
      images, pickup_address, pickup_city, donor_phone, donor_notes, charity_notes, status,
      volunteer_type, volunteer_id, volunteer_name, volunteer_phone,
      pickup_token_expires_at, donor_pickup_confirmed_at, accepted_at,
      assigned_at, completed_at, created_at, updated_at,
      open_to_independent_volunteers, charity_accepted_at, volunteer_accepted_at,
      charity_pickup_code, delivery_type, rejection_reason,
      users:donor_id (id, name, phone, email, avatar_url)
    ''').eq('charity_id', charityId).order('created_at', ascending: false);

    final result = <Map<String, dynamic>>[];
    for (final rawRow in (rows as List)) {
      final row = Map<String, dynamic>.from(rawRow as Map);
      row['source'] = 'user_donation';
      row['images'] = await _signedDonationImages(row['images']);
      result.add(row);
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getRestaurantDonations() async {
    await _charityIdForCurrentUser();
    final response = await _client.rpc('charity_list_restaurant_donations');
    if (response is! List) return const <Map<String, dynamic>>[];

    final result = <Map<String, dynamic>>[];
    for (final raw in response) {
      if (raw is! Map) continue;
      final source = Map<String, dynamic>.from(raw);
      final normalized = <String, dynamic>{
        ...source,
        'id': source['id'] ?? source['donation_id'],
        'source': 'restaurant_donation',
        'title': source['title'] ?? source['item_title'] ?? 'تبرع من مؤسسة',
        'description': source['description'] ?? '',
        'quantity': source['quantity'] ?? 1,
        'status': source['status'] ?? 'pending',
        'created_at': source['created_at'] ?? source['donated_at'],
        'users': <String, dynamic>{
          'id': source['restaurant_id'] ?? source['business_id'],
          'name': source['restaurant_name'] ??
              source['business_name'] ??
              'مؤسسة متبرعة',
          'phone': source['restaurant_phone'] ??
              source['business_phone'] ??
              source['donor_phone'],
          'email': source['restaurant_email'] ?? source['business_email'],
        },
      };
      normalized['images'] = await _signedDonationImages(normalized['images']);
      result.add(normalized);
    }

    result.sort((a, b) {
      final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return result;
  }

  Future<List<Map<String, dynamic>>> getInstitutionDonations() =>
      getRestaurantDonations();

  Future<List<Map<String, dynamic>>> getVolunteerDonations() async {
    final userId = await _currentUserId();
    final rows = await _client.from('charity_donation_requests').select('''
      id, title, description, category, quantity, images, pickup_address, pickup_city,
      donor_phone, status, volunteer_name, volunteer_phone, donor_pickup_confirmed_at,
      charity_received_at, delivery_type, open_to_independent_volunteers,
      charities:charity_id (id, name, address, phone)
    ''').eq('volunteer_id', userId).order('created_at', ascending: false);
    final result = <Map<String, dynamic>>[];
    for (final rawRow in (rows as List)) {
      final row = Map<String, dynamic>.from(rawRow as Map);
      row['images'] = await _signedDonationImages(row['images']);
      result.add(row);
    }
    return result;
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ NEW RPCs — الجديدة (من SQL اللي عملناه)
  // ═══════════════════════════════════════════════════════════════

  // ─────────────────────────────────────────────────────────────
  // 1) الجمعية تقبل التبرع (مسارين)
  // ─────────────────────────────────────────────────────────────

  /// الجمعية تقبل التبرع
  /// - [openToVolunteers] = true → تفتحه للمتطوعين (status = 'volunteer_needed')
  /// - [openToVolunteers] = false → تحتفظ بيه لنفسها (status = 'accepted')
  Future<Map<String, dynamic>> charityAcceptDonation({
    required String requestId,
    required bool openToVolunteers,
  }) async {
    try {
      final result = await _client.rpc(
        'charity_accept_donation',
        params: {
          'p_request_id': requestId.trim(),
          'p_open_to_volunteers': openToVolunteers,
        },
      );
      return _mapFromRpc(result);
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 2) الجمعية ترفض التبرع
  // ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> charityRejectDonation({
    required String requestId,
    String? reason,
  }) async {
    try {
      final result = await _client.rpc(
        'charity_reject_donation',
        params: {
          'p_request_id': requestId.trim(),
          'p_reason': reason?.trim(),
        },
      );
      return _mapFromRpc(result);
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 3) الجمعية تعيّن مندوب (داخلي أو خارجي)
  // ─────────────────────────────────────────────────────────────

  /// - [volunteerId] → مندوب من الجمعية (charity_volunteers)
  /// - [externalName] + [externalPhone] → مندوب خارجي
  Future<Map<String, dynamic>> charityAssignVolunteer({
    required String requestId,
    String? volunteerId,
    String? externalName,
    String? externalPhone,
  }) async {
    try {
      final result = await _client.rpc(
        'charity_assign_volunteer',
        params: {
          'p_request_id': requestId.trim(),
          'p_volunteer_id': volunteerId?.trim(),
          'p_external_name': externalName?.trim(),
          'p_external_phone': externalPhone?.trim(),
        },
      );
      return _mapFromRpc(result);
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 4) المتبرع يعلن جاهزيته
  // ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> markDonorReadyV2(String requestId) async {
    try {
      final result = await _client.rpc(
        'mark_donor_ready',
        params: {'p_request_id': requestId.trim()},
      );
      return _mapFromRpc(result);
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 5) تأكيد الاستلام من المتبرع (بكود)
  // ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> confirmPickupFromDonor({
    required String requestId,
    required String code,
  }) async {
    try {
      final result = await _client.rpc(
        'confirm_pickup_from_donor',
        params: {
          'p_request_id': requestId.trim(),
          'p_code': code.trim(),
        },
      );
      return _mapFromRpc(result);
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 6) المندوب يعلن أنه في الطريق
  // ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> volunteerMarkInTransit(String requestId) async {
    try {
      final result = await _client.rpc(
        'volunteer_mark_in_transit',
        params: {'p_request_id': requestId.trim()},
      );
      return _mapFromRpc(result);
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 6.b) ✅ المتبرع يعلن أن التبرع في الطريق للجمعية (fallback)
  // ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> donorMarkInTransit(String requestId) async {
    try {
      final result = await _client.rpc(
        'donor_mark_in_transit',
        params: {'p_request_id': requestId.trim()},
      );

      final data = Map<String, dynamic>.from(result as Map);

      if (data['success'] != true) {
        throw Exception(
          data['error']?.toString() ?? 'تعذر تحديث حالة التبرع',
        );
      }

      return data;
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 7) المندوب يسلّم للجمعية
  // ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> volunteerDeliverToCharity(
      String requestId) async {
    try {
      final result = await _client.rpc(
        'volunteer_deliver_to_charity',
        params: {'p_request_id': requestId.trim()},
      );
      return _mapFromRpc(result);
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 8) جلب التبرعات المفتوحة للمتطوعين
  // ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listOpenDonationsForVolunteers({
    String? city,
  }) async {
    try {
      final rows = await _client.rpc(
        'list_open_donations_for_volunteers',
        params: {'p_city': city?.trim()},
      );
      final result = <Map<String, dynamic>>[];
      for (final rawRow in (rows as List)) {
        final row = Map<String, dynamic>.from(rawRow as Map);
        row['images'] = await _signedDonationImages(row['images']);
        result.add(row);
      }
      return result;
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 9) جلب تبرعات المتطوع
  // ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listMyVolunteerDonations() async {
    try {
      final rows = await _client.rpc('list_my_volunteer_donations');
      final result = <Map<String, dynamic>>[];
      for (final rawRow in (rows as List)) {
        final row = Map<String, dynamic>.from(rawRow as Map);
        row['images'] = await _signedDonationImages(row['images']);
        result.add(row);
      }
      return result;
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ⚠️ الدوال القديمة (الاحتفاظ بيها للتوافقية)
  // ═══════════════════════════════════════════════════════════════

  Future<void> assignCharityVolunteer({
    required String requestId,
    required String volunteerId,
  }) async {
    try {
      await _client.rpc(
        'assign_direct_donation_charity_volunteer',
        params: {
          'p_request_id': requestId.trim(),
          'p_volunteer_id': volunteerId.trim(),
        },
      );
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  Future<String> markDonorReady(String requestId) async {
    try {
      final result = await _client.rpc('mark_direct_donation_donor_ready_v2',
          params: {'p_request_id': requestId});
      final data = Map<String, dynamic>.from(result as Map);
      return data['pickup_code']?.toString() ?? '';
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  Future<String> generatePickupToken(String requestId) =>
      getPickupCode(requestId);

  Future<String> getPickupCode(String requestId) async {
    try {
      final userId = await _currentUserId();
      final row = await _client
          .from('charity_donation_requests')
          .select('pickup_token, status, volunteer_name, volunteer_phone')
          .eq('id', requestId)
          .eq('donor_id', userId)
          .maybeSingle();
      if (row == null) throw Exception('التبرع غير موجود');
      final currentStatus = row['status']?.toString().trim().toLowerCase();
      final representativeAssigned =
          (row['volunteer_name']?.toString().trim().isNotEmpty ?? false);
      final canShow = currentStatus == 'volunteer_assigned' ||
          (currentStatus == 'donor_ready' && representativeAssigned) ||
          currentStatus == 'picked_up_from_donor' ||
          currentStatus == 'in_transit';
      if (!canShow) {
        throw Exception('سيظهر الكود بعد أن تعيّن الجمعية المندوب');
      }
      final code = row['pickup_token']?.toString();
      if (code == null || code.isEmpty) {
        throw Exception('لم يتم إنشاء كود ثابت لهذا التبرع');
      }
      return code;
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  Future<void> confirmPickup(
      {required String requestId, required String token}) async {
    try {
      await _client.rpc('confirm_direct_donation_pickup',
          params: {'p_request_id': requestId, 'p_token': token.trim()});
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  Future<void> assignExternalRepresentative(
      {required String requestId,
      required String name,
      required String phone}) async {
    try {
      await _client.rpc('assign_direct_external_representative_v2', params: {
        'p_request_id': requestId,
        'p_name': name.trim(),
        'p_phone': phone.trim(),
      });
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  Future<void> assignVolunteer(
      {required String requestId,
      required String volunteerType,
      String? volunteerId,
      String? volunteerName,
      String? volunteerPhone}) async {
    try {
      await _client.rpc('assign_direct_donation_volunteer', params: {
        'p_request_id': requestId,
        'p_volunteer_type': volunteerType,
        'p_volunteer_id': volunteerId,
        'p_volunteer_name': volunteerName,
        'p_volunteer_phone': volunteerPhone,
      });
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  Future<void> assignRestaurantVolunteer({
    required String donationId,
    required String volunteerId,
  }) async {
    try {
      await _client.rpc(
        'charity_assign_restaurant_donation_volunteer',
        params: {
          'p_donation_id': donationId,
          'p_volunteer_id': volunteerId,
        },
      );
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  Future<Map<String, dynamic>> generateRestaurantPickupCode(
    String donationId,
  ) async {
    try {
      final result = await _client.rpc(
        'charity_generate_restaurant_donation_pickup_code',
        params: {'p_donation_id': donationId},
      );
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  Future<void> markRestaurantDonationDeparted(String donationId) async {
    try {
      await _client.rpc(
        'charity_mark_restaurant_donation_departed',
        params: {'p_donation_id': donationId},
      );
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  Future<void> confirmRestaurantDonationPickup({
    required String donationId,
    required String token,
  }) async {
    final normalized = token.trim();
    if (!RegExp(r'^[0-9]{6}$').hasMatch(normalized)) {
      throw Exception('كود الاستلام يجب أن يتكون من 6 أرقام');
    }
    try {
      await _client.rpc(
        'charity_confirm_restaurant_donation_pickup',
        params: {
          'p_donation_id': donationId,
          'p_token': normalized,
        },
      );
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  Future<void> confirmRestaurantDonationArrival(String donationId) async {
    try {
      await _client.rpc(
        'charity_confirm_restaurant_donation_arrival',
        params: {'p_donation_id': donationId},
      );
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  Future<void> updateStatus({
    required String requestId,
    required String status,
    String? notes,
    bool isRestaurantDonation = false,
  }) async {
    const allowed = {'accepted', 'rejected', 'in_transit', 'completed'};
    if (!allowed.contains(status)) {
      throw Exception('هذه الحالة لا يتم تحديثها من صفحة الجمعية');
    }
    try {
      final result = isRestaurantDonation
          ? await _client.rpc(
              'charity_update_restaurant_donation_status',
              params: {
                'p_donation_id': requestId,
                'p_next_status': status,
              },
            )
          : await _client.rpc(
              'advance_direct_donation_status',
              params: {
                'p_request_id': requestId,
                'p_next_status': status,
              },
            );
      if (!isRestaurantDonation && notes != null && notes.trim().isNotEmpty) {
        await _client
            .from('charity_donation_requests')
            .update({'charity_notes': notes.trim()}).eq('id', requestId);
      }
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  // ==================== مسار المتطوع المستقل (مسار ب) ====================

  Future<void> acceptAndOpenForVolunteers(String requestId) async {
    try {
      await _client.rpc(
        'accept_and_open_for_volunteers',
        params: {'p_request_id': requestId},
      );
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  Future<List<Map<String, dynamic>>> getOpenDonationsForVolunteers({
    String? city,
  }) async {
    return listOpenDonationsForVolunteers(city: city);
  }

  Future<void> claimOpenDonation(String requestId) async {
    try {
      await _client.rpc(
        'volunteer_claim_charity_donation',
        params: {'p_request_id': requestId},
      );
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  Future<void> confirmVolunteerDonorPickup(String requestId) async {
    try {
      await _client.rpc(
        'volunteer_confirm_donor_pickup',
        params: {'p_request_id': requestId},
      );
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  Future<void> confirmVolunteerCharityDelivery(String requestId) async {
    try {
      await _client.rpc(
        'volunteer_confirm_charity_delivery',
        params: {'p_request_id': requestId},
      );
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  // ==================== دوال كود الاستلام للمتطوع ====================

  Future<String> getPickupCodeForVolunteer(String requestId) async {
    try {
      final row = await _client
          .from('charity_donation_requests')
          .select('pickup_token')
          .eq('id', requestId)
          .maybeSingle();
      if (row == null) throw Exception('التبرع غير موجود');
      return row['pickup_token']?.toString() ?? '';
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  Future<void> confirmVolunteerPickupWithCode(
      String requestId, String code) async {
    try {
      final result = await _client.rpc(
        'volunteer_confirm_pickup_with_code',
        params: {'p_request_id': requestId, 'p_code': code.trim()},
      );
      final data = Map<String, dynamic>.from(result as Map);
      if (data['success'] != true) {
        throw Exception(data['error']?.toString() ?? 'كود الاستلام غير صحيح');
      }
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  Future<String> generatePickupCodeForDonation(String requestId) async {
    try {
      final result = await _client.rpc(
        'generate_pickup_code_for_donation',
        params: {'p_request_id': requestId},
      );
      final data = Map<String, dynamic>.from(result as Map);
      return data['pickup_code']?.toString() ?? '';
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  // ==================== دوال كود المتطوع ====================

  Future<String> generateCharityPickupCode(String requestId) async {
    try {
      final result = await _client.rpc(
        'volunteer_generate_charity_code',
        params: {'p_request_id': requestId, 'p_expires_in_hours': 12},
      );
      final data = Map<String, dynamic>.from(result as Map);
      if (data['success'] != true) {
        throw Exception(data['error']?.toString() ?? 'تعذر إنشاء كود المتطوع');
      }
      return data['charity_code']?.toString() ?? '';
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  Future<String> getCharityPickupCode(String requestId) async {
    try {
      final row = await _client
          .from('charity_donation_requests')
          .select('charity_pickup_code')
          .eq('id', requestId)
          .maybeSingle();
      if (row == null) throw Exception('التبرع غير موجود');
      return row['charity_pickup_code']?.toString() ?? '';
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  Future<void> confirmCharityDeliveryWithCode(
    String requestId,
    String code, {
    String? charityId,
  }) async {
    try {
      final row = await _client
          .from('charity_donation_requests')
          .select('charity_pickup_code, status')
          .eq('id', requestId)
          .maybeSingle();

      if (row == null) {
        throw Exception('التبرع غير موجود');
      }

      final storedCode = row['charity_pickup_code']?.toString() ?? '';
      final currentStatus = row['status']?.toString() ?? '';

      if (currentStatus != 'in_transit') {
        throw Exception('لا يمكن تأكيد الوصول في هذه الحالة');
      }

      if (code.trim().isEmpty) {
        throw Exception('يرجى إدخال كود المتطوع');
      }

      if (code.trim() != storedCode) {
        throw Exception('كود المتطوع غير صحيح');
      }

      await _client.from('charity_donation_requests').update({
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
        'charity_received_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }
}
