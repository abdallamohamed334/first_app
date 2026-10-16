import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/sentry_service.dart';

class SentryTestPage extends StatelessWidget {
  const SentryTestPage({super.key});

  static const bool isEnabled = kDebugMode ||
      bool.fromEnvironment('SENTRY_TEST', defaultValue: false);

  void _show(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (!isEnabled) {
      return const Scaffold(body: Center(child: Text('Not available')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sentry filter test')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: () {
                final result = LoqmaSentry.classify(
                  type: 'SocketException',
                  message: 'Network is unreachable',
                );
                _show(context, 'SocketException: ${result.name} (dropped)');
              },
              child: const Text('Test filtered network error'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final result = LoqmaSentry.classify(
                  type: 'StateError',
                  message: 'Unexpected test failure',
                );
                await LoqmaSentry.testException();
                _show(context, 'StateError: ${result.name}; event sent');
              },
              child: const Text('Send real StateError test'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Debug builds verify the filter only. To verify ingestion, build '
              'release/profile with SENTRY_TEST=true and SENTRY_DSN.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
