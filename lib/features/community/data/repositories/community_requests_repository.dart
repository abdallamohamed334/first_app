import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityRequestsRepository {
  final SupabaseClient _client;

  CommunityRequestsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  String? get currentUserId => _client.auth.currentUser?.id;

  // ✅ دالة جلب عروض المؤسسات (من جدول community_offers)
  Future<List<Map<String, dynamic>>> getInstitutionOffers() async {
    final rows = await _client
        .from('community_offers')
        .select('*')
        .not('charity_id', 'is', null) // عروض مرتبطة بجمعية
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  // ✅ دالة جلب التبرعات اللي أنا متطوع أوصلها (هتشتغل لما تضيف جدول delivery_tasks)
  Future<List<Map<String, dynamic>>> getMyVolunteerTasks() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول أولًا');

    // لو في جدول delivery_tasks عندك، عدّل الجدول ده
    final rows = await _client
        .from('delivery_tasks') // ⚠️ عدّل اسم الجدول لو مختلف
        .select('*')
        .eq('volunteer_id', user.id)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  // ✅ دالة جلب الطلبات اللي على عروضي (لتبويب "تبرعاتي المنشورة")
  Future<List<Map<String, dynamic>>> getMyDonationRequests() async {
    return getOwnerRequests(); // نفس الدالة الموجودة
  }

  // ================== الدوال الموجودة عندك (زي ما هي) ==================
  Future<void> _sendPush({
    required String userId,
    required String title,
    required String body,
    required String type,
    required String referenceId,
  }) async {
    try {
      await _client.functions.invoke(
        'send-notification',
        body: {
          'userId': userId,
          'title': title,
          'body': body,
          'data': {
            'type': type,
            'reference_id': referenceId,
            'reference_type': 'community_request',
          },
        },
      );
    } catch (_) {}
  }

  Future<Map<String, dynamic>> createRequest({
    required String offerId,
    String? message,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول أولًا');

    final offer = await _client
        .from('community_offers')
        .select('owner_id, charity_id, title')
        .eq('id', offerId)
        .single();

    final inserted = await _client
        .from('community_requests')
        .insert({
          'offer_id': offerId,
          'requester_id': user.id,
          'owner_id': offer['owner_id'],
          'charity_id': offer['charity_id'],
          'message': message?.trim().isEmpty == true ? null : message?.trim(),
        })
        .select()
        .single();

    final request = Map<String, dynamic>.from(inserted);
    final ownerId = offer['owner_id']?.toString();
    if (ownerId != null && ownerId.isNotEmpty && ownerId != user.id) {
      await _sendPush(
        userId: ownerId,
        title: 'طلب جديد على عرضك',
        body: 'يوجد مستخدم مهتم بالعرض: ${offer['title'] ?? 'عرض المجتمع'}',
        type: 'offer_request',
        referenceId: request['id'].toString(),
      );
    }

    final charityId = offer['charity_id']?.toString();
    if (charityId != null && charityId.isNotEmpty) {
      final charity = await _client
          .from('charities')
          .select('user_id, name')
          .eq('id', charityId)
          .maybeSingle();
      final charityUserId = charity?['user_id']?.toString();
      if (charityUserId != null &&
          charityUserId.isNotEmpty &&
          charityUserId != user.id) {
        await _sendPush(
          userId: charityUserId,
          title: 'وصل طلب تبرع جديد',
          body: 'هناك تبرع جديد موجه إلى ${charity?['name'] ?? 'جمعيتك'}',
          type: 'offer_request',
          referenceId: request['id'].toString(),
        );
      }
    }

    return request;
  }

  Future<List<Map<String, dynamic>>> getMyRequests() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول أولًا');

    final rows = await _client
        .from('community_requests')
        .select('''
          id,
          offer_id,
          requester_id,
          owner_id,
          charity_id,
          status,
          message,
          price_snapshot,
          pickup_location_snapshot,
          requested_at,
          updated_at,
          accepted_at,
          completed_at,
          community_offers:offer_id (
            title,
            category,
            listing_type,
            image,
            images,
            pickup_location
          )
        ''')
        .eq('requester_id', user.id)
        .order('requested_at', ascending: false);

    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getMyCharityDonations() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول أولًا');

    final rows = await _client
        .from('community_requests')
        .select('''
          id,
          requester_id,
          owner_id,
          charity_id,
          status,
          message,
          charity_notes,
          pickup_location_snapshot,
          pickup_scheduled_at,
          requested_at,
          updated_at,
          accepted_at,
          completed_at,
          community_offers:offer_id (
            id,
            title,
            description,
            category,
            item_condition,
            quantity,
            image,
            images,
            pickup_location,
            listing_type
          ),
          charity:charity_id (
            id,
            name,
            logo,
            address,
            phone,
            email,
            description,
            is_verified
          )
        ''')
        .eq('requester_id', user.id)
        .not('charity_id', 'is', null)
        .order('requested_at', ascending: false);

    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getOwnerRequests() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول أولًا');

    final rows = await _client.from('community_requests').select('''
          id,
          offer_id,
          requester_id,
          owner_id,
          charity_id,
          status,
          message,
          price_snapshot,
          pickup_location_snapshot,
          requested_at,
          updated_at,
          accepted_at,
          completed_at,
          community_offers:offer_id (
            title,
            category,
            listing_type,
            image,
            images,
            pickup_location
          ),
          requester:requester_id (
            id,
            name,
            phone,
            email,
            avatar_url
          )
        ''').eq('owner_id', user.id).order('requested_at', ascending: false);

    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<void> updateRequestStatus({
    required String requestId,
    required String status,
  }) async {
    if (![
      'accepted',
      'rejected',
      'cancelled',
      'ready_for_pickup',
      'completed',
    ].contains(status)) {
      throw Exception('حالة الطلب غير مسموحة');
    }

    final user = _client.auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول أولًا');

    final request = await _client
        .from('community_requests')
        .select(
            'id, requester_id, owner_id, status, community_offers:offer_id(title)')
        .eq('id', requestId)
        .or('owner_id.eq.${user.id},requester_id.eq.${user.id}')
        .maybeSingle();

    if (request == null) {
      throw Exception('الطلب غير موجود أو ليس لديك صلاحية');
    }

    final currentStatus = request['status']?.toString() ?? '';
    if (status == 'ready_for_pickup') {
      if (request['owner_id']?.toString() != user.id) {
        throw Exception('فقط صاحب العرض يستطيع تجهيز الطلب');
      }
      if (currentStatus != 'accepted') {
        throw Exception('لا يمكن التجهيز قبل قبول الطلب');
      }
    }

    final patch = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (status == 'accepted') {
      patch['accepted_at'] = DateTime.now().toUtc().toIso8601String();
    }
    if (status == 'completed') {
      patch['completed_at'] = DateTime.now().toUtc().toIso8601String();
    }

    final updated = await _client
        .from('community_requests')
        .update(patch)
        .eq('id', requestId)
        .or('owner_id.eq.${user.id},requester_id.eq.${user.id}')
        .select('id');

    if ((updated as List).isEmpty) {
      throw Exception('لا يمكن تحديث هذا الطلب');
    }

    final requesterId = request['requester_id']?.toString();
    if (requesterId != null &&
        requesterId.isNotEmpty &&
        requesterId != user.id) {
      final offer = request['community_offers'];
      final offerTitle = offer is Map
          ? (offer['title']?.toString() ?? 'عرض المجتمع')
          : 'عرض المجتمع';
      final notification = <String, dynamic>{
        'user_id': requesterId,
        'title': status == 'ready_for_pickup'
            ? 'العرض جاهز للاستلام'
            : status == 'accepted'
                ? 'تم قبول طلبك'
                : status == 'rejected'
                    ? 'تم رفض طلبك'
                    : 'تحديث على طلبك',
        'body': status == 'ready_for_pickup'
            ? 'العرض "$offerTitle" أصبح جاهزًا للاستلام.'
            : 'تم تحديث حالة طلبك على العرض "$offerTitle".',
        'type': status == 'rejected'
            ? 'request_rejected'
            : status == 'ready_for_pickup'
                ? 'delivery_assigned'
                : status == 'accepted'
                    ? 'request_accepted'
                    : 'system',
        'reference_id': requestId,
        'reference_type': 'community_request',
        'is_read': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };
      try {
        await _client.from('notifications').insert(notification);
      } catch (_) {}
      await _sendPush(
        userId: requesterId,
        title: notification['title'].toString(),
        body: notification['body'].toString(),
        type: notification['type'].toString(),
        referenceId: requestId,
      );
    }
  }

  Future<String> getOrCreatePickupToken(String requestId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول أولًا');

    final result = await _client.rpc(
      'community_generate_pickup_token',
      params: {'p_request_id': requestId},
    );

    Map<String, dynamic>? payload;
    if (result is Map) {
      payload = Map<String, dynamic>.from(result);
    } else if (result is List && result.isNotEmpty && result.first is Map) {
      payload = Map<String, dynamic>.from(result.first as Map);
    }

    final token = payload?['token']?.toString() ??
        payload?['pickup_token']?.toString() ??
        (result is String ? result : null);
    if (token == null || token.trim().isEmpty) {
      throw Exception(
          'تعذر إنشاء رمز الاستلام: استجابة RPC لا تحتوي على token');
    }
    return token.trim();
  }

  Future<void> completeByPickupToken(String token) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول أولًا');
    if (token.trim().isEmpty) throw Exception('رمز الاستلام فارغ');

    await _client.rpc(
      'community_complete_by_pickup_token',
      params: {'p_token': token.trim()},
    );
  }
}
