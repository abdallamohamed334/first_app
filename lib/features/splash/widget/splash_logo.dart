import 'package:flutter/material.dart';

class SplashLogo extends StatelessWidget {
  final Animation<double> animation;

  const SplashLogo({
    super.key,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final logoSize = MediaQuery.of(context).size.width < 600 ? 100.0 : 128.0;

    return Semantics(
      label: 'Ø´Ø¹Ø§Ø± Ù„Ù‚Ù…Ø©',
      child: ScaleTransition(
        scale: animation,
        child: Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.15),
                blurRadius: 60,
                spreadRadius: 20,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 40,
                spreadRadius: 5,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.restaurant,
                  size: logoSize * 0.5,
                  color: Theme.of(context).colorScheme.primary,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

