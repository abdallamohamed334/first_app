import 'package:equatable/equatable.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/services/supabase_service.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileLoaded extends ProfileState {
  final UserModel user;
  final int points;
  final int deliveriesCount;
  final int mealsSaved;
  final List<RewardData> rewards;
  final int completedTasks;

  const ProfileLoaded({
    required this.user,
    this.points = 0,
    this.deliveriesCount = 0,
    this.mealsSaved = 0,
    this.rewards = const [],
    this.completedTasks = 0,
  });

  @override
  List<Object?> get props => [
        user,
        points,
        deliveriesCount,
        mealsSaved,
        rewards,
        completedTasks,
      ];
}

class ProfileUpdated extends ProfileState {
  final UserModel user;

  const ProfileUpdated({required this.user});

  @override
  List<Object?> get props => [user];
}

class ProfilePasswordUpdated extends ProfileState {
  const ProfilePasswordUpdated();
}

class ProfileSignedOut extends ProfileState {
  const ProfileSignedOut();
}

class ProfileError extends ProfileState {
  final String message;

  const ProfileError(this.message);

  @override
  List<Object?> get props => [message];
}
