import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:loqma/core/errors/failures.dart';
import 'package:loqma/features/splash/domain/usecases/usecase.dart';
import '../repositories/auth_repository.dart';

@injectable
class CheckAuthStatus implements UseCase<bool, NoParams> {
  final AuthRepository _repository;

  CheckAuthStatus(this._repository);

  @override
  Future<Either<Failure, bool>> execute(NoParams params) async {
    try {
      final result = await _repository.isAuthenticated();
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}