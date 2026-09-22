class NearbyPlace {
  final String id;
  final String name;
  final String emoji;
  final double distance;
  final double? lat;
  final double? lng;
  final String? address;
  final int? offersCount;

  const NearbyPlace({
    required this.id,
    required this.name,
    required this.emoji,
    required this.distance,
    this.lat,
    this.lng,
    this.address,
    this.offersCount,
  });

  factory NearbyPlace.fromJson(Map<String, dynamic> json) {
    return NearbyPlace(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      emoji: json['emoji'] ?? '🏪',
      distance: (json['distance'] ?? 0).toDouble(),
      lat: json['lat']?.toDouble(),
      lng: json['lng']?.toDouble(),
      address: json['address'],
      offersCount: json['offers_count'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'distance': distance,
      'lat': lat,
      'lng': lng,
      'address': address,
      'offers_count': offersCount,
    };
  }
}
