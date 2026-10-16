import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/sentry_service.dart';

class SentryTestPage extends StatelessWidget {
  const SentryTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const Scaffold(
        body: Center(child: Text('Not available')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sentry debug test')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await LoqmaSentry.testException();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Test event sent')),
              );
            }
          },
          child: const Text('Send test exception'),
        ),
      ),
    );
  }
}
