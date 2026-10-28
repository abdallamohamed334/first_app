import 'package:share_plus/share_plus.dart';

import '../../domain/entities/service_provider.dart';

/// Shares the provider's short code. It works from WhatsApp without a domain,
/// because the recipient searches for the code inside the Khedma app.
class ProviderProfileShareService {
  ProviderProfileShareService._();

  static Future<void> share({required ServiceProvider provider}) async {
    final code = provider.providerCode?.trim();
    if (code == null || code.isEmpty) {
      throw StateError('Provider code is missing');
    }
    final message = 'قيّم مقدم الخدمة ${provider.displayName} على تطبيق خدمة\n'
        'افتح التطبيق وابحث باستخدام الكود: $code';
    await Share.share(message, subject: 'كود تقييم مقدم الخدمة');
  }
}
