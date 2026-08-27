import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:loqma/core/errors/failures.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/data/datasources/local/auth_local_datasource.dart';

@Injectable(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  final AuthLocalDataSource _localDataSource;

  AuthRepositoryImpl(this._localDataSource);

  @override
  Future<bool> isAuthenticated() async {
    try {
      final token = await _localDataSource.getToken();
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<Either<Failure, String>> getToken() async {
    try {
      final token = await _localDataSource.getToken();
      if (token == null || token.isEmpty) {
        return const Left(CacheFailure(message: 'No token found'));
      }
      return Right(token);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> clearSession() async {
    try {
      await _localDataSource.clearSession();
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }
}
