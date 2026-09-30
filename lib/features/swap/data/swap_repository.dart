import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class SwapRepository {
  final SupabaseClient _client;
  SwapRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  String get _uid => _client.auth.currentUser?.id ?? (throw Exception('يجب تسجيل الدخول أولًا'));
  String? get currentUserId => _client.auth.currentUser?.id;

  Future<String> uploadListingImage(XFile image) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('يجب تسجيل الدخول أولًا');
    final extension = image.path.split('.').last.toLowerCase();
    final safeExtension = const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension) ? extension : 'jpg';
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$safeExtension';
    final contentType = safeExtension == 'png'
        ? 'image/png'
        : safeExtension == 'webp'
            ? 'image/webp'
            : 'image/jpeg';
    await _client.storage.from('swap-images').uploadBinary(
          path,
          await image.readAsBytes(),
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return _client.storage.from('swap-images').getPublicUrl(path);
  }

  Future<List<Map<String, dynamic>>> listOpenListings({String? search}) async {
    var query = _client.from('swap_listings').select('''
      id, owner_id, wanted_title, description, category, wanted_condition,
      city, governorate, latitude, longitude, images, status, expires_at,
      created_at, updated_at, users:owner_id(name, avatar_url)
    ''').eq('status', 'open').gt('expires_at', DateTime.now().toUtc().toIso8601String());
    final rows = await query.order('created_at', ascending: false).limit(100);
    final result = (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
    final q = search?.trim().toLowerCase() ?? '';
    if (q.isEmpty) return result;
    return result.where((r) => '${r['wanted_title']} ${r['description']} ${r['category']}'.toLowerCase().contains(q)).toList();
  }

  Future<Map<String, dynamic>> getListing(String id) async {
    final row = await _client.from('swap_listings').select('''
      id, owner_id, wanted_title, description, category, wanted_condition,
      city, governorate, latitude, longitude, images, status, expires_at,
      contact_phone, contact_whatsapp, created_at, updated_at,
      users:owner_id(name, avatar_url)
    ''').eq('id', id).single();
    final proposals = await _client.from('swap_proposals').select('''
      id, listing_id, proposer_id, offered_title, offered_description,
      offered_condition, images, status, created_at, updated_at, accepted_at,
      users:proposer_id(name, avatar_url)
    ''').eq('listing_id', id).order('created_at', ascending: false);
    final data = Map<String, dynamic>.from(row);
    data['proposals'] = (proposals as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
    return data;
  }

  Future<Map<String, dynamic>> createListing({
    required String wantedTitle,
    required String description,
    required String category,
    required String wantedCondition,
    required String contactPhone,
    required String contactWhatsapp,
    List<String> images = const [],
    String? city,
    String? governorate,
    double? latitude,
    double? longitude,
  }) async {
    final title = wantedTitle.trim();
    final body = description.trim();
    final phone = _cleanPhone(contactPhone);
    final whatsapp = _cleanPhone(contactWhatsapp);
    if (title.length < 3) throw Exception('اكتب الشيء المطلوب استبداله بوضوح');
    if (body.length < 10) throw Exception('الوصف يجب أن يكون 10 أحرف على الأقل');
    if (!_isValidPhone(phone)) throw Exception('رقم الهاتف غير صحيح (مثال: 01012345678)');
    if (!_isValidPhone(whatsapp)) throw Exception('رقم الواتساب غير صحيح (مثال: 01012345678)');
    if (latitude != null && (latitude < -90 || latitude > 90)) throw Exception('الموقع غير صحيح');
    if (longitude != null && (longitude < -180 || longitude > 180)) throw Exception('الموقع غير صحيح');
    final row = await _client.from('swap_listings').insert({
      'owner_id': _uid,
      'wanted_title': title,
      'description': body,
      'category': category.trim().isEmpty ? 'other' : category.trim(),
      'wanted_condition': wantedCondition,
      'contact_phone': phone,
      'contact_whatsapp': whatsapp,
      'images': images,
      'city': city?.trim().isEmpty == true ? null : city?.trim(),
      'governorate': governorate?.trim().isEmpty == true ? null : governorate?.trim(),
      'latitude': latitude,
      'longitude': longitude,
    }).select().single();
    return Map<String, dynamic>.from(row);
  }

  String _cleanPhone(String value) =>
      value.trim().replaceAll(RegExp(r'[^0-9+ ()-]'), '');

  bool _isValidPhone(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 8 && digits.length <= 15;
  }

  Future<Map<String, dynamic>> createProposal({
    required String listingId,
    required String offeredTitle,
    required String offeredDescription,
    required String offeredCondition,
  }) async {
    final title = offeredTitle.trim();
    final body = offeredDescription.trim();
    if (title.length < 3) throw Exception('اكتب الشيء الذي ستقدمه في المقابل');
    if (body.length < 10) throw Exception('وصف الشيء المعروض يجب أن يكون 10 أحرف على الأقل');
    final row = await _client.rpc('create_swap_proposal', params: {
      'p_listing_id': listingId,
      'p_offered_title': title,
      'p_offered_description': body,
      'p_offered_condition': offeredCondition,
      'p_images': <String>[],
    });
    if (row is Map) return Map<String, dynamic>.from(row);
    if (row is List && row.isNotEmpty && row.first is Map) return Map<String, dynamic>.from(row.first as Map);
    throw Exception('استجابة غير صحيحة من الخادم');
  }

  Future<List<Map<String, dynamic>>> myProposals() async {
    final rows = await _client.from('swap_proposals').select('''
      id, listing_id, proposer_id, offered_title, offered_description,
      offered_condition, images, status, created_at, updated_at, accepted_at,
      swap_listings:listing_id(wanted_title, description, status, owner_id)
    ''').eq('proposer_id', _uid).order('created_at', ascending: false);
    return (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> myListings() async {
    final rows = await _client.from('swap_listings').select('''
      id, owner_id, wanted_title, description, category, wanted_condition,
      city, contact_phone, contact_whatsapp, status, expires_at, created_at,
      swap_proposals(id, proposer_id, offered_title, offered_description, offered_condition, status, created_at, users:proposer_id(name, avatar_url))
    ''').eq('owner_id', _uid).order('created_at', ascending: false);
    return (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
  }

  Future<void> updateProposalStatus({required String proposalId, required String status}) async {
    await _client.rpc('update_swap_proposal_status', params: {
      'p_proposal_id': proposalId,
      'p_status': status,
    });
  }

  Future<void> closeListing(String listingId) async {
    await _client.from('swap_listings').update({'status': 'closed', 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', listingId).eq('owner_id', _uid);
  }
}
