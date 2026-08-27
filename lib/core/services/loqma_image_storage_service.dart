import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uploads image bytes to the two dedicated public buckets and returns the
/// public URL stored in database rows.
class LoqmaImageStorageService {
  final SupabaseClient _client;

  LoqmaImageStorageService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<String> uploadCharityLogo(XFile image) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('يجب تسجيل الدخول أولًا');
    return _upload(
      bucket: 'charity-images',
      path: 'charities/${user.id}/${_fileName(image)}',
      image: image,
      errorMessage: 'تعذر رفع صورة الجمعية، حاول مرة أخرى.',
    );
  }

  Future<String> uploadRestaurantOfferImage(XFile image) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('يجب تسجيل الدخول أولًا');
    return _upload(
      bucket: 'restaurant-offers',
      path: 'restaurants/${user.id}/${_fileName(image)}',
      image: image,
      errorMessage: 'تعذر رفع صورة الوجبة، حاول مرة أخرى.',
    );
  }

  Future<String> _upload({
    required String bucket,
    required String path,
    required XFile image,
    required String errorMessage,
  }) async {
    try {
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty) throw StateError(errorMessage);
      final extension = _extension(image.name);
      final finalPath = path.replaceFirst(
        RegExp(r'\.[a-zA-Z0-9]+$'),
        '.$extension',
      );
      await _client.storage.from(bucket).uploadBinary(
            finalPath,
            Uint8List.fromList(bytes),
            fileOptions: FileOptions(
              contentType: _contentType(extension),
              upsert: true,
            ),
          );
      return _client.storage.from(bucket).getPublicUrl(finalPath);
    } catch (_) {
      throw StateError(errorMessage);
    }
  }

  String _fileName(XFile image) {
    final extension = _extension(image.name);
    return '${DateTime.now().microsecondsSinceEpoch}.$extension';
  }

  String _extension(String name) {
    final extension = name.split('.').last.toLowerCase();
    return const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)
        ? extension
        : 'jpg';
  }

  String _contentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
