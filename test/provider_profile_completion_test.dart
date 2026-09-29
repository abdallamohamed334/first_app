import 'package:flutter_test/flutter_test.dart';
import 'package:loqma/features/provider/data/repositories/service_provider_repository.dart';

void main() {
  final repository = ServiceProviderRepository();

  Map<String, dynamic> completeProvider({dynamic experienceYears = 5}) => {
        'profile_image_url': 'https://example.com/profile.webp',
        'bio': 'نبذة طويلة عن مقدم الخدمة وخبرته',
        'city': 'طنطا',
        'service_areas': ['طنطا'],
        'phone': '01012345678',
        'skills': ['صيانة'],
        'experience_years': experienceYears,
      };

  test('accepts numeric strings returned by PostgREST', () {
    expect(
      repository.checkProfileCompletion(
        completeProvider(experienceYears: '5'),
      ),
      isEmpty,
    );
  });

  test('rejects zero experience regardless of numeric representation', () {
    expect(
      repository.checkProfileCompletion(
        completeProvider(experienceYears: '0'),
      ),
      contains('سنوات الخبرة'),
    );
    expect(
      repository.checkProfileCompletion(
        completeProvider(experienceYears: 0.0),
      ),
      contains('سنوات الخبرة'),
    );
  });
}
