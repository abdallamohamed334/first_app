import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Banner CTA for businesses that want to advertise in Khedma.
class AdBannerCard extends StatelessWidget {
  const AdBannerCard({super.key});

  static const String _supportPhone = '201286162776';
  static const String _supportPhoneLocal = '01286162776';
  static const String _message =
      'مرحبًا، أريد الاستفسار عن إضافة إعلان في تطبيق خدمة.';

  Future<void> _openAdvertisingSupport(BuildContext context) async {
    final primaryUri = Uri.https(
      'wa.me',
      '/$_supportPhone',
      {'text': _message},
    );

    try {
      final opened = await launchUrl(
        primaryUri,
        mode: LaunchMode.externalApplication,
      );
      if (opened || !context.mounted) return;

      final fallbackUri = Uri.https(
        'api.whatsapp.com',
        '/send',
        {'phone': _supportPhone, 'text': _message},
      );
      final fallbackOpened = await launchUrl(
        fallbackUri,
        mode: LaunchMode.externalApplication,
      );
      if (fallbackOpened || !context.mounted) return;
    } catch (error) {
      debugPrint('[AdBannerCard] Could not open WhatsApp: $error');
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر فتح واتساب. تواصل مع الدعم على $_supportPhoneLocal',
            textDirection: TextDirection.rtl,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Material(
        color: colors.primary,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _openAdvertisingSupport(context),
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.primary,
                  colors.primary.withValues(alpha: .82),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.onPrimary.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      Icons.campaign_rounded,
                      color: colors.onPrimary,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'سيب إعلانك هنا',
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            color: colors.onPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'لو عايز تعلن، تواصل مع دعم خدمة عبر واتساب',
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            color: colors.onPrimary.withValues(alpha: .88),
                            fontSize: 11.5,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFF25D366),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chat_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
