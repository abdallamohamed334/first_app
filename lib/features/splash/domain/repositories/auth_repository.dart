import 'package:dartz/dartz.dart';
import 'package:loqma/core/errors/failures.dart';
import 'package:loqma/core/services/supabase_service.dart';

abstract class AuthRepository {
  AuthRepository(SupabaseService supabaseService);

  Future<bool> isAuthenticated();
  Future<Either<Failure, String>> getToken();
  Future<Either<Failure, void>> clearSession();
}
