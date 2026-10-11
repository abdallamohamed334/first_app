import 'package:flutter_test/flutter_test.dart';
import 'package:loqma/features/community/presentation/utils/offer_expiry_helper.dart';

void main() {
  group('OfferExpiryHelper.effectiveExpiry', () {
    test('uses the stored expiry when it exists', () {
      final stored = DateTime.utc(2026, 10, 20, 12);
      final created = DateTime.utc(2026, 10, 10, 12);

      expect(
        OfferExpiryHelper.effectiveExpiry(
          expiresAt: stored,
          createdAt: created,
        ),
        stored,
      );
    });

    test('derives a seven-day expiry for a legacy offer without one', () {
      final created = DateTime.utc(2026, 10, 10, 12);

      expect(
        OfferExpiryHelper.effectiveExpiry(
          expiresAt: null,
          createdAt: created,
        ),
        DateTime.utc(2026, 10, 17, 12),
      );
    });

    test('returns null only when neither timestamp is available', () {
      expect(
        OfferExpiryHelper.effectiveExpiry(
          expiresAt: null,
          createdAt: null,
        ),
        isNull,
      );
    });
  });
}
