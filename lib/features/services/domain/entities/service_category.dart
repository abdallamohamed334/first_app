// lib/features/services/domain/entities/service_category.dart

class ServiceCategory {
  final String id;
  final String slug;
  final String nameAr;
  final String? nameEn;
  final String? icon;
  final String? color;
  final String? description;
  final bool supportsIndividual;
  final bool supportsCompany;
  final String defaultPricing;
  final bool isActive;
  final int sortOrder;

  const ServiceCategory({
    required this.id,
    required this.slug,
    required this.nameAr,
    this.nameEn,
    this.icon,
    this.color,
    this.description,
    this.supportsIndividual = true,
    this.supportsCompany = true,
    this.defaultPricing = 'market',
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory ServiceCategory.fromMap(Map<String, dynamic> map) {
    return ServiceCategory(
      id: map['id']?.toString() ?? '',
      slug: map['slug']?.toString() ?? '',
      nameAr: map['name_ar']?.toString() ?? '',
      nameEn: map['name_en']?.toString(),
      icon: map['icon']?.toString(),
      color: map['color']?.toString(),
      description: map['description']?.toString(),
      supportsIndividual: map['supports_individual'] as bool? ?? true,
      supportsCompany: map['supports_company'] as bool? ?? true,
      defaultPricing: map['default_pricing']?.toString() ?? 'market',
      isActive: map['is_active'] as bool? ?? true,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'slug': slug,
        'name_ar': nameAr,
        'name_en': nameEn,
        'icon': icon,
        'color': color,
        'description': description,
        'supports_individual': supportsIndividual,
        'supports_company': supportsCompany,
        'default_pricing': defaultPricing,
        'is_active': isActive,
        'sort_order': sortOrder,
      };
}
