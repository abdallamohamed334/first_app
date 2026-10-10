import 'package:flutter_test/flutter_test.dart';
import 'package:loqma/features/swap/data/swap_repository.dart';

void main() {
  group('SwapRepository contact validation', () {
    test('accepts Egyptian contact numbers with valid length and characters', () {
      expect(
        () => SwapRepository.validateContactNumbers(
          contactPhone: '01012345678',
          contactWhatsapp: '+20 1012345678',
        ),
        returnsNormally,
      );
    });

    test('rejects values outside the database trigger character limit', () {
      expect(
        () => SwapRepository.validateContactNumbers(
          contactPhone: '0-1-0-1-2-3-4-5-6-7-8',
          contactWhatsapp: '01012345678',
        ),
        throwsException,
      );
    });

    test('rejects numbers with fewer than eight digits', () {
      expect(
        () => SwapRepository.validateContactNumbers(
          contactPhone: '0101234',
          contactWhatsapp: '01012345678',
        ),
        throwsException,
      );
    });
  });
}
