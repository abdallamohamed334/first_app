import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'image_upload_codec.dart';

class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<String?> uploadAvatar({
    required String userId,
    required XFile imageFile,
  }) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) return null;

    try {
      final authUserId = _client.auth.currentUser?.id;
      if (authUserId == null || authUserId != cleanUserId) return null;
      final stamp = DateTime.now().microsecondsSinceEpoch;
      // Use a new object on every upload. This avoids requiring Storage UPDATE
      // permission and prevents the browser/device from serving the old image.
      final path = '$cleanUserId/avatar_$stamp.webp';
      final bytes = await ImageUploadCodec.fromXFile(imageFile);
      if (bytes.isEmpty) return null;
      if (bytes.length > 5 * 1024 * 1024) return null;

      await _client.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: false,
              contentType: 'image/webp',
              cacheControl: '3600',
            ),
          );

      final baseUrl = _client.storage.from('avatars').getPublicUrl(path);
      final imageUrl = '$baseUrl?v=$stamp';
      final updated = await _client
          .from('users')
          .update({'avatar_url': imageUrl})
          .eq('id', cleanUserId)
          .select('id, avatar_url')
          .maybeSingle();
      if (updated == null) {
        throw StateError('لم يتم تحديث صورة المستخدم في قاعدة البيانات');
      }
      return imageUrl;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[ProfileAvatar] upload failed: ${error.runtimeType}');
        debugPrint('[ProfileAvatar] details: $error');
      }
      return null;
    }
  }

  Future<List<String>> uploadOfferImages({
    required String offerId,
    required List<XFile> images,
  }) async {
    final cleanOfferId = offerId.trim();
    if (cleanOfferId.isEmpty || images.isEmpty) return const <String>[];

    final uploadedUrls = <String>[];
    for (var index = 0; index < images.length; index++) {
      try {
        final bytes = await ImageUploadCodec.fromXFile(images[index]);
        if (bytes.isEmpty) continue;

        final path =
            'offers/$cleanOfferId/${DateTime.now().microsecondsSinceEpoch}_$index.webp';
        await _client.storage.from('offer_images').uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(
                upsert: false,
                contentType: 'image/webp',
                cacheControl: '3600',
              ),
            );
        uploadedUrls
            .add(_client.storage.from('offer_images').getPublicUrl(path));
      } catch (_) {
        // Preserve successful uploads and continue with the remaining images.
      }
    }
    return uploadedUrls;
  }

  Future<bool> deleteImage({
    required String bucket,
    required String path,
  }) async {
    final cleanBucket = bucket.trim();
    final cleanPath = path.trim();
    if (cleanBucket.isEmpty || cleanPath.isEmpty) return false;

    try {
      await _client.storage.from(cleanBucket).remove([cleanPath]);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteAvatar(String userId) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) return false;

    try {
      await _client.storage.from('avatars').remove(['$cleanUserId/avatar.jpg']);
      await _client.from('users').update({'avatar_url': null}).eq(
        'id',
        cleanUserId,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<XFile?> pickImageFromGallery() {
    return ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
      maxHeight: 800,
    );
  }

  Future<XFile?> pickImageFromCamera() {
    return ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 800,
      maxHeight: 800,
    );
  }

  Future<List<XFile>> pickMultipleImages({int maxCount = 5}) async {
    final images = await ImagePicker().pickMultiImage(
      imageQuality: 80,
      maxWidth: 800,
      maxHeight: 800,
    );
    return images.take(maxCount < 1 ? 1 : maxCount).toList(growable: false);
  }
}
