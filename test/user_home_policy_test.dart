import 'package:flutter_test/flutter_test.dart';
import 'package:loqma/features/userhome/domain/entities/category_offer.dart';
import 'package:loqma/features/userhome/domain/user_home_policy.dart';

void main() {
  group('UserHomePolicy', () {
    test('allows exactly the commercial and surplus institution types', () {
      expect(
        [
          'grocery',
          'supermarket',
          'bakery',
          'pastry_shop',
          'hotel',
          'wedding_hall',
        ].every(UserHomePolicy.isVisibleInstitutionType),
        isTrue,
      );
      expect(
        ['poultry_shop', 'game_store', 'catering', 'restaurant']
            .any(UserHomePolicy.isVisibleInstitutionType),
        isFalse,
      );
    });

    test('normalizes institution slugs before applying the catalog filter', () {
      expect(UserHomePolicy.isAllowedCatalogSlug('  SuperMarket '), isTrue);
      expect(UserHomePolicy.isAllowedCatalogSlug('game_store'), isFalse);
      expect(UserHomePolicy.isAllowedCatalogSlug(null), isFalse);
    });

    test('deduplicates the same offer id while preserving order', () {
      final offers = [
        _offer('offer-1', 'الأول'),
        _offer('offer-1', 'نسخة مكررة'),
        _offer('offer-2', 'الثاني'),
        _offer(' ', 'بلا معرّف'),
      ];

      final result = UserHomePolicy.uniqueById(offers, (offer) => offer.id);

      expect(result.map((offer) => offer.id), ['offer-1', 'offer-2']);
      expect(result.first.title, 'الأول');
    });
  });
}

CategoryOffer _offer(String id, String title) {
  return CategoryOffer(
    id: id,
    title: title,
    ownerType: 'institution',
    status: 'active',
    createdAt: DateTime.utc(2026, 10, 13),
  );
}
