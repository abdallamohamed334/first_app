import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:wasla/core/services/image_upload_codec.dart';

class SwapRepository {
  final SupabaseClient _client;
  SwapRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  String get _uid =>
      _client.auth.currentUser?.id ??
      (throw Exception('يجب تسجيل الدخول أولًا'));
  String? get currentUserId => _client.auth.currentUser?.id;

  Future<List<Map<String, dynamic>>> listSwapCategories() async {
    final rows = await _client
        .from('swap_categories')
        .select('slug, name_ar, icon')
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<String> uploadListingImage(XFile image) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('يجب تسجيل الدخول أولًا');
    final path =
        '$userId/${DateTime.now().millisecondsSinceEpoch}.webp';
    await _client.storage.from('swap-images').uploadBinary(
        path, await ImageUploadCodec.fromXFile(image),
        fileOptions: const FileOptions(
          contentType: 'image/webp',
          upsert: false,
        ));
    return _client.storage.from('swap-images').getPublicUrl(path);
  }

  Future<List<Map<String, dynamic>>> listOpenListings({
    String? search,
    String? governorate,
    String? category,
    String? categorySlug,
    String? city,
    bool withImagesOnly = false,
  }) async {
    var query = _client
        .from('swap_listings')
        .select('''
      id, owner_id, wanted_title, description, category, categories, wanted_condition,
      city, governorate, latitude, longitude, images, status, expires_at,
      created_at, updated_at, users:owner_id(name, avatar_url)
    ''')
        .eq('status', 'open')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String());
    if (governorate != null && governorate.trim().isNotEmpty) {
      query = query.ilike('governorate', governorate.trim());
    }
    if (city != null && city.trim().isNotEmpty) {
      query = query.ilike('city', city.trim());
    }
    if (withImagesOnly) {
      query = query.neq('images', '{}');
    }
    final categoryValues = <String>{
      if (category != null && category.trim().isNotEmpty) category.trim(),
      if (categorySlug != null && categorySlug.trim().isNotEmpty)
        categorySlug.trim(),
    };
    if (categoryValues.isNotEmpty) {
      final filters = categoryValues
          .expand((value) => [
                'category.eq.${_escapePostgrestValue(value)}',
                'categories.cs.{${_escapePostgrestValue(value)}}',
              ])
          .join(',');
      query = query.or(filters);
    }
    final q = _escapePostgrestValue(search?.trim() ?? '');
    if (q.isNotEmpty) {
      query = query.or([
        'wanted_title.ilike.*$q*',
        'description.ilike.*$q*',
        'city.ilike.*$q*',
        'governorate.ilike.*$q*',
        'category.ilike.*$q*',
        'categories.cs.{${q}}',
      ].join(','));
    }
    final rows = await query.order('created_at', ascending: false).limit(1000);
    final result =
        (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
    return result;
  }

  String _escapePostgrestValue(String value) => value
      .replaceAll(RegExp(r'[(),{}]'), ' ')
      .replaceAll('*', ' ')
      .trim();

