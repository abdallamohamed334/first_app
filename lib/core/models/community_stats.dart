import 'package:equatable/equatable.dart';

class CommunityStats extends Equatable {
  final int mealsSaved;
  final int familiesHelped;
  final double wastePrevented;
  final double co2Reduced;
  final int activeCharities;
  final int totalDonors;
  final double averageRating;
  final int activeVolunteers;
  final int participatingRestaurants;
  final int beneficiaryCharities;
  final DateTime lastUpdated;

  const CommunityStats({
    this.mealsSaved = 0,
    this.familiesHelped = 0,
    this.wastePrevented = 0,
    this.co2Reduced = 0,
    this.activeCharities = 0,
    this.totalDonors = 0,
    this.averageRating = 0,
    this.activeVolunteers = 0,
    this.participatingRestaurants = 0,
    this.beneficiaryCharities = 0,
    required this.lastUpdated,
  });

  factory CommunityStats.fromJson(Map<String, dynamic> json) {
    return CommunityStats(
      mealsSaved: _toInt(json['meals_saved']),
      familiesHelped: _toInt(json['families_helped']),
      wastePrevented: _toDouble(json['waste_prevented']),
      co2Reduced: _toDouble(json['co2_reduced']),
      activeCharities: _toInt(json['active_charities']),
      totalDonors: _toInt(json['total_donors']),
      averageRating: _toDouble(json['avg_rating']),
      activeVolunteers: _toInt(json['active_volunteers']),
      participatingRestaurants: _toInt(json['participating_restaurants']),
      beneficiaryCharities: _toInt(json['beneficiary_charities']),
      lastUpdated: _toDateTime(json['last_updated']) ?? DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'meals_saved': mealsSaved,
      'families_helped': familiesHelped,
      'waste_prevented': wastePrevented,
      'co2_reduced': co2Reduced,
      'active_charities': activeCharities,
      'total_donors': totalDonors,
      'avg_rating': averageRating,
      'active_volunteers': activeVolunteers,
      'participating_restaurants': participatingRestaurants,
      'beneficiary_charities': beneficiaryCharities,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  CommunityStats copyWith({
    int? mealsSaved,
    int? familiesHelped,
    double? wastePrevented,
    double? co2Reduced,
    int? activeCharities,
    int? totalDonors,
    double? averageRating,
    int? activeVolunteers,
    int? participatingRestaurants,
    int? beneficiaryCharities,
    DateTime? lastUpdated,
  }) {
    return CommunityStats(
      mealsSaved: mealsSaved ?? this.mealsSaved,
      familiesHelped: familiesHelped ?? this.familiesHelped,
      wastePrevented: wastePrevented ?? this.wastePrevented,
      co2Reduced: co2Reduced ?? this.co2Reduced,
      activeCharities: activeCharities ?? this.activeCharities,
      totalDonors: totalDonors ?? this.totalDonors,
      averageRating: averageRating ?? this.averageRating,
      activeVolunteers: activeVolunteers ?? this.activeVolunteers,
      participatingRestaurants:
          participatingRestaurants ?? this.participatingRestaurants,
      beneficiaryCharities: beneficiaryCharities ?? this.beneficiaryCharities,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  String get formattedMealsSaved => _formatCount(mealsSaved);

  String get formattedWastePrevented => _formatWeight(wastePrevented);

  String get formattedCo2Reduced => _formatWeight(co2Reduced);

  String get formattedActiveVolunteers => _formatCount(activeVolunteers);

  String get formattedParticipatingRestaurants =>
      _formatCount(participatingRestaurants);

  String get formattedBeneficiaryCharities =>
      _formatCount(beneficiaryCharities);

  static String _formatCount(int value) {
    return value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}k' : '$value';
  }

  static String _formatWeight(double value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)} طن';
    return '${value.toInt()} كجم';
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  @override
  List<Object?> get props => [
        mealsSaved,
        familiesHelped,
        wastePrevented,
        co2Reduced,
        activeCharities,
        totalDonors,
        averageRating,
        activeVolunteers,
        participatingRestaurants,
        beneficiaryCharities,
        lastUpdated,
      ];
}
