import 'package:equatable/equatable.dart';

class SplashConfig extends Equatable {
  final double logoSize;
  final Duration animationDuration;
  final Duration splashDuration;
  final String tagline;
  final String brandingText;

  const SplashConfig({
    this.logoSize = 128,
    this.animationDuration = const Duration(milliseconds: 1000),
    this.splashDuration = const Duration(milliseconds: 3500),
    this.tagline = 'كل وجبة تصنع فرقًا',
    this.brandingText = 'استدامة . عطاء . جُود',
  });

  @override
  List<Object?> get props => [
        logoSize,
        animationDuration,
        splashDuration,
        tagline,
        brandingText,
      ];
}
