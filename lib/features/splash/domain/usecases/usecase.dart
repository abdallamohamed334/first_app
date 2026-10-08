import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:loqma/core/errors/failures.dart';

/// Base class for all use cases
abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> execute(Params params);
}

/// Use case with no parameters
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}
