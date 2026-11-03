import 'package:flutter/material.dart';

import '../../../../core/services/app_update_service.dart';

class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  late Future<AppUpdateRequirement> _checkFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkFuture = AppUpdateService.instance.check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {
        _checkFuture = AppUpdateService.instance.check();
      });
    }
  }

  void _retry() {
    setState(() {
      _checkFuture = AppUpdateService.instance.check();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppUpdateRequirement>(
      future: _checkFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _UpdateLoadingPage();
        }
        final requirement = snapshot.data;
        if (requirement?.isRequired != true) return widget.child;
        return _ForceUpdatePage(
          requirement: requirement!,
          onRetry: _retry,
        );
      },
    );
  }
}

class _UpdateLoadingPage extends StatelessWidget {
  const _UpdateLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF0B7650)),
        ),
      ),
    );
  }
}

class _ForceUpdatePage extends StatelessWidget {
  const _ForceUpdatePage({
    required this.requirement,
    required this.onRetry,
  });

  final AppUpdateRequirement requirement;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8F6),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B7650).withValues(alpha: .1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.system_update_rounded,
                            size: 40,
                            color: Color(0xFF0B7650),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'تحديث إجباري مطلوب',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF123F31),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          requirement.message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            height: 1.6,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'الإصدار المثبت: ${requirement.currentVersion}\n'
                          'الإصدار المطلوب: ${requirement.minimumVersion}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: requirement.storeUrl.isEmpty
                                ? null
                                : () => AppUpdateService.openStore(
                                      requirement.storeUrl,
                                    ),
                            icon: const Icon(Icons.download_rounded),
                            label: const Text(
                              'تحديث التطبيق الآن',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0B7650),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('تحقق مرة أخرى بعد التحديث'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
