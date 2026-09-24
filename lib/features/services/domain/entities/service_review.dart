// lib/features/services/domain/entities/service_review.dart

class ServiceReview {
  final String id;
  final String requestId;
  final String fromUserId;
  final String toProviderId;
  final int rating;
  final String? comment;
  final List<String> images;
  final List<String> tags;
  final bool isAnonymous;
  final DateTime? createdAt;
  final String? userName;
  final String? userAvatar;

  const ServiceReview({
    required this.id,
    required this.requestId,
    required this.fromUserId,
    required this.toProviderId,
    required this.rating,
    this.comment,
    this.images = const [],
    this.tags = const [],
    this.isAnonymous = false,
    this.createdAt,
    this.userName,
    this.userAvatar,
  });

  /// اسم العرض (مجهول أو الاسم الحقيقي)
  String get displayName {
    if (isAnonymous) return 'مستخدم مجهول';
    return userName ?? 'مستخدم';
  }

  factory ServiceReview.fromMap(Map<String, dynamic> map) {
    return ServiceReview(
      id: map['id']?.toString() ?? '',
      requestId: map['request_id']?.toString() ?? '',
      fromUserId: map['from_user_id']?.toString() ?? '',
      toProviderId: map['to_provider_id']?.toString() ?? '',
      rating: (map['rating'] as num?)?.toInt() ?? 0,
      comment: map['comment']?.toString(),
      images: _stringList(map['images']),
      tags: _stringList(map['tags']),
      isAnonymous: map['is_anonymous'] as bool? ?? false,
      createdAt: _parseDate(map['created_at']),
      userName: map['user_name']?.toString(),
      userAvatar: map['user_avatar']?.toString(),
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return const [];
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null') return null;
    return DateTime.tryParse(text);
  }

  /// نص التاريخ النسبي
  String get timeAgo {
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(createdAt!);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} شهر';
    if (diff.inDays > 0) return '${diff.inDays} يوم';
    if (diff.inHours > 0) return '${diff.inHours} ساعة';
    if (diff.inMinutes > 0) return '${diff.inMinutes} دقيقة';
    return 'الآن';
  }
}
