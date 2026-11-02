import 'package:flutter/material.dart';

import '../../../../core/services/launch_ad_service.dart';

class LaunchAdGate extends StatefulWidget {
  const LaunchAdGate({super.key, required this.child});

  final Widget child;

  @override
  State<LaunchAdGate> createState() => _LaunchAdGateState();
}

class _LaunchAdGateState extends State<LaunchAdGate> {
  LaunchAdCampaign? _campaign;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCampaign();
  }

  Future<void> _loadCampaign() async {
    final campaign = await LaunchAdService.instance.getCampaignForToday();
    if (!mounted) return;
    setState(() {
      _campaign = campaign;
      _loading = false;
    });
  }

  void _close() {
    if (!mounted) return;
    setState(() => _campaign = null);
  }

  @override
  Widget build(BuildContext context) {
    final campaign = _campaign;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_loading && campaign != null)
          _LaunchAdOverlay(
            campaign: campaign,
            onClose: _close,
          ),
      ],
    );
  }
}

class _LaunchAdOverlay extends StatelessWidget {
  const _LaunchAdOverlay({
    required this.campaign,
    required this.onClose,
  });

  final LaunchAdCampaign campaign;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: .86),
      child: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 64, 20, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => LaunchAdService.openTarget(campaign),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.network(
                            campaign.imageUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const SizedBox(
                                height: 260,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              height: 220,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: const Icon(
                                Icons.campaign_rounded,
                                color: Colors.white70,
                                size: 72,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        campaign.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (campaign.description != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          campaign.description!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                      if (campaign.targetUrl != null ||
                          campaign.whatsapp != null) ...[
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: () => LaunchAdService.openTarget(campaign),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text(
                            'اعرف المزيد',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0B7650),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      const Text(
                        'إعلان مدفوع',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              top: 10,
              end: 10,
              child: IconButton.filled(
                onPressed: onClose,
                tooltip: 'إغلاق الإعلان',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: .18),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
