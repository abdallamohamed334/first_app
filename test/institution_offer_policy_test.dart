import 'package:flutter_test/flutter_test.dart';
import 'package:loqma/features/institutions/domain/institution_offer_policy.dart';

void main() {
  test('commercial institution types publish symbolic-sale offers', () {
    for (final type in ['grocery', 'supermarket', 'bakery', 'pastry_shop']) {
      expect(InstitutionOfferPolicy.canPublishOffers(type), isTrue);
      expect(InstitutionOfferPolicy.isCommercial(type), isTrue);
      expect(InstitutionOfferPolicy.isSurplus(type), isFalse);
      expect(InstitutionOfferPolicy.sectionLabel(type), 'شراء رمزي');
    }
  });

  test('hotels and wedding halls publish institutional surplus', () {
    for (final type in ['hotel', 'wedding_hall']) {
      expect(InstitutionOfferPolicy.canPublishOffers(type), isTrue);
      expect(InstitutionOfferPolicy.isSurplus(type), isTrue);
      expect(InstitutionOfferPolicy.sectionLabel(type), 'فائض مؤسسات');
    }
  });

  test('removed institution types cannot publish or appear in sections', () {
    for (final type in [
      'poultry_shop',
      'game_store',
      'catering',
      'restaurant'
    ]) {
      expect(InstitutionOfferPolicy.canPublishOffers(type), isFalse);
      expect(InstitutionOfferPolicy.isCommercial(type), isFalse);
      expect(InstitutionOfferPolicy.isSurplus(type), isFalse);
    }
  });

  test('categories are tailored to institution type', () {
    expect(
      InstitutionOfferPolicy.categoryIdsFor('pastry_shop'),
      containsAll(['dessert', 'bakery', 'food', 'other']),
    );
    expect(
      InstitutionOfferPolicy.categoryIdsFor('wedding_hall'),
      containsAll(['food', 'dessert', 'drink']),
    );
  });
}
