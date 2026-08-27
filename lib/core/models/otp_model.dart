import 'package:equatable/equatable.dart';

class OtpModel extends Equatable {
  final String id;
  final String phone;
  final String code;
  final bool isUsed;
  final DateTime expiresAt;

  const OtpModel({
    required this.id,
    required this.phone,
    required this.code,
    this.isUsed = false,
    required this.expiresAt,
  });

  factory OtpModel.fromJson(Map<String, dynamic> json) {
    return OtpModel(
      id: json['id'] ?? '',
      phone: json['phone'] ?? '',
      code: json['code'] ?? '',
      isUsed: json['is_used'] ?? false,
      expiresAt: DateTime.parse(
          json['expires_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'code': code,
      'is_used': isUsed,
      'expires_at': expiresAt.toIso8601String(),
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  @override
  List<Object?> get props => [id, phone, code, isUsed, expiresAt];
}
