import 'package:flutter/material.dart';

import 'package:loqma/core/models/user_model.dart';
import 'complete_profile_page.dart';
import 'location_picker_page.dart';

class UserLocationSetupPage extends StatefulWidget {
  final UserModel user;

  const UserLocationSetupPage({super.key, required this.user});

  @override
  State<UserLocationSetupPage> createState() => _UserLocationSetupPageState();
}

class _UserLocationSetupPageState extends State<UserLocationSetupPage> {
  static const _primary = Color(0xFF0B7650);
  static const _darkGreen = Color(0xFF123F31);
  double? _lat;
  double? _lng;
  bool _openingMap = false;

  Future<void> _chooseLocation() async {
    setState(() => _openingMap = true);
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          initialLat: _lat ?? widget.user.lat,
          initialLng: _lng ?? widget.user.lng,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _openingMap = false);
    if (result == null) return;

    final lat = (result['lat'] as num?)?.toDouble();
    final lng = (result['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return;

    setState(() {
      _lat = lat;
      _lng = lng;
    });

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CompleteProfilePage(
          user: widget.user,
          role: 'user',
          initialLat: lat,
          initialLng: lng,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F8F6),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: _primary,
                      size: 46,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'خلّينا نحدد مكانك الأول',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _darkGreen,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'الموقع بيساعدنا نعرضلك العروض والاحتياجات والخدمات القريبة منك بدقة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.55),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border:
                          Border.all(color: _primary.withValues(alpha: 0.14)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.privacy_tip_outlined, color: _primary),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'موقعك بيُستخدم لتحسين النتائج القريبة منك فقط.',
                            style: TextStyle(
                              color: _darkGreen,
                              fontSize: 12.5,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _openingMap ? null : _chooseLocation,
                      icon: _openingMap
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.map_rounded),
                      label: const Text(
                        'اختيار موقعي على الخريطة',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'لا يمكن دخول التطبيق قبل تحديد الموقع وإكمال البيانات.',
                    style: TextStyle(color: Colors.black45, fontSize: 11.5),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
