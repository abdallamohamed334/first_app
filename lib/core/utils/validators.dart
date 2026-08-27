class Validators {
  Validators._();

  static String normalizeEmail(String value) => value.trim().toLowerCase();

  static String normalizePhone(String value) {
    var phone = value.trim().replaceAll(RegExp(r'[\s().-]'), '');
    if (phone.startsWith('00')) phone = '+${phone.substring(2)}';
    if (phone.startsWith('+20')) phone = '0${phone.substring(3)}';
    if (phone.startsWith('20') && phone.length == 12) {
      phone = '0$phone'.substring(0, 11);
    }
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    const westernDigits = '0123456789';
    phone = phone.split('').map((character) {
      final index = arabicDigits.indexOf(character);
      return index >= 0 ? westernDigits[index] : character;
    }).join();
    return phone;
  }

  static bool isValidName(String name) {
    final value = name.trim();
    if (value.length < 3 || value.length > 100) return false;
    return RegExp(r"^[a-zA-Z\u0600-\u06FF][a-zA-Z\u0600-\u06FF\s'_-]*$")
        .hasMatch(value);
  }

  static bool isValidPhone(String phone) {
    final normalized = normalizePhone(phone);
    return RegExp(r'^01[0125][0-9]{8}$').hasMatch(normalized);
  }

  static bool isValidEmail(String email) {
    final value = normalizeEmail(email);
    return RegExp(
      r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@'
      r'[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?'
      r'(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$',
    ).hasMatch(value);
  }

  static bool isValidPassword(String password) {
    final value = password.trim();
    return value.length >= 6 && value.length <= 128;
  }

  static String? nameError(String value) {
    if (value.trim().isEmpty) return 'اكتب الاسم';
    if (!isValidName(value)) return 'اكتب اسمًا صحيحًا من 3 أحرف على الأقل';
    return null;
  }

  static String? phoneError(String value) {
    if (value.trim().isEmpty) return 'اكتب رقم الهاتف';
    if (!isValidPhone(value)) return 'اكتب رقم هاتف مصري صحيح';
    return null;
  }

  static String? emailError(String value) {
    if (value.trim().isEmpty) return 'اكتب البريد الإلكتروني';
    if (!isValidEmail(value)) return 'اكتب بريدًا إلكترونيًا صحيحًا';
    return null;
  }

  static String? passwordError(String value) {
    if (value.isEmpty) return 'اكتب كلمة المرور';
    if (!isValidPassword(value)) {
      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    }
    return null;
  }
}
