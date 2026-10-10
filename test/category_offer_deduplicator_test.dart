import 'package:flutter_test/flutter_test.dart';
import 'package:loqma/features/userhome/domain/entities/category_offer.dart';

void main() {
  CategoryOffer offer({
    required String id,
    required String title,
  }) {
    return CategoryOffer(
      id: id,
      title: title,
      ownerType: 'institution',
      status: 'active',
      createdAt: DateTime.utc(2026),
    );
  }

  group('uniqueCategoryOffersById', () {
    test('keeps one card per offer id and preserves the first occurrence', () {
      final result = uniqueCategoryOffersById([
        offer(id: 'offer-1', title: 'الأول'),
        offer(id: 'offer-1', title: 'نسخة مكررة'),
        offer(id: 'offer-2', title: 'عرض آخر'),
      ]);

      expect(result.map((item) => item.id), ['offer-1', 'offer-2']);
      expect(result.first.title, 'الأول');
    });

    test('ignores offers without a usable id', () {
      final result = uniqueCategoryOffersById([
        offer(id: '  ', title: 'بلا معرّف'),
        offer(id: 'offer-1', title: 'عرض صالح'),
      ]);

      expect(result, hasLength(1));
      expect(result.single.id, 'offer-1');
    });
  });
}
