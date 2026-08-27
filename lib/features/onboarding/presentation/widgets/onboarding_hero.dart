import 'package:flutter/material.dart';
import '../bloc/onboarding_bloc.dart';

class OnboardingHero extends StatelessWidget {
  final OnboardingPageData page;
  final int currentIndex;

  const OnboardingHero({
    super.key,
    required this.page,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final diameter = size.width * 0.55; // ✅ زيادة الحجم من 0.45 إلى 0.55

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            colorScheme.primary.withValues(alpha: 0.05),
            colorScheme.secondary.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Center(
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Orbit Ring 1 - أكبر
              Container(
                width: diameter * 1.15,
                height: diameter * 1.15,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    width: 2,
                  ),
                ),
              ),
              // Orbit Ring 2 - أكبر
              Container(
                width: diameter * 1.3,
                height: diameter * 1.3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.secondary.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              // ✅ الصورة بحجم أكبر
              Image.asset(
                page.imageUrl,
                height: diameter * 0.7, // ✅ زيادة من 0.5 إلى 0.7
                width: diameter * 0.7,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.image_not_supported,
                    size: diameter * 0.4,
                    color: colorScheme.primary,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}


