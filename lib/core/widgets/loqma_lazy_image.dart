import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Network image used by cards and scrolling lists.
/// CachedNetworkImage only resolves/loads the URL when this widget is built,
/// while its disk and memory cache prevents repeated downloads when a card is
/// revisited.
class LoqmaLazyImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final int? cacheWidth;
  final int? cacheHeight;

  const LoqmaLazyImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.cacheWidth,
    this.cacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return errorWidget ?? const SizedBox.shrink();
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: cacheWidth,
      memCacheHeight: cacheHeight,
      fadeInDuration: const Duration(milliseconds: 160),
      placeholder: (_, __) => placeholder ??
          const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      errorWidget: (_, __, ___) => errorWidget ??
          const Center(child: Icon(Icons.image_not_supported_outlined)),
    );
  }
}
