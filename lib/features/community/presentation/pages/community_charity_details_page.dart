import 'package:flutter/material.dart';
import 'package:loqma/features/community/presentation/pages/community_charity_option.dart';

class CommunityCharityDetailsPage extends StatelessWidget {
  final CommunityCharityOption charity;

  const CommunityCharityDetailsPage({
    super.key,
    required this.charity,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF8),
      appBar: AppBar(
        title: const Text('تفاصيل الجمعية'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF123F31),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
        children: [
          _hero(),
          const SizedBox(height: 16),
          _infoCard(),
          const SizedBox(height: 14),
          _descriptionCard(),
          const SizedBox(height: 20),
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, charity),
              icon: const Icon(Icons.favorite_rounded),
              label: const Text('اختيار هذه الجمعية'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B7650),
                foregroundColor: Colors.white,
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
                Text('جمعية موثقة',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
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
        child:
            Icon(Icons.account_balance_rounded, color: Colors.white, size: 44),
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
          child: Icon(Icons.account_balance_rounded,
              color: Colors.white, size: 44),
        ),
      ),
    );
  }

  Widget _infoCard() => _card(
        children: [
          if (charity.address?.isNotEmpty == true)
            _row(Icons.location_on_outlined, 'العنوان', charity.address!),
          if (charity.phone?.isNotEmpty == true)
            _row(Icons.phone_outlined, 'الهاتف', charity.phone!),
          if (charity.email?.isNotEmpty == true)
            _row(Icons.email_outlined, 'البريد الإلكتروني', charity.email!),
          if (charity.rating != null)
            _row(Icons.star_outline_rounded, 'التقييم',
                charity.rating!.toString()),
        ],
      );

  Widget _descriptionCard() => _card(
        children: [
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'عن الجمعية',
              style: TextStyle(
                color: Color(0xFF123F31),
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
            style: const TextStyle(color: Color(0xFF60746B), height: 1.6),
          ),
        ],
      );

  Widget _card({required List<Widget> children}) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: const Color(0xFFE1ECE6)),
        ),
        child: Column(children: children),
      );

  Widget _row(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF0B7650), size: 21),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Color(0xFF8A9B93), fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          color: Color(0xFF123F31),
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      );
}
