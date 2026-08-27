import 'package:flutter/material.dart';
import '../../../../core/models/user_model.dart';

class ProfileInfoCard extends StatelessWidget {
  final UserModel user;

  const ProfileInfoCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final items = [
      (Icons.person_outline_rounded, 'الاسم', _value(user.name)),
      (Icons.email_outlined, 'البريد الإلكتروني', _value(user.email)),
      (Icons.phone_outlined, 'رقم الهاتف', _value(user.phone)),
      (Icons.location_city_rounded, 'المدينة', _value(user.city)),
      (Icons.location_on_outlined, 'العنوان', _value(user.address)),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withAlpha(100)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'المعلومات الشخصية',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(items.length, (index) {
            final item = items[index];
            return Column(
              children: [
                if (index > 0)
                  Divider(
                    height: 20,
                    color: colors.outlineVariant.withAlpha(75),
                  ),
                _InfoRow(
                  icon: item.$1,
                  label: item.$2,
                  value: item.$3,
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  String _value(String? value) {
    final clean = value?.trim() ?? '';
    return clean.isEmpty ? 'غير محدد' : clean;
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colors.primary.withAlpha(18),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: colors.primary, size: 19),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
