import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// إعلان Google AdMob بانر واحد غير متطفل.
///
/// يستخدم معرّفات Google التجريبية في Debug، ومعرّفات الإنتاج الممررة
/// عبر ADMOB_BANNER_ANDROID_ID / ADMOB_BANNER_IOS_ID في Release.
class AdBannerCard extends StatefulWidget {
  const AdBannerCard({super.key});

  @override
  State<AdBannerCard> createState() => _AdBannerCardState();
}

class _AdBannerCardState extends State<AdBannerCard> {
  static const _androidTestAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const _iosTestAdUnitId = 'ca-app-pub-3940256099942544/2934735716';
  static const _androidAdUnitId = String.fromEnvironment(
    'ADMOB_BANNER_ANDROID_ID',
    defaultValue: 'ca-app-pub-7040845911809776/2951369417',
  );
  static const _iosAdUnitId = String.fromEnvironment(
    'ADMOB_BANNER_IOS_ID',
    defaultValue: '',
  );

  static Future<InitializationStatus>? _initialization;

  BannerAd? _banner;
  bool _isLoaded = false;
  bool _retriedAfterTransientFailure = false;

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

  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    if (!_isSupportedPlatform) return;

    // لا نستخدم Test ID على iOS في Release بدون إعداد معرف إنتاج.
    if (!kDebugMode &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        _adUnitId.isEmpty) {
      debugPrint('[Ads] iOS production banner ID is not configured');
      return;
    }

    _loadBanner();
  }

  Future<void> _loadBanner() async {
    if (kDebugMode) {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          testDeviceIds: const ['36B1A66D9CDF208A83ADE52C6181EAB2'],
        ),
      );
    }

    _initialization ??= MobileAds.instance.initialize();
    await _initialization;
    if (!mounted) return;

    final banner = BannerAd(
      adUnitId: _adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('[Ads] Banner loaded successfully: ${ad.adUnitId}');
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _banner = ad as BannerAd;
            _isLoaded = true;
            _retriedAfterTransientFailure = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint(
            '[Ads] Banner failed to load: code=${error.code}, '
            'domain=${error.domain}, message=${error.message}, '
            'response=${error.responseInfo}',
          );
          if (mounted &&
              !_retriedAfterTransientFailure &&
              (error.code == 2 || error.code == 3)) {
            _retriedAfterTransientFailure = true;
            Future<void>.delayed(const Duration(seconds: 15), () {
              if (mounted && !_isLoaded) _loadBanner();
            });
          }
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

    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 22, bottom: 22),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: .18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'إعلان',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
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
