import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityMyOffersRepository {
  final SupabaseClient _client;

  CommunityMyOffersRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getMyOffersWithRequests() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول أولًا');

    final offerRows = await _client.from('community_offers').select('''
          id,
          owner_id,
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
          status,
          created_at,
          updated_at
        ''').eq('owner_id', user.id).order('created_at', ascending: false);

    final offers = (offerRows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();

    if (offers.isEmpty) return offers;

    final offerIds = offers.map((offer) => offer['id'].toString()).toList();
    final requestRows = await _client
        .from('community_requests')
        .select('''
          id,
          offer_id,
          requester_id,
          owner_id,
          status,
          message,
          price_snapshot,
          requested_at,
          updated_at,
          accepted_at,
          completed_at,
          requester:requester_id (
            id,
            name,
            avatar_url
          )
        ''')
        .inFilter('offer_id', offerIds)
        .order('requested_at', ascending: false);

    final requestsByOffer = <String, List<Map<String, dynamic>>>{};
    for (final row in (requestRows as List)) {
      final request = Map<String, dynamic>.from(row as Map);
      final offerId = request['offer_id']?.toString();
      if (offerId == null) continue;
      requestsByOffer
          .putIfAbsent(offerId, () => <Map<String, dynamic>>[])
          .add(request);
    }

    return offers.map((offer) {
      final copy = Map<String, dynamic>.from(offer);
      copy['requests'] =
          requestsByOffer[offer['id']?.toString()] ?? <Map<String, dynamic>>[];
      return copy;
    }).toList();
  }

  Future<void> updateRequestStatus({
    required String requestId,
    required String status,
  }) async {
    if (!['accepted', 'rejected', 'completed'].contains(status)) {
      throw Exception('حالة الطلب غير مسموحة');
    }

    final user = _client.auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول أولًا');

    final rows = await _client
        .from('community_requests')
        .update({
          'status': status,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          if (status == 'accepted')
            'accepted_at': DateTime.now().toUtc().toIso8601String(),
          if (status == 'completed')
            'completed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', requestId)
        .eq('owner_id', user.id)
        .select('id');

    if ((rows as List).isEmpty) {
      throw Exception('لا يمكن تحديث هذا الطلب أو أنه لا يخص عروضك');
    }
  }
}
