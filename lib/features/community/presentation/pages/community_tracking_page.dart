import 'package:flutter/material.dart';

import 'my_community_needs_page.dart';

/// Legacy route retained for compatibility; tracking now contains only the
/// user's published service-related needs.
class CommunityTrackingPage extends StatelessWidget {
  const CommunityTrackingPage({super.key});

  @override
  Widget build(BuildContext context) => const MyCommunityNeedsPage();
}
