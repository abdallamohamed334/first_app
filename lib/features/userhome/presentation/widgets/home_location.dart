import 'package:flutter/material.dart';

class HomeLocation extends StatelessWidget {
  final String city;
  final VoidCallback onLocationTap;

  const HomeLocation({
    super.key,
    required this.city,
    required this.onLocationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: GestureDetector(
        onTap: onLocationTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_on_rounded,
              size: 16,
              color: Color(0xFF0B7650),
            ),
            const SizedBox(width: 4),
            Text(
              city,
              style: const TextStyle(
                color: Color(0xFF123F31),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: Color(0xFF71837C),
            ),
          ],
        ),
      ),
    );
  }
}
