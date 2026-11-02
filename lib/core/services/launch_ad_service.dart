import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'supabase_service.dart';

class LaunchAdCampaign {
  const LaunchAdCampaign({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.description,
    this.targetUrl,
    this.whatsapp,
  });

  final String id;
  final String title;
  final String imageUrl;
  final String? description;
  final String? targetUrl;
  final String? whatsapp;

  factory LaunchAdCampaign.fromMap(Map<String, dynamic> map) {
    return LaunchAdCampaign(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'إعلان',
      imageUrl: map['image_url']?.toString() ?? '',
      description: _clean(map['description']),
      targetUrl: _clean(map['target_url']),
      whatsapp: _clean(map['whatsapp']),
    );
  }

  static String? _clean(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

class LaunchAdService {
  LaunchAdService._();

  static final LaunchAdService instance = LaunchAdService._();
  static const _shownPrefix = 'launch_ad_shown_at_';
  static const _cooldown = Duration(hours: 24);

  Future<LaunchAdCampaign?> getCampaignForToday() async {
    try {
      final row = await SupabaseService()
          .client
          .from('advertising_campaigns')
          .select('id, title, description, image_url, target_url, whatsapp')
          .eq('status', 'active')
          .eq('is_enabled', true)
          .lte('starts_at', DateTime.now().toUtc().toIso8601String())
          .gte('ends_at', DateTime.now().toUtc().toIso8601String())
          .order('priority', ascending: false)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row == null) return null;
      final campaign = LaunchAdCampaign.fromMap(Map<String, dynamic>.from(row));
      if (campaign.id.isEmpty || campaign.imageUrl.isEmpty) return null;

      final preferences = await SharedPreferences.getInstance();
      final lastShownMs = preferences.getInt('$_shownPrefix${campaign.id}');
      if (lastShownMs != null &&
          DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastShownMs)) <
              _cooldown) {
        return null;
      }

      await preferences.setInt(
        '$_shownPrefix${campaign.id}',
        DateTime.now().millisecondsSinceEpoch,
      );
      return campaign;
    } catch (error, stack) {
      debugPrint('[LaunchAd] campaign lookup skipped: $error');
      debugPrintStack(stackTrace: stack);
      return null;
    }
  }

  static Future<bool> openTarget(LaunchAdCampaign campaign) async {
    final raw = campaign.targetUrl ??
        (campaign.whatsapp == null ? null : _whatsappUrl(campaign.whatsapp!));
    if (raw == null || raw.isEmpty) return false;
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static String _whatsappUrl(String phone) {
    var cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    cleanPhone = cleanPhone.replaceFirst('+', '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '20${cleanPhone.substring(1)}';
    }
    return 'https://wa.me/$cleanPhone';
  }
}
