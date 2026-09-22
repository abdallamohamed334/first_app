// lib/features/community/data/repositories/community_my_offers_repository.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityMyOffersRepository {
  final SupabaseClient _client;

  CommunityMyOffersRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // ✅ جلب العروض الخاصة بالمستخدم فقط
  // (بدون فلترة في DB — الفلترة بتحصل في الـ UI)
  Future<List<Map<String, dynamic>>> getMyOffers() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول أولًا');

    final rows = await _client
        .from('community_offers')
        .select('*')
        .eq('owner_id', user.id)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  // ✅ جلب صورة العرض كـ Signed URL
  Future<String?> getOfferImage(String offerId) async {
    try {
      final row = await _client
          .from('community_offers')
          .select('image')
          .eq('id', offerId)
          .maybeSingle();

      if (row == null) return null;
      final imagePath = row['image']?.toString();
      if (imagePath == null || imagePath.isEmpty) return null;

      // لو الصورة رابط مباشر، هتستخدمه زي ما هو
      if (imagePath.startsWith('http')) return imagePath;

      // لو الصورة مسار في الـ Storage، هجيب Signed URL
      return await _client.storage
          .from('community-offers')
          .createSignedUrl(imagePath, 3600);
    } catch (e) {
      debugPrint('❌ Error getting offer image: $e');
      return null;
    }
  }

  // ✅ جلب كل الصور كـ Signed URLs
  Future<List<String>> getOfferImages(String offerId) async {
    try {
      final row = await _client
          .from('community_offers')
          .select('images')
          .eq('id', offerId)
          .maybeSingle();

      if (row == null) return [];
      final images = row['images'] as List? ?? [];
      final result = <String>[];

      for (final imagePath in images) {
        final path = imagePath?.toString() ?? '';
        if (path.isEmpty) continue;

        if (path.startsWith('http')) {
          result.add(path);
        } else {
          try {
            final signedUrl = await _client.storage
                .from('community-offers')
                .createSignedUrl(path, 3600);
            result.add(signedUrl);
          } catch (e) {
            debugPrint('❌ Error getting signed URL for $path: $e');
          }
        }
      }

      return result;
    } catch (e) {
      debugPrint('❌ Error getting offer images: $e');
      return [];
    }
  }

  // ✅ إلغاء العرض (حذف ناعم — بغيّر status بس)
  Future<void> deleteOffer(String offerId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول أولًا');

    await _client
        .from('community_offers')
        .update({
          'status': 'cancelled',
        })
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

    try {
      await _client.rpc(
        'mark_community_offer_completed',
        params: {
          'p_offer_id': offerId,
          'p_user_id': user.id,
        },
      );

      return true;
    } catch (e) {
      debugPrint('❌ markOfferAsCompleted error: $e');

      // ✅ لو الـ RPC مش موجود → fallback update مباشر
      final text = e.toString().toLowerCase();

      if (text.contains('function') && text.contains('does not exist')) {
        await _client
            .from('community_offers')
            .update({
              'status': 'completed',
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', offerId)
            .eq('owner_id', user.id);

        return true;
      }

      rethrow;
    }
  }

  // ============================================================
  // ✅ NEW: تجديد العرض (Renew Offer)
  // ============================================================

  /// يجدّد عرض منتهي أو ملغي
  /// - [days] عدد الأيام الجديدة (افتراضي: 7)
  /// - يرجع تاريخ الانتهاء الجديد، أو null لو فشل
  Future<DateTime?> renewOffer(
    String offerId, {
    int days = 7,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول أولًا');

    try {
      final response = await _client.rpc(
        'renew_community_offer',
        params: {
          'p_offer_id': offerId,
          'p_user_id': user.id,
          'p_days': days,
        },
      );

      // ✅ الـ RPC بيرجع timestamptz
      if (response == null) return null;

      final text = response.toString().trim();
      if (text.isEmpty) return null;

      return DateTime.tryParse(text);
    } catch (e) {
      debugPrint('❌ renewOffer error: $e');

      // ✅ Fallback: تحديث مباشر
      final text = e.toString().toLowerCase();

      if (text.contains('function') && text.contains('does not exist')) {
        final newExpiry = DateTime.now().add(Duration(days: days));

        await _client
            .from('community_offers')
            .update({
              'status': 'available',
              'expires_at': newExpiry.toUtc().toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', offerId)
            .eq('owner_id', user.id);

        return newExpiry;
      }

      rethrow;
    }
  }
}
