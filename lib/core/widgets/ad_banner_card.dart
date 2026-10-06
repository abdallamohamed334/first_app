import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// إعلان واحد غير متطفل يظهر داخل صفحة تفاصيل العرض فقط.
///
/// يتم تمرير معرّفات AdMob عبر --dart-define عند الحاجة، مع استخدام معرّف
/// وصلة الحقيقي لأندرويد كقيمة افتراضية.
class AdBannerCard extends StatefulWidget {
  const AdBannerCard({super.key});

  @override
  State<AdBannerCard> createState() => _AdBannerCardState();
}

class _AdBannerCardState extends State<AdBannerCard> {
  // Google's official test banner. Never click test ads or use them in release.
  static const _androidTestAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const _iosTestAdUnitId = 'ca-app-pub-3940256099942544/2934735716';

  static const _androidAdUnitId = String.fromEnvironment(
    'ADMOB_BANNER_ANDROID_ID',
    defaultValue: 'ca-app-pub-7040845911809776/2951369417',
  );
  static const _iosAdUnitId = String.fromEnvironment(
    'ADMOB_BANNER_IOS_ID',
    defaultValue: 'ca-app-pub-3940256099942544/2934735716',
  );

  BannerAd? _banner;
  bool _isLoaded = false;

  String get _adUnitId {
    if (kDebugMode) {
      return defaultTargetPlatform == TargetPlatform.iOS
          ? _iosTestAdUnitId
          : _androidTestAdUnitId;
    }

    final configured = (defaultTargetPlatform == TargetPlatform.iOS
            ? dotenv.env['ADMOB_BANNER_IOS_ID']
            : dotenv.env['ADMOB_BANNER_ANDROID_ID'])
        ?.trim();
    if (configured != null && configured.isNotEmpty) return configured;
    return defaultTargetPlatform == TargetPlatform.iOS
        ? _iosAdUnitId
        : _androidAdUnitId;
  }

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    _loadBanner();
  }

  Future<void> _loadBanner() async {
    await MobileAds.instance.initialize();
    if (!mounted) return;

    final banner = BannerAd(
      adUnitId: _adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _banner = ad as BannerAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint(
            '[Ads] Banner failed to load: ${error.code} ${error.message}',
          );
        },
      ),
    );
    banner.load();
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !_isLoaded || _banner == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 22, bottom: 22),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
              alpha: .42,
            ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: .18),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'إعلان',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: _banner!.size.width.toDouble(),
            height: _banner!.size.height.toDouble(),
            child: AdWidget(ad: _banner!),
          ),
        ],
      ),
    );
  }
}
