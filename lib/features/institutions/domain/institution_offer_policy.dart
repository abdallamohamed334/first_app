/// Business rules for the institution-offer marketplace.
///
/// Commercial institutions publish symbolic-price sale offers. Hotels and
/// wedding halls publish surplus food for redistribution.
class InstitutionOfferPolicy {
  static const commercialTypes = <String>{
    'grocery',
    'supermarket',
    'bakery',
    'butcher',
    'meat_shop',
  };

  static const surplusTypes = <String>{
    'hotel',
    'wedding_hall',
  };

  static const allowedOfferTypes = <String>{
    ...commercialTypes,
    ...surplusTypes,
  };

  static String normalizeType(String? value) => (value ?? '')
      .trim()
      .toLowerCase()
      .replaceAll('-', '_')
      .replaceAll(RegExp(r'\s+'), '_');

  static bool isCommercial(String? value) =>
      commercialTypes.contains(normalizeType(value));

  static bool isSurplus(String? value) =>
      surplusTypes.contains(normalizeType(value));

  static bool canPublishOffers(String? value) =>
      allowedOfferTypes.contains(normalizeType(value));

  static String typeLabel(String? value) {
    switch (normalizeType(value)) {
      case 'grocery':
        return 'بقالة';
      case 'supermarket':
        return 'سوبر ماركت';
      case 'bakery':
        return 'مخبز';
      case 'butcher':
      case 'meat_shop':
        return 'جزارة';
      case 'hotel':
        return 'فندق';
      case 'wedding_hall':
        return 'قاعة أفراح';
      default:
        return 'مؤسسة';
    }
  }

  static String sectionLabel(String? value) =>
      isSurplus(value) ? 'فائض مؤسسات' : 'شراء رمزي';

  static List<String> categoryIdsFor(String? value) {
    if (isSurplus(value)) {
      return const ['food', 'bakery', 'dessert', 'fruit', 'drink', 'other'];
    }
    switch (normalizeType(value)) {
      case 'bakery':
        return const ['bakery', 'dessert', 'food', 'drink', 'other'];
      case 'butcher':
      case 'meat_shop':
        return const ['meat', 'food', 'other'];
      default:
        return const ['food', 'bakery', 'fruit', 'drink', 'other'];
    }
  }
}
