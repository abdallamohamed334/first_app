import 'package:flutter_test/flutter_test.dart';
import 'package:wasla/core/utils/validators.dart';

void main() {
  group('Validators', () {
    test('normalizes Egyptian phone formats and Arabic digits', () {
      expect(Validators.normalizePhone('+20 1012345678'), '01012345678');
      expect(Validators.normalizePhone('٠١٠١٢٣٤٥٦٧٨'), '01012345678');
    });

    test('accepts valid Egyptian phones only', () {
      expect(Validators.isValidPhone('01012345678'), isTrue);
      expect(Validators.isValidPhone('01112345678'), isTrue);
      expect(Validators.isValidPhone('0212345678'), isFalse);
    });

    test('validates names and emails', () {
      expect(Validators.isValidName('محمد علي'), isTrue);
      expect(Validators.isValidName('x'), isFalse);
      expect(Validators.isValidEmail('User@example.com'), isTrue);
      expect(Validators.isValidEmail('not-an-email'), isFalse);
    });
  });
}
