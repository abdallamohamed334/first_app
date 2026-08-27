import 'package:equatable/equatable.dart';

class Institution extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String type;
  final String? phone;
  final String? email;
  final String? logoUrl;
  final String? coverImageUrl;
  final String? description;
  final String? city;
  final String? address;
  final String status;
  final bool isVerified;

  const Institution({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    this.phone,
    this.email,
    this.logoUrl,
    this.coverImageUrl,
    this.description,
    this.city,
    this.address,
    this.status = 'active',
    this.isVerified = false,
  });

  bool get isActive => status.toLowerCase() == 'active';
  bool get isReadyForPublishing => isActive;

  String get typeLabel {
    switch (type.toLowerCase()) {
      case 'bakery':
        return 'مخبز';
      case 'grocery':
        return 'بقالة';
      case 'game_store':
        return 'متجر ألعاب';
      case 'supermarket':
        return 'سوبرماركت';
      case 'cafe':
        return 'كافيه';
      case 'hotel':
        return 'فندق';
      case 'restaurant':
        return 'مطعم';
      default:
        return 'مؤسسة';
    }
  }

  factory Institution.fromJson(Map<String, dynamic> json) {
    return Institution(
      id: _text(json['id']),
      userId: _text(json['user_id']),
      name: _text(json['name'], fallback: 'مؤسسة بدون اسم'),
      type: _text(json['institution_type'] ?? json['type'], fallback: 'other'),
      phone: _nullableText(json['phone']),
      email: _nullableText(json['email']),
      logoUrl: _firstText([json['logo_url'], json['image_url'], json['logo']]),
      coverImageUrl: _firstText([
        json['cover_image_url'],
        json['cover_url'],
      ]),
      description: _nullableText(json['description']),
      city: _nullableText(json['city']),
      address: _nullableText(json['address']),
      status: _text(json['status'], fallback: 'active'),
      isVerified: _asBool(json['is_verified']),
    );
  }

  Institution copyWith({
    String? id,
    String? userId,
    String? name,
    String? type,
    String? phone,
    String? email,
    String? logoUrl,
    String? coverImageUrl,
    String? description,
    String? city,
    String? address,
    String? status,
    bool? isVerified,
  }) {
    return Institution(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      logoUrl: logoUrl ?? this.logoUrl,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      description: description ?? this.description,
      city: city ?? this.city,
      address: address ?? this.address,
      status: status ?? this.status,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'institution_type': type,
        'phone': phone,
        'email': email,
        'logo_url': logoUrl,
        'cover_image_url': coverImageUrl,
        'description': description,
        'city': city,
        'address': address,
        'status': status,
        'is_verified': isVerified,
      };

  static String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String? _nullableText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static String? _firstText(List<dynamic> values) {
    for (final value in values) {
      final text = _nullableText(value);
      if (text != null) return text;
    }
    return null;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        type,
        phone,
        email,
        logoUrl,
        coverImageUrl,
        description,
        city,
        address,
        status,
        isVerified,
      ];
}
