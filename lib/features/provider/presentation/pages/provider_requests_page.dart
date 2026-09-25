// lib/features/provider/presentation/pages/provider_requests_page.dart

import 'package:flutter/material.dart';

class ProviderRequestsPage extends StatelessWidget {
  const ProviderRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Color(0xFFF4F8F6),
        body: Center(
          child: Text(
            'الطلبات — قيد التطوير',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
