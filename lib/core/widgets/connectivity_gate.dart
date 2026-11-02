import 'package:flutter/material.dart';

import '../services/connectivity_service.dart';

class ConnectivityGate extends StatelessWidget {
  const ConnectivityGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final service = ConnectivityService.instance;

    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        if (!service.isOffline) return child;

        final colors = Theme.of(context).colorScheme;
        return Scaffold(
          backgroundColor: colors.surface,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 72,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'لا يوجد اتصال بالإنترنت',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'افتح الإنترنت ثم اضغط إعادة المحاولة للمتابعة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => service.retry(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
