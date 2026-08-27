import 'package:flutter/material.dart';

class OnboardingActions extends StatelessWidget {
  final bool isLastPage;
  final VoidCallback onNext;
  final VoidCallback onComplete;
  final VoidCallback onLogin;

  const OnboardingActions({
    super.key,
    required this.isLastPage,
    required this.onNext,
    required this.onComplete,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Primary Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLastPage ? onComplete : onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
              elevation: 2,
              shadowColor: colorScheme.primary.withValues(alpha: 0.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isLastPage ? 'ابدأ الآن' : 'التالي',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isLastPage ? Icons.rocket_launch : Icons.arrow_forward,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Login Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onLogin,
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.onSurfaceVariant,
              side: BorderSide(
                color: colorScheme.outlineVariant,
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('لدي حساب بالفعل'),
                SizedBox(width: 8),
                Icon(Icons.login, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


