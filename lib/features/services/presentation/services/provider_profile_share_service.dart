import 'package:share_plus/share_plus.dart';

import '../../domain/entities/service_provider.dart';

/// Builds a public HTTPS link so recipients without the app can still open a
/// web fallback page. Android App Links/iOS Universal Links open the same
/// route in the installed app when the domain is configured for the release.
class ProviderProfileShareService {
  ProviderProfileShareService._();

  static const publicBaseUrl = 'https://khedma.app';

  static Uri profileUri(String providerId) => Uri.parse(
        '$publicBaseUrl/service-provider/${Uri.encodeComponent(providerId)}',
      );

  static Future<void> share({required ServiceProvider provider}) async {
    final uri = profileUri(provider.id);
    final message = 'شوف ${provider.displayName} على تطبيق خدمة\n$uri';
    await Share.share(message, subject: 'رابط تقييم مقدم الخدمة');
  }
}
