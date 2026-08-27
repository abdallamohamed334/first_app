import 'package:flutter/material.dart';

/// Reusable Loqma branding widget for splash, login, home, and profile screens.
class LoqmaLogo extends StatelessWidget {
  final double size;
  final bool showWordmark;
  final BoxFit fit;

  const LoqmaLogo({
    super.key,
    this.size = 96,
    this.showWordmark = true,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loqma',
      image: true,
      child: Image.asset(
        'assets/images/loqma_logo.png',
        width: showWordmark ? size * 2.6 : size,
        height: size,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.restaurant_rounded,
          size: size * 0.65,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// Icon-only variant for app bars and compact cards.
class LoqmaLogoMark extends StatelessWidget {
  final double size;

  const LoqmaLogoMark({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return LoqmaLogo(
      size: size,
      showWordmark: false,
    );
  }
}
