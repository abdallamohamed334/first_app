import 'package:equatable/equatable.dart';

/// ✅ Base Failure class
abstract class Failure extends Equatable {
  final String message;

  const Failure({required this.message});

  @override
  List<Object> get props => [message];
}

/// ✅ Network related failures
class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'لا يوجد اتصال بالإنترنت'});
}

/// ✅ Server related failures
class ServerFailure extends Failure {
  const ServerFailure({super.message = 'حدث خطأ في الخادم'});
}

/// ✅ Authentication related failures
class AuthFailure extends Failure {
  const AuthFailure({super.message = 'يرجى تسجيل الدخول أولاً'});
}

/// ✅ Cache related failures
class CacheFailure extends Failure {
  const CacheFailure({super.message = 'حدث خطأ في التخزين المؤقت'});
}

/// ✅ Database related failures
class DatabaseFailure extends Failure {
  const DatabaseFailure({super.message = 'حدث خطأ في قاعدة البيانات'});
}

/// ✅ Validation related failures
class ValidationFailure extends Failure {
  const ValidationFailure({required super.message});
}

/// ✅ Storage related failures
class StorageFailure extends Failure {
  const StorageFailure({super.message = 'حدث خطأ في رفع الملف'});
}

/// ✅ Permission related failures
class PermissionFailure extends Failure {
  const PermissionFailure({super.message = 'لا يوجد صلاحية'});
}

/// ✅ Not found related failures
class NotFoundFailure extends Failure {
  const NotFoundFailure({super.message = 'العنصر غير موجود'});
}

/// ✅ Unknown failures
class UnknownFailure extends Failure {
  const UnknownFailure({super.message = 'حدث خطأ غير متوقع'});
}

/// ✅ Factory to create Failure from exception
class FailureFactory {
  static Failure fromException(dynamic exception) {
    if (exception is Failure) return exception;

    final errorMessage = exception.toString();

    if (errorMessage.contains('network') ||
        errorMessage.contains('connection') ||
        errorMessage.contains('internet')) {
      return const NetworkFailure();
    }

    if (errorMessage.contains('auth') ||
        errorMessage.contains('permission') ||
        errorMessage.contains('unauthorized')) {
      return const AuthFailure();
    }

    if (errorMessage.contains('not found') || errorMessage.contains('404')) {
      return const NotFoundFailure();
    }

    if (errorMessage.contains('storage') || errorMessage.contains('upload')) {
      return const StorageFailure();
    }

    if (errorMessage.contains('validation') ||
        errorMessage.contains('invalid')) {
      return ValidationFailure(message: errorMessage);
    }

    return UnknownFailure(message: errorMessage);
  }
}
