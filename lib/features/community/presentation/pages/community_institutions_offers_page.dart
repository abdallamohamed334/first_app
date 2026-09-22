// lib/features/community/presentation/pages/community_institutions_offers_page.dart
import 'package:flutter/material.dart';

class CommunityInstitutionsOffersPage extends StatelessWidget {
  const CommunityInstitutionsOffersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_hospital_outlined,
            size: 64,
            color: Color(0xFF0B7650),
          ),
          SizedBox(height: 12),
          Text(
            'متابعة عروض المؤسسات',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF123F31),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'هنا هتظهر العروض اللي نشرتها المؤسسات',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF71837C),
            ),
          ),
        ],
      ),
    );
  }
}
