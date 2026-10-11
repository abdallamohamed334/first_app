import 'package:flutter/material.dart';
import 'package:loqma/features/community/presentation/pages/community_charity_option.dart';

class CommunityCharityDetailsPage extends StatelessWidget {
  final CommunityCharityOption charity;

  const CommunityCharityDetailsPage({super.key, required this.charity});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = colors.brightness == Brightness.dark
        ? const Color(0xFF48C98A)
        : const Color(0xFF0B7650);
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('تفاصيل الجمعية'),
        centerTitle: true,
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
        children: [
          _hero(),
          const SizedBox(height: 16),
          _infoCard(colors),
          const SizedBox(height: 14),
          _descriptionCard(colors),
          const SizedBox(height: 20),
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, charity),
              icon: const Icon(Icons.favorite_rounded),
              label: const Text('اختيار هذه الجمعية'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: colors.brightness == Brightness.dark
                    ? colors.surface
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B7650), Color(0xFF21A36F)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          _logo(),
          const SizedBox(height: 14),
          Text(
            charity.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              height: 1.35,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (charity.isVerified) ...[
            const SizedBox(height: 9),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_rounded, color: Colors.white, size: 18),
                SizedBox(width: 5),
                Text(
                  'جمعية موثقة',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _logo() {
    if (charity.logo == null || charity.logo!.isEmpty) {
      return const CircleAvatar(
        radius: 44,
        backgroundColor: Colors.white24,
        child: Icon(
          Icons.account_balance_rounded,
          color: Colors.white,
          size: 44,
        ),
      );
    }
    return ClipOval(
      child: Image.network(
        charity.logo!,
        width: 88,
        height: 88,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const CircleAvatar(
          radius: 44,
          backgroundColor: Colors.white24,
          child: Icon(
            Icons.account_balance_rounded,
            color: Colors.white,
            size: 44,
          ),
        ),
      ),
    );
  }

  Widget _infoCard(ColorScheme colors) => _card(
    colors,
    children: [
      if (charity.address?.isNotEmpty == true)
        _row(colors, Icons.location_on_outlined, 'العنوان', charity.address!),
      if (charity.phone?.isNotEmpty == true)
        _row(colors, Icons.phone_outlined, 'الهاتف', charity.phone!),
      if (charity.email?.isNotEmpty == true)
        _row(colors, Icons.email_outlined, 'البريد الإلكتروني', charity.email!),
      if (charity.rating != null)
        _row(
          colors,
          Icons.star_outline_rounded,
          'التقييم',
          charity.rating!.toString(),
        ),
    ],
  );

  Widget _descriptionCard(ColorScheme colors) => _card(
    colors,
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: Text(
          'عن الجمعية',
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        charity.description?.isNotEmpty == true
            ? charity.description!
            : 'لا توجد تفاصيل إضافية عن الجمعية حاليًا.',
        textAlign: TextAlign.right,
        style: TextStyle(color: colors.onSurfaceVariant, height: 1.6),
      ),
    ],
  );

  Widget _card(ColorScheme colors, {required List<Widget> children}) =>
      Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(children: children),
      );

  Widget _row(ColorScheme colors, IconData icon, String label, String value) {
    final accent = colors.brightness == Brightness.dark
        ? const Color(0xFF48C98A)
        : const Color(0xFF0B7650);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