  Future<String?> currentUserGovernorate() async {
    if (currentUserId == null) return null;
    final profile = await _client
        .from('users')
        .select('governorate, city, latitude, longitude')
        .eq('id', _uid)
        .maybeSingle();
    final value = profile?['governorate']?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<Map<String, dynamic>?> currentUserLocation() async {
    if (currentUserId == null) return null;
    final profile = await _client
        .from('users')
        .select('latitude, longitude')
        .eq('id', _uid)
        .maybeSingle();
    if (profile == null) return null;
    return Map<String, dynamic>.from(profile);
  }

  Future<Set<String>> favoriteListingIds() async {
    if (currentUserId == null) return <String>{};
    final rows = await _client
        .from('favorites')
        .select('target_id')
        .eq('user_id', _uid)
        .eq('target_type', 'swap_listing');
    return (rows as List).map((row) => row['target_id'].toString()).toSet();
  }

  Future<void> toggleFavorite(String listingId, bool favorite) async {
    if (favorite) {
      await _client.from('favorites').upsert({
        'user_id': _uid,
        'target_type': 'swap_listing',
        'target_id': listingId
      });
    } else {
      await _client
          .from('favorites')
          .delete()
          .eq('user_id', _uid)
          .eq('target_type', 'swap_listing')
          .eq('target_id', listingId);
    }
  }

  Future<List<Map<String, dynamic>>> recentlyViewedListings() async {
    if (currentUserId == null) return <Map<String, dynamic>>[];
    final rows = await _client
        .from('swap_listing_views')
        .select('''
      last_viewed_at,
      listing:listing_id(id, owner_id, wanted_title, description, category, categories, wanted_condition,
        city, governorate, latitude, longitude, images, status, expires_at, created_at,
        users:owner_id(name, avatar_url))
    ''')
        .eq('user_id', _uid)
        .order('last_viewed_at', ascending: false)
        .limit(12);
    return (rows as List)
        .map((row) =>
            Map<String, dynamic>.from((row['listing'] as Map?) ?? const {}))
        .where((row) => row.isNotEmpty && row['status'] == 'open')
        .toList();
  }

  Future<void> recordListingView(String listingId) async {
    if (currentUserId == null) return;
    await _client.from('swap_listing_views').upsert({
      'user_id': _uid,
      'listing_id': listingId,
      'last_viewed_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> reportListing({
    required String listingId,
    required String reason,
    String? details,
  }) async {
    await _client.from('swap_listing_reports').insert({
      'listing_id': listingId,
      'reporter_id': _uid,
      'reason': reason,
      'details': details?.trim().isEmpty == true ? null : details?.trim(),
    });
  }

  Future<List<Map<String, dynamic>>> listSwapReports() async {
    final rows = await _client
        .from('swap_listing_reports')
        .select('''
          id, listing_id, reporter_id, reason, details, status, created_at,
          resolution, swap_listings:listing_id(wanted_title, governorate, city),
          reporter:reporter_id(name, phone)
        ''')
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<void> updateSwapReportStatus({
    required String reportId,
    required String status,
    String? resolution,
  }) async {
    await _client.from('swap_listing_reports').update({
      'status': status,
      'resolution': resolution?.trim().isEmpty == true ? null : resolution?.trim(),
      'resolved_at': status == 'resolved' || status == 'dismissed'
          ? DateTime.now().toUtc().toIso8601String()
          : null,
      'resolved_by': status == 'resolved' || status == 'dismissed'
          ? _uid
          : null,
    }).eq('id', reportId);
  }

  Future<List<Map<String, dynamic>>> listNearbyOpenListings(
      {String? search, String? governorate}) async {
    final selectedGovernorate = governorate?.trim().isNotEmpty == true
        ? governorate!.trim()
        : await currentUserGovernorate();
    if (selectedGovernorate == null || selectedGovernorate.isEmpty) {
      return <Map<String, dynamic>>[];
    }
    return listOpenListings(search: search, governorate: selectedGovernorate);
  }

  Future<List<Map<String, dynamic>>> listMyGovernorateOpenListings() async {
    final governorate = await currentUserGovernorate();
    if (governorate == null || governorate.trim().isEmpty) {
      return <Map<String, dynamic>>[];
    }
    return listOpenListings(governorate: governorate.trim());
  }

  Future<Map<String, dynamic>> getListing(String id) async {
    final row = await _client.from('swap_listings').select('''
      id, owner_id, wanted_title, description, category, categories, wanted_condition,
      city, governorate, latitude, longitude, images, status, expires_at,
      contact_phone, contact_whatsapp, created_at, updated_at, users:owner_id(name, avatar_url)
    ''').eq('id', id).single();
    final data = Map<String, dynamic>.from(row);
    return data;
  }

  Future<Map<String, dynamic>> createListing({
    required String wantedTitle,
    required String description,
    required String category,
    List<String> categories = const [],
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
    final selectedCategories = categories
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    if (selectedCategories.isEmpty && category.trim().isNotEmpty)
      selectedCategories.add(category.trim());
    final phone = _cleanPhone(contactPhone);
    final whatsapp = _cleanPhone(contactWhatsapp);
    if (title.length < 3) throw Exception('اكتب الشيء المطلوب استبداله بوضوح');
    if (body.length < 10)
      throw Exception('الوصف يجب أن يكون 10 أحرف على الأقل');
    if (!_isValidPhone(phone))
      throw Exception('رقم الهاتف غير صحيح (مثال: 01012345678)');
    if (!_isValidPhone(whatsapp))
      throw Exception('رقم الواتساب غير صحيح (مثال: 01012345678)');
    final profile = await _client
        .from('users')
        .select('latitude, longitude')
        .eq('id', _uid)
        .maybeSingle();
    final listingLat = latitude ?? (profile?['latitude'] as num?)?.toDouble();
    final listingLng = longitude ?? (profile?['longitude'] as num?)?.toDouble();
    final row = await _client
        .from('swap_listings')
        .insert({
          'owner_id': _uid,
          'wanted_title': title,
          'description': body,
          'category': category.trim().isEmpty ? 'other' : category.trim(),
          'categories': selectedCategories,
          'wanted_condition': wantedCondition,
          'contact_phone': phone,
          'contact_whatsapp': whatsapp,
          'images': images,
          'city': city?.trim().isEmpty == true ? null : city?.trim(),
          'governorate':
              governorate?.trim().isEmpty == true ? null : governorate?.trim(),
          'latitude': listingLat,
          'longitude': listingLng,
        })
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  String _cleanPhone(String value) =>
      value.trim().replaceAll(RegExp(r'[^0-9+ ()-]'), '');
  bool _isValidPhone(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '').length;
    return digits >= 8 && digits <= 15;
  }

  Future<List<Map<String, dynamic>>> myListings() async {
    final rows = await _client
        .from('swap_listings')
        .select(
            '''id, owner_id, wanted_title, description, category, categories, wanted_condition, city, governorate, images, contact_phone, contact_whatsapp, status, expires_at, created_at''')
        .eq('owner_id', _uid)
        .order('created_at', ascending: false);
    final hidden = await hiddenListingIds();
    return (rows as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .where((r) => !hidden.contains(r['id'].toString()))
        .toList();
  }

  Future<void> closeListing(String listingId) async {
    await _client
        .from('swap_listings')
        .update({
          'status': 'cancelled',
          'updated_at': DateTime.now().toUtc().toIso8601String()
        })
        .eq('id', listingId)
        .eq('owner_id', _uid);
  }

  Future<void> hideListing(String listingId) async {
    await _client
        .from('swap_listing_hidden')
        .upsert({'user_id': _uid, 'listing_id': listingId});
  }

  Future<Set<String>> hiddenListingIds() async {
    final rows = await _client
        .from('swap_listing_hidden')
        .select('listing_id')
        .eq('user_id', _uid);
    return (rows as List).map((row) => row['listing_id'].toString()).toSet();
  }
}
