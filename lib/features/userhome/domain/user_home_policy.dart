/// Business rules shared by User Home presentation and tests.
class UserHomePolicy {
  const UserHomePolicy._();

  static const Set<String> visibleInstitutionTypes = {
    'grocery',
    'supermarket',
    'bakery',
    'pastry_shop',
    'hotel',
    'wedding_hall',
  };

  static const Set<String> institutionCatalogSlugs = {
    'grocery',
    'supermarket',
    'bakery',
    'pastry_shop',
    'hotel',
    'wedding_hall',
  };

  static const Set<String> removedInstitutionTypes = {
    'poultry_shop',
    'game_store',
    'catering',
    'restaurant',
    'home_restaurant',
    'home-restaurants',
  };

  static bool isVisibleInstitutionType(String? value) {
    final normalized = value?.trim().toLowerCase();
    return normalized != null && visibleInstitutionTypes.contains(normalized);
  }

  static bool isAllowedCatalogSlug(String? value) {
    final normalized = value?.trim().toLowerCase();
    return normalized != null && institutionCatalogSlugs.contains(normalized);
  }

  static List<T> uniqueById<T>(
    Iterable<T> items,
    String Function(T item) idOf,
  ) {
    final seen = <String>{};
    final result = <T>[];
    for (final item in items) {
      final id = idOf(item).trim();
      if (id.isEmpty || !seen.add(id)) continue;
      result.add(item);
    }
    return result;
  }
}
