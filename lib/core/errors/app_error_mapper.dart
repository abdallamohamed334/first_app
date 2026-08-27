import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Converts technical exceptions into short, actionable Arabic messages.
/// Keep the original exception in debug logs only; never show it directly to users.
class AppErrorMapper {
  const AppErrorMapper._();

  static String message(Object error, {String fallback = 'حدث خطأ غير متوقع'}) {
    if (error is AppUserException) return error.message;

    if (error is AuthException) {
      return _authMessage(error);
    }

    if (error is PostgrestException) {
      return _postgrestMessage(error);
    }

    if (error is SocketException || error is TimeoutException) {
      return 'لا يوجد اتصال بالإنترنت. تحقق من الشبكة وحاول مرة أخرى.';
    }

    final raw = error.toString().toLowerCase();

    if (raw.contains('permission') ||
        raw.contains('row-level security') ||
        raw.contains('42501')) {
      return 'ليس لديك صلاحية لتنفيذ هذه العملية.';
    }

    if (raw.contains('camera') &&
        (raw.contains('denied') || raw.contains('permission'))) {
      return 'لم يتم السماح باستخدام الكاميرا. افتح إعدادات الهاتف واسمح بالكاميرا.';
    }

    if (raw.contains('expired') || raw.contains('منتهي')) {
      return 'انتهت صلاحية الطلب أو كود الاستلام.';
    }

    if (raw.contains('invalid') || raw.contains('غير صالح')) {
      return 'البيانات المدخلة غير صحيحة. راجعها وحاول مرة أخرى.';
    }

    if (kDebugMode) {
      debugPrint('[AppErrorMapper] $error');
    }
    return fallback;
  }

  static String _authMessage(AuthException error) {
    final code = error.statusCode?.toString() ?? '';
    final raw = '${error.message} $code'.toLowerCase();

    if (raw.contains('invalid login credentials') ||
        raw.contains('invalid credentials')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
    }
    if (raw.contains('email not confirmed')) {
      return 'يجب تأكيد البريد الإلكتروني قبل تسجيل الدخول.';
    }
    if (raw.contains('already registered') || raw.contains('already exists')) {
      return 'هذا البريد الإلكتروني مسجل بالفعل.';
    }
    if (raw.contains('rate limit') || code == '429') {
      return 'تم تجاوز عدد المحاولات. انتظر قليلًا ثم حاول مرة أخرى.';
    }
    return 'تعذر إتمام عملية الحساب. حاول مرة أخرى.';
  }

  static String _postgrestMessage(PostgrestException error) {
    final code = error.code ?? '';
    final raw = '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
        .toLowerCase();

    if (code == '23505' || raw.contains('duplicate')) {
      return 'هذه البيانات موجودة بالفعل.';
    }
    if (code == '23503' || raw.contains('foreign key')) {
      return 'تعذر ربط البيانات المطلوبة. حدّث الصفحة وحاول مرة أخرى.';
    }
    if (code == '23502' || raw.contains('not-null')) {
      return 'يوجد حقل مطلوب لم يتم إدخاله.';
    }
    if (code == '42501' || raw.contains('permission')) {
      return 'ليس لديك صلاحية لتنفيذ هذه العملية.';
    }
    if (code == 'PGRST116' || raw.contains('no rows')) {
      return 'لم يتم العثور على البيانات المطلوبة.';
    }
    if (raw.contains('community_generate_pickup_token')) {
      return 'لا يمكن إنشاء كود الاستلام الآن. تأكد أن الطلب جاهز للاستلام.';
    }
    if (raw.contains('community_complete_by_pickup_token')) {
      return 'كود الاستلام غير صحيح أو منتهي أو تم استخدامه من قبل.';
    }
    return 'تعذر حفظ البيانات. حاول مرة أخرى.';
  }
}

class AppUserException implements Exception {
  final String message;
  const AppUserException(this.message);

  @override
  String toString() => message;
}
