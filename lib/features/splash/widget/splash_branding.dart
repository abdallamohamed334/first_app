import 'package:flutter/material.dart';

class SplashBranding extends StatelessWidget {
  final Animation<double> animation;

  const SplashBranding({
    super.key,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 600;

    return FadeTransition(
      opacity: animation,
      child: Text(
        'استدامة . عطاء . لقمة',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: isSmall ? 12 : 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}


