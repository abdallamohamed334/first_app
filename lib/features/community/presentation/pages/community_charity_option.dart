class CommunityCharityOption {
  final String id;
  final String name;
  final String? logo;
  final String? address;
  final String? phone;
  final String? email;
  final String? description;
  final double? latitude;
  final double? longitude;
  final num? rating;
  final bool isVerified;

  const CommunityCharityOption({
    required this.id,
    required this.name,
    this.logo,
    this.address,
    this.phone,
    this.email,
    this.description,
    this.latitude,
    this.longitude,
    this.rating,
    this.isVerified = false,
  });

  factory CommunityCharityOption.fromMap(Map<String, dynamic> map) {
    double? asDouble(dynamic value) =>
        value == null ? null : double.tryParse(value.toString());

    return CommunityCharityOption(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'جمعية بدون اسم',
      logo: map['logo']?.toString(),
      address: map['address']?.toString(),
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      description: map['description']?.toString(),
      latitude: asDouble(map['latitude']),
      longitude: asDouble(map['longitude']),
      rating: map['rating'] is num
          ? map['rating'] as num
          : num.tryParse(map['rating']?.toString() ?? ''),
      isVerified: map['is_verified'] == true,
    );
  }
}
