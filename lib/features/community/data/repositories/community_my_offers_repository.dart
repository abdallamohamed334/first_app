// lib/features/community/data/repositories/community_my_offers_repository.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityMyOffersRepository {
  final SupabaseClient _client;

  CommunityMyOffersRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // ✅ جلب العروض المنشورة الخاصة بالمستخدم فقط.
  // المحاولات التي فشل حفظ مواصفاتها تُعلّم cancelled داخليًا، ولا يجب
  // عرضها للمستخدم كأنها عروض منشورة أو تستهلك مساحة من قائمته.
  Future<List<Map<String, dynamic>>> getMyOffers() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول أولًا');

    final rows = await _client
        .from('community_offers')
        .select(
          'id, owner_id, charity_id, title, description, category, listing_type, '
          'item_condition, quantity, price, image, images, pickup_location, '
          'latitude, longitude, status, created_at, updated_at, expires_at, '
          'phone, whatsapp, category_id, marketplace_category_id, edit_count',
        )
        .eq('owner_id', user.id)
        .neq('status', 'cancelled')
        .order('created_at', ascending: false)
        .limit(100);

    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  // ✅ جلب أول صورة متاحة للعرض مع تجاوز المسارات القديمة أو المفقودة.
  Future<String?> getOfferImage(String offerId) async {
    final row = await _client
        .from('community_offers')
        .select('image, images')
        .eq('id', offerId)
        .maybeSingle();
    if (row == null) return null;

    final candidates = <String>[];
    final images = row['images'];
    if (images is List) {
      candidates.addAll(images.map((image) => image?.toString() ?? ''));
    }
    candidates.add(row['image']?.toString() ?? '');

    final seen = <String>{};
    for (final candidate in candidates) {
      final clean = candidate.trim();
      if (clean.isEmpty || clean == 'null' || !seen.add(clean)) continue;
      final resolved = await _resolveOfferImage(clean);
      if (resolved != null) return resolved;
    }
    return null;
  }

  // ✅ جلب كل الصور كـ Signed URLs
  Future<List<String>> getOfferImages(String offerId) async {
    final row = await _client
        .from('community_offers')
        .select('image, images')
        .eq('id', offerId)
        .maybeSingle();
    if (row == null) return [];

    final candidates = <String>[];
    final images = row['images'];
    if (images is List) {
      candidates.addAll(images.map((image) => image?.toString() ?? ''));
    }
    candidates.add(row['image']?.toString() ?? '');

    final result = <String>[];
    final seen = <String>{};
    for (final candidate in candidates) {
      final clean = candidate.trim();
      if (clean.isEmpty || clean == 'null' || !seen.add(clean)) continue;
      final resolved = await _resolveOfferImage(clean);
      if (resolved != null) result.add(resolved);
    }
    return result;
  }

  Future<String?> _resolveOfferImage(String value) async {
    final clean = value.trim();
    final path = _offerStoragePath(clean);
    if (path == null) {
      return clean.startsWith('http://') || clean.startsWith('https://')
          ? clean
          : null;
    }

    try {
      return await _client.storage
          .from('community-offers')
          .createSignedUrl(path, 3600);
    } catch (error) {
      final message = error.toString().toLowerCase();
      final isMissingObject = message.contains('404') ||
          message.contains('not_found') ||
          message.contains('object not found');
      if (!isMissingObject) {
        debugPrint('⚠️ تعذر تحميل صورة العرض: $error');
      }
      return null;
    }
  }

  String? _offerStoragePath(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      try {
        final segments = Uri.parse(value).pathSegments;
        final bucketIndex = segments.indexOf('community-offers');
        if (bucketIndex >= 0 && bucketIndex < segments.length - 1) {
          return segments.sublist(bucketIndex + 1).join('/');
        }
      } catch (_) {}
      return null;
    }

    var path = value;
    while (path.startsWith('/')) {
      path = path.substring(1);
    }
    if (path.startsWith('community-offers/')) {
      path = path.substring('community-offers/'.length);
    }
    return path.isEmpty ? null : path;
  }

  // ✅ إلغاء العرض (حذف ناعم — بغيّر status بس)
  Future<void> deleteOffer(String offerId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول أولًا');

    await _client
        .from('community_offers')
        .update({'status': 'cancelled'})
        .eq('id', offerId)
        .eq('owner_id', user.id);
  }

  // ============================================================
  // ✅ NEW: تم البيع (Mark as Completed)
  // ============================================================

  /// يحوّل حالة العرض إلى `completed` (تم البيع)
  /// - يستخدم RPC `mark_community_offer_completed` للأمان
  /// - بيرجع true لو نجح
  Future<bool> markOfferAsCompleted(String offerId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول أولًا');

    await _client.rpc(
      'mark_community_offer_completed',
      params: {'p_offer_id': offerId, 'p_user_id': user.id},
    );
    return true;
  }

  // ============================================================
  // ✅ NEW: تجديد العرض (Renew Offer)
  // ============================================================

  /// يجدّد عرض بيع مجتمعي انتهت مدته لمدة أسبوع واحد فقط.
  /// - [days] يظل للاتساق مع النداءات الحالية ويجب أن يساوي 7.
  /// - يرجع تاريخ الانتهاء الجديد، أو null لو فشل
  Future<DateTime?> renewOffer(String offerId, {int days = 7}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول أولًا');
    if (days != 7) {
      throw ArgumentError('يمكن تجديد العرض لمدة أسبوع واحد فقط');
    }

    final response = await _client.rpc(
      'renew_community_offer',
      params: {'p_offer_id': offerId, 'p_user_id': user.id, 'p_days': days},
    );

    if (response == null) return null;
    final text = response.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  /// Updates only the offer title and its current category specifications.
  /// The category and all commercial/contact fields remain server-side immutable.
  Future<void> updateOfferNameAndAttributes({
    required String offerId,
    required String title,
    required List<Map<String, dynamic>> attributes,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول أولًا');

    await _client.rpc(
      'update_community_offer_display_details',
      params: {
        'p_offer_id': offerId,
        'p_title': title.trim(),
        'p_attributes': attributes,
      },
    );
  }
}
