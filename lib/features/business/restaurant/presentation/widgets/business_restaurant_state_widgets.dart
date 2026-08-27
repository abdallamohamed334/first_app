import 'package:flutter/material.dart';

const _green = Color(0xFF0B7650);
const _dark = Color(0xFF123F31);
const _muted = Color(0xFF71837C);

class BusinessRestaurantLoadingView extends StatelessWidget {
  const BusinessRestaurantLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _green),
            SizedBox(height: 14),
            Text(
              'جاري تحميل بيانات المطعم...',
              textAlign: TextAlign.center,
              style: TextStyle(color: _dark, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 5),
            Text(
              'نقرأ العروض والطلبات من قاعدة البيانات',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class BusinessRestaurantErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const BusinessRestaurantErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEDEA),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color: Color(0xFFD64545),
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'تعذر تحميل بيانات المطعم',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _dark,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, height: 1.4),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
                style: FilledButton.styleFrom(backgroundColor: _green),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BusinessRestaurantEmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const BusinessRestaurantEmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDCEBE3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF72A890), size: 36),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _dark, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 12, height: 1.4),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded),
                label: Text(actionLabel!),
                style: OutlinedButton.styleFrom(foregroundColor: _green),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
