// lib/features/volunteer/presentation/models/volunteer_model.dart

import 'package:loqma/core/models/user_model.dart';

// ✅ VolunteerModel
class VolunteerModel {
  final String id;
  final String name;
  final String? avatarUrl;
  final int points;
  final int level;

  const VolunteerModel({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.points,
    required this.level,
  });

  factory VolunteerModel.fromJson(Map<String, dynamic> json) {
    return VolunteerModel(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      points: json['points'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
    );
  }

  factory VolunteerModel.fromUserModel(UserModel user) {
    return VolunteerModel(
      id: user.id,
      name: user.name,
      avatarUrl: user.avatarUrl,
      points: user.points,
      level: user.level,
    );
  }
}

// ✅ UserRankInfo
class UserRankInfo {
  final int currentRank;
  final int totalVolunteers;
  final int points;
  final int mealsSaved;
  final int completedDeliveries;
  final int completedRequests;
  final int pointsToNextRank;
  final int nextRankPosition;
  final double progress;
  final String badge;
  final int level;

  const UserRankInfo({
    required this.currentRank,
    required this.totalVolunteers,
    required this.points,
    required this.mealsSaved,
    required this.completedDeliveries,
    required this.completedRequests,
    required this.pointsToNextRank,
    required this.nextRankPosition,
    required this.progress,
    required this.badge,
    required this.level,
  });
}
